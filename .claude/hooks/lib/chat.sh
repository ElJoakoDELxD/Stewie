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

stewie_sandboxed() {
  [[ ! -L "$1/.claude" && ! -L "$1/.claude/hooks" && -d "$1/.claude/hooks" && ! -w "$1/.claude/hooks" ]]
}

stewie_agent_file() {
  if [[ "$2" == "custodian" ]]; then printf '%s/.claude/agents/custodian.md' "$1"
  else printf '%s/.agent/agent.md' "$1"; fi
}

stewie_declarations() {
  python3 -I - "$1" "${2:-}" "${3:-marks}" <<'PY' 2>/dev/null
import json, re, sys
path, root, mode = sys.argv[1:4]
call = re.compile(r"\s*(header|tools/bin/header|\./tools/bin/header) --declare (agent=[a-z0-9][a-z0-9-]*|workplace=[A-Za-z0-9._/-]+)\s*")
mark = re.compile(r"STEWIE_DECLARED (agent|workplace)=([A-Za-z0-9._/-]+) chat=([A-Za-z0-9_-]+)")


def declared(command, cwd):
    m = call.fullmatch(command)
    if not m:
        return None
    if m.group(1) == "header" or (root and cwd and cwd.rstrip("/") == root.rstrip("/")):
        return m.group(2)
    return None


calls, pending = {}, {}
try:
    lines = open(path, encoding="utf-8", errors="replace")
except OSError:
    sys.exit()
for line in lines:
    if "--declare" not in line and "STEWIE_DECLARED" not in line and "tool_result" not in line:
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
        if r.get("type") == "assistant" and b.get("type") == "tool_use" and b.get("name") == "Bash" and isinstance(b.get("id"), str):
            command = str((b.get("input") or {}).get("command", ""))
            kv = declared(command, r.get("cwd") if isinstance(r.get("cwd"), str) else None)
            if kv:
                calls[b["id"]] = kv
            if "--declare" in command:
                pending[b["id"]] = "alone" if kv else "chained"
        elif r.get("type") == "user" and b.get("type") == "tool_result":
            pending.pop(b.get("tool_use_id"), None)
            kv = calls.pop(b.get("tool_use_id"), None)
            out = b.get("content")
            if isinstance(out, list):
                out = "\n".join(x.get("text", "") for x in out if isinstance(x, dict) and x.get("type") == "text")
            if mode != "marks" or not kv or b.get("is_error") is True or not isinstance(out, str):
                continue
            for text in out.splitlines():
                m = mark.fullmatch(text.strip())
                if m and "%s=%s" % (m.group(1), m.group(2)) == kv:
                    print(m.group(0))
                    break
if mode == "pending" and pending:
    print("alone" if "alone" in pending.values() else "chained")
PY
}

stewie_identity() {
  local root="$1" transcript="$2" sid="${3:-}" strict="${4:-}" marks first
  STEWIE_AGENT=""; STEWIE_WORKPLACE=""
  STEWIE_CHAT_ID="${STEWIE_CHAT:-${CLAUDE_CODE_REMOTE_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-${sid:-unknown}}}}"
  marks="$(stewie_declarations "${transcript}" "${root}")"
  first="$(printf '%s\n' "${marks}" | grep -m1 '^STEWIE_DECLARED agent=')"
  if [[ -n "${first}" ]]; then
    STEWIE_AGENT="${first#STEWIE_DECLARED agent=}"; STEWIE_AGENT="${STEWIE_AGENT%% *}"
    STEWIE_CHAT_ID="${first##*chat=}"
  elif [[ "${strict}" != "strict" && -f "${root}/.agent/chats/${STEWIE_CHAT_ID}.md" ]]; then
    STEWIE_AGENT="$(stewie_attached "${root}")"
  fi
  export STEWIE_WORKPLACE
  STEWIE_WORKPLACE="$(printf '%s\n' "${marks}" | sed -n 's/^STEWIE_DECLARED workplace=\([^ ]*\) .*/\1/p' | tail -1)"
}
