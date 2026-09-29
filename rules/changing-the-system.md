# Changing the system

The system is this copy's `main`: the template, its hooks, skills and forms. An agent never edits it.

- **An agent** that finds a fix to the system records it in its chat's file, under *Improvements*, with the files and the change. At handoff it gives the person a short proposal to bring to a chat that runs as the custodian.
- **The custodian** alone changes `main`: it lands the fix by a pull request the person approves, proposes to the canon what serves every copy, and brings in the canon's new releases.

The steps are in `.claude/skills/update/SKILL.md`; the role is `.claude/agents/custodian.md`.
