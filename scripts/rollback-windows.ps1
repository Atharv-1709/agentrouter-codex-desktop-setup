[CmdletBinding()]
param(
    [string] $BackupPath,
    [string] $ConfigPath,
    [switch] $RemoveCredential
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mergeTool = Join-Path $scriptDir 'merge_config_windows.py'
$resolver = Join-Path $scriptDir 'credential-windows.ps1'
if (-not $ConfigPath) {
    $codexHomeDir = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
    $ConfigPath = Join-Path $codexHomeDir 'config.toml'
}
$ConfigPath = [IO.Path]::GetFullPath($ConfigPath)
$backupDir = Join-Path (Split-Path -Parent $ConfigPath) 'backups'

if (-not $BackupPath) {
    $candidate = Get-ChildItem -LiteralPath $backupDir -File -Filter 'config.toml.pre-agentrouter.*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.meta.json' } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($candidate) { $BackupPath = $candidate.FullName }
}
if (-not $BackupPath -or -not (Test-Path -LiteralPath $BackupPath -PathType Leaf)) {
    throw "No valid AgentRouter backup was found under $backupDir."
}

Write-Output "Backup: $BackupPath"
Write-Output "Destination: $ConfigPath"
$answer = Read-Host 'Restore this backup? [y/N]'
if ($answer -notin @('y', 'Y', 'yes', 'YES')) { Write-Output 'Cancelled.'; exit 0 }

& python $mergeTool --config $ConfigPath --resolver $resolver --rollback $BackupPath
if ($LASTEXITCODE -ne 0) { throw "Rollback failed with exit code $LASTEXITCODE." }
if ($RemoveCredential) {
    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if (-not $pwsh) { throw 'Configuration restored, but pwsh.exe is required to remove the credential.' }
    & $pwsh.Source -NoLogo -NoProfile -File $resolver -Delete
    if ($LASTEXITCODE -ne 0) { throw 'Configuration restored, but credential removal failed.' }
}
Write-Output 'Rollback complete. Restart Codex and start a new task.'
