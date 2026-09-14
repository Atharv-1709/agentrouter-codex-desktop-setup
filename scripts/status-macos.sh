#!/bin/bash
set -euo pipefail

CONFIG_PATH="${CODEX_HOME:-$HOME/.codex}/config.toml"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This status check currently supports macOS only." >&2
  exit 1
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Configuration not found: $CONFIG_PATH" >&2
  exit 1
fi

python3 - "$CONFIG_PATH" <<'PY'
from pathlib import Path
import sys
import tomllib

path = Path(sys.argv[1])
with path.open("rb") as handle:
    config = tomllib.load(handle)

provider = config.get("model_providers", {}).get("agentrouter", {})
auth = provider.get("auth", {})

print(f"Configuration: {path}")
print(f"Model: {config.get('model', '<not set>')}")
print(f"Selected provider: {config.get('model_provider', '<not set>')}")
print(f"Base URL: {provider.get('base_url', '<not set>')}")
print(f"Wire API: {provider.get('wire_api', '<not set>')}")
print(f"Command-backed authentication: {'configured' if auth.get('command') else 'missing'}")
PY

if /usr/bin/security find-generic-password \
  -s agentrouter-codex \
  -a codex >/dev/null 2>&1; then
  echo "Keychain entry: present"
else
  echo "Keychain entry: missing"
  exit 1
fi
