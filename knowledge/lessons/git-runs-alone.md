---
title: Git runs alone
status: current
date: 2026-10-10
trigger: bash (?:&&|\|\||[;|&\n(]|\$\()\s*(?:\w+=\S*\s+)*git\s
about: CLAUDE.md "Your own git calls"
repeat: every
---
# Git runs alone

A git call that follows another command runs inside the sandbox. It cannot reach the signing service, and it lists the sandbox's temporary placeholder files as if they were untracked files. Start the command with `git`.
