# YouTube recording checklist

## Windows 10/11 recording

- Run the offline tests before recording; they use only a generated dummy
  credential.
- Show dry-run output and the explicit warning that AgentRouter's documented
  Chat Completions API conflicts with Codex 0.145.0's Responses-only config.
- Do not show or record the hidden API-key prompt or Credential Manager UI.
- Do not run the live request unless using a test key and you intentionally
  opt in. Astra is not in AgentRouter's current public list; do not imply it is
  supported.
- Demonstrate rollback from a disposable Codex config path, not a personal
  configuration.

## Before recording

- Update the ChatGPT desktop app and Codex CLI.
- Create a temporary AgentRouter key specifically for the demonstration.
- Check AgentRouter's live System Notice and convert the release times for your
  audience.
- Close private applications, notifications and unrelated Terminal tabs.
- Increase Terminal font size.
- Perform a private rehearsal and verify rollback.

## Suggested chapter order

1. Explain that this changes Codex mode, not ordinary ChatGPT Chat.
2. Explain the third-party privacy and billing implications.
3. Clone the repository.
4. Run the installer.
5. Pause or crop the recording while entering the API key.
6. Run the status check.
7. Run the harmless connectivity test.
8. Explain successful, `401` and `402` outcomes.
9. Restart the desktop app and open a new Codex task.
10. Show the model/reasoning control below the message box and **Advanced**, if
    present, to choose Astra / GPT-6 Astra. Explain that AgentRouter is the
    configured provider and may not appear in the model's label.
11. If the pool is empty, label the result “installed; generation unavailable”
    and demonstrate the controls without repeatedly sending requests. Do not
    imply the UI was verified if you could not actually open it.
12. Demonstrate rollback.

## Before publishing

- Review every frame containing Terminal or Keychain prompts.
- Search the recording transcript for fragments of the key.
- Rotate or revoke the demonstration key.
- Confirm no personal paths, email addresses or account identifiers are visible.
- Add links to the repository, OpenAI documentation and AgentRouter's current
  notice in the video description.
