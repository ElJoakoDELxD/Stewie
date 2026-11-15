---
name: leak-check
description: Check a tree for leaked personal data, words and thoughts, and environment details before it becomes public. Use before every push of memory to a public branch and on the candidate tree before a release.
---
# Leak check

Public text is permanent (`CLAUDE.md`). Three reviewers read what would be published, each with one criterion and no other context, so none of them can excuse what it finds.

1. **Choose the target**: the files the push or release would publish, listed with `git diff --name-only <base>`, or the whole tree.
2. **Send three reviewers in parallel**, each a subagent given only the target's paths and one criterion:
   - **Personal data**: names, emails, phone numbers, addresses, account names, where the person lives or works, their time zone.
   - **Words and thoughts**: quotes of the person, private reasoning of the agent or the person, judgements about people.
   - **Environment and secrets**: tokens, keys, internal host names, machine paths, session or chat links, proxy and sandbox details.

   Each reports file, line and type, never the text it found. Use the cheapest model that finds every leak you plant in a copy of the target; `.claude/skills/orchestrate/SKILL.md` has the steps for choosing it.
3. **Fix every finding**, then run the three again. Push only when all three come back clean.
4. **A leak already pushed** stays in the history. Tell the person, and propose replacing the branch with a clean single-commit snapshot; rewriting a shared branch waits for their approval.
