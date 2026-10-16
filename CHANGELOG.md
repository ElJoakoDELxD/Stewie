# Changelog

One entry per release, newest first.

## Unreleased

An agent's memory is a core and categories. `memory/core.md`, at most 300 words, is the only memory every chat reads; everything else lives one file per item in `lessons/`, `decisions/`, `open/`, `references/` or `projects/`, each following its folder's `_schema.md`. `memory check` holds every file to its schema, and `memory index` writes `INDEX.md`, which nobody edits by hand.

**Migrating an agent's memory (format 1 to 2)**, on the agent's own branch and only with the person's consent:

1. Copy `memory/_example/memory/` from this release into `.agent/memory/`, without overwriting files that exist.
2. Move what every chat needs from `MEMORY.md` into `core.md`, and each other entry into one file in its category, with the fields its `_schema.md` requires. `backlog.md` items become files in `open/`, with `owner: person` or `owner: agent`; `delegations.md` moves to `references/delegations.md`.
3. Delete `MEMORY.md` and `backlog.md`, run `memory index`, and repeat `memory check` until it reports no problem.

## 2.0.0 — first public release

The first public release: a persistent colleague made of Claude Code and the person's own GitHub repository. Each agent is one file on its own branch, with its memory, its chat notes and its work beside it; its declared effects are its permissions. A new chat picks an agent, attaches its branch, and saves to it before it ends. The template lives only in `main`, and a custodian keeps it a stable product: every change is a release, with benches that run in CI.
