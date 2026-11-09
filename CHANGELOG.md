# Changelog

One entry per release, newest first.

## Unreleased

A chat knows how full its context window is. `tools/bin/context` reads the usage the transcript records for the latest turn, and `context.sh`, at each message, says nothing below half and, past 50%, 70% and 85%, says to run the handoff and offer a new chat: a long chat costs more every turn and fails when the window fills. Its text changes only between bands, so it does not break the prompt cache. The handoff gives each memory item its source, a commit, `file:line` or a URL, so a summary can be opened back to its detail. The canon can withdraw a release with a tag `withdrawn/v<x.y.z>`: a copy is not offered it, and a copy on it is told. These add 47 words to the governing prose, and its ceiling rises to match: they are new rules, not a repeat of old ones, and 5s trims what is said twice, not what is new.

## 2.0.0 — first public release

The first public release: a persistent colleague made of Claude Code and the person's own GitHub repository. Each agent is one file on its own branch, with its memory, its chat notes and its work beside it; its declared effects are its permissions. A new chat picks an agent, attaches its branch, and saves to it before it ends. The template lives only in `main`, and a custodian keeps it a stable product: every change is a release, with benches that run in CI.
