---
title: Git runs alone
status: current
date: 2026-10-16
trigger: bash (?:&&|\|\||[;|&\n(]|\$\()\s*(?:\w+=\S*\s+)*git\s
about: CLAUDE.md "Your own git calls"
enforce: deny
---
# Git runs alone

A git call that follows another command runs inside the sandbox. It cannot reach the signing service, and it lists the sandbox's temporary placeholder files as if they were untracked files. Start the command with `git`; for another directory, use `git -C <dir>`. Reminding did not teach it, so the call is blocked.
