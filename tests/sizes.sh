#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.."
MAX_START=6714
BUDGET_WORDS=7000
MAX_RULE=200
MAX_TOOL=600
START_MEMORY=(memory/_example/memory/core.md memory/_example/memory/INDEX.md)

tmp="$(mktemp -d)"; trap 'rm -rf "${tmp}"' EXIT
canon="$(python3 -I -c 'import json; print(json.load(open(".claude/settings.json"))["env"]["STEWIE_CANON"])')"
files() { git ls-files -z -co --exclude-standard; }

git init -q -b main "${tmp}/canon"
files | tar --null -T - -cf - | tar -xf - -C "${tmp}/canon"
git -C "${tmp}/canon" remote add origin "${canon}"
start='{"session_id":"sizes","transcript_path":"/dev/null","source":"startup","hook_event_name":"SessionStart"}'
mkdir -p "${tmp}/home"
hooks="$(python3 -I -c 'import json; [print(h["command"]) for g in json.load(open(".claude/settings.json"))["hooks"]["SessionStart"] for h in g["hooks"] if h.get("type") == "command"]' \
  | while IFS= read -r cmd; do
      printf '%s' "${start}" | env -u CLAUDE_CODE_REMOTE CLAUDE_PROJECT_DIR="${tmp}/canon" STEWIE_OFFLINE=1 TS_ZONE=UTC \
        STEWIE_CLOCK_REFERENCE_EPOCH="$(date -u +%s)" HOME="${tmp}/home" bash -c "${cmd}" 2>/dev/null
    done)"
listed="$(python3 -I - .claude/skills/*/SKILL.md .claude/agents/*.md <<'PY'
import re, sys
for path in sys.argv[1:]:
    head = open(path, encoding="utf-8").read().split("\n---", 1)[0]
    field = lambda k: (re.search(r"^%s:\s*(.*)$" % k, head, re.M) or [None, ""])[1]
    print("- %s: %s" % (field("name"), field("description")))
PY
)"
(cd "${tmp}/canon" && HOME="${tmp}/home" tools/bin/memory index --memory memory/_example/memory >/dev/null 2>&1)
[[ -f "${tmp}/canon/memory/_example/memory/INDEX.md" ]] || { echo "FAIL  the memory index could not be built"; exit 1; }
loaded=$(( $(wc -c < CLAUDE.md) + $(printf '%s\n' "${hooks}" | wc -c) + $(printf '%s\n' "${listed}" | wc -c) + $(cd "${tmp}/canon" && cat "${START_MEMORY[@]}" | wc -c) ))

words="$(files | tr '\0' '\n' | grep -E '\.md$' | grep -vE '^CHANGELOG\.md$|^memory/_example/' | tr '\n' '\0' | xargs -0 cat | wc -w)"

fail=0
echo "read at start: ${loaded} bytes (ceiling ${MAX_START})"
echo "the whole system: ${words} words (budget ${BUDGET_WORDS})"
(( loaded <= MAX_START )) || { echo "FAIL  the start is above its ceiling"; fail=1; }
(( loaded < MAX_START )) && { echo "FAIL  the start fell to ${loaded}: set MAX_START=${loaded}"; fail=1; }
(( words <= BUDGET_WORDS )) || { echo "FAIL  the system is above its budget"; fail=1; }
cap() {
  local max="$1" f n; shift
  for f in "$@"; do
    [[ -f "${f}" ]] || continue
    n="$(wc -w < "${f}")"
    (( n <= max )) || { echo "FAIL  ${f} holds ${n} words, over ${max}"; fail=1; }
  done
}
cap "${MAX_RULE}" rules/*.md knowledge/*.md knowledge/*/*.md
cap "${MAX_TOOL}" .claude/skills/*/SKILL.md .claude/agents/*.md
exit "${fail}"
