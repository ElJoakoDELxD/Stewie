---
name: orchestrate
description: Give the plan, the work and the check of a task each to the cheapest model that does it well. Use when delegating might give the same result for less, or when a task is harder than the model serving this session.
---
# Orchestrate

No rule here names a model: models change. Once per session, read the lineup at `https://platform.claude.com/docs/en/models/overview`: each model's ID, price and stated use. If the read fails, work alone.

1. **Size.** A task is hard if no written criteria can check its result, if it changes the system or anything public, or if it cannot be undone. The most capable model you can run plans and checks a hard task, as a subagent if it is not you.
2. **Plan.** Write the brief to a file: the goal, the acceptance criteria, the files, and what not to touch; the delegate knows nothing else. Delegate only what the criteria check, never the person's decisions.
3. **Delegate.** Give the brief to a subagent on the cheapest model whose stated use covers the task and that `.agent/memory/delegations.md` does not show failing it. Its transcript says which model served: an alias can differ by provider. A child session only for work that needs its own hooks or branch.
4. **Check.** A reader at the planner's level, which did not write the result, checks each criterion. A failure goes back once, one step up in price; then the planner does it.
5. **Record.** One line in `.agent/memory/delegations.md`: the date, the kind of task, the model that served, and whether it passed.

The header reports the model that served this turn, never the one you delegated to.
