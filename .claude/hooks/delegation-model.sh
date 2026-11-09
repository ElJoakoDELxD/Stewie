#!/usr/bin/env bash

set -uo pipefail

python3 -I -c '
import json, re, sys
i = json.load(sys.stdin)["tool_input"]
m, a = i.get("model"), i.get("subagent_type")
sys.exit(0 if (isinstance(m, str) and m.strip()) or a == "malicious-code-review" or (isinstance(a, str) and re.fullmatch(r"(egm:)?egm-[a-z]+(-[a-z]+)*", a)) else 1)
' 2>/dev/null && exit 0

cat >&2 <<'EOF'
BLOCKED by delegation-model.sh: a delegation names its model; without one it
inherits this session's, the most expensive, in silence. Pick the cheapest whose
stated use covers the task (rules/delegating-a-task.md): a smaller model when
the task is mostly reading or doing, its result is checked cheaply against
written criteria, and the brief is short beside the work. Repeat the call with
`model` set. Only malicious-code-review and the Elephant-Goldfish reviewers (egm-*)
inherit on purpose: what they miss, no later check finds. A call this hook cannot read is blocked too.
EOF
exit 2
