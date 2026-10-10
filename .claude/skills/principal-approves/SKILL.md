---
name: principal-approves
description: The person's approval of one guarded act. Only the person types it; the model never invokes it.
disable-model-invocation: true
argument-hint: "[item]"
---
# Principal approves

The person typed this command. It is the only yes that unlocks a guarded act: a push to `candidate/*`, `custodian` or a tag, a push that rewrites, deletes or sends every branch, a merge of a pull request, a write to `main` or a shared branch through the GitHub tools, and attaching the custodian. The hook `.claude/hooks/lib/approved.py` finds it in the transcript as a turn the person typed. While the sandbox keeps the transcript out of reach, no tool result and no text of the model can stand in for it.

One approval unlocks one act. It is spent when the hook lets the act through, even if something else then stops it, and it lapses when the person sends another message first.

1. Find what it approves. With an argument, it is that pending item. Without one, it is the single open request. If none is open, or several are and no argument names one, ask which; do nothing yet.
2. Do what was approved, and only that, in one call that holds that act alone.
