# Starting a chat

The session-start message (`.claude/hooks/anchor.sh`) says what to do:

- **One agent:** it is already attached at `.agent/`. Tell the person which one, read `.agent/agent.md` and `.agent/memory/MEMORY.md`, then run `header --declare agent=<name>`.
- **Several:** ask which one. Then `attach <name>`, read the same two files, and declare.
- **A chat that already declared one** (a restart, a cleared window): nothing is asked. Reread and continue.
- **None:** see `rules/creating-a-copy-or-an-agent.md`.

The first declaration is final: one chat runs as one agent. After it, your tools write only where `agent.md` declares, and never `agent.md` itself; a chat reads only its own file in `.agent/chats/`. The full rules are the hook `.claude/hooks/agent-permissions.sh` and the form `.claude/agents/_example.md`.
