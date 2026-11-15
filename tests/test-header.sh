#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
HOOK="${STEWIE}/.claude/hooks/header.sh"
now="$(date -u +%s)"
export STEWIE_CLOCK_RECORD="${TMP}/methods.tsv" STEWIE_CLOCK_SIGNATURE="Test/bench" STEWIE_CLOCK_REFERENCE_EPOCH="${now}" TS_ZONE=UTC
cd "${TMP}" || exit 1

tr="${TMP}/t.jsonl"
printf '{"type":"assistant","message":{"model":"m-test","content":[]},"effort":"xhigh","timestamp":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" > "${tr}"
said() { printf '{"hook_event_name":"UserPromptSubmit","session_id":"s1","transcript_path":"%s","prompt":"hi"}' "$1" | bash "${HOOK}" 2>/dev/null; }

out="$(said "${tr}")"; rc=$?
check "each message brings one header line"     '[[ ${rc} -eq 0 && "$(wc -l <<< "${out}")" -eq 1 && "${out}" =~ ^\[[0-9]{2}-[0-9]{2}-[0-9]{4}\ [0-9]{2}:[0-9]{2}\ \+00\ ·\ .*\]$ ]]'
check "it is the line clock | header prints"    '[[ "${out}" == "$(STEWIE_TRANSCRIPT="${tr}" "${STEWIE}/tools/bin/clock" 2>/dev/null | STEWIE_TRANSCRIPT="${tr}" "${STEWIE}/tools/bin/header" 2>/dev/null)" ]]'
check "it reads the transcript the input names" '[[ "${out}" == *"m-test·xhigh]" ]]'
printf '{"type":"assistant","message":{"model":"m-old","content":[]},"effort":"low","timestamp":"%s"}\n' "$(date -u -d "@$(( now - 600 ))" +%Y-%m-%dT%H:%M:%S.000Z)" > "${TMP}/stale.jsonl"
out="$(said "${TMP}/stale.jsonl")"
check "a stale reply still brings one line, model unknown" '[[ "$(wc -l <<< "${out}")" -eq 1 && "${out}" =~ ^\[[0-9]{2}-.*\ ·\ \?·\?\]$ ]]'
: > "${TMP}/empty.jsonl"
out="$(said "${TMP}/empty.jsonl")"
check "a first message still brings one line, model unknown" '[[ "$(wc -l <<< "${out}")" -eq 1 && "${out}" =~ ^\[[0-9]{2}-.*\ ·\ \?·\?\]$ ]]'
out="$(said "${tr}")"
check "never the check mark"                    '[[ "${out}" != *✓* ]]'
out="$(STEWIE_CLOCK_REFERENCE_EPOCH=$(( now - 600 )) said "${tr}")"
check "a DESFASE comes with the line"           '[[ "$(sed -n 2p <<< "${out}")" == DESFASE* ]]'
out="$(TS_ZONE=Nowhere/Void said "${tr}")"; rc=$?
check "no time, no line and no failure"        '[[ ${rc} -eq 0 && -z "${out}" ]]'
out="$(printf 'x' | bash "${HOOK}" 2>&1)"; rc=$?
check "bad input never fails the message"       '[[ ${rc} -eq 0 && "${out}" != *rror* ]]'
check "the hook is wired to each message"       'python3 -I -c "import json,sys; s=json.load(open(sys.argv[1])); sys.exit(0 if any(\"header.sh\" in h.get(\"command\",\"\") for g in s[\"hooks\"].get(\"UserPromptSubmit\",[]) for h in g[\"hooks\"]) else 1)" "${STEWIE}/.claude/settings.json"'

finish "header"
