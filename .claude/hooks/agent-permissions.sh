#!/usr/bin/env bash

set -uo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/lib/command.sh"
source "${here}/lib/chat.sh"

input="$(cat)"
eval "$(printf '%s' "${input}" | python3 -c '
import json, shlex, sys
d = json.load(sys.stdin)
ti = d.get("tool_input") or {}
for k, v in (("tool", d.get("tool_name", "")), ("cwd", d.get("cwd", "")),
             ("sid", d.get("session_id", "")), ("transcript", d.get("transcript_path", "")),
             ("path", ti.get("file_path") or ti.get("notebook_path") or ti.get("path") or ""),
             ("pattern", ti.get("pattern", "") if d.get("tool_name") == "Glob" else ""),
             ("command", ti.get("command", ""))):
    print("%s=%s" % (k, shlex.quote(v or "")))
' 2>/dev/null)" || exit 0
cwd="${cwd:-$PWD}"
case "${tool}" in
  Read|Grep|Glob) [[ "${path}${pattern}" == *chats* || "${path:-${cwd}}" == *.agent* ]] || exit 0 ;;
  Bash) [[ "${command}" == *chats/* || "${command}" == *push* ]] || exit 0 ;;
esac
root="$(cd "${cwd}" 2>/dev/null && stewie_root)"; root="${root:-$(stewie_root)}"
root="$(cd "${root}" && pwd -P)"
stewie_identity "${root}" "$(stewie_transcript "${transcript}")" "${sid}"
chats="${root}/.agent/chats"
own="${chats}/${STEWIE_CHAT_ID}.md"

deny() { echo "BLOCKED by agent-permissions.sh: $1" >&2; exit 2; }
resolve() { python3 -c 'import os,sys; print(os.path.realpath(os.path.join(sys.argv[1], sys.argv[2])))' "${cwd}" "$1"; }
other_chat() { deny "$1 is another chat's memory. A chat reads only its own file, .agent/chats/${STEWIE_CHAT_ID}.md; what is known lives in .agent/memory/."; }

case "${tool}" in
  Read|Write|Edit|MultiEdit|NotebookEdit)
    abs="$(resolve "${path:-.}")"
    [[ "${abs}" == "${chats}/"* && "${abs}" != "${own}" ]] && other_chat "${abs#"${root}"/}" ;;
  Grep|Glob)
    abs="$(resolve "${path:-.}")"
    if [[ "${abs}" == "${chats}" || "${abs}" == "${chats}/"* || "${abs}" == "${root}/.agent" ]]; then
      [[ "${abs}" == "${own}" ]] || other_chat "${abs#"${root}"/}"
    fi
    if [[ "${pattern}" == *chats/* ]]; then
      target="$(resolve "${path:-.}/${pattern}")"
      [[ "${target}" == "${own}" ]] || other_chat "${pattern}"
    fi ;;
  Bash)
    while IFS= read -r ref; do
      [[ -z "${ref}" || "${ref}" == "chats/${STEWIE_CHAT_ID}.md" ]] || other_chat "${ref}"
    done < <(executable_text "${command}" | grep -oE '(^|[^A-Za-z0-9_.-])chats/[^[:space:]"'"'"'|;&)<>]*' | sed -E 's#^[^c]*##')
    ;;
esac

[[ -n "${STEWIE_AGENT}" ]] || exit 0

file="$(stewie_agent_file "${root}" "${STEWIE_AGENT}")"
effects() { [[ -f "${file}" ]] && awk -v k="$1" '/^---[[:space:]]*$/{f++;next} f==1 && $0 ~ "^[[:space:]]*-[[:space:]]*" k ":" {sub(/^[^:]*:[[:space:]]*/,""); sub(/[[:space:]]+#.*$/,""); print}' "${file}"; }
within() {
  local base
  while IFS= read -r base; do
    [[ -n "${base}" ]] || continue
    base="$(python3 -c 'import os,sys; print(os.path.realpath(os.path.join(sys.argv[1], sys.argv[2])))' "${root}" "${base}")"
    [[ "$1" == "${base}" || "$1" == "${base}/"* ]] && return 0
  done < <(effects "$2")
  return 1
}

case "${tool}" in
  Write|Edit|MultiEdit|NotebookEdit)
    abs="$(resolve "${path}")"
    if [[ "${abs}" == "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${file}")" ]]; then
      deny "agent '${STEWIE_AGENT}' may not change its own definition (${file#"${root}"/}). Changes to it arrive by pull request."
    fi
    within "${abs}" writes || deny "agent '${STEWIE_AGENT}' declares no effect that writes ${abs#"${root}"/} (${file#"${root}"/}, effects)."
    ;;
  Bash)
    while IFS= read -r where; do
      [[ -n "${where}" ]] || continue
      within "${where}" pushes || deny "agent '${STEWIE_AGENT}' pushes only from what ${file#"${root}"/} declares under pushes:. Run 'cd .agent' in one call, then 'git push' alone."
    done < <(executable_text "${command}" | python3 "${here}/lib/git_calls.py" | python3 -c '
import json, os, sys
for line in sys.stdin:
    c = json.loads(line)
    if c.get("unparsed"):
        if "push" in sys.argv[2]:
            print(os.path.realpath(sys.argv[1]))
        continue
    if c["sub"] == "push":
        where = sys.argv[1]
        for d in c["C"]:
            where = os.path.join(where, d)
        print(os.path.realpath(where))
' "${cwd}" "${command}")
    ;;
esac
exit 0
