[CmdletBinding(DefaultParameterSetName = 'Get')]
param(
    [Parameter(ParameterSetName = 'Store', Mandatory = $true)]
    [switch] $Store,

    [Parameter(ParameterSetName = 'Get', Mandatory = $true)]
    [switch] $Get,

    [Parameter(ParameterSetName = 'Delete', Mandatory = $true)]
    [switch] $Delete,

    [Parameter(ParameterSetName = 'Exists', Mandatory = $true)]
    [switch] $Exists,

    [Parameter(ParameterSetName = 'SelfTest', Mandatory = $true)]
    [switch] $SelfTest,

    [Parameter(ParameterSetName = 'Get')]
    [Parameter(ParameterSetName = 'Store')]
    [Parameter(ParameterSetName = 'Delete')]
    [Parameter(ParameterSetName = 'Exists')]
    [Parameter(ParameterSetName = 'SelfTest')]
    [string] $TargetName = 'AgentRouter/Codex/windows-support-v1'
)

$ErrorActionPreference = 'Stop'
$stage = 'initialize'

$nativeSource = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security;

public static class AgentRouterCredentialStore
{
    private const int CRED_TYPE_GENERIC = 1;
    private const int CRED_PERSIST_LOCAL_MACHINE = 2;

    [StructLayout(LayoutKind.Sequential)]
    private struct FILETIME
    {
        public uint LowDateTime;
        public uint HighDateTime;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL
    {
        public int Flags;
        public int Type;
        public string TargetName;
        public string Comment;
        public FILETIME LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("Advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CredWrite(ref CREDENTIAL credential, int flags);

    [DllImport("Advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CredRead(string target, int type, int flags, out IntPtr credential);

    [DllImport("Advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool CredDelete(string target, int type, int flags);

    [DllImport("Advapi32.dll", EntryPoint = "CredFree")]
    private static extern void CredFree(IntPtr buffer);

    public static void Store(string target, SecureString secret)
    {
        IntPtr secureText = IntPtr.Zero;
        IntPtr blob = IntPtr.Zero;
        byte[] bytes = null;
        try
        {
            if (secret == null || secret.Length == 0) throw new InvalidOperationException();
            int size = checked(secret.Length * 2);
            if (size > 2560) throw new InvalidOperationException();
            secureText = Marshal.SecureStringToGlobalAllocUnicode(secret);
            bytes = new byte[size];
            Marshal.Copy(secureText, bytes, 0, size);
            blob = Marshal.AllocHGlobal(size);
            Marshal.Copy(bytes, 0, blob, size);
            CREDENTIAL c = new CREDENTIAL();
            c.Type = CRED_TYPE_GENERIC;
            c.TargetName = target;
            c.CredentialBlobSize = size;
            c.CredentialBlob = blob;
            c.Persist = CRED_PERSIST_LOCAL_MACHINE;
            c.UserName = "AgentRouter API key";
            if (!CredWrite(ref c, 0))
                throw NativeFailure("write");
        }
        finally
        {
            if (bytes != null) Array.Clear(bytes, 0, bytes.Length);
            if (blob != IntPtr.Zero)
            {
                for (int i = 0; i < secret.Length * 2; i++) Marshal.WriteByte(blob, i, 0);
                Marshal.FreeHGlobal(blob);
            }
            if (secureText != IntPtr.Zero) Marshal.ZeroFreeGlobalAllocUnicode(secureText);
        }
    }

    public static bool Exists(string target)
    {
        IntPtr ptr;
        if (!CredRead(target, CRED_TYPE_GENERIC, 0, out ptr))
        {
            int error = Marshal.GetLastWin32Error();
            if (error == 1168) return false;
            throw NativeFailure("read", error);
        }
        CredFree(ptr);
        return true;
    }

    public static bool Delete(string target)
    {
        if (CredDelete(target, CRED_TYPE_GENERIC, 0)) return true;
        int error = Marshal.GetLastWin32Error();
        if (error == 1168) return false;
        throw NativeFailure("delete", error);
    }

    private static InvalidOperationException NativeFailure(string operation)
    {
        return NativeFailure(operation, Marshal.GetLastWin32Error());
    }

    private static InvalidOperationException NativeFailure(string operation, int error)
    {
        return new InvalidOperationException("Credential Manager " + operation + " failed (Win32 error " + error + ": " + new Win32Exception(error).Message + ").");
    }

    public static void WriteToken(string target)
    {
        WriteToken(target, Console.Out);
    }

    public static void WriteToken(string target, System.IO.TextWriter output)
    {
        IntPtr ptr = IntPtr.Zero;
        char[] chars = null;
        try
        {
            if (!CredRead(target, CRED_TYPE_GENERIC, 0, out ptr))
            {
                int error = Marshal.GetLastWin32Error();
                if (error == 1168) throw new InvalidOperationException("credential unavailable");
                throw NativeFailure("read", error);
            }
            CREDENTIAL c = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
            if (c.CredentialBlob == IntPtr.Zero || c.CredentialBlobSize < 2 || c.CredentialBlobSize % 2 != 0)
                throw new InvalidOperationException("credential unavailable");
            chars = new char[c.CredentialBlobSize / 2];
            Marshal.Copy(c.CredentialBlob, chars, 0, chars.Length);
            output.Write(chars);
            output.WriteLine();
        }
        finally
        {
            if (chars != null) Array.Clear(chars, 0, chars.Length);
            if (ptr != IntPtr.Zero) CredFree(ptr);
        }
    }
}
'@

try {
    if (-not [Environment]::OSVersion.Platform.Equals([PlatformID]::Win32NT)) {
        throw 'Windows is required.'
    }
    if (-not ('AgentRouterCredentialStore' -as [type])) {
        $stage = 'load Windows credential API wrapper'
        Add-Type -TypeDefinition $nativeSource -Language CSharp
    }

    if ($Store) {
        $stage = 'read hidden credential input'
        $secret = Read-Host 'AgentRouter API key (hidden)' -AsSecureString
        try {
            $stage = 'write Credential Manager entry'
            [AgentRouterCredentialStore]::Store($TargetName, $secret)
        }
        finally {
            if ($null -ne $secret) { $secret.Dispose() }
        }
        Write-Output 'Credential stored in Windows Credential Manager.'
    }
    elseif ($Get) {
        $stage = 'retrieve Credential Manager entry'
        [AgentRouterCredentialStore]::WriteToken($TargetName)
    }
    elseif ($Exists) {
        $stage = 'check Credential Manager entry'
        if ([AgentRouterCredentialStore]::Exists($TargetName)) {
            Write-Output 'present'
        }
        else {
            Write-Output 'missing'
            exit 2
        }
    }
    elseif ($Delete) {
        $stage = 'delete Credential Manager entry'
        if ([AgentRouterCredentialStore]::Delete($TargetName)) {
            Write-Output 'Credential removed from Windows Credential Manager.'
        }
        else {
            Write-Output 'No matching credential was found.'
        }
    }
    elseif ($SelfTest) {
        $stage = 'initialize dummy-only Credential Manager test'
        if ([AgentRouterCredentialStore]::Exists($TargetName)) {
            throw 'Refusing to overwrite a pre-existing credential at the offline test target.'
        }
        # Prove the process can delete a missing test target before storing anything.
        [void][AgentRouterCredentialStore]::Delete($TargetName)
        $testToken = 'offline-test-' + [guid]::NewGuid().ToString('N')
        $testSecret = ConvertTo-SecureString -String $testToken -AsPlainText -Force
        $writer = [IO.StringWriter]::new()
        try {
            $stage = 'write dummy Credential Manager test entry'
            [AgentRouterCredentialStore]::Store($TargetName, $testSecret)
            $stage = 'read dummy Credential Manager test entry'
            [AgentRouterCredentialStore]::WriteToken($TargetName, $writer)
            $stage = 'verify dummy Credential Manager test output'
            if ($writer.ToString().TrimEnd("`r", "`n") -cne $testToken) {
                throw 'Offline credential round-trip failed.'
            }
            Write-Output 'PASS: dummy-only Credential Manager round-trip.'
        }
        finally {
            [void][AgentRouterCredentialStore]::Delete($TargetName)
            $testSecret.Dispose()
            $writer.Dispose()
        }
    }
}
catch {
    # Only emit known generic/status diagnostics; never emit the credential or arbitrary exception text.
    $exception = $_.Exception
    $safeMessage = $null
    $exceptionTypes = [System.Collections.Generic.List[string]]::new()
    while ($null -ne $exception) {
        $exceptionTypes.Add($exception.GetType().FullName)
        if ($exception.Message -match '^Credential Manager (write|read|delete) failed \(Win32 error \d+: [^\r\n]{1,160}\)\.$' -or
            $exception.Message -eq 'credential unavailable' -or
            $exception.Message -eq 'Refusing to overwrite a pre-existing credential at the offline test target.') {
            $safeMessage = $exception.Message
            break
        }
        $exception = $exception.InnerException
    }
    if ($safeMessage) {
        [Console]::Error.WriteLine("Credential operation failed: $safeMessage")
    } else {
        [Console]::Error.WriteLine("Credential operation failed during $stage (exception types: $($exceptionTypes -join ' -> ')).")
    }
    exit 1
}
