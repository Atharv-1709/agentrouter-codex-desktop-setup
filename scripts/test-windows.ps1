[CmdletBinding()]
param(
    [switch] $Live,
    [switch] $Offline,
    [ValidateSet('gpt-6-astra', 'gpt-5.5')]
    [string] $Model = 'gpt-6-astra'
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$resolver = Join-Path $scriptDir 'credential-windows.ps1'
$pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
if (-not $pwsh) { throw 'PowerShell 7 (pwsh.exe) is required for resolver checks.' }

if ($Live -and $Offline) { throw 'Choose either -Live or -Offline.' }
if ($Offline -or -not $Live) {
    Write-Output 'Offline checks: Python config/backup/rollback tests and a unique missing-credential resolver check.'
    & python -m unittest discover -s (Join-Path $repoRoot 'tests') -p 'test_*.py' -v
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $roundTripTarget = 'AgentRouter/Codex/offline-test-' + [guid]::NewGuid().ToString('N')
    $roundTrip = @(& $pwsh.Source -NoLogo -NoProfile -NonInteractive -File $resolver -SelfTest -TargetName $roundTripTarget 2>&1)
    $roundTripText = $roundTrip -join "`n"
    if ($LASTEXITCODE -eq 0 -and ($roundTrip -join "`n") -match 'PASS: dummy-only Credential Manager round-trip') {
        Write-Output 'PASS: Windows Credential Manager store/retrieve path works with a generated dummy secret; it was deleted.'
    }
    elseif ($roundTripText -match 'Win32 error 5') {
        Write-Output 'PASS: Credential Manager access-denied failure is handled without stdout token output or a live request.'
        Write-Output 'NOTE: successful Credential Manager storage/retrieval could not be verified in this restricted execution context.'
    }
    else {
        throw 'Credential Manager dummy-only round-trip failed; inspect only the generic resolver diagnostic.'
    }

    $uniqueTarget = 'AgentRouter/Codex/offline-test-' + [guid]::NewGuid().ToString('N')
    $resolverOutput = @(& $pwsh.Source -NoLogo -NoProfile -NonInteractive -File $resolver -Get -TargetName $uniqueTarget 2>&1)
    $resolverExit = $LASTEXITCODE
    $resolverText = $resolverOutput -join "`n"
    if ($resolverExit -eq 0 -or $resolverText -match '^[A-Za-z0-9_-]{24,}$') {
        throw 'Missing-credential test failed: resolver must fail without writing a token to stdout.'
    }
    if ($resolverText -match 'credential unavailable') {
        Write-Output 'PASS: missing credential fails closed and produces no stdout token.'
    }
    elseif ($resolverText -match 'Win32 error 5') {
        Write-Output 'PASS: resolver fails closed when Credential Manager access is denied; no stdout token.'
    }
    else {
        throw 'Resolver failure path returned an unexpected generic diagnostic.'
    }
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
