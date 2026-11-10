#!/usr/bin/env bash

set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/chat.sh"
session_id="" transcript_path=""
eval "$(python3 -I -c '
import json, shlex, sys
d = json.load(sys.stdin)
for k in ("session_id", "transcript_path"):
    print("%s=%s" % (k, shlex.quote(str(d.get(k) or ""))))
' 2>/dev/null)" || { session_id=""; transcript_path=""; }
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
root="$(stewie_root)"
[[ -L "${root}/.agent" ]] && exit 0
agent="$(stewie_attached "${root}")"
[[ -n "${agent}" ]] || exit 0
work="${root}/.agent"
[[ "$(git -C "${work}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" == "$(git -C "${root}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" ]] || exit 0
for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do
  path="$(git -C "${work}" rev-parse --path-format=absolute --git-path "${state}" 2>/dev/null)" || exit 0
  [[ -e "${path}" ]] && exit 0
done
branch="$(git -C "${work}" branch --show-current 2>/dev/null)"
[[ -n "$(git -C "${work}" status --porcelain 2>/dev/null)" ]] || exit 0

if ! { git -C "${work}" add -A && git -C "${work}" commit -q -m "${agent}: autosave"; } >/dev/null 2>&1; then
  printf '{"systemMessage": "Autosave could not commit the work in .agent/ (%s): it is saved on this machine only."}\n' "${branch}"
  exit 0
fi
origin="$(git -C "${work}" remote get-url origin 2>/dev/null)" || exit 0
canon="${STEWIE_CANON:-$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["env"]["STEWIE_CANON"])' "${root}/.claude/settings.json" 2>/dev/null)}"
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | sed -E 's#^[a-z+]+://([^@/]*@)?##; s#^git@([^:]*):#\1/#; s#\.git/?$##; s#/+$##'; }
[[ -n "${canon}" && "$(norm "${origin}")" == "$(norm "${canon}")" ]] && exit 0
if [[ "${branch}" == "custodian" ]]; then
  printf '{"systemMessage": "Autosave committed the work in .agent/ on custodian, but it is not pushed: a push of the custodian waits for the person to approve it."}\n'
  exit 0
fi
GIT_TERMINAL_PROMPT=0 stewie_timeout 15 git -C "${work}" ls-remote --exit-code --heads origin "agent/${agent}" >/dev/null 2>&1
case $? in
  0) if ! GIT_TERMINAL_PROMPT=0 stewie_timeout 30 git -C "${work}" fetch -q origin "refs/heads/agent/${agent}" >/dev/null 2>&1; then
       printf '{"systemMessage": "Autosave committed the work in .agent/ on %s, but it is not pushed: push it from .agent/ before this machine goes away."}\n' "${branch}"
       exit 0
     fi
     if ! git -C "${work}" rebase -q --no-autostash FETCH_HEAD >/dev/null 2>&1; then
       git -C "${work}" rebase --abort >/dev/null 2>&1
       printf '{"systemMessage": "Autosave committed the work in .agent/ on %s, but it is not pushed: it conflicts with what another chat pushed to origin."}\n' "${branch}"
       exit 0
     fi ;;
  2) stewie_identity "${root}" "$(stewie_transcript "${transcript_path}")" "${session_id}"
     if [[ "${STEWIE_AGENT}" != "${agent}" ]]; then
       printf '{"systemMessage": "Autosave committed the work in .agent/ on agent/%s, but it is not pushed: the branch is not on origin yet, and this chat did not declare it."}\n' "${agent}"
       exit 0
     fi ;;
  *) printf '{"systemMessage": "Autosave committed the work in .agent/ on %s, but it is not pushed: push it from .agent/ before this machine goes away."}\n' "${branch}"
     exit 0 ;;
esac
if ! GIT_TERMINAL_PROMPT=0 stewie_timeout 30 git -C "${work}" push -q origin "HEAD:refs/heads/agent/${agent}" >/dev/null 2>&1; then
  printf '{"systemMessage": "Autosave committed the work in .agent/ on %s, but it is not pushed: push it from .agent/ before this machine goes away."}\n' "${branch}"
fi
exit 0
