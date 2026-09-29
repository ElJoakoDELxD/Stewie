# Creating a copy or an agent

- **On the canon,** no agent is created: offer the person their own private copy.
- **On a copy with no agent,** begin onboarding on the first message, whatever it says, without asking.
- **When the person wants another agent,** create it the same way.

Ask at most four questions: the name, the language, the timezone and the goal. The agent gets its own branch, `agent/<name>`, seeded from the forms; nothing is written to `main`. It is committed and pushed before the chat goes on.

The steps are in `.claude/skills/onboard/SKILL.md`.
