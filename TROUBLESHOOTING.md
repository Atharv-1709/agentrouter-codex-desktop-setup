# Troubleshooting

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
