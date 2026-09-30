#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.."
MAX_LOADED=3878
MAX_WORDS=4412

tmp="$(mktemp -d)"; trap 'rm -rf "${tmp}"' EXIT
canon="$(python3 -c 'import json; print(json.load(open(".claude/settings.json"))["env"]["STEWIE_CANON"])')"
files() { git ls-files -z -co --exclude-standard; }

git init -q -b main "${tmp}/canon"
files | tar --null -T - -cf - | tar -xf - -C "${tmp}/canon"
git -C "${tmp}/canon" remote add origin "${canon}"
start='{"session_id":"sizes","transcript_path":"/dev/null","source":"startup"}'
hooks="$( { printf '%s' "${start}" | CLAUDE_PROJECT_DIR="${tmp}/canon" bash "${tmp}/canon/.claude/hooks/path.sh"
            printf '%s' "${start}" | CLAUDE_PROJECT_DIR="${tmp}/canon" STEWIE_OFFLINE=1 TS_ZONE=UTC \
              STEWIE_CLOCK_REFERENCE_EPOCH="$(date -u +%s)" bash "${tmp}/canon/.claude/hooks/anchor.sh"; } 2>/dev/null)"
loaded=$(( $(wc -c < CLAUDE.md) + $(printf '%s\n' "${hooks}" | wc -c) ))

words="$(files | tr '\0' '\n' | grep -E '\.md$' | grep -vE '^(knowledge|docs)/|^CHANGELOG\.md$' | tr '\n' '\0' | xargs -0 cat | wc -w)"

fail=0
echo "loaded before the first turn: ${loaded} bytes (ceiling ${MAX_LOADED})"
echo "governing prose: ${words} words (ceiling ${MAX_WORDS})"
(( loaded <= MAX_LOADED )) || { echo "FAIL  loaded bytes above the ceiling"; fail=1; }
(( words <= MAX_WORDS )) || { echo "FAIL  words above the ceiling"; fail=1; }
(( loaded < MAX_LOADED )) && { echo "FAIL  loaded bytes fell to ${loaded}: set MAX_LOADED=${loaded}"; fail=1; }
(( words < MAX_WORDS )) && { echo "FAIL  words fell to ${words}: set MAX_WORDS=${words}"; fail=1; }
for rule in rules/*.md; do
  n="$(wc -w < "${rule}")"
  echo "power rule ${rule}: ${n} words"
  (( n <= 200 )) || { echo "FAIL  ${rule} holds ${n} words, over 200"; fail=1; }
done
exit "${fail}"
