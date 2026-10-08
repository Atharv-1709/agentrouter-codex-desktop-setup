# Copy-paste setup prompts

## Windows 10/11

For native Windows setup, review the Windows section in the README, then run
the repository's offline checks before installation:

```powershell
.\scripts\install-windows.ps1 -DryRun
.\scripts\test-windows.ps1 -Offline
```

Only after reviewing the proposed settings and test results, run this locally:

```powershell
.\scripts\install-windows.ps1
```

Enter the key only in its hidden PowerShell prompt. Never send the key through
chat, add it to config, or save it as a persistent environment variable. The
current Windows path requires PowerShell 7 (`pwsh.exe`) and uses Responses
because installed Codex 0.145.0 rejects Chat Completions, while the
AgentRouter guide still documents Chat Completions; authenticated live
compatibility is not verified. Astra is not on AgentRouter's current public
model list. To explicitly choose the documented GPT-5.5 fallback, pass
`-Model gpt-5.5`; never switch models without telling the user.

The live connection test is opt-in and sends a fixed prompt only when the user
runs this locally:

```powershell
.\scripts\test-windows.ps1 -Live -Model gpt-6-astra
```

Do not run it during repository development. Never use a real API key in
automated tests. Use `rollback-windows.ps1` to restore the config.

## macOS

Paste everything below into a **new Codex task in the ChatGPT desktop app on
macOS**. The task must have local computer and Terminal access.

---

Help me install the AgentRouter GPT-6 Astra Codex configuration from this
repository:

https://github.com/Itsme23476/agentrouter-codex-desktop-setup

Configure only Codex mode inside the ChatGPT desktop app. Do not attempt to
redirect ordinary ChatGPT Chat or Work, and do not change or sign me out of my
ChatGPT subscription.

Before doing anything, read the repository README, scripts and security notes.
Also verify the current official OpenAI documentation for custom Codex model
providers and command-backed authentication, and check AgentRouter's current
Codex instructions and System Notice. If the provider endpoint, authentication,
required client support, or Codex-only scope conflicts with the repository,
stop and explain the difference before installing. If only the resource-release
schedule changed, report the current schedule and continue: availability does
not prevent installing the configuration or explaining the model selector.

You have permission to:

1. Check the macOS and Codex prerequisites.
2. Clone the repository into an appropriate user-owned folder if it is not
   already present.
3. Run `./scripts/install-macos.sh`.
4. Open a visible Terminal window when the installer needs my API key.
5. Run `./scripts/status-macos.sh` and one harmless connectivity test using
   `./scripts/test-macos.sh`, with HTTP and stream retries disabled for that run.
6. If the Keychain entry already exists but the provider settings are missing,
   use the reviewed `scripts/merge_config.py` helper to complete the configuration
   with a fresh backup, without reading the key or asking me to enter it again.

Security requirements:

- Never ask me to paste the API key into this conversation.
- Never print, echo, log or inspect the API key.
- Let me enter it only into the installer's hidden Terminal prompt.
- Store it only in macOS Keychain, using service `agentrouter-codex` and account
  `codex`.
- Never put it in `config.toml`, a shell startup file, an environment file or
  the Git repository.
- Do not send project files or personal information during the connectivity
  test.
- If I accidentally paste a key into chat, do not repeat it or copy it into
  commands, files or tool arguments. Recommend revoking it and have me enter a
  replacement through the hidden Terminal prompt.

In Terminal, explain that I must first enter `y` at `Continue? [y/N]`, then
enter the key only when the hidden password prompt appears. If computer-control
tools block Terminal, explain the tool restriction and give me the exact local
installer command; do not try to bypass the restriction. After I say “done,”
verify the actual configuration and Keychain presence. An installer exit code
of zero can also mean the user cancelled, so it is not proof of installation.

The installer must preserve unrelated settings in `~/.codex/config.toml` and
create a timestamped backup before changing it. Do not replace the entire file.

Interpret test results carefully:

- A successful model response of `AGENTROUTER_OK` means generation works;
  seeing the text echoed in the test prompt alone is not proof of success.
- `401` normally means an authentication or supported-client problem.
- `402` with “Budget pool quota has been exhausted” means AgentRouter accepted
  the authenticated request but its resource pool is currently exhausted. It
  does not, by itself, mean my API key is invalid.
- For a `402`, read AgentRouter's live System Notice and tell me the next
  resource-release time in my current timezone. Do not repeatedly retry.
- Keep the installed configuration after a pool-exhausted `402` and report
  “installed; generation blocked by AgentRouter pool capacity.” Do not make
  viewing the model selector depend on a successful generation.

Finish by explaining how to see the configured model: fully quit the ChatGPT
desktop app with Command-Q, reopen it, select Codex, start a new local task,
and use the model/reasoning control beneath the message box. If Advanced is
available, use it to select Astra / GPT-6 Astra (`gpt-6-astra`). Check the current
official model-selection instructions rather than inventing an AgentRouter
button. AgentRouter is the configured provider, not a separate model name;
the model label alone does not verify the provider. Existing tasks may retain
their original provider. If app-control tools block inspection, state that
the actual dropdown was not verified and give the documented steps.

At the end, tell me:

- Whether the configuration and Keychain entry are present
- Which provider, endpoint and model Codex selected
- The connectivity-test result
- The exact backup path
- How to restore the previous Codex configuration
- Whether I need to restart the ChatGPT desktop app
- How to open the model selector, and whether its actual UI was verified

Proceed autonomously, stopping only when I must enter the API key, approve a
macOS permission, or resolve a genuine conflict in the current documentation.
