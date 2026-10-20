---
title: The gatekeeper's cases
status: current
date: 2026-10-20
trigger: edit .claude/hooks/gatekeeper.md
about: CLAUDE.md "A blocked tool call names its rule"
---
# The gatekeeper's cases

A changed criterion or model makes `tests/gatekeeper-cases/record.json` stale, and the gatekeeper bench fails. Build the cases with `cases.py build`, give each `prompt.txt` to a subagent on the gatekeeper's model with the instruction it prints, and write the answers with `cases.py record`. Read each miss or false block before its rate.
