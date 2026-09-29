---
name: handoff
description: Write this chat's memory, fold into the agent's global memory what a later chat must know, then commit and push from .agent/. Use when the person asks for a handoff, when the context window is filling, and before any session ends.
---
# Handoff

1. **This chat's memory.** Update `.agent/chats/<chat-id>.md`, the file `header --declare` started:
   - **State:** what was done, and what is true now.
   - **Next:** the next step, concrete enough to start on.
   - **Open:** decisions that wait on the person.
   - **Files:** what was made or changed, as paths.
   - **Dead ends:** what was tried and failed, and why.
   - **Improvements:** each one, and where it went (the levels are in `CLAUDE.md`). A fix to the system is recorded here with its files and change, as `rules/changing-the-system.md` says.
2. **The global memory.** Run `cd .agent`, then `git pull --rebase`, since another chat of this agent may have written. Then put what a later chat must know in a small file under `.agent/memory/`, with one line for it in `MEMORY.md` (200 lines at most). Write what was learned, not the story of the chat.
3. **Push.** `git add -A`, then `git commit -m "<agent>: <what this chat did>"`, then `git push`, each alone, from `.agent/`.
4. Say in one line what was saved and pushed.
