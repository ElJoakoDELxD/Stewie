# Ending a session

Work that is not pushed does not exist. Before a session ends, or when the window fills:

1. Update this chat's own file, `.agent/chats/<chat-id>.md`: where things stand, the next step, and what is open.
2. Move what a later chat must know into `.agent/memory/`, after pulling what other chats wrote.
3. Commit and push from `.agent/`.

The steps are in `.claude/skills/handoff/SKILL.md`.
