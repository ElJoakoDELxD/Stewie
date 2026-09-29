# Contributing

Stewie's template changes only by release. The custodian curates it, and the person who owns the canon approves every change by merging its pull request.

## Rules

1. **No new rule without a failure a user saw.** Name the failure in the pull request.
2. **A rule is a hook with a bench, a declared effect, a deny rule, at most one line in `CLAUDE.md`, or a file in `rules/` of at most 200 words that points to its full version.** Prose policies are not accepted.
3. **One open template pull request at a time.** Semver: a patch for fixes, a minor for features, a major for breaks.
4. **Every line, hook, skill and tool passes the removal test, and passes it again when the model changes.** Does it serve the north star at the head of `CLAUDE.md`, or the custodian's mandate? Would removing it cause a mistake the current model actually makes, shown by a bench, an experiment, or an incident named in the git log? Keep it only on two yeses; to re-test a hook, disable it for one ordinary session. When unsure, remove it and list it in the pull request as removable and restorable.
5. **Sizes only ratchet down.** A pull request that raises a CI ceiling says why in its description, and the owner of the canon approves it.
6. **The custodian's brake and release checklist apply** to every change: see `.claude/agents/custodian.md`.

## How to propose a change

Fork the repository, make the change on a branch, and open a pull request. `bash tests/run.sh` runs every bench; CI runs them again, with the size ceilings and the version check. The custodian reviews it as a diff.
