---
title: Cut the first release from candidate/2.0.0
status: open
owner: agent
opened: 2026-11-16
source: .claude/agents/custodian.md
---
Steps, from `.claude/agents/custodian.md`:

1. `5s documents` by a fresh subagent; resolve each finding. In progress on 2026-11-16.
2. Leak-check on the whole tree, with the planted-leak calibration the skill asks for.
3. Onboarding test by the person on a throwaway copy; it means something only once `main` is the default branch.
4. Close `CHANGELOG.md`: `## Unreleased` sits above `## 2.0.0 — first public release`, and no tag exists; the version number is the person's call.
5. Create `main`: none exists and the default branch is `candidate/2.0.0`, so this is not a pull request; how is the person's call. `ci.yml` runs on push only for `main`.
6. Tag and GitHub release, by the person.

Batch the fixes from steps 1, 2 and 4 into one pull request.
