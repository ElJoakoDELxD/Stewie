#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
bin="${STEWIE}/tools/bin"
now="$(date -u +%s)"
export STEWIE_CLOCK_RECORD="${TMP}/methods.tsv" STEWIE_CLOCK_SIGNATURE="Test/bench" STEWIE_CLOCK_REFERENCE_EPOCH="${now}"
cd "${TMP}"

out="$(TS_ZONE=UTC "${bin}/clock" 2>"${TMP}/err")"
check "format" '[[ "${out}" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{4}\ [0-9]{2}:[0-9]{2}\ \+00$ ]]'
check "saved after testing" 'grep -q "^Test/bench	date_tzdata	" "${STEWIE_CLOCK_RECORD}"'
check "says it saved" 'grep -q "tested and saved" "${TMP}/err"'
TS_ZONE=UTC "${bin}/clock" >/dev/null 2>"${TMP}/err2"
check "reused, not saved twice" '[[ $(wc -l < "${STEWIE_CLOCK_RECORD}") -eq 1 ]] && ! grep -q "saved" "${TMP}/err2"'
printf 'Test/bench\tno_such_method\t2026-01-01\tx\n' > "${STEWIE_CLOCK_RECORD}"
TS_ZONE=UTC "${bin}/clock" >/dev/null 2>/dev/null
check "unknown saved method replaced" 'grep -q "	date_tzdata	" "${STEWIE_CLOCK_RECORD}"'
out="$(TS_ZONE=UTC STEWIE_CLOCK_REFERENCE_EPOCH=$(( now - 600 )) "${bin}/clock" 2>"${TMP}/err3")"; rc=$?
check "DESFASE reported" 'grep -q "^DESFASE" "${TMP}/err3"'
check "DESFASE still prints the time" '[[ ${rc} -eq 0 && -n "${out}" ]]'
TS_ZONE=UTC STEWIE_CLOCK_REFERENCE_EPOCH=$(( now - 60 )) "${bin}/clock" >/dev/null 2>"${TMP}/err4"
check "under 3 minutes is quiet" '! grep -q DESFASE "${TMP}/err4"'
TS_ZONE=UTC TS_CTX_DATE=1999-01-01 "${bin}/clock" >/dev/null 2>"${TMP}/err5"
check "a context date mismatch is DESFASE, with its reason" 'grep -q "^DESFASE: the context date is 1999-01-01" "${TMP}/err5"'
check "an unknown zone prints nothing" '[[ -z "$(TS_ZONE=Nowhere/Void "${bin}/clock" 2>/dev/null)" ]]'
unset STEWIE_CLOCK_RECORD
out="$(cd "${TMP}" && TS_ZONE=UTC "${bin}/clock" 2>&1)"
check "no agent attached: nothing is saved" '[[ "${out}" != *saved* ]]'

fixture "${TMP}/p" scout
cd "${TMP}/p"
"${bin}/attach" scout >/dev/null 2>&1
tr="${TMP}/t.jsonl"; : > "${tr}"
export STEWIE_TRANSCRIPT="${tr}" STEWIE_CHAT=chat-a
h="$(echo "01-02-2026 03:04 +00" | "${bin}/header" 2>/dev/null)"
check "six fields, nothing declared" '[[ "${h}" == "[01-02-2026 03:04 +00 · no agent · main · no workplace declared · sandbox off · ?·?]" ]]'
check "never the check mark" '[[ "${h}" != *✓* ]]'

reply() { printf '{"type":"assistant","message":{"model":"m-test","content":[{"type":"text","text":"say \\"model\\":\\"m-quoted\\""}]},"effort":"xhigh","timestamp":"%s"}\n' "$1"; }
reply "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" >> "${tr}"
h="$(echo "t" | CLAUDE_EFFORT=low "${bin}/header" 2>/dev/null)"
check "model and effort from this turn's record" '[[ "${h}" == *"· m-test·xhigh]" ]]'
check "effort never from the environment" '[[ "${h}" != *low* ]]'
reply "$(date -u -d '-10 min' +%Y-%m-%dT%H:%M:%S.000Z)" > "${TMP}/stale.jsonl"
h="$(echo "t" | STEWIE_TRANSCRIPT="${TMP}/stale.jsonl" "${bin}/header" 2>"${TMP}/err6")"
check "an earlier turn is never used" '[[ "${h}" == *"· ?·?]" ]] && grep -q "not this turn" "${TMP}/err6"'

check "with the sandbox off, no agent is declared" '! "${bin}/header" --declare agent=scout 2>"${TMP}/err8" && grep -q "only with the Bash sandbox on" "${TMP}/err8"'
mv "${TMP}/p/.claude/hooks" "${TMP}/hooks.real"; mkdir -p "${TMP}/ro/.claude/hooks"; ln -s "${TMP}/ro/.claude/hooks" "${TMP}/p/.claude/hooks"
check "a hooks folder linked to a read-only one is not the sandbox" '! locked "${TMP}/ro" "${bin}/header" --declare agent=scout 2>/dev/null'
rm "${TMP}/p/.claude/hooks"; mv "${TMP}/hooks.real" "${TMP}/p/.claude/hooks"
h="$(echo "t" | locked "${TMP}/p" "${bin}/header" 2>/dev/null)"
check "with the hooks read-only, the header says so" '[[ "${h}" == *" · sandbox on · "* ]]'
d="$(locked "${TMP}/p" "${bin}/header" --declare agent=scout 2>&1)"; result "${d}" >> "${tr}"
check "a declaration prints its record" '[[ "${d}" == "${MARK} agent=scout chat=chat-a" ]]'
check "and starts this chat's own file" '[[ -f .agent/chats/chat-a.md ]]'
h="$(echo "t" | "${bin}/header" 2>/dev/null)"
check "the declared agent shows" '[[ "${h}" == "[t · scout · main · no workplace declared · sandbox off · "* ]]'
check "a second agent is refused" '! "${bin}/header" --declare agent=other 2>"${TMP}/err7" && grep -q "One chat, one agent: open a new chat" "${TMP}/err7"'
check "an agent not attached is refused" '! STEWIE_CHAT=chat-z STEWIE_TRANSCRIPT=/dev/null "${bin}/header" --declare agent=nobody 2>/dev/null'
d="$("${bin}/header" --declare workplace=.agent/projects/garden/ 2>&1)"; result "${d}" >> "${tr}"
h="$(echo "t" | "${bin}/header" 2>/dev/null)"
check "the declared workplace shows" '[[ "${h}" == *" · .agent/projects/garden/ · "* ]]'
check "a workplace outside projects is refused" '! "${bin}/header" --declare workplace=README.md 2>/dev/null'
h="$(echo "t" | STEWIE_TRANSCRIPT="${TMP}/new.jsonl" "${bin}/header" 2>/dev/null)"
check "a cleared window keeps the agent, from the chat's own file" '[[ "${h}" == "[t · scout · "* ]]'

finish "tools/bin/clock and header"
