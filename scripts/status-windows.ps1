[CmdletBinding()]
param([string] $ConfigPath)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$resolver = Join-Path $scriptDir 'credential-windows.ps1'
$config = if ($ConfigPath) { [IO.Path]::GetFullPath($ConfigPath) } elseif ($env:CODEX_HOME) {
    Join-Path ([IO.Path]::GetFullPath($env:CODEX_HOME)) 'config.toml'
} else { Join-Path $env:USERPROFILE '.codex\config.toml' }

if (-not (Test-Path -LiteralPath $config -PathType Leaf)) { throw "Codex configuration not found: $config" }
$probe = @'
import json,sys,tomllib
with open(sys.argv[1],"rb") as f: c=tomllib.load(f)
p=c.get("model_providers",{}).get("agentrouter",{})
a=p.get("auth",{})
print(json.dumps({"model":c.get("model"),"provider":c.get("model_provider"),"base_url":p.get("base_url"),"wire_api":p.get("wire_api","responses"),"auth_command":bool(a.get("command"))}))
'@
$raw = & python -c $probe $config
if ($LASTEXITCODE -ne 0) { throw 'Configuration is invalid TOML or Python could not parse it.' }
$state = $raw | ConvertFrom-Json
Write-Output "Configuration: $config"
Write-Output "Model: $($state.model)"
Write-Output "Selected provider: $($state.provider)"
Write-Output "Base URL: $($state.base_url)"
Write-Output "Wire API: $($state.wire_api)"
Write-Output "Command-backed auth configured: $($state.auth_command)"
if ($state.wire_api -eq 'chat') {
    Write-Output 'Protocol compatibility: incompatible with installed Codex 0.145.0; chat is rejected.'
}

$pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
if (-not $pwsh) { throw 'PowerShell 7 (pwsh.exe) is required to check the credential store.' }
& $pwsh.Source -NoLogo -NoProfile -File $resolver -Exists
$credentialStatus = $LASTEXITCODE
if ($credentialStatus -eq 0) { Write-Output 'Windows Credential Manager entry: present' }
else { Write-Output 'Windows Credential Manager entry: missing or unreadable'; exit 1 }
if ($state.provider -ne 'agentrouter' -or $state.base_url -ne 'https://co.agentrouter.org/v1' -or -not $state.auth_command) {
    throw 'AgentRouter provider configuration is incomplete.'
}
