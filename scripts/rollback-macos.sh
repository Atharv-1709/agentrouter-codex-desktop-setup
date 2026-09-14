#!/bin/bash
set -euo pipefail

CONFIG_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG_PATH="$CONFIG_DIR/config.toml"
BACKUP_DIR="$CONFIG_DIR/backups"
REMOVE_KEYCHAIN=0
REQUESTED_BACKUP=""

usage() {
  echo "Usage: $0 [--backup PATH] [--remove-keychain]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup)
      [[ $# -ge 2 ]] || { usage >&2; exit 1; }
      REQUESTED_BACKUP="$2"
      shift 2
      ;;
    --remove-keychain)
      REMOVE_KEYCHAIN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This rollback tool currently supports macOS only." >&2
  exit 1
fi

if [[ -n "$REQUESTED_BACKUP" ]]; then
  BACKUP_PATH="$REQUESTED_BACKUP"
else
  BACKUP_PATH="$(find "$BACKUP_DIR" -maxdepth 1 -type f \
    -name 'config.toml.pre-agentrouter.*' -print 2>/dev/null | sort | tail -n 1)"
fi

if [[ -z "$BACKUP_PATH" || ! -f "$BACKUP_PATH" ]]; then
  echo "No AgentRouter pre-install backup was found in $BACKUP_DIR" >&2
  exit 1
fi

python3 - "$BACKUP_PATH" <<'PY'
from pathlib import Path
import sys
import tomllib

path = Path(sys.argv[1])
with path.open("rb") as handle:
    tomllib.load(handle)
print(f"Validated backup: {path}")
PY

echo "This will restore: $BACKUP_PATH"
echo "Destination: $CONFIG_PATH"
read -r -p "Continue? [y/N] " answer
case "$answer" in
  y|Y|yes|YES) ;;
  *) echo "Cancelled."; exit 0 ;;
esac

mkdir -p "$BACKUP_DIR"
if [[ -f "$CONFIG_PATH" ]]; then
  RECOVERY_PATH="$BACKUP_DIR/config.toml.agentrouter-state.$(date '+%Y-%m-%dT%H%M%S')"
  cp -p "$CONFIG_PATH" "$RECOVERY_PATH"
  chmod 600 "$RECOVERY_PATH"
  echo "Saved current AgentRouter state: $RECOVERY_PATH"
fi

cp -p "$BACKUP_PATH" "$CONFIG_PATH"
chmod 600 "$CONFIG_PATH"
echo "Original Codex configuration restored."

if [[ $REMOVE_KEYCHAIN -eq 1 ]]; then
  if /usr/bin/security delete-generic-password \
    -s agentrouter-codex \
    -a codex >/dev/null 2>&1; then
    echo "AgentRouter Keychain entry removed."
  else
    echo "No matching AgentRouter Keychain entry was found."
  fi
fi

echo "Fully quit and reopen the ChatGPT desktop app before starting a new Codex task."
