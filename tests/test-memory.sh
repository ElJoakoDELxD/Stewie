#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
R="${TMP}/repo"
mkdir -p "${R}"
cp -R "${STEWIE}/.claude" "${STEWIE}/rules" "${STEWIE}/knowledge" "${STEWIE}/tools" "${STEWIE}/tests" "${STEWIE}/memory" "${STEWIE}/CLAUDE.md" "${R}/"
rm -rf "${R}/.claude/worktrees" "${R}/.memory"
git -C "${R}" init -q -b main && git -C "${R}" add -A && git -C "${R}" commit -q -m init
M="${R}/.claude/hooks/lib/memory.py"
mem() { python3 -I "${M}" "$@"; }
recall() { printf '%s' "$1" | bash "${R}/.claude/hooks/recall.sh"; }
rc() { printf '%s' "$1" | bash "${R}/.claude/hooks/recall.sh" >/dev/null 2>&1; echo $?; }
denied() {
  local out
  out="$(printf '%s' "$1" | bash "${R}/.claude/hooks/recall.sh" 2>&1 >/dev/null)"
  [[ $? -eq 2 ]] && grep -q "^BLOCKED by memory.py" <<< "${out}" && grep -q -- "${2-.}" <<< "${out}"
}
shape() {
  python3 -I -c 'import json,sys; o=json.load(sys.stdin)["hookSpecificOutput"]; sys.exit(0 if set(o)=={"hookEventName","additionalContext"} and o["hookEventName"]==sys.argv[1] and isinstance(o["additionalContext"],str) and o["additionalContext"] else 1)' "$1"
}
bash_call() { printf '{"hook_event_name":"PreToolUse","session_id":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" "$2"; }
edit_call() { printf '{"hook_event_name":"PreToolUse","session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" "$2"; }
agent_edit() { printf '{"hook_event_name":"PreToolUse","session_id":"%s","agent_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1" "$2" "$3"; }
L="${R}/knowledge/lessons"
check "the shipped git lesson blocks a chained git call" 'denied "$(bash_call s0 "ls; git log")" "git -C" && [[ "$(rc "$(bash_call s0b "git -C x log")")" == 0 ]]'
sed 's/^enforce: deny$/repeat: every/' "${R}/.claude/hooks/lessons/git-runs-alone.md" > "${L}/git-runs-alone.md"; rm -rf "${R}/.claude/hooks/lessons"

echo "=== the architecture is a graph ==="
check "a node can be shown before any index"     'mem show CLAUDE.md | head -1 | grep -q "^CLAUDE.md "'
check "the index builds"                         'mem index | grep -q "indexed"'
check "a rule of CLAUDE.md is its own node"      'mem find git calls run alone --limit 1 | head -1 | grep -q "^CLAUDE.md#always/"'
check "a hook knows who wires and tests it"      'out="$(mem show .claude/hooks/guard-main.sh)"; grep -q "← wires .claude/settings.json#" <<< "${out}" && grep -q "← tests tests/test-guard-main.sh" <<< "${out}"'
check "a query returns a short digest"           '(( $(mem find gatekeeper criterion | wc -c) < 2000 ))'
check "a gatekeeper prompt wires its criterion, not what it mentions" 'out="$(mem show ".claude/settings.json#stop-1-2")"; grep -q "→ wires .claude/hooks/gatekeeper.md" <<< "${out}" && ! grep -q "→ wires .claude/hooks/lib/approved.py" <<< "${out}"'
check "an unknown query says so"                 '! mem find zzzqqq >/dev/null'
printf '# Zebracorn\n\nNew.\n' > "${R}/knowledge/zebra.md"
check "a new file is found without an index"     'mem find zebracorn | grep -q "knowledge/zebra.md"'
printf '\n## Quokkafly\n\nMore.\n' >> "${R}/knowledge/zebra.md"
check "an edited file is found without an index" 'mem find quokkafly | grep -q "knowledge/zebra.md#quokkafly"'
printf '# Fenced\n\nText.\n\n\x60\x60\x60bash\n# not a heading\nls\n\x60\x60\x60\n\n## Real\n\nBody.\n' > "${R}/knowledge/fenced.md"
check "a comment in a code block is not a section" 'mem show "knowledge/fenced.md#real" >/dev/null && ! mem show "knowledge/fenced.md#not-a-heading" >/dev/null'
printf -- '---\n---\n# Kept\n\nBody.\n\n---\n\n## After\n\nMore.\n' > "${R}/knowledge/empty.md"
check "an empty frontmatter keeps the body"      'mem show knowledge/empty.md | sed -n 2p | grep -qx "Kept"'

echo
echo "=== what stopped being true is found ==="
N="${R}/scratch/notes"; mkdir -p "${N}"
c1="$(git -C "${R}" rev-parse --short HEAD)"
printf '# Notes\n\n- **Delegation.** The rule is `rules/ending-a-session.md`. (%s)\n- **Gone.** See `rules/no-such-rule.md`.\n' "${c1}" > "${N}/n.md"
check "a fresh note is not stale"                '! mem stale --notes "${N}" | grep -q "Delegation"'
printf '\nChanged.\n' >> "${R}/rules/ending-a-session.md"; git -C "${R}" commit -qam change
c2="$(git -C "${R}" rev-parse --short HEAD)"
out="$(mem stale --notes "${N}")"
check "a changed source makes its note stale"    'grep -q "changed since: rules/ending-a-session.md" <<< "${out}"'
check "a missing path is reported"               'grep -q "missing path: rules/no-such-rule.md" <<< "${out}"'
printf '# Later\n\n- **Rechecked.** `rules/ending-a-session.md` again. (%s, %s)\n' "${c2}" "${c1}" > "${N}/m.md"
check "the newest commit a note cites is its base" '! mem stale --notes "${N}" | grep -q "/m.md"'
printf 'Uncommitted.\n' >> "${R}/rules/ending-a-session.md"
check "an uncommitted change makes a note stale" 'mem stale --notes "${N}" | grep -q "/m.md.*changed since: rules/ending-a-session.md"'
git -C "${R}" checkout -q -- rules/ending-a-session.md

echo
echo "=== lessons come back by themselves ==="
check "git after another command recalls the lesson"   'recall "$(bash_call s1 "cd x && git status")" | grep -q "git-runs-alone"'
check "a reminder is context for the call, nothing else" 'recall "$(bash_call s1 "cd x && git status")" | shape PreToolUse'
check "git alone recalls nothing"                      '[[ -z "$(recall "$(bash_call s1 "git status")")" ]]'
check "a session starts with nothing recalled"         '[[ -z "$(recall "{\"hook_event_name\":\"SessionStart\",\"session_id\":\"s5\"}")" ]]'
check "a hook that recalls nothing lets the call run"  '[[ "$(rc "$(bash_call s1 "git status")")" == 0 ]]'
check "a hook that reminds lets the call run"          '[[ "$(rc "$(bash_call s1 "cd x && git status")")" == 0 ]]'
check "a heredoc body is not a command"                '[[ -z "$(recall "$(bash_call s1 "cat <<EOF\\n; git x\\nEOF")")" ]]'
check "a here-string hides no later line"              'recall "$(bash_call s1 "cat <<< x\\ntrue && git y")" | grep -q "git-runs-alone"'
check "the rule's own line is quoted live"             'recall "$(bash_call s2 "true; git log")" | grep -q "CLAUDE.md: Your own git calls"'
check "a lesson marked every returns each time"        'a="$(recall "$(bash_call s2 "true; git log")" | grep -o "recalled [0-9]*×")"; b="$(recall "$(bash_call s2 "true; git log")" | grep -o "recalled [0-9]*×")"; [[ -n "${a}" && "${b#recalled }" == "$(( ${a//[^0-9]/} + 1 ))×" ]]'
check "editing the system points to its rule"          'recall "$(edit_call s3 "${R}/rules/x.md")" | grep -q "rules/changing-the-system.md"'
check "a pointer comes once per session"               '[[ -z "$(recall "$(edit_call s3 "${R}/tools/x")")" ]]'
check "a pointer comes again in a new session"         'recall "$(edit_call s3b "${R}/rules/x.md")" | grep -q "rules/changing-the-system.md"'
check "a subagent gets the pointer its parent saw"     'recall "$(agent_edit s3 a1 "${R}/rules/x.md")" | grep -q "rules/changing-the-system.md"'
stop='{"hook_event_name":"Stop","session_id":"s17","last_assistant_message":"[10-10-2026 11:3x] done"}'
check "a reply with a made-up time is sent back"       'out="$(printf "%s" "${stop}" | bash "${R}/.claude/hooks/recall.sh" 2>&1 >/dev/null)"; [[ $? -eq 2 ]] && grep -q "invented-time" <<< "${out}"'
check "but only once per reply"                        '[[ "$(rc "${stop/\"s17\"/\"s17\",\"stop_hook_active\":true}")" == 0 ]]'
check "a reply with a real time ends"                  '[[ "$(rc "${stop/3x/32}")" == 0 ]]'
failure='{"hook_event_name":"PostToolUseFailure","session_id":"s4","tool_name":"Bash","error":"CONNECT tunnel failed, response 403"}'
check "a refused host is recalled after the failure"   'recall "${failure}" | grep -q "refused-host"'
check "and as context for that event"                  'recall "${failure/s4/s4b}" | shape PostToolUseFailure'
check "a broken input never fails the hook"            '[[ "$(rc "not json")" == 0 ]]'
for i in 1 2 3 4; do printf -- '---\ntrigger: bash zzf\n---\n# Four %s\n\nText.\n' "${i}" > "${L}/four-${i}.md"; done
recall "$(bash_call s21 "zzf")" >/dev/null
check "a lesson past the third comes on the next call" 'recall "$(bash_call s21 "zzf")" | grep -q "Four 4"'
rm -f "${L}"/four-*.md
printf '\xef\xbb\xbf---\ntrigger: bash zzb\n---\n# Bom\n\nText.\n' > "${L}/bom.md"
check "a lesson saved with a byte-order mark still comes back" 'recall "$(bash_call s23 "zzb")" | grep -q "Bom"'
rm -f "${L}/bom.md"
printf -- '---\r\ntrigger: bash zzc\r\n---\r\n# Crlf\r\n\r\nText.\r\n' > "${L}/crlf.md"
check "a lesson saved with CRLF still comes back"      'recall "$(bash_call s22 "zzc")" | grep -q "Crlf"'
rm -f "${L}/crlf.md"
rm -rf "${R}/.memory"; mkdir -p "${TMP}/elsewhere"; ln -s "${TMP}/elsewhere" "${R}/.memory"
recall "$(bash_call s6 "true && git status")" >/dev/null
check "the hit log never follows a symlink"            '[[ ! -e "${TMP}/elsewhere/hits.jsonl" ]]'
check "nor does the index"                             '! mem index >/dev/null 2>&1 && [[ ! -e "${TMP}/elsewhere/graph.db" ]]'
rm "${R}/.memory"
mkdir -p "${R}/.memory"; ln "${TMP}/elsewhere/../repo/CLAUDE.md" "${R}/.memory/hits.jsonl" 2>/dev/null || cp "${R}/CLAUDE.md" "${R}/.memory/hits.jsonl"
before="$(wc -c < "${R}/CLAUDE.md")"
recall "$(bash_call s6 "true && git status")" >/dev/null
check "the hit log never writes through a hard link"   '[[ "$(wc -c < "${R}/CLAUDE.md")" == "${before}" ]]'
rm -f "${R}/.memory/hits.jsonl"
printf 'zzqmarker line\n' > "${TMP}/outside.txt"
printf -- '---\ntrigger: bash zzq\nabout: %s "zzqmarker"\n---\n# Outside\n\nText.\n' "${TMP}/outside.txt" > "${L}/outside.md"
check "a lesson cannot quote a file outside the copy"  'out="$(recall "$(bash_call s7 "zzq")")"; grep -q "Outside" <<< "${out}" && ! grep -q "zzqmarker line" <<< "${out}"'
printf -- '---\ntrigger: bash zzw\n---\n# No blank line\nText right under.\n' > "${L}/tight.md"
check "a lesson with no blank line still comes back"   'recall "$(bash_call s8 "zzw && true; git x")" | grep -q "No blank line"'
check "a lesson with no blank line silences no other"  'recall "$(bash_call s9 "zzw && true; git x")" | grep -q "git-runs-alone"'
mkfifo "${L}/pipe.md"
piped="$(bash_call s10 "cd x; git y")"
check "a named pipe never hangs the hook"              'timeout 5 bash "${R}/.claude/hooks/recall.sh" <<< "${piped}" | grep -q "git-runs-alone"'
rm -f "${L}/pipe.md" "${L}/outside.md" "${L}/tight.md"
printf -- '---\ntrigger: bash zzd\nenforce: deny\n---\n# Escalated\n\nUse the right form.\n' > "${L}/escalated.md"
check "a writable folder cannot escalate a lesson"     '! denied "$(bash_call s11 "zzd")" && [[ "$(rc "$(bash_call s11b "zzd")")" == 0 ]]'
mkdir -p "${R}/.claude/hooks/lessons"; mv "${L}/escalated.md" "${R}/.claude/hooks/lessons/"
check "an escalated lesson blocks the call with its fix" 'denied "$(bash_call s12 "zzd")" "Use the right form"'
check "and blocks it every time"                       'denied "$(bash_call s12 "zzd")"'
check "but never for quoted data"                      '[[ "$(rc "$(bash_call s12 "echo \\\"zzd\\\"")")" == 0 ]]'
head -c 200000 /dev/zero | tr '\0' '\n' >> "${R}/.memory/hits.jsonl"
check "a hit log that cannot grow still blocks"        '(ulimit -f 100; denied "$(bash_call s15 "zzd")")'
printf -- '---\ntrigger: bash (\\w+\\s?)+;$\n---\n# Slow\n\nText.\n' > "${L}/slow.md"
slow="$(bash_call s16 "zzd aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!")"
check "a slow writable lesson cannot outrun a block"   'printf "%s" "${slow}" | timeout 5 bash "${R}/.claude/hooks/recall.sh" >/dev/null 2>&1; [[ $? -eq 2 ]]'
rm -f "${L}/slow.md"
printf -- '---\ntrigger: tool Read\nenforce: deny\n---\n# Too wide\n\nNo.\n' > "${R}/.claude/hooks/lessons/wide.md"
check "an escalation never blocks anything but a command" '[[ "$(rc "{\"hook_event_name\":\"PreToolUse\",\"session_id\":\"s13\",\"tool_name\":\"Read\",\"tool_input\":{}}")" == 0 ]]'
rm -rf "${R}/.claude/hooks/lessons"
printf '1\n[]\n' >> "${R}/.memory/hits.jsonl" 2>/dev/null
check "a malformed hit log silences nothing"           'recall "$(bash_call s14 "true && git x")" | grep -q "git-runs-alone"'
fail_call() { printf '{"hook_event_name":"PostToolUseFailure","session_id":"%s","tool_name":"Bash","tool_input":{"command":"make %s"},"error":"Exit code 1\\n%s"}' "$1" "$2" "$3"; }
first="$(recall "$(fail_call e1 a "make: *** No rule for /tmp/x 12")")"; second="$(recall "$(fail_call e1 b "make: *** No rule for /var/y 34")")"
check "an error twice says nothing"                    '[[ -z "${first}${second}" ]]'
check "a third error stops the work"                   'recall "$(fail_call e1 c "make: *** No rule for /opt/z 56")" | grep -q "happened 3 times in this chat.*stop and clear it"'
recall "$(fail_call e2 a "make: *** One")" >/dev/null; recall "$(fail_call e2 a "make: *** One")" >/dev/null
check "different errors are not mixed"                 '[[ -z "$(recall "$(fail_call e2 a "make: *** Two")")" ]]'
check "another chat starts its own count"              '[[ -z "$(recall "$(fail_call e3 a "make: *** No rule for /tmp/x 12")")" ]]'
printf -- '---\ntrigger: bash zzk\nkind: error\n---\n# Habit\n\nDo it right.\n' > "${L}/habit.md"
for s in k1 k2; do recall "$(bash_call "${s}" "zzk")" >/dev/null; done
check "a lesson recalled a third time asks to escalate" 'recall "$(bash_call k3 "zzk")" | grep -q "reminding has failed. Stop and escalate"'
printf -- '---\ntrigger: bash zzr\nrepeat: every\n---\n# Moment\n\nRemember.\n' > "${L}/moment.md"
for s in r1 r2; do recall "$(bash_call "${s}" "zzr")" >/dev/null; done
check "a reminder never asks to escalate"              '! recall "$(bash_call r3 "zzr")" | grep -q "escalate"'
rm -f "${L}/habit.md" "${L}/moment.md"

echo
echo "=== repetitions are found in a transcript ==="
T="${TMP}/t.jsonl"
for i in 1 2; do
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"b%s","name":"Bash","input":{"command":"x; git push"}}]}}\n' "${i}"
  printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"b%s","is_error":true,"content":"PreToolUse:Bash hook error: BLOCKED by guard-x.sh: no"}]}}\n' "${i}"
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e%s","name":"Edit","input":{"file_path":"%s/rules/r%s.md"}}]}}\n' "${i}" "${R}" "${i}"
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"f%s","name":"Bash","input":{"command":"curl x"}}]}}\n' "${i}"
  printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"f%s","is_error":true,"content":"CONNECT tunnel failed, response 403"}]}}\n' "${i}"
done > "${T}"
printf '{"type":"user","origin":{"kind":"human"},"message":{"role":"user","content":"stop doing that"}}\n' >> "${T}"
printf '{"type":"user","origin":{"kind":"human"},"message":{"role":"user","content":"<3 that worked"}}\n' >> "${T}"
printf '{"type":"user","origin":{"kind":"human"},"message":{"role":"user","content":"<command-message>x</command-message> <command-name>/x</command-name>"}}\n' >> "${T}"
printf '{"type":"user","origin":{"kind":"task-notification"},"message":{"role":"user","content":"a task ended"}}\n' >> "${T}"
check "the same block twice is a repetition"     'mem repeats "${T}" | grep -q "2  blocked by guard-x.sh"'
check "the same lesson twice is a repetition"    'mem repeats "${T}" | grep -q "2  lesson knowledge/lessons/git-runs-alone.md"'
check "a lesson after a failure counts once, as it is shown" 'mem repeats --min 1 "${T}" | grep -q " 1  lesson knowledge/lessons/refused-host.md"'
check "a pointer counts once, as it is shown"    'mem repeats --min 1 "${T}" | grep -q " 1  pointer to rules/changing-the-system.md"'
check "the retrospective keeps what a person typed" 'out="$(mem retro "${T}")"; grep -q "stop doing that" <<< "${out}" && grep -q "<3 that worked" <<< "${out}" && ! grep -q "a task ended\|command-name" <<< "${out}"'

echo
echo "=== memory has a core and categories, by a standard ==="
X="${R}/memory/_example/memory"
check "the template memory follows its schemas"  'mem check --memory "${X}" | grep -q "follows its schemas"'
mkdir -p "${R}/scratch"; Q="${R}/scratch/lessons-as-memory"; mkdir -p "${Q}/lessons"; cp "${X}/core.md" "${Q}/"; cp "${X}/lessons/_schema.md" "${R}"/knowledge/lessons/*.md "${Q}/lessons/"
check "the template lessons follow the lessons schema" 'mem check --memory "${Q}" | grep -q "follows its schemas"'
Y="${R}/scratch/mem"; cp -R "${X}" "${Y}"
printf -- '---\ntitle: Ask about the logo\nstatus: open\nowner: person\nopened: 2026-10-16\n---\nWhat was tried.\n' > "${Y}/open/logo.md"
printf -- '---\ntitle: Use a blue palette\nstatus: current\ndate: 2026-10-16\nby: the person\n---\nWhy.\n' > "${Y}/decisions/palette.md"
check "a filled memory follows its schemas"      'mem check --memory "${Y}" | grep -q "follows its schemas"'
check "the index lists each entry by category"   'mem index --memory "${Y}" >/dev/null && grep -q "^## open" "${Y}/INDEX.md" && grep -q "\[Ask about the logo\](open/logo.md) · open · 2026-10-16 · person" "${Y}/INDEX.md" && grep -q "\[Use a blue palette\](decisions/palette.md)" "${Y}/INDEX.md"'
printf 'keep\n' > "${TMP}/victim"; rm -f "${Y}/INDEX.md"; ln -s "${TMP}/victim" "${Y}/INDEX.md"
mem index --memory "${Y}" >/dev/null
check "the index never writes through a link"   '[[ "$(cat "${TMP}/victim")" == keep && -f "${Y}/INDEX.md" && ! -L "${Y}/INDEX.md" ]]'
mkfifo "${Y}/open/pipe.md"
check "a named pipe never hangs the index"       'timeout 10 python3 -I "${M}" index --memory "${Y}" >/dev/null 2>&1 && timeout 10 python3 -I "${M}" check --memory "${Y}" >/dev/null 2>&1; [[ $? -ne 124 ]]'
rm -f "${Y}/open/pipe.md"; mem index --memory "${Y}" >/dev/null
check "notes outside the copy are refused"       '! mem index --notes "${TMP}" >/dev/null 2>&1'
check "a memory outside the copy is refused"     '! mem check --memory "${TMP}" >/dev/null 2>&1 && ! mem index --memory "${TMP}" >/dev/null 2>&1'
printf -- '---\ntitle: x\nstatus: maybe\nowner: person\nopened: 16-10-2026\ncolour: red\n---\n' > "${Y}/open/bad.md"
printf -- '---\nstatus: done\nowner: agent\nopened: 2026-10-16\n---\n' > "${Y}/open/closed.md"
printf 'loose\n' > "${Y}/loose.md"
out="$(mem check --memory "${Y}")"
check "a value outside the schema is caught"     'grep -q "open/bad.md: status is maybe" <<< "${out}"'
check "a field outside the schema is caught"     'grep -q "open/bad.md: colour is not in open/_schema.md" <<< "${out}"'
check "a date in another format is caught"       'grep -q "open/bad.md: opened is not a real date" <<< "${out}"'
check "a missing field is caught"                'grep -q "open/closed.md: needs title" <<< "${out}"'
check "a closed item needs its date"             'grep -q "open/closed.md: a closed item needs closed" <<< "${out}"'
check "a file outside the categories is caught"  'grep -q "loose.md: belongs in a category folder" <<< "${out}"'
check "and the check fails"                      '! mem check --memory "${Y}" >/dev/null'
printf -- '---\ntitle: x\nstatus: current\nstatus: bogus\ndate: 2026-02-31\n- https://a.example\n---\n' > "${Y}/decisions/dup.md"
mkdir -p "${Y}/notes"; printf 'free\n' > "${Y}/notes/free.md"; printf 'x\n' > "${Y}/open/todo.txt"
printf -- '---\ntitle: "Quoted"\nstatus: "current"\ndate: 2026-10-16\n---\n' > "${Y}/references/quoted.md"
python3 -I -c 'print("---\ntitle: big\nstatus: current\ndate: 2026-10-16\n---\n" + "w " * 40000)' > "${Y}/references/big.md"
out="$(mem check --memory "${Y}")"
check "a key given twice is caught"              'grep -q "decisions/dup.md: status is given 2 times" <<< "${out}"'
check "an impossible date is caught"             'grep -q "decisions/dup.md: date is not a real date" <<< "${out}"'
check "a list on its own lines is explained"     'grep -q "a list goes on one line" <<< "${out}"'
check "a folder with no schema is caught"        'grep -q "notes/: a folder with no _schema.md" <<< "${out}"'
check "a file that is not markdown is caught"    'grep -q "open/todo.txt: not a .md file" <<< "${out}"'
check "quoted values are read as values"         '! grep -q "references/quoted.md" <<< "${out}"'
check "an entry too big to read says so"         'grep -q "references/big.md: cannot be read" <<< "${out}"'
rm -rf "${Y}/notes" "${Y}/open/todo.txt" "${Y}/open/bad.md" "${Y}/open/closed.md" "${Y}/loose.md" "${Y}/decisions/dup.md" "${Y}/references/big.md"
mem index --memory "${Y}" >/dev/null; printf -- '---\ntitle: Later\nstatus: current\ndate: 2026-10-16\n---\n' > "${Y}/references/later.md"
check "a stale index is caught"                  'out="$(mem check --memory "${Y}")"; grep -q "INDEX.md: stale" <<< "${out}"'
python3 -I -c 'print("---\nformat: 2\n---\n" + "w " * 40000)' > "${Y}/core.md"
check "a core too big to read is caught"         'out="$(mem check --memory "${Y}")"; grep -q "core.md: cannot be read" <<< "${out}"'
Z="${R}/scratch/real"; cp -R "${X}" "${Z}"; printf 'x\n' > "${Z}/clock.tsv"; : > "${Z}/open/.gitkeep"
printf -- '---\ntitle: Two triggers\nstatus: current\ndate: 2026-10-16\ntrigger: bash zzx\ntrigger: prompt zzy\n---\n' > "${Z}/lessons/two.md"
printf -- '---\ntitle: Logo\nstatus: current\ndate: 2026-10-16\nby: the person\n---\n' > "${Z}/decisions/logo (v2).md"
mem index --memory "${Z}" >/dev/null
check "a real agent memory can pass the check"   'mem check --memory "${Z}" | grep -q "follows its schemas"'
check "an index link keeps the file name"        'grep -q "(decisions/logo%20%28v2%29.md)" "${Z}/INDEX.md"'
rm "${Z}/open/_schema.md"; ln -s "${X}/open/_schema.md" "${Z}/open/_schema.md"
check "a schema that cannot be read is caught"   'out="$(mem check --memory "${Z}")"; grep -q "open/_schema.md: cannot be read" <<< "${out}"'
O="${R}/scratch/old"; mkdir -p "${O}"; printf -- '---\nformat: 1\n---\n# Memory\n' > "${O}/MEMORY.md"
check "an old-format memory asks for consent"    'out="$(mem check --memory "${O}")"; grep -q "old format" <<< "${out}"'
python3 -I -c 'print("---\nformat: 2\n---\n" + "word " * 301)' > "${Y}/core.md"
check "a core over its words is caught"          'out="$(mem check --memory "${Y}")"; grep -q "core.md: 301 words, over 300" <<< "${out}"'
A="${R}/scratch/cap"; cp -R "${X}" "${A}"
printf -- '---\ntitle: Old task\nstatus: done\nowner: agent\nopened: 2026-10-01\nclosed: 2026-10-10\n---\n' > "${A}/open/old.md"
mem index --memory "${A}" >/dev/null
check "an archived entry stays off the index"     '! grep -q "Old task" "${A}/INDEX.md" && mem check --memory "${A}" | grep -q "follows its schemas"'
for i in $(seq 1 60); do printf -- '---\ntitle: Lesson number %s\nstatus: current\ndate: 2026-10-16\n---\n' "${i}" > "${A}/lessons/l${i}.md"; done
mem index --memory "${A}" >/dev/null
check "an index over its words is caught"         'out="$(mem check --memory "${A}")"; grep -q "INDEX.md: [0-9]* words, over 400; close, retire or replace" <<< "${out}"'
sed -i 's/^status: current$/status: retired/' "${A}"/lessons/l*.md; mem index --memory "${A}" >/dev/null
check "retiring entries makes room"               'mem check --memory "${A}" | grep -q "follows its schemas"'

echo
echo "=== it is wired ==="
for event in PreToolUse UserPromptSubmit PostToolUseFailure Stop; do
  check "recall runs on ${event}" 'python3 -I -c "import json,sys; h=json.load(open(sys.argv[1]))[\"hooks\"][sys.argv[2]]; sys.exit(0 if any(\"recall.sh\" in x.get(\"command\",\"\") for g in h for x in g[\"hooks\"]) else 1)" "${STEWIE}/.claude/settings.json" '"${event}"
done
check "the hook code sits where sandboxed Bash cannot write" '[[ -f "${STEWIE}/.claude/hooks/lib/memory.py" && ! -e "${STEWIE}/tools/bin/memory.py" ]]'

finish "memory graph"
