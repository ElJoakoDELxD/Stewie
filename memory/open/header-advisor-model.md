---
title: The header could declare the advisor's model, read from the transcript
status: open
owner: agent
opened: 2026-11-17
source: tools/bin/header, .claude/hooks/header.sh
---
The transcript line of an advisor call holds `advisorModel` (the model requested) and, in `message.usage.iterations`, an entry of type `advisor_message` with its own `model` (the model the usage record names for that call). The header already reads the transcript for the session's model; it could show the advisor's the same way, so nobody has to deduce it. Neither field proves more than the harness's own record. This changes the header of every copy: it needs its bench, a size check and a pull request.
