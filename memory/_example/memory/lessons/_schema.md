---
required: title, status, date
optional: trigger, example, unless, kind, about, repeat, source, links
repeatable: trigger, example, unless
status: current, retired
archived: retired
kind: error, reminder
---
# Lessons

One file per error or finding worth not repeating. A `trigger` brings it back by itself (see `knowledge/lessons/` for the forms), and an `example` in the same form proves it fires; `unless` stands it down where the latest isolation record is that text; `about` quotes the rule it serves; `kind: error` marks a trigger that catches the error itself, not a moment to remind. Retire a lesson that stopped being true instead of deleting it. The third time its error happens, reminding has failed: stop, and escalate it by a pull request to `.claude/hooks/lessons/` with `enforce: deny`, which blocks the call with its fix.
