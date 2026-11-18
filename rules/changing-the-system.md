---
trigger: edit CLAUDE.md
trigger: edit rules/*
trigger: edit knowledge/*
trigger: edit .claude/*
trigger: edit tools/*
trigger: edit tests/*
example: edit CLAUDE.md
example: edit rules/starting-a-chat.md
example: edit knowledge/models.md
example: edit .claude/settings.json
example: edit tools/bin/clock
example: edit tests/run.sh
---
# Changing the system

The system is this copy's `main`: the template, its hooks, skills and forms. An agent never edits it.

- **An agent** that finds a fix to the system records it in its chat's file, under *Improvements*, with the files and the change. At handoff it gives the person a short proposal to bring to a chat that runs as the custodian.
- **The custodian** alone changes `main`: each fix starts as an issue, passes `malicious-code-review`, and lands by a pull request it squash-merges on the person's yes (`/principal-approves`); it also brings in the canon's new releases. If the person wants, it proposes what serves every copy to the canon, as an issue.

On a copy, the custodian changes that copy's `main` the same way, never the canon's.

The steps are in `.claude/skills/update/SKILL.md`; the role is `.claude/agents/custodian.md`.
