#!/usr/bin/env bash

set -uo pipefail
STEWIE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=bench GIT_AUTHOR_EMAIL=bench@example.invalid
export GIT_COMMITTER_NAME=bench GIT_COMMITTER_EMAIL=bench@example.invalid
unset CLAUDE_CODE_REMOTE_SESSION_ID CLAUDE_CODE_SESSION_ID CLAUDE_PROJECT_DIR STEWIE_TRANSCRIPT STEWIE_CHAT
TMP="$(mktemp -d)"; trap 'rm -rf "${TMP}"' EXIT
export STEWIE_SANDBOX_BIN="${TMP}/sandbox-bin"; mkdir -p "${STEWIE_SANDBOX_BIN}"
failures=0
MARK="STEWIE_""DECLARED"

check() {
  if eval "$2"; then printf 'ok    %s\n' "$1"; else printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); fi
}
finish() {
  if [[ ${failures} -eq 0 ]]; then echo "$1: bench passed"; else echo "$1: ${failures} failing"; fi
  exit "${failures}"
}

fixture() {
  local dir="$1"; shift
  git init -q --bare "${dir}.origin"
  git init -q -b main "${dir}"
  cp -R "${STEWIE}/.claude" "${STEWIE}/memory" "${STEWIE}/tools" "${STEWIE}/CHANGELOG.md" "${dir}/"
  printf '.agent/\n.claude/settings.local.json\n' > "${dir}/.gitignore"
  git -C "${dir}" add -A && git -C "${dir}" commit -q -m init
  git -C "${dir}" remote add origin "${dir}.origin"
  git -C "${dir}" push -q origin main 2>/dev/null
  local name
  for name in "$@"; do
    git -C "${dir}" worktree add -q --orphan -b "agent/${name}" "${dir}/.seed" 2>/dev/null
    cp -R "${dir}/memory/_example/." "${dir}/.seed/"
    sed "s/^name: .*/name: ${name}/" "${dir}/.claude/agents/_example.md" > "${dir}/.seed/agent.md"
    git -C "${dir}/.seed" add -A && git -C "${dir}/.seed" commit -q -m "${name}"
    git -C "${dir}/.seed" push -q origin "agent/${name}" 2>/dev/null
    git -C "${dir}" worktree remove --force "${dir}/.seed"
    git -C "${dir}" branch -q -D "agent/${name}"
  done
}

calls=0
result() {
  local kv="${1#* }" id; kv="${kv%% chat=*}"; calls=$((calls + 1)); id="toolu_b${calls}_${RANDOM}"
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"%s","name":"Bash","input":{"command":"header --declare %s"}}]}}\n' "${id}" "${kv}"
  printf '{"type":"user","message":{"content":[{"tool_use_id":"%s","type":"tool_result","content":"%s","is_error":false}]}}\n' "${id}" "$1"
}

hook() {
  local rc
  printf '%s' "$2" | bash "$1" >/dev/null 2>"${TMP}/hook.err"; rc=$?
  if [[ ${rc} -eq 2 ]]; then echo BLOCK; else echo PASS; fi
}
payload() {
  python3 - "$@" <<'PY'
import json, sys
tool, cwd, transcript, *kv = sys.argv[1:]
ti = dict(x.split("=", 1) for x in kv)
print(json.dumps({"tool_name": tool, "cwd": cwd, "session_id": "sid-bench",
                  "transcript_path": transcript, "tool_input": ti}))
PY
}
