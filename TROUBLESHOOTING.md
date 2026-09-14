# Troubleshooting

## `402 Payment Required: Budget pool quota has been exhausted`

The request reached AgentRouter but the resource pool assigned to the key has
no capacity available. AgentRouter's September 15, 2026 System Notice listed
resource releases three times a day—Beijing 00:00, 08:00 and 16:00—and said
resources are available only while supplies last.

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

## Restore manually

Backups are stored under:

```text
~/.codex/backups/config.toml.pre-agentrouter.*
```

Prefer `./scripts/rollback-macos.sh`, which validates the backup and creates a
recovery copy of the current configuration before restoring it.
