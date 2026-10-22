---
title: Git runs alone
status: current
date: 2026-10-16
trigger: bash (?:&&|\|\||[;|&\n(]|\$\()\s*(?:\w+=\S*\s+)*git\s
example: bash cd .agent && git status
unless: a cloud container
about: CLAUDE.md "Your own git calls"
enforce: deny
---
# Git runs alone

A git call that follows another command runs inside the sandbox even where git alone runs outside it: it cannot reach the signing service, and it lists the sandbox's placeholder files as untracked. Start the command with `git`; for another directory, use `git -C <dir>`. Reminding did not teach it, so the call is blocked.
