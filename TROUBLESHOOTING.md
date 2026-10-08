# Troubleshooting

## Windows: `wire_api = "chat"` is rejected

The installed Codex CLI 0.145.0 reports that `chat` is no longer supported and
requires `wire_api = "responses"`. The AgentRouter Codex guide still documents
Chat Completions. The Windows installer uses Responses so Codex accepts the
config, but AgentRouter's Responses compatibility remains unverified. Do not
manually force `chat` into config. Check for updated guidance from both
projects before retrying.

## Windows: `gpt-6-astra` is rejected

The current public AgentRouter model list names GPT-5.5 but not Astra. The
Windows setup requests Astra explicitly and never switches models on its own.
If the test reports a model error, choose whether to test the documented
fallback with:

```powershell
.\scripts\test-windows.ps1 -Live -Model gpt-5.5
```

This sends a separate request only after you run it. It does not rewrite the
configured model.

## Windows Credential Manager access fails

Run the offline checks first:

```powershell
.\scripts\test-windows.ps1 -Offline
```

They use a generated dummy value, never a real key. If Credential Manager
returns access denied, a sandbox or local policy blocked the operation. Do not
use an environment-variable or plaintext config workaround. Ask your device
administrator to permit the documented Windows Credential Manager API for the
current user, or do not install this provider. Check that PowerShell execution
policy permits this local resolver; this project does not bypass policy.

## Windows: resolver cannot be launched

Codex runs `pwsh.exe -NoProfile -NonInteractive -File` against the
resolver in this checkout. Keep the repository at its original path and ensure
that PowerShell 7 is installed and can run local scripts under the current
execution policy. Run `status-windows.ps1` to confirm the configured command and credential entry;
the status check never prints the token.

## Windows backup and rollback

The installer reports the exact timestamped backup path. Restore the newest
backup interactively, preserving a recovery copy of the current file, with:

```powershell
.\scripts\rollback-windows.ps1
```

Use `-BackupPath <path>` to choose a backup. The key remains in Windows
Credential Manager unless you explicitly add `-RemoveCredential`.

## `402 Payment Required: Budget pool quota has been exhausted`

The request reached AgentRouter but the resource pool assigned to the key has
no capacity available. The configuration can remain installed, and you can
restart the app and inspect the model controls without waiting for a successful
generation. Do not reinstall or repeatedly retry the test to fix pool capacity.

AgentRouter's live System Notice checked on September 25, 2026 listed two daily
releases: Beijing **10:00 and 19:00**, or **02:00 and 11:00 UTC**. This replaces
the earlier three-batch schedule. In Athens during EEST, those are **05:00 and
14:00**; convert again when the date or daylight saving offset changes.

Open [AgentRouter](https://agentrouter.org/), click **System Notice**, and use
the current schedule. Do not assume the times in this repository remain
permanent.

## `401 Unauthorized`

Run the local status check:

```bash
./scripts/status-macos.sh
```

If the Keychain entry is missing, rerun the installer. Enter the key only into
the hidden Terminal prompt. If the entry exists, confirm that the key is still
active in the AgentRouter console and that Codex is a supported client.

## Model catalog warning

Some AgentRouter `/models` responses may not match the model-catalog shape that
Codex expects. The installer declares `gpt-6-astra` explicitly, so Codex can
still select it. A catalog warning is not necessarily a failed generation;
check the final HTTP or test result.
Explicit model selection does not guarantee that the desktop dropdown will
populate correctly. If the model is absent, record the non-secret error and
check current client/provider compatibility; do not claim the dropdown was
verified from the CLI result alone.

## `codex: command not found`

Update or reinstall the ChatGPT desktop app/Codex CLI. Confirm the command is
available:

```bash
codex --version
```

GPT-6 Astra requires Codex CLI 0.153.0 or newer according to current OpenAI
guidance.

## Python is too old

The merge helper uses Python's standard TOML parser and requires Python 3.11 or
newer. Install a current Python release, then rerun the installer.

## The desktop app still shows the previous provider

Fully quit the ChatGPT desktop app, reopen it and start a new Codex task.
Existing tasks may retain the provider selected when they were created.

In the new local Codex task, click the model/reasoning control below the message
box and open **Advanced**, if available, to select **Astra / GPT-6 Astra**.
AgentRouter is configured as the provider; this setup does not add a separate
“AgentRouter” model or a provider-switching button. UI labels vary by version;
see [OpenAI's model guide](https://learn.chatgpt.com/docs/models#choose-a-model).

## The installer exited successfully but AgentRouter is not selected

The installer also exits with status zero when cancelled at `Continue? [y/N]`.
Check the status output, not just the exit code: model, selected provider,
endpoint, command-backed authentication, and Keychain presence must all match
the README. Never paste the key at the initial `Continue?` prompt.

If the Keychain entry is already present and only the configuration is missing,
the reviewed merge helper can finish that step without touching the secret:

```bash
python3 ./scripts/merge_config.py --config "${CODEX_HOME:-$HOME/.codex}/config.toml"
./scripts/status-macos.sh
```

The helper creates a timestamped backup before editing. Do not use `--dry-run`
in a shared recording or chat: it prints the full configuration, which may
contain unrelated private values.

## Restore manually

Backups are stored under:

```text
~/.codex/backups/config.toml.pre-agentrouter.*
```

Prefer `./scripts/rollback-macos.sh`, which validates the backup and creates a
recovery copy of the current configuration before restoring it.
