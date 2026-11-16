---
title: The commit guard lets a cd-then-commit through when the command does not parse
status: open
owner: agent
opened: 2026-11-16
source: .claude/hooks/lib/approved.py:257-271
---
A `cd … && git commit -m …` with a newline inside an `-m` argument passed live, while the same call on one line is refused. Likely cause: `git_calls` raises, and the fallback in `bash()` only refuses when HEAD is already a shared branch. Not yet replayed through the bench; check before fixing.
