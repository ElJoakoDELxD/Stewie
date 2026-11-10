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
held() {
  printf '{"systemMessage": "Autosave committed the work in .agent/ on %s, but it is not pushed: %s. It is saved on this machine only; tell the person so in plain words."}\n' "${branch}" "$1"
  exit 0
}
[[ -n "$(norm "${canon}")" ]] || held "the canon could not be read, so origin cannot be told apart from it"
[[ "$(norm "${origin}")" == "$(norm "${canon}")" ]] && exit 0
if [[ "${branch}" == "custodian" ]]; then
  printf '{"systemMessage": "Autosave committed the work in .agent/ on custodian, but it is not pushed: a push of the custodian waits for the person to approve it."}\n'
  exit 0
fi
[[ -z "$(git -C "${work}" config --name-only --get-regexp '\.(pushurl|pushinsteadof)$' 2>/dev/null)" ]] || held "git config holds a pushurl or pushInsteadOf entry, which could send it elsewhere"
transcript="$(stewie_transcript "${transcript_path}")"
stewie_identity "${root}" "${transcript}" "${session_id}"
[[ "${STEWIE_AGENT}" == "${agent}" ]] || held "this chat is not known to be ${agent}, the agent .agent/ holds"
GIT_TERMINAL_PROMPT=0 stewie_timeout 10 git -C "${work}" ls-remote --exit-code --heads origin "agent/${agent}" >/dev/null 2>&1
case $? in
  0) GIT_TERMINAL_PROMPT=0 stewie_timeout 15 git -C "${work}" fetch -q origin "refs/heads/agent/${agent}" >/dev/null 2>&1 \
       || held "origin could not be read"
     if ! stewie_timeout 10 git -C "${work}" rebase -q --no-autostash FETCH_HEAD >/dev/null 2>&1; then
       git -C "${work}" rebase --abort >/dev/null 2>&1
       held "it conflicts with what another chat pushed to origin"
     fi ;;
  2) stewie_identity "${root}" "${transcript}" "${session_id}" strict
     [[ "${STEWIE_AGENT}" == "${agent}" ]] || held "the branch is not on origin yet, and this chat did not declare it"
     ;;
  *) held "origin could not be read" ;;
esac
GIT_TERMINAL_PROMPT=0 stewie_timeout 20 git -C "${work}" push -q "${origin}" "HEAD:refs/heads/agent/${agent}" >/dev/null 2>&1 \
  || held "the push to origin failed"
exit 0
