---
name: update
description: Bring this copy's template to the canon's latest release, or land a fix an agent recorded; custodian only. Use when the session start says the copy is behind, when the person asks for an update, or when the person brings an agent's proposal.
---
# Update

Only the custodian runs this skill: a chat attached to the `custodian` branch (`attach custodian`). An ordinary agent's fixes arrive as `rules/changing-the-system.md` says. Here *reviewed* means passed through `malicious-code-review`, and only `CLEAN` goes on.

A copy made with *Use this template* shares no git history with the canon, so an update applies the difference between two canon releases. It changes template paths only, on a new branch, and never touches an agent's branch.

## Take a release

Every git call alone.

1. This copy's version is the first `## x.y.z` in `CHANGELOG.md`.
2. `git fetch --no-tags https://github.com/ElJoakoDELxD/Stewie "+refs/tags/*:refs/canon/*"`. Never pass `--depth`: the ancestry check below needs the whole line.
3. `<latest>` is the newest release the canon has not withdrawn with a tag `withdrawn/v<x.y.z>`. Place the version before ordering it. No `refs/canon/v<this version>` means this copy's version is not a canon release: stop, and say that no direction can be claimed. If `git merge-base --is-ancestor refs/canon/v<this version> refs/canon/v<latest>` fails, the canon's line was rewritten: stop, and report it.
4. Same version: say the copy is current, and stop. Otherwise, show the person the `CHANGELOG.md` entries in between: they say why.
5. Open an issue on this copy for the update, `git switch -c update-<latest> main`, and resolve the pending proposals (below).
6. `git diff --binary refs/canon/v<this version> refs/canon/v<latest> --output=<tmp>/update.patch`, then have `<tmp>/update.patch` reviewed, then `git apply --3way <tmp>/update.patch`. On a conflict, keep what a `pending/` record explains; otherwise take the canon's.
7. If the memory format changed (the `format:` of `memory/_example/memory/core.md`, or of `MEMORY.md` in releases before it), say so; new `_schema.md` files reach an agent only this way. The release notes say how to migrate an agent's memory. That runs on the agent's own branch with the person's consent, never in this pull request.
8. Commit, have the branch's diff against `main` reviewed, push the branch, and open a pull request to `main` or give its compare link. Squash-merge it on the person's yes (`/principal-approves`).

## Land a fix an agent recorded

Start from an issue on this copy stating the change. On a new branch from `main`, make it, have the diff reviewed (and again whatever changes after), then push the branch and open a pull request. If it would serve every copy, offer to propose it to the canon before merging. Squash-merge it only on the person's yes (`/principal-approves`).

## Propose a fix to the canon

Only on the person's yes. The canon takes fixes as public issues: plain words, plus the solution's code if it helps. Nothing private goes in.

1. Make the fix here first (above); its pull request also carries the record of step 3.
2. Write it: what failed, how it showed, and the change. Open it with a GitHub tool or `gh`; failing both, give the person `https://github.com/ElJoakoDELxD/Stewie/issues/new?title=<title>&body=<body>`, URL-encoded, which opens it written.
3. Record `pending/<short-name>.md` in this copy, by the same pull request as the fix: the issue's link, the files, and the patch in a `diff` block.

At each update, each record: **still open:** leave it. **Accepted** (issue completed, change released) or **rejected** (not planned; ask the person whether to keep the change here): have the stored patch reviewed, reverse it with `git apply -R` on the update branch, take the canon's version if accepted, delete the record.
