#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This test currently supports macOS only." >&2
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "Codex was not found." >&2
  exit 1
fi

if ! "$SCRIPT_DIR/status-macos.sh"; then
  echo "Local setup validation failed; the API test was not attempted." >&2
  exit 1
fi

TEST_DIR="$(mktemp -d -t agentrouter-codex-test.XXXXXX)"
OUTPUT_FILE="$(mktemp -t agentrouter-codex-output.XXXXXX)"
trap 'rm -rf "$TEST_DIR" "$OUTPUT_FILE"' EXIT

echo
echo "Sending only a fixed confirmation prompt from an empty temporary folder..."

codex exec \
  -c model_providers.agentrouter.request_max_retries=0 \
  -c model_providers.agentrouter.stream_max_retries=0 \
  --ephemeral \
  --skip-git-repo-check \
  --sandbox read-only \
  --ignore-rules \
  --color never \
  -C "$TEST_DIR" \
  "Reply with exactly: AGENTROUTER_OK" \
  </dev/null 2>&1 | tee "$OUTPUT_FILE"
codex_status=${PIPESTATUS[0]}

if grep -q "AGENTROUTER_OK" "$OUTPUT_FILE" && [[ $codex_status -eq 0 ]]; then
  echo
  echo "SUCCESS: Codex received a GPT-6 Astra response through AgentRouter."
  exit 0
fi

if grep -Eqi "402|Budget pool quota has been exhausted" "$OUTPUT_FILE"; then
  echo
  echo "AGENTROUTER POOL EXHAUSTED: Authentication and routing reached AgentRouter,"
  echo "but the shared resource pool currently has no capacity."
  echo "Open https://agentrouter.org/ and check the live System Notice."
  exit 2
fi

if grep -Eqi "401|unauthorized" "$OUTPUT_FILE"; then
  echo
  echo "AUTHENTICATION ERROR: Check the Keychain entry and AgentRouter key status."
  exit 3
fi

echo
echo "TEST FAILED: Review the output above and TROUBLESHOOTING.md."
exit "${codex_status:-1}"
