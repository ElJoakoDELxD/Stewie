#!/usr/bin/env bash

set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/chat.sh"
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
root="$(stewie_root)"
agent="$(stewie_attached "${root}")"
[[ -n "${agent}" ]] || exit 0
work="${root}/.agent"
[[ "$(git -C "${work}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" == "$(git -C "${root}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" ]] || exit 0
branch="$(git -C "${work}" branch --show-current 2>/dev/null)"
[[ -n "$(git -C "${work}" status --porcelain 2>/dev/null)" ]] || exit 0

if ! { git -C "${work}" add -A && git -C "${work}" commit -q -m "${agent}: autosave"; } >/dev/null 2>&1; then
  printf '{"systemMessage": "Autosave could not commit the work in .agent/ (%s): it is saved on this machine only. Run the handoff."}\n' "${branch}"
  exit 0
fi
git -C "${work}" remote get-url origin >/dev/null 2>&1 || exit 0
if ! GIT_TERMINAL_PROMPT=0 stewie_timeout 30 git -C "${work}" push -q origin "${branch}" >/dev/null 2>&1; then
  printf '{"systemMessage": "Autosave committed the work in .agent/ on %s, but it is not pushed: push it from .agent/ before this machine goes away."}\n' "${branch}"
fi
exit 0
