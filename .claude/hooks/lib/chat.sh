#!/usr/bin/env bash

stewie_timeout() {
  if command -v timeout >/dev/null 2>&1; then timeout "$@"; else shift; "$@"; fi
}

stewie_root() {
  local common root
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  root="${common%/.git}"
  if [[ -n "${common}" && "${root}" != "${common}" ]]; then printf '%s' "${root}"
  else printf '%s' "${CLAUDE_PROJECT_DIR:-$PWD}"; fi
}

stewie_transcript() {
  if [[ -n "${STEWIE_TRANSCRIPT:-}" ]]; then printf '%s' "${STEWIE_TRANSCRIPT}"; return; fi
  if [[ -n "${1:-}" ]]; then printf '%s' "$1"; return; fi
  printf '%s/.claude/projects/%s/%s.jsonl' "${HOME}" "$(stewie_root | sed 's#[^A-Za-z0-9]#-#g')" "${CLAUDE_CODE_SESSION_ID:-none}"
}

stewie_attached() {
  local root="$1" branch
  [[ -e "${root}/.agent/.git" ]] || return 0
  branch="$(git -C "${root}/.agent" branch --show-current 2>/dev/null)"
  case "${branch}" in
    custodian) printf 'custodian' ;;
    agent/*)   printf '%s' "${branch#agent/}" ;;
  esac
}

stewie_agent_file() {
  if [[ "$2" == "custodian" ]]; then printf '%s/.claude/agents/custodian.md' "$1"
  else printf '%s/.agent/agent.md' "$1"; fi
}

stewie_identity() {
  local root="$1" transcript="$2" sid="${3:-}" marks first
  STEWIE_AGENT=""; STEWIE_WORKPLACE=""
  STEWIE_CHAT_ID="${STEWIE_CHAT:-${CLAUDE_CODE_REMOTE_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-${sid:-unknown}}}}"
  marks="$(grep -F '"tool_result"' "${transcript}" 2>/dev/null \
    | grep -oE 'STEWIE_DECLARED (agent|workplace)=[A-Za-z0-9._/-]+ chat=[A-Za-z0-9_-]+')"
  first="$(printf '%s\n' "${marks}" | grep -m1 '^STEWIE_DECLARED agent=')"
  if [[ -n "${first}" ]]; then
    STEWIE_AGENT="${first#STEWIE_DECLARED agent=}"; STEWIE_AGENT="${STEWIE_AGENT%% *}"
    STEWIE_CHAT_ID="${first##*chat=}"
  elif [[ -f "${root}/.agent/chats/${STEWIE_CHAT_ID}.md" ]]; then
    STEWIE_AGENT="$(stewie_attached "${root}")"
  fi
  STEWIE_WORKPLACE="$(printf '%s\n' "${marks}" | sed -n 's/^STEWIE_DECLARED workplace=\([^ ]*\) .*/\1/p' | tail -1)"
}
