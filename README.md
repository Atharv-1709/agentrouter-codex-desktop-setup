# AgentRouter setup for Codex on Windows and macOS

Configure **Codex only** inside the ChatGPT desktop app or Codex CLI. Windows
and macOS scripts are separate; see the compatibility notes before choosing a
provider configuration.

> [!IMPORTANT]
> This changes Codex only. It does not redirect ordinary ChatGPT Chat or Work.
> AgentRouter is a third-party service and will process prompts sent through
> this provider. Review its terms and privacy policy before using sensitive
> code or data.

This project is community-maintained and is not affiliated with OpenAI or
AgentRouter.

## Windows 10/11 (experimental compatibility)

AgentRouter's [Codex guide](https://co.agentrouter.org/portal/guide) documents
`https://co.agentrouter.org/v1`, `wire_api = "chat"`, and `gpt-5.5` as its
example. The installed Codex CLI 0.145.0 on the development machine rejects
`wire_api = "chat"` and requires `responses`. The Windows installer therefore
uses Responses so Codex accepts the configuration; AgentRouter's guide does
not document Responses support. **No authenticated AgentRouter request has
verified this combination.** It is experimental and may fail until the two
published interfaces agree.

AgentRouter's [public model list](https://co.agentrouter.org/portal/models)
currently lists GPT-5.5 but not `gpt-6-astra`. The installer keeps Astra as the
requested default without claiming AgentRouter supports it. You can explicitly
select the documented fallback with `-Model gpt-5.5`; the setup never switches
models automatically.

Prerequisites: Windows 10 or 11, Python 3.11+, Codex CLI 0.145.0+, PowerShell
7 (`pwsh.exe`), and an AgentRouter API key. The PowerShell credential helper
uses Windows Credential Manager and Codex's
`model_providers.<id>.auth.command` interface. Its
offline checks attempt a dummy-only round trip and report when local policy
blocks it. Credential Manager access was denied in the restricted development
shell, so successful Windows credential storage/retrieval is **not verified**
yet. Do not treat it as functional until the dummy-only check succeeds on the
target host. No real API key is used by automated tests.

From PowerShell in the repository:

```powershell
.\scripts\install-windows.ps1 -DryRun
.\scripts\test-windows.ps1 -Offline
```

Inspect the proposed provider settings and offline test results first. When you
choose to install, run:

```powershell
.\scripts\install-windows.ps1
```

The installer asks for confirmation, then opens a hidden local PowerShell
prompt and saves the key to Windows Credential Manager. It makes a timestamped
backup before changing `config.toml`. Keep the repository at the same path
because Codex runs the token resolver from that checkout. To choose the
documented model explicitly:

```powershell
.\scripts\install-windows.ps1 -Model gpt-5.5
```

Check status without sending a request, then opt into one live test only when
you are ready:

```powershell
.\scripts\status-windows.ps1
.\scripts\test-windows.ps1 -Live -Model gpt-6-astra
```

The live test sends only a fixed confirmation prompt from an empty temporary
directory, disables retries, and does not silently switch models. If Astra is
rejected, it reports the response and offers `gpt-5.5` as an explicit retry.
`AGENTROUTER_OK` means success; `401` means authentication or client support;
`402 Budget pool quota has been exhausted` means stop retrying until capacity
returns.

Rollback interactively with:

```powershell
.\scripts\rollback-windows.ps1
```

Use `-BackupPath <path>` to select a specific backup. Add
`-RemoveCredential` to remove this setup's Credential Manager entry after
configuration restore. Restart Codex and start a new task after install or
rollback.

To inspect the currently incompatible AgentRouter protocol as a **preview
only**, run the Python helper with `--wire-api chat --dry-run`. It refuses to
write a `chat` configuration because Codex 0.145.0 rejects it. Do not edit the
config manually to bypass that validation.

## macOS setup

The existing macOS workflow below continues to use macOS Keychain and the
Responses API at `https://agentrouter.org/v1`. It is separate from the Windows
guide above.

## What the macOS installer does

- Checks that it is running on macOS with Python 3.11+ and Codex installed.
- Validates the existing `~/.codex/config.toml` before changing it.
- Creates a timestamped backup in `~/.codex/backups/`.
- Preserves unrelated Codex settings.
- Configures AgentRouter's Responses-compatible endpoint and `gpt-6-astra`.
- Opens a hidden-input prompt and stores the API key in macOS Keychain.
- Keeps the configuration file private with `0600` permissions.

The API key is never written to this repository, `config.toml`, shell history,
or an environment file.

## Requirements

- macOS
- The current ChatGPT desktop app with Codex, or the Codex CLI
- Codex CLI 0.153.0 or newer for GPT-6 Astra
- Python 3.11 or newer
- An AgentRouter API key

Update the ChatGPT desktop app before starting. OpenAI's current documentation
is linked under [References](#references).

## Quick setup

Open Terminal and run:

```bash
git clone https://github.com/Itsme23476/agentrouter-codex-desktop-setup.git
cd agentrouter-codex-desktop-setup
./scripts/install-macos.sh
```

Enter `y` at `Continue? [y/N]`. When the hidden password prompt appears,
paste your AgentRouter API key into Terminal and press Return.
The key will not appear while you type or paste it.

Check the local settings, then test the connection once:

```bash
./scripts/status-macos.sh
./scripts/test-macos.sh
```

Confirm the status output shows model `gpt-6-astra`, provider `agentrouter`,
base URL `https://agentrouter.org/v1`, command-backed authentication configured,
and a present Keychain entry. A present Keychain entry alone does not confirm
that the provider settings were applied.

The connection test disables HTTP and stream retries for that run. A successful
model response of `AGENTROUTER_OK` confirms generation works. A `402` with
`Budget pool quota has been exhausted` means **installed, but AgentRouter's
shared pool currently has no capacity**. Keep the configuration; do not rerun
the installer or repeatedly retry the test just because of this response.

## See the model in the desktop app

You can load the installed configuration even while AgentRouter's pool is empty:

1. Fully quit the ChatGPT desktop app with **Command-Q**, then reopen it.
2. Select **Codex** and start a **new local Codex task**. Existing tasks may keep
   their original provider.
3. Click the **model and reasoning control beneath the message box**.
4. If your version shows **Advanced**, open it to choose a specific model.
   Look for **Astra / GPT-6 Astra** (`gpt-6-astra`), the configured default.

The exact labels and available controls vary by app version and rollout; see
[OpenAI's model-selection guide](https://learn.chatgpt.com/docs/models#choose-a-model).
AgentRouter is the provider selected in the configuration, while GPT-6 Astra
is the model. Do not expect a separate model named “AgentRouter” or assume
the model label alone proves which provider is active. Use the status check
to inspect the saved provider; the CLI test prints the provider it actually uses.

This repository does not add a provider-switching button or change the app's
interface. The desktop dropdown was not independently verified during the
September 25 setup; the steps above follow the official documentation. If the
model is missing after a restart, see [Troubleshooting](TROUBLESHOOTING.md).

## Current AgentRouter resource releases

AgentRouter's live System Notice, checked on **September 25, 2026**, changed
resource releases from three daily batches to **two**:

- Beijing: **10:00 and 19:00**
- UTC: **02:00 and 11:00**
- Athens on that date (EEST, UTC+3): **05:00 and 14:00**

Resources are available only while supplies last. This schedule can change;
open [AgentRouter](https://agentrouter.org/) and click the bell-shaped
**System Notice** before recording or troubleshooting.
Convert the live schedule using the user's timezone and the release date;
Athens changes offset with daylight saving time.

A response such as `402 Payment Required: Budget pool quota has been exhausted`
usually means the AgentRouter resource pool has run out for that release window.
It does not, by itself, mean the API key is invalid.

## Restore the original Codex setup

Run:

```bash
./scripts/rollback-macos.sh
```

The rollback tool shows the newest backup, asks before restoring it, and first
saves the current AgentRouter configuration as another recovery copy. It leaves
the Keychain entry in place by default.

To restore and also remove the AgentRouter key from Keychain:

```bash
./scripts/rollback-macos.sh --remove-keychain
```

Normal ChatGPT Chat continues to use the signed-in ChatGPT subscription whether
or not this Codex configuration is installed.

## Check status without making an API request

```bash
./scripts/status-macos.sh
```

This checks the model, provider, endpoint and whether the Keychain item exists.
It never prints the key.

## Use ChatGPT/Codex to perform the setup

If you prefer a guided setup, copy the prompt from
[SETUP_PROMPT.md](SETUP_PROMPT.md) into a new ChatGPT desktop Codex task. A
plain browser or mobile conversation cannot modify files or Keychain on your
Mac.

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for `401`, `402`, model-catalog
warnings, missing commands and rollback recovery.

## References

- [OpenAI: Advanced Codex configuration](https://learn.chatgpt.com/docs/config-file/config-advanced)
- [OpenAI: Codex configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- [OpenAI: Choose a model in the desktop app](https://learn.chatgpt.com/docs/models#choose-a-model)
- [OpenAI: GPT-6 Astra model](https://developers.openai.com/api/docs/models/gpt-6-astra)
- [AgentRouter](https://agentrouter.org/)

## License

[MIT](LICENSE)
