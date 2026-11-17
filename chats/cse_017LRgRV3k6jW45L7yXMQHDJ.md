# Chat cse_017LRgRV3k6jW45L7yXMQHDJ

Agent: custodian. Started 15-11-2026.

## State
- PRs #3, #4, #5 merged into candidate/2.0.0.
- Branch fix/5s-documents: origin has 31567a5; local adds 9321dc0 (delegation note), 3650392 (release workflow only from the canon after CI, workflow_dispatch on CI, README sandbox sentence, refusal cites the orchestrate skill) 8ea6c40 (orchestrate by role and tier, budget 7096) and the attach sandbox-kit check (amended into one commit, see git log). Not pushed; no pull request or CI yet. malicious-code-review on 3650392: CLEAN. Benches, sizes (7018 of 7021 words) and lint pass.
- Commit guard cause proven from the transcript: a call that changes directory before a commit is refused, any other passes; no unexplained passes. Fail-open paths for push or merge are unchecked.
- The advisor timed out on its last call; nothing returned. Do not retry blindly: each call rereads the whole conversation.
- Memory is audited clean (leak-check, three reviewers) but not pushed.

## Next
- With the person's approval, one push each: custodian memory, then fix/5s-documents. Then open the pull request into candidate/2.0.0 and read its CI step by step.
- Sandbox kit: the person chose to verify it. `attach` now runs `.agent/tools/sandbox/activate.sh` only if the kit equals the committed template's; three opus merge reviews, last CLEAN. Accepted limits: checked once per attach; local git write access can change HEAD; git archive honours export attributes. The restore advice was verified by hand, not by a bench; no bench for a missing committed template.
- Then: issues #1 and #2 point by point; fold Unreleased into 2.0.0 (user-level draft, no internal numbers); decide naming sweep; check guard-main covers main before the rename; the person renames candidate/2.0.0 to main; the onboarding test; tag.
- Header could show the advisor's model: `memory/open/header-advisor-model.md`.

## Open
- The person: issues #1 and #2 scope; naming sweep now or later.

## Files
- fix/5s-documents: 16 files against candidate/2.0.0.
- Audit findings: `memory/references/release-audits-2026-11-16.md`. Model use: `memory/decisions/capable-model-use.md`.
