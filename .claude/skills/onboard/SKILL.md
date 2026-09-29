---
name: onboard
description: Make the person's own copy of Stewie, or create a new agent in this copy on its own branch. Use on the first message in a copy with no agent, whatever that message says; when the person asks for another agent; and on the canon when someone wants their own copy.
---
# Onboard

Greet briefly, in the person's language. They may not know what this is.

## 1. On the canon: make their copy

No agent is created on the canon. The person's copy is a private repository of their own, made from the template with the default branch only.

- If this session can create a repository under their account (a GitHub tool, or `gh` logged in as them), create it: `gh repo create <name> --private --template ElJoakoDELxD/Stewie`.
- Otherwise, walk them through the *Start* section of `README.md`.

Stop there: their agent is created in a chat on their copy.

## 2. In a copy: create the agent

Ask at most four questions, in one message, and skip what the person already said: the agent's name, the language, the timezone, and the goal. The name is lowercase letters, digits and hyphens.

Then, with every git call alone:

1. `git ls-remote --heads origin agent/<name>` must print nothing; if it prints a branch, the name is taken.
2. `git worktree add --orphan -b agent/<name> .agent` (git 2.42 or later).
3. `cp -R memory/_example/. .agent/ && cp .claude/agents/_example.md .agent/agent.md`
4. Fill `.agent/agent.md`: `name: <name>`, a one-line `description`, and the body from the answers. Keep the default effects.
5. `attach <name>`, which turns the Bash sandbox on, then `header --declare agent=<name>`, which starts this chat's memory file.
6. `cd .agent`, then `git add -A`, then `git commit -m "<name>: first chat"`, then `git push -u origin agent/<name>`.

Nothing is written to `main`. Tell the person, in one or two lines, that every new chat starts with this agent, or offers a choice once there are several.

A later change to `agent.md` is made by a chat that has not declared that agent: it edits the file on a new branch cut from `agent/<name>`, and opens a pull request for the person to approve.
