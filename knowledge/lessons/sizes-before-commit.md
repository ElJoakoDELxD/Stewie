---
trigger: bash ^\s*git\s+commit\b
repeat: every
---
# Sizes before a commit

`tests/run.sh` does not run `tests/sizes.sh`; CI does. Run both before committing, and bring the person the exact counts when a ceiling moves.
