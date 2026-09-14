# Security policy

## Protect API keys

Never submit an AgentRouter API key in an issue, pull request, screenshot,
video, chat message or configuration example.

The macOS installer stores the key as:

- Keychain service: `agentrouter-codex`
- Keychain account: `codex`

The public configuration contains only a command that asks macOS Keychain for
the secret when Codex needs it.

## Before recording a tutorial

- Use a temporary demonstration key and rotate it after recording.
- Keep Terminal history, notifications and password-manager overlays out of the
  recording.
- Never reveal `~/.codex/auth.json`, private configuration values or backup
  contents.
- Review the video frame by frame before publishing.

## Reporting a vulnerability

Do not open a public issue containing credentials or exploitable details.
Contact the repository owner privately through their GitHub profile.
