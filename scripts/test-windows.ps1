[CmdletBinding()]
param(
    [switch] $Live,
    [switch] $Offline,
    [switch] $SkipPythonTests,
    [ValidateSet('gpt-6-astra', 'gpt-5.5')]
    [string] $Model = 'gpt-6-astra'
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$resolver = Join-Path $scriptDir 'credential-windows.ps1'
$pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
if (-not $pwsh) { throw 'PowerShell 7 (pwsh.exe) is required for resolver checks.' }

function Invoke-ResolverProcess {
    param([string[]] $Arguments)

    # Capture the child process streams directly. PowerShell can promote a
    # nonzero native exit plus stderr to NativeCommandError when invoked with
    # $ErrorActionPreference='Stop', even when that failure is intentional.
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwsh.Source
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    # ProcessStartInfo.ArgumentList is missing in Windows PowerShell 5.1's
    # .NET Framework. Build a correctly escaped Windows command line instead.
    $quotedArguments = foreach ($argument in $Arguments) {
        $builder = [System.Text.StringBuilder]::new()
        [void]$builder.Append('"')
        $backslashes = 0
        foreach ($character in $argument.ToCharArray()) {
            if ($character -eq [char]92) {
                $backslashes++
                continue
            }
            if ($character -eq [char]34) {
                for ($i = 0; $i -lt (2 * $backslashes + 1); $i++) { [void]$builder.Append([char]92) }
                [void]$builder.Append([char]34)
            }
            else {
                for ($i = 0; $i -lt $backslashes; $i++) { [void]$builder.Append([char]92) }
                [void]$builder.Append($character)
            }
            $backslashes = 0
        }
        for ($i = 0; $i -lt (2 * $backslashes); $i++) { [void]$builder.Append([char]92) }
        [void]$builder.Append('"')
        $builder.ToString()
    }
    $startInfo.Arguments = $quotedArguments -join ' '

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw 'Could not start the PowerShell credential resolver.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    [pscustomobject]@{
        ExitCode = $process.ExitCode
        Stdout = $stdoutTask.GetAwaiter().GetResult()
        Stderr = $stderrTask.GetAwaiter().GetResult()
    }
    $process.Dispose()
}

if ($Live -and $Offline) { throw 'Choose either -Live or -Offline.' }
if ($SkipPythonTests -and -not $Offline) { throw '-SkipPythonTests can be used only with -Offline.' }
if ($Offline -or -not $Live) {
    if ($SkipPythonTests) {
        Write-Output 'Offline checks: PowerShell resolver checks only (Python suite already ran in the parent test process).'
    }
    else {
        Write-Output 'Offline checks: Python config/backup/rollback tests and a unique missing-credential resolver check.'
        & python -m unittest discover -s (Join-Path $repoRoot 'tests') -p 'test_*.py' -v
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    $roundTripTarget = 'AgentRouter/Codex/offline-test-' + [guid]::NewGuid().ToString('N')
    $roundTrip = Invoke-ResolverProcess @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $resolver, '-SelfTest', '-TargetName', $roundTripTarget)
    if ($roundTrip.ExitCode -eq 0 -and $roundTrip.Stdout -match 'PASS: dummy-only Credential Manager round-trip' -and -not $roundTrip.Stderr) {
        Write-Output 'PASS: Windows Credential Manager store/retrieve path works with a generated dummy secret; it was deleted.'
    }
    else {
        $diagnostic = $roundTrip.Stderr.Trim()
        if ($diagnostic -notmatch '^Credential operation failed: (Credential Manager (?:read|write|delete) failed \(Win32 error \d+: [^\r\n]{1,160}\)\.|Credential operation failed during [^\r\n]{1,160}\.)$') {
            $diagnostic = 'unrecognized resolver failure; output suppressed'
        }
        throw "Credential Manager dummy round-trip failed (exit $($roundTrip.ExitCode)): $diagnostic"
    }

    $uniqueTarget = 'AgentRouter/Codex/offline-test-' + [guid]::NewGuid().ToString('N')
    $missingCredential = Invoke-ResolverProcess @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $resolver, '-Get', '-TargetName', $uniqueTarget)
    if ($missingCredential.ExitCode -ne 1 -or $missingCredential.Stdout.Trim().Length -ne 0) {
        throw 'Missing-credential test failed: resolver must fail without writing a token to stdout.'
    }
    if ($missingCredential.Stderr.Trim() -cne 'Credential operation failed: credential unavailable') {
        $safeError = $missingCredential.Stderr.Trim()
        if ($safeError -notmatch '^Credential operation failed: Credential Manager read failed \(Win32 error \d+: [^\r\n]{1,160}\)\.$') {
            $safeError = 'unrecognized resolver failure; output suppressed'
        }
        throw "Missing-credential test got an unexpected resolver error (exit $($missingCredential.ExitCode)): $safeError"
    }
    Write-Output 'PASS: missing credential returned the expected error, exit code 1, and no stdout token.'
    Write-Output 'PASS: no live AgentRouter request was sent.'
    exit 0
}

$codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codex) { throw 'Codex CLI was not found.' }
& (Join-Path $scriptDir 'status-windows.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Local AgentRouter configuration/credential check failed; no request sent.' }

$testDir = Join-Path $env:TEMP ('agentrouter-codex-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDir | Out-Null
try {
    Write-Output "Testing model $Model using the configured AgentRouter provider and Responses protocol."
    Write-Output 'Only a fixed confirmation prompt is sent from an empty temporary directory.'
    $captured = & $codex.Source exec `
        -c model_providers.agentrouter.request_max_retries=0 `
        -c model_providers.agentrouter.stream_max_retries=0 `
        --ephemeral --skip-git-repo-check --sandbox read-only --ignore-rules `
        --color never -C $testDir --model $Model 'Reply with exactly: AGENTROUTER_OK' 2>&1
    $exitCode = $LASTEXITCODE
    $output = ($captured | Out-String)

    if ($exitCode -eq 0 -and $output -match 'AGENTROUTER_OK') {
        Write-Output 'AGENTROUTER_OK: successful test; Codex returned the expected response.'
        exit 0
    }
    if ($output -match '(?i)402|Budget pool quota has been exhausted') {
        Write-Output '402 Budget pool quota has been exhausted: resource pool unavailable; do not retry repeatedly.'
        exit 2
    }
    if ($output -match '(?i)401|unauthorized|authentication') {
        Write-Output '401: authentication or supported-client problem. No key or raw response was printed.'
        exit 3
    }
    if ($output -match '(?i)model.{0,30}(not found|unsupported|unavailable)|(?:not found|unsupported).{0,30}model') {
        $status = if ($output -match '\bHTTP\s*(\d{3})\b') { $Matches[1] } elseif ($output -match '\b(400|404|422)\b') { $Matches[1] } else { 'not reported' }
        Write-Output "Model rejected (HTTP $status): AgentRouter did not accept $Model. No automatic model switch was made."
        Write-Output 'The documented fallback is gpt-5.5; rerun explicitly with -Model gpt-5.5 only if you choose it.'
        Write-Output 'Redacted error: requested model is unsupported or unavailable; response body suppressed to protect credentials.'
        exit 4
    }

    Write-Output "TEST FAILED: Codex exit code $exitCode. Raw output suppressed to prevent accidental secret disclosure."
    exit 1
}
finally {
    if (Test-Path -LiteralPath $testDir) { Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue }
}
