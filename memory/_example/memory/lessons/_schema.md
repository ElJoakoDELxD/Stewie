---
required: title, status, date
optional: trigger, about, repeat, source, links
repeatable: trigger
status: current, retired
archived: retired
---
# Lessons

One file per error or finding worth not repeating. A `trigger` brings it back by itself (see `knowledge/lessons/` for the forms); `about` quotes the rule it serves. Retire a lesson that stopped being true instead of deleting it. The third time its error happens, reminding has failed: stop, and escalate it by a pull request to `.claude/hooks/lessons/` with `enforce: deny`, which blocks the call with its fix.
