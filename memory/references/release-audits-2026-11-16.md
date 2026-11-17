---
title: Audits before the first release, with triage
status: current
date: 2026-11-16
source: four subagent reports in chat cse_017LRgRV3k6jW45L7yXMQHDJ; branch release/2.0.0 at 31567a5
---
Reported by subagents, not yet each verified by the custodian unless marked.

Block 2.0.0 (one pull request into candidate/2.0.0, before the rename):
- `.github/workflows/release.yml` runs in every copy on push to main and would publish a copy's own release; it also tags after `tests/run.sh` only. Fix: run only in the canon, add `workflow_dispatch`, run the same checks as `ci.yml` before tagging.
- `README.md` says the sandbox keeps commands inside the repository; `memory/_example/tools/sandbox/activate.sh` runs git outside it, links bwrap and socat into `/usr/local/bin`, auto-allows sandboxed Bash, and allows `raw.githubusercontent.com` and `*.github.com`, which no code uses. Make the sentence true; drop unused hosts only if `tests/test-sandbox.sh` and a push still pass.
- `tools/bin/attach` runs the agent branch's `activate.sh` at session start with no check against the template copy. The person decides: a check with a bench, or a stated limit in the notes.
- `.claude/hooks/delegation-model.sh:15` cites `rules/delegating-a-task.md`, which does not exist.
- Rename candidate/2.0.0 to main is required: `guard-main.sh`, `ci.yml`, `release.yml`, rules and skills name main.
- Order: everything merges into candidate/2.0.0 first; after the rename Version check fails unless the version rises. Whether a rename fires `release.yml` is unverified.
- Issues #1 and #2 are open; #2 holds the release until its items land. Go through them point by point.
- CHANGELOG: fold Unreleased into 2.0.0; a user-level draft was written (scratchpad, not kept).

Record, not blocking: local install path is undocumented and fails on Linux without root; the clock zone jumps once `agent.md` sets a timezone; the gatekeeper judges curl and `gh pr create` only at Stop; MCP tools named get/list/search/read pass unjudged.

Verified by the custodian: shipped binaries match their packages, gatekeeper prompts match (6), actions are pinned (2026-11-16).

Commit guard: blocks when a call changes directory before a commit (`approved.py:202`); four live commits with a leading `cd` passed at the repository root, unexplained. The guard audit stopped before reporting.

"Graded", proposed: on the commit to tag, every `ci.yml` step succeeds and none is skipped, mutation passes, the gatekeeper record holds its thresholds, sizes, lint and binaries pass.
