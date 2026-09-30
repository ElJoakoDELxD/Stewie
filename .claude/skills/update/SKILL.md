---
name: update
description: Run only as the custodian. Bring this copy's template up to the canon's latest release and land a system fix an agent recorded, each by a pull request the person approves; if the person wants, propose to the canon what serves every copy. Use when the session start says the copy is behind, when the person asks for an update, or when the person brings an agent's proposal.
---
# Update

Only the custodian runs this skill: a chat attached to the `custodian` branch (`attach custodian`). An ordinary agent never edits `main`; it records the fix in its chat's memory, and the person brings it here.

A copy made with *Use this template* shares no git history with the canon, so an update applies the difference between two canon releases. It never merges the two histories. It changes template paths only, on a new branch, and never touches an agent's branch.

## Take a release

Every git call alone.

1. This copy's version is the first `## x.y.z` in `CHANGELOG.md`.
2. `git fetch --no-tags https://github.com/ElJoakoDELxD/Stewie "+refs/tags/*:refs/canon/*"`. Never pass `--depth`: the ancestry check below needs the whole line.
3. Place the version before ordering it. No `refs/canon/v<this version>` means this copy's version is not a canon release: stop, and say that no direction can be claimed. If `git merge-base --is-ancestor refs/canon/v<this version> refs/canon/v<latest>` fails, the canon's line was rewritten: stop, and report it.
4. Same version: say the copy is current, and stop. Otherwise, show the person the `CHANGELOG.md` entries in between: they say why.
5. Resolve the pending proposals first (below).
6. `git switch -c update-<latest> main`, then `git diff --binary refs/canon/v<this version> refs/canon/v<latest> --output=<tmp>/update.patch`, then `git apply --3way <tmp>/update.patch`. On a conflict, keep what a `pending/` record explains, and take the canon's version otherwise.
7. If the `format:` of `memory/_example/memory/MEMORY.md` changed, say so. The release notes say how to migrate an agent's memory. That runs on the agent's own branch with the person's consent, never in this pull request.
8. Commit, push the branch, and open a pull request to `main`, or give the person its compare link. Squash-merge it on the person's yes alone.

## Land a fix an agent recorded

On a new branch from `main`, make the change the proposal describes, push the branch, and open a pull request; squash-merge it only on the person's yes. If it would serve every copy, offer to propose it to the canon.

## Propose a fix to the canon

Only on the person's yes. The canon takes fixes as public issues: plain words, plus the solution's code if it helps. Nothing private goes in.

1. Land the fix here first (above).
2. Write it: what failed, how it showed, and the change. Open it with a GitHub tool or `gh`; failing both, give the person `https://github.com/ElJoakoDELxD/Stewie/issues/new?title=<title>&body=<body>`, URL-encoded, which opens it written.
3. Record `pending/<short-name>.md` in this copy, by the same pull request as the fix: the issue's link, the files, and the patch in a `diff` block.

At each update, per record: **accepted** (issue completed, change released): reverse the patch with `git apply -R`, take the canon's version, and delete the record. **Rejected** (not planned): ask the person whether to keep the change here or remove it, which is the same reversal. **Still open:** leave it.
