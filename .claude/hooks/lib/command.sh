#!/usr/bin/env bash

hook_command() {
  local input
  input="$(cat)"
  printf '%s' "${input}" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))' \
    2>/dev/null || printf ''
}

_STEWIE_INTERPRETERS='sh|bash|zsh|ksh|dash|ash|busybox|python|python2|python3|node|deno|bun|perl|ruby|php|eval|source|exec|xargs|env|command'

executable_text() {
  printf '%s\n' "$1" | python3 -c '
import re, sys

INTERP = re.compile(r"(^|[|&;(\s])(" + sys.argv[1] + r")([\s|;&)]|$)")
OPENER = re.compile(r"<<(-?)\s*([\x27\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")

out, delim, dash, keep = [], None, False, False
for line in sys.stdin.read().split("\n"):
    if delim is not None:
        candidate = line.lstrip("\t") if dash else line
        if candidate.strip() == delim:
            delim = None
        elif keep:
            out.append(line)
        continue
    out.append(line)
    m = OPENER.search(line)
    if m:
        dash = m.group(1) == "-"
        delim = m.group(3)
        head = OPENER.sub(" ", line)
        keep = bool(INTERP.search(head)) or "$(" in head or "`" in head
print("\n".join(out))
' "${_STEWIE_INTERPRETERS}"
}

command_segments() {
  printf '%s' "$1" | sed 's/&&/\n/g; s/||/\n/g' | tr ';|&' '\n'
}
