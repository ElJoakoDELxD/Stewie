#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
HOOK="${STEWIE}/.claude/hooks/context.sh"
METER="${STEWIE}/tools/bin/context"

turn() { printf '{"type":"assistant","message":{"model":"%s","usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":9}}}\n' "${4:-claude-opus-5-5}" "$1" "$2" "$3"; }
meter() { python3 -I "${METER}" "$1"; }
said() { printf '{"transcript_path":"%s"}' "$1" | bash "${HOOK}" 2>/dev/null; }
at() { turn 0 0 "$1" "${2:-claude-opus-5-5}" > "${TMP}/at.jsonl"; said "${TMP}/at.jsonl"; }

t="${TMP}/t.jsonl"
{ turn 10 90 100; turn 5 5 299990; printf 'not json\n'; printf '{"type":"assistant","isSidechain":true,"message":{"usage":{"input_tokens":900000}}}\n'; } > "${t}"
check "the meter sums the latest main turn"       '[[ "$(meter "${t}")" == "30 300000 1000000" ]]'
check "cache writes count"                        'turn 0 400000 0 > "${TMP}/c.jsonl"; [[ "$(meter "${TMP}/c.jsonl")" == "40 400000 1000000" ]]'
check "a subagent turn does not count"            '[[ "$(meter "${t}")" != 90* ]]'
check "a value that is not a number is skipped"   'printf "{\"type\":\"assistant\",\"message\":{\"usage\":{\"input_tokens\":\"9\",\"cache_read_input_tokens\":100}}}\n" > "${TMP}/n.jsonl"; [[ "$(meter "${TMP}/n.jsonl")" == "0 100 1000000" ]]'
check "a 200k model gets a 200k window"           'turn 0 0 100000 claude-haiku-4-5 > "${TMP}/h.jsonl"; [[ "$(meter "${TMP}/h.jsonl")" == "50 100000 200000" ]]'
check "the window can be set"                     'turn 0 0 100000 > "${TMP}/s.jsonl"; [[ "$(STEWIE_CONTEXT_WINDOW=400000 meter "${TMP}/s.jsonl")" == "25 100000 400000" ]]'

check "at 49%, the hook says nothing"             '[[ -z "$(at 490000)" ]]'
check "at 50%, the first band"                    '[[ "$(at 500000)" == *"at least 50% full"* ]]'
check "at 69%, still the first band"              '[[ "$(at 690000)" == "$(at 500000)" ]]'
check "at 70%, the second band"                   '[[ "$(at 700000)" == *"at least 70% full"* && "$(at 700000)" != "$(at 500000)" ]]'
check "at 85%, the top band"                      '[[ "$(at 850000)" == *"at least 85% full"* ]]'
check "on a 200k model, 120k is past half"        '[[ "$(at 120000 claude-haiku-4-5)" == *"at least 50% full"* ]]'
check "it points to the handoff"                  '[[ "$(at 850000)" == *"run the handoff now"* ]]'
check "no transcript, no output"                  '[[ -z "$(said "${TMP}/missing.jsonl")" ]]'
check "bad input, no output and no failure"       'out="$(printf "x" | bash "${HOOK}" 2>&1)"; [[ $? -eq 0 && -z "${out}" ]]'
check "the hook is wired to each message"         'python3 -I -c "import json,sys; s=json.load(open(sys.argv[1])); sys.exit(0 if any(\"context.sh\" in h.get(\"command\",\"\") for g in s[\"hooks\"].get(\"UserPromptSubmit\",[]) for h in g[\"hooks\"]) else 1)" "${STEWIE}/.claude/settings.json"'

finish "context"
