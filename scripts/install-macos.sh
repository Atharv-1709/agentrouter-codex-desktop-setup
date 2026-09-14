#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="${CODEX_HOME:-$HOME/.codex}/config.toml"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer currently supports macOS only." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3.11 or newer is required." >&2
  exit 1
fi

if ! python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 11))'; then
  echo "Python 3.11 or newer is required." >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "Codex was not found. Install or update the ChatGPT desktop app/Codex CLI first." >&2
  exit 1
fi

if [[ ! -x /usr/bin/security ]]; then
  echo "macOS Keychain command /usr/bin/security was not found." >&2
  exit 1
fi

echo "AgentRouter GPT-6 Astra setup for Codex"
echo "Configuration: $CONFIG_PATH"
echo
echo "Your existing configuration will be validated and backed up before editing."
echo "Your API key will be stored in macOS Keychain and will not be displayed."
echo
read -r -p "Continue? [y/N] " answer
case "$answer" in
  y|Y|yes|YES) ;;
  *) echo "Cancelled."; exit 0 ;;
esac

python3 "$SCRIPT_DIR/merge_config.py" --config "$CONFIG_PATH"

echo
echo "Paste your AgentRouter API key at the hidden prompt, then press Return."
/usr/bin/security add-generic-password \
  -a codex \
  -s agentrouter-codex \
  -l "AgentRouter Codex API Key" \
  -U \
  -w >/dev/null

chmod 600 "$CONFIG_PATH"

echo
echo "Setup complete. The key is stored in macOS Keychain."
echo "Run ./scripts/status-macos.sh, then ./scripts/test-macos.sh."
echo "Fully quit and reopen the ChatGPT desktop app before starting a new Codex task."
