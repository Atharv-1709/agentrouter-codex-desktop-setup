[CmdletBinding()]
param(
    [string] $ConfigPath,
    [ValidateSet('gpt-6-astra', 'gpt-5.5')]
    [string] $Model = 'gpt-6-astra',
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$resolver = Join-Path $scriptDir 'credential-windows.ps1'
$mergeTool = Join-Path $scriptDir 'merge_config_windows.py'

function Get-CodexConfigPath {
    if ($ConfigPath) { return [IO.Path]::GetFullPath($ConfigPath) }
    $root = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
    return [IO.Path]::GetFullPath((Join-Path $root 'config.toml'))
}

function Invoke-Python {
    param([string[]] $Arguments)
    & $python.Source @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Python helper failed with exit code $LASTEXITCODE." }
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'This script supports native Windows only.'
}
$osVersion = [Environment]::OSVersion.Version
$productName = ''
try {
    $productName = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name ProductName -ErrorAction Stop).ProductName
}
catch {
    # ProductName may be hidden by enterprise policy; the kernel version check remains available.
}
if ($osVersion.Major -lt 10 -or $osVersion.Build -lt 10240 -or $productName -match 'Windows Server') {
    throw 'Windows 10 or Windows 11 is required.'
}
$windowsRelease = if ($osVersion.Build -ge 22000) { 'Windows 11' } else { 'Windows 10' }
$python = Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $python -or $python.CommandType -ne 'Application') { throw 'Python 3.11+ is required.' }
$pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
if (-not $pwsh) { throw 'PowerShell 7 (pwsh.exe) is required for the command-backed credential resolver.' }
$pyVersionOutput = (& $python.Source --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $pyVersionOutput -notmatch '^Python\s+(\d+)\.(\d+)(?:\.(\d+))?') {
    throw "Could not determine Python version from '$($python.Source) --version'."
}
$pyVersion = [version]::new([int]$Matches[1], [int]$Matches[2], [int]$(if ($Matches[3]) { $Matches[3] } else { 0 }))
if ($pyVersion -lt [version]'3.11') { throw "Python 3.11+ is required; found Python $pyVersionOutput at $($python.Source)." }
$codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codex) { throw 'Codex CLI was not found. Install/update Codex before continuing.' }
$versionOutput = & $codex.Source --version 2>$null
if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch 'codex-cli\s+(\d+\.\d+\.\d+)') {
    throw 'Could not determine Codex CLI version.'
}
$codexVersion = [version]$Matches[1]
if ($codexVersion -lt [version]'0.145.0') {
    throw 'Codex 0.145.0 or newer is required for command-backed provider auth; update Codex first.'
}

$config = Get-CodexConfigPath
Write-Output "Codex CLI: $versionOutput"
Write-Output "$windowsRelease build $($osVersion.Build)"
Write-Output "Configuration: $config"
Write-Output 'Provider: AgentRouter; endpoint https://co.agentrouter.org/v1; wire_api=responses.'
Write-Output "Requested model: $Model (AgentRouter availability is unverified; public list currently names gpt-5.5)."
Write-Output 'The latest AgentRouter guide documents wire_api=chat, which this installed Codex build rejects.'

$pythonArgs = @($mergeTool, '--config', $config, '--resolver', $resolver, '--model', $Model, '--wire-api', 'responses')
if ($DryRun) {
    Write-Output 'DRY RUN: existing TOML (if present) and proposed merge validate; no credential prompt, backup, or write.'
    & $python.Source @pythonArgs --dry-run | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Python helper failed with exit code $LASTEXITCODE." }
    exit 0
}

# Validate before the user enters a secret. Do not print the merged config because
# unrelated existing settings may themselves contain private values.
& $python.Source @pythonArgs --dry-run | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Configuration preflight failed with exit code $LASTEXITCODE." }

Write-Output 'This changes only the user Codex provider settings in config.toml and creates a timestamped backup.'
$answer = Read-Host 'Continue? [y/N]'
if ($answer -notin @('y', 'Y', 'yes', 'YES')) { Write-Output 'Cancelled.'; exit 0 }

$credentialProbeTarget = 'AgentRouter/Codex/install-check-' + [guid]::NewGuid().ToString('N')
$credentialProbe = & $pwsh.Source -NoLogo -NoProfile -NonInteractive -File $resolver -SelfTest -TargetName $credentialProbeTarget 2>&1
if ($LASTEXITCODE -ne 0 -or ($credentialProbe -join "`n") -notmatch 'PASS: dummy-only Credential Manager round-trip') {
    throw 'Windows Credential Manager verification failed. Configuration is unchanged and no API key was requested.'
}

# Hidden local input; the secret is handed to Credential Manager through SecureString.
& $pwsh.Source -NoLogo -NoProfile -File $resolver -Store
if ($LASTEXITCODE -ne 0) { throw 'Credential Manager storage failed. Configuration was not changed.' }
& $pwsh.Source -NoLogo -NoProfile -File $resolver -Exists
if ($LASTEXITCODE -ne 0) { throw 'Credential Manager read-back failed. Configuration was not changed.' }

Invoke-Python $pythonArgs
Write-Output "Installed $Model through AgentRouter using Responses API."
Write-Output 'Restart Codex and start a new task to load this user-level provider configuration.'
