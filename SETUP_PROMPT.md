# Copy-paste setup prompt

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
Codex instructions and System Notice. If the current documentation conflicts
with the repository, stop and explain the difference instead of blindly
installing outdated settings.

You have permission to:

1. Check the macOS and Codex prerequisites.
2. Clone the repository into an appropriate user-owned folder if it is not
   already present.
3. Run `./scripts/install-macos.sh`.
4. Open a visible Terminal window when the installer needs my API key.
5. Run `./scripts/status-macos.sh` and one harmless connectivity test using
   `./scripts/test-macos.sh`.

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

The installer must preserve unrelated settings in `~/.codex/config.toml` and
create a timestamped backup before changing it. Do not replace the entire file.

Interpret test results carefully:

- `AGENTROUTER_OK` means the complete setup works.
- `401` normally means an authentication or supported-client problem.
- `402` with “Budget pool quota has been exhausted” means AgentRouter accepted
  the authenticated request but its resource pool is currently exhausted. It
  does not, by itself, mean my API key is invalid.
- For a `402`, read AgentRouter's live System Notice and tell me the next
  resource-release time in my current timezone. Do not repeatedly retry.

At the end, tell me:

- Whether the configuration and Keychain entry are present
- Which provider, endpoint and model Codex selected
- The connectivity-test result
- The exact backup path
- How to restore the previous Codex configuration
- Whether I need to restart the ChatGPT desktop app

Proceed autonomously, stopping only when I must enter the API key, approve a
macOS permission, or resolve a genuine conflict in the current documentation.
