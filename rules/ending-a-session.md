# Ending a session

Work that is not pushed does not exist. Before a session ends, or when `context.sh` says the window is filling:

1. Update this chat's own file, `.agent/chats/<chat-id>.md`: where things stand, the next step, and what is open.
2. Move what a later chat must know into `.agent/memory/`.
3. The autosave at the end of the turn commits and pushes `.agent/`; tell the person if it could not push.

The steps are in `.claude/skills/handoff/SKILL.md`.
