# AgentRouter GPT-6 Astra setup for Codex on macOS

Configure the **Codex mode inside the ChatGPT desktop app** to use
`gpt-6-astra` through [AgentRouter](https://agentrouter.org/), while keeping the
normal ChatGPT experience and subscription unchanged.

> [!IMPORTANT]
> This changes Codex only. It does not redirect ordinary ChatGPT Chat or Work.
> AgentRouter is a third-party service and will process prompts sent through
> this provider. Review its terms and privacy policy before using sensitive
> code or data.

This project is community-maintained and is not affiliated with OpenAI or
AgentRouter.

## What the installer does

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
