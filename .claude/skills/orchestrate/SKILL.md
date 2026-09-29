---
name: orchestrate
description: Plan a task, delegate it to a cheaper model, and check the result against the plan. Use when a task might come out as good, and cheaper, delegated.
---
# Orchestrate

It runs only when `knowledge/models.md` allows your header's model to orchestrate, and delegating gives the same result at a lower cost; otherwise do the work yourself.

1. **Plan.** Write the brief to a file: the goal, the acceptance criteria, the files, and what not to touch. The brief is all the delegate knows.
2. **Delegate.** Hand the brief's path to a subagent on a cheaper model (`sonnet` or `haiku`). A child session is only for an experiment that needs its own hooks or branch.
3. **Check.** Read the result against the brief, criterion by criterion, as a reader that did not write it. A failed criterion goes back once, with the reason; after that, do it yourself.

The header reports the model and effort that served this turn. What you delegate to is a different fact, and it never changes the header.
