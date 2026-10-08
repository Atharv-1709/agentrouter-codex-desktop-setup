# Security policy

## Protect API keys

Never submit an AgentRouter API key in an issue, pull request, screenshot,
video, chat message or configuration example.

### macOS

The macOS installer stores the key as:

- Keychain service: `agentrouter-codex`
- Keychain account: `codex`

The public configuration contains only a command that asks macOS Keychain for
the secret when Codex needs it.

### Windows

The Windows installer prompts locally with hidden PowerShell input and stores
the key in Windows Credential Manager as a generic credential under target
`AgentRouter/Codex/windows-support-v1`. The key is not added to `config.toml`,
the repository, logs, or a persistent environment variable. Codex's
command-backed provider authentication launches `credential-windows.ps1 -Get`;
the resolver writes only the bearer token to stdout and uses generic,
non-secret diagnostics on stderr. Its `-SelfTest` uses a generated dummy value
and a unique target, then deletes it; automated tests must never use a real
AgentRouter key.

The resolver is stored in this checkout and the generated Codex config refers
to its absolute path. Keep the checkout in place while the provider is
configured. PowerShell execution policy must permit this local script; the
installer does not bypass policy. The local dummy Credential Manager test must
pass before treating the Windows credential path as verified. A sandbox or
managed policy can deny Credential Manager access; in that case the installer
must not be used and the resolver must not be described as working.

### Provider compatibility limits

The published AgentRouter Codex guide documents Chat Completions, while the
installed Codex CLI tested for this project rejects `wire_api = "chat"` and
requires Responses. The Windows installer uses Responses because the local
Codex build requires it, but AgentRouter does not currently document this
combination. Astra is absent from AgentRouter's public model list. Do not claim
either protocol/model combination works until an authenticated request
succeeds, and never use a real key in automated tests.

## Before recording a tutorial

- Use a temporary demonstration key and rotate it after recording.
- Keep Terminal history, notifications and password-manager overlays out of the
  recording.
- Never reveal `~/.codex/auth.json`, private configuration values or backup
  contents.
- On Windows, keep PowerShell windows and the Credential Manager UI out of
  recordings. Do not run the resolver in a way that displays its stdout.
- Review the video frame by frame before publishing.

## Reporting a vulnerability

Do not open a public issue containing credentials or exploitable details.
Contact the repository owner privately through their GitHub profile.
