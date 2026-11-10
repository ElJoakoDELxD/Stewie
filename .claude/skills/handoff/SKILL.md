---
name: handoff
description: Save this chat's work into the agent's memory and branch. Use when the person asks for a handoff, when the context window is filling, and before any session ends.
---
# Handoff

1. **This chat's memory.** Update `.agent/chats/<chat-id>.md`, the file `header --declare` started:
   - **State:** what was done, and what is true now.
   - **Next:** the next step, concrete enough to start on.
   - **Open:** decisions that wait on the person.
   - **Files:** what was made or changed, as paths.
   - **Dead ends:** what was tried and failed, and why.
   - **Improvements:** each one, and where it went: the agent's memory, or the system. A fix to the system is recorded here with its files and change, as `rules/changing-the-system.md` says.
2. **The global memory.** Put what a later chat must know in one file per item in its category folder under `.agent/memory/`, following that folder's `_schema.md`; only what every chat needs goes in `core.md`, one statement per line. Write this chat's **Next** as an item in `open/`, as `open/_schema.md` says, so a new chat finds it in `INDEX.md`, and close the `open/` items this chat finished. Run `memory index` and `memory check`, and fix every problem it lists; a memory in the old format is migrated only with the person's consent, as `CHANGELOG.md` says. Write what was learned, not the story of the chat, and give each item its source (a commit, `file:line` or a URL), so a later chat can open the summary back to its detail.
3. **Save.** If the branch is public, run the `leak-check` skill first. Only write the files: the autosave at the end of the turn commits and pushes `.agent/`.
4. Say in one line what was saved, and in plain words if the autosave could not push.
