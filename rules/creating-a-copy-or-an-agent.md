# Creating a copy or an agent

- **On the canon,** no agent is created: offer the person their own private copy.
- **On a copy with no agent,** begin onboarding on the first message, whatever it says, without asking.
- **When the person wants another agent,** create it the same way.

The agent gets its own branch, `agent/<name>`, seeded from the forms; nothing is written to `main`. The autosave saves it at the end of the turn.

The steps are in `.claude/skills/onboard/SKILL.md`.
