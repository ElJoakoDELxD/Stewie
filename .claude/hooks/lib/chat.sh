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

stewie_declarations() {
  python3 - "$1" <<'PY' 2>/dev/null
import json, re, sys
call = re.compile(r"header --declare (agent=[a-z0-9][a-z0-9-]*|workplace=[A-Za-z0-9._/-]+)")
mark = re.compile(r"STEWIE_DECLARED (agent|workplace)=([A-Za-z0-9._/-]+) chat=([A-Za-z0-9_-]+)")
calls = {}
try:
    lines = open(sys.argv[1], encoding="utf-8", errors="replace")
except OSError:
    sys.exit()
for line in lines:
    if "header --declare" not in line and "STEWIE_DECLARED" not in line:
        continue
    try:
        r = json.loads(line)
        content = r["message"]["content"]
    except Exception:
        continue
    if not isinstance(content, list):
        continue
    for b in content:
        if not isinstance(b, dict):
            continue
        if r.get("type") == "assistant" and b.get("type") == "tool_use" and b.get("name") == "Bash":
            m = call.fullmatch(str((b.get("input") or {}).get("command", "")))
            if m and isinstance(b.get("id"), str):
                calls[b["id"]] = m.group(1)
        elif r.get("type") == "user" and b.get("type") == "tool_result" and b.get("is_error") is not True:
            kv = calls.pop(b.get("tool_use_id"), None)
            out = b.get("content")
            if isinstance(out, list):
                out = "".join(x.get("text", "") for x in out if isinstance(x, dict) and x.get("type") == "text")
            m = mark.fullmatch(out.strip()) if kv and isinstance(out, str) else None
            if m and "%s=%s" % (m.group(1), m.group(2)) == kv:
                print(m.group(0))
PY
}

stewie_identity() {
  local root="$1" transcript="$2" sid="${3:-}" marks first
  STEWIE_AGENT=""; STEWIE_WORKPLACE=""
  STEWIE_CHAT_ID="${STEWIE_CHAT:-${CLAUDE_CODE_REMOTE_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-${sid:-unknown}}}}"
  marks="$(stewie_declarations "${transcript}")"
  first="$(printf '%s\n' "${marks}" | grep -m1 '^STEWIE_DECLARED agent=')"
  if [[ -n "${first}" ]]; then
    STEWIE_AGENT="${first#STEWIE_DECLARED agent=}"; STEWIE_AGENT="${STEWIE_AGENT%% *}"
    STEWIE_CHAT_ID="${first##*chat=}"
  elif [[ -f "${root}/.agent/chats/${STEWIE_CHAT_ID}.md" ]]; then
    STEWIE_AGENT="$(stewie_attached "${root}")"
  fi
  STEWIE_WORKPLACE="$(printf '%s\n' "${marks}" | sed -n 's/^STEWIE_DECLARED workplace=\([^ ]*\) .*/\1/p' | tail -1)"
}
