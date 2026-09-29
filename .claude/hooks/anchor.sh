#!/usr/bin/env bash

set -uo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/lib/chat.sh"

input="$(cat)"
eval "$(printf '%s' "${input}" | python3 -c '
import json, shlex, sys
d = json.load(sys.stdin)
for k in ("session_id", "transcript_path"):
    print("%s=%s" % (k, shlex.quote(d.get(k) or "")))
' 2>/dev/null)" || { session_id=""; transcript_path=""; }

root="${CLAUDE_PROJECT_DIR:-$(stewie_root)}"
cd "${root}" || exit 0
bin="${root}/tools/bin"
offline="${STEWIE_OFFLINE:-0}"
canon="${STEWIE_CANON:-$(python3 -c 'import json; print(json.load(open(".claude/settings.json"))["env"]["STEWIE_CANON"])' 2>/dev/null)}"
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | sed -E 's#^[a-z+]+://([^@/]*@)?##; s#^git@([^:]*):#\1/#; s#\.git/?$##; s#/+$##'; }

err="$(mktemp)"; trap 'rm -f "${err}"' EXIT
stamp="$("${bin}/clock" 2>"${err}")" || stamp="?"
branch="$(git branch --show-current 2>/dev/null)"; branch="${branch:-?}"
origin="$(git remote get-url origin 2>/dev/null)"
if [[ -z "${origin}" || -z "${canon}" ]]; then place="undetermined (no origin to compare with the canon); ask, do not guess"
elif [[ "$(norm "${origin}")" == "$(norm "${canon}")" ]]; then place="the canon"
else place="a copy of the canon"; fi

echo "Session start: ${stamp} · branch ${branch} · ${place}."
grep '^DESFASE' "${err}"

if [[ "${place}" == "a copy of the canon" && "${offline}" != "1" ]]; then
  here_v="$(sed -n 's/^## \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' CHANGELOG.md 2>/dev/null | head -1)"
  if ! released="$(stewie_timeout 15 git ls-remote --tags --refs "${canon}" 'v*' 2>/dev/null | sed -n 's#.*refs/tags/v##p')" || [[ -z "${released}" ]]; then
    echo "Update check unavailable: the canon did not answer. Say so; silence is not parity."
  elif ! grep -qxF "${here_v}" <<< "${released}"; then
    echo "This copy's version (${here_v:-none}) is not a release of the canon, so no direction can be claimed. The update skill says why."
  else
    latest="$(sort -V <<< "${released}" | tail -1)"
    [[ "${latest}" != "${here_v}" ]] && echo "This copy is behind the canon: ${here_v} here, ${latest} released. Say so before other work and offer the update skill."
  fi
fi

stewie_identity "${root}" "$(stewie_transcript "${transcript_path}")" "${session_id}"
if [[ -n "${STEWIE_AGENT}" ]]; then
  file=".agent/agent.md"; [[ "${STEWIE_AGENT}" == "custodian" ]] && file=".claude/agents/custodian.md"
  if out="$("${bin}/attach" "${STEWIE_AGENT}" 2>&1)"; then echo "${out}"
  else echo "Could not re-attach ${STEWIE_AGENT}: ${out} Tell the person."; fi
  echo "This chat already runs as ${STEWIE_AGENT}; do not ask again. Reread ${file}, .agent/memory/MEMORY.md and .agent/chats/${STEWIE_CHAT_ID}.md, then continue."
  exit 0
fi

if [[ "${offline}" == "1" ]]; then list=""; else list="$("${bin}/attach" --list 2>/dev/null)"; fi
list="$(printf '%s\n%s\n' "${list}" "$(git for-each-ref --format='%(refname:lstrip=2)' refs/heads/agent refs/heads/custodian | sed 's#^agent/##')" | sed '/^$/d' | sort -u)"
agents="$(grep -vx custodian <<< "${list}")"
count="$(grep -c . <<< "${agents}")"
if [[ "${count}" -eq 1 ]]; then
  if out="$("${bin}/attach" "${agents}" 2>&1)"; then
    echo "${out} It is the only agent here, so it was attached without asking: tell the person which agent this is."
    echo "Read .agent/agent.md and .agent/memory/MEMORY.md, then run: header --declare agent=${agents}"
  else echo "Could not attach ${agents}, the only agent: ${out} Tell the person."; fi
elif [[ "${count}" -gt 1 ]]; then
  echo "Agents here: $(paste -sd, <<< "${agents}" | sed 's/,/, /g'). Ask which one this chat runs as, or whether to create another (onboard skill). Then run 'attach <name>', read .agent/agent.md and .agent/memory/MEMORY.md, and run 'header --declare agent=<name>'. One chat, one agent."
elif [[ "${place}" == "the canon" ]]; then
  echo "No agent is created on the canon. Greet briefly and offer to make the person's own copy (onboard skill, step 1)."
elif [[ "${place}" == undetermined* ]]; then
  echo "No agent exists yet. Ask the person whether this is their own copy before onboarding."
else
  echo "No agent exists yet. Begin onboarding (onboard skill) on the first message, whatever it says."
fi
grep -qx custodian <<< "${list}" && echo "The custodian's branch exists. Attach it ('attach custodian') only when the person asks for the custodian."
exit 0
