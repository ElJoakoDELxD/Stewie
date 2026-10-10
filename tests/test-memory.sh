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

echo "=== the architecture is a graph ==="
check "a node can be shown before any index"     'mem show CLAUDE.md | head -1 | grep -q "^CLAUDE.md "'
check "the index builds"                         'mem index | grep -q "indexed"'
check "a rule of CLAUDE.md is its own node"      'mem find git calls run alone --limit 1 | head -1 | grep -q "^CLAUDE.md#always/"'
check "a hook knows who wires and tests it"      'out="$(mem show .claude/hooks/guard-main.sh)"; grep -q "← wires .claude/settings.json#" <<< "${out}" && grep -q "← tests tests/test-guard-main.sh" <<< "${out}"'
check "a query returns a short digest"           '(( $(mem find gatekeeper criterion | wc -c) < 2000 ))'
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
N="${TMP}/notes"; mkdir -p "${N}"
c1="$(git -C "${R}" rev-parse --short HEAD)"
printf '# Notes\n\n- **Delegation.** The rule is `rules/delegating-a-task.md`. (%s)\n- **Gone.** See `rules/no-such-rule.md`.\n' "${c1}" > "${N}/n.md"
check "a fresh note is not stale"                '! mem stale --notes "${N}" | grep -q "Delegation"'
printf '\nChanged.\n' >> "${R}/rules/delegating-a-task.md"; git -C "${R}" commit -qam change
c2="$(git -C "${R}" rev-parse --short HEAD)"
out="$(mem stale --notes "${N}")"
check "a changed source makes its note stale"    'grep -q "changed since: rules/delegating-a-task.md" <<< "${out}"'
check "a missing path is reported"               'grep -q "missing path: rules/no-such-rule.md" <<< "${out}"'
printf '# Later\n\n- **Rechecked.** `rules/delegating-a-task.md` again. (%s, %s)\n' "${c2}" "${c1}" > "${N}/m.md"
check "the newest commit a note cites is its base" '! mem stale --notes "${N}" | grep -q "/m.md"'
printf 'Uncommitted.\n' >> "${R}/rules/delegating-a-task.md"
check "an uncommitted change makes a note stale" 'mem stale --notes "${N}" | grep -q "/m.md.*changed since: rules/delegating-a-task.md"'
git -C "${R}" checkout -q -- rules/delegating-a-task.md

echo
echo "=== lessons come back by themselves ==="
check "git after another command recalls the lesson"   'recall "$(bash_call s1 "cd x && git status")" | grep -q "git-runs-alone"'
check "a reminder is context for the call, nothing else" 'recall "$(bash_call s1 "cd x && git status")" | shape PreToolUse'
check "git alone recalls nothing"                      '[[ -z "$(recall "$(bash_call s1 "git status")")" ]]'
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
check "a session starts with the lessons in force"     'recall "{\"hook_event_name\":\"SessionStart\",\"session_id\":\"s5\"}" | grep -q "Lessons in force"'
check "and as context for that event"                  'recall "{\"hook_event_name\":\"SessionStart\",\"session_id\":\"s5\"}" | shape SessionStart'
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
echo "=== it is wired ==="
for event in SessionStart PreToolUse UserPromptSubmit PostToolUseFailure Stop; do
  check "recall runs on ${event}" 'python3 -I -c "import json,sys; h=json.load(open(sys.argv[1]))[\"hooks\"][sys.argv[2]]; sys.exit(0 if any(\"recall.sh\" in x.get(\"command\",\"\") for g in h for x in g[\"hooks\"]) else 1)" "${STEWIE}/.claude/settings.json" '"${event}"
done
check "the hook code sits where sandboxed Bash cannot write" '[[ -f "${STEWIE}/.claude/hooks/lib/memory.py" && ! -e "${STEWIE}/tools/bin/memory.py" ]]'

finish "memory graph"
