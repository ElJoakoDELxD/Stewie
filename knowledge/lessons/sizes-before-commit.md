---
title: Sizes before a commit
status: current
date: 2026-10-10
trigger: bash ^\s*git\s+commit\b
example: bash git commit -m "Fix the bench"
repeat: every
---
# Sizes before a commit

`tests/run.sh` does not run `tests/sizes.sh` or `tests/lint.sh`; CI does. Run all three before committing, and bring the person the exact counts when a ceiling moves.
