#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
kit="${STEWIE}/memory/_example/tools/sandbox"
[[ "$(uname -s)/$(uname -m)" == "Linux/x86_64" ]] || { echo "sandbox kit: bench skipped (not Linux x86_64)"; exit 0; }

mkdir -p "${TMP}/bin" "${TMP}/proj/.claude"
STEWIE_SANDBOX_BIN="${TMP}/bin" CLAUDE_PROJECT_DIR="${TMP}/proj" HTTPS_PROXY=http://127.0.0.1:41547 bash "${kit}/activate.sh"
s="${TMP}/proj/.claude/settings.local.json"
check "tools linked" '[[ -L "${TMP}/bin/bwrap" && -L "${TMP}/bin/socat" ]]'
check "settings are JSON" 'python3 -m json.tool "${s}" >/dev/null'
check "sandbox on, nested, auto-allowed, git out" 'python3 -c "import json,sys; x=json.load(open(sys.argv[1]))[\"sandbox\"]; assert x[\"enabled\"] and x[\"enableWeakerNestedSandbox\"] and x[\"autoAllowBashIfSandboxed\"] and x[\"excludedCommands\"]==[\"git *\"]" "${s}"'
check "a domain allowlist" 'grep -q "\"allowedDomains\":\[\"api.anthropic.com\"" "${s}"'
check "no fixed proxy port (it changes between restarts)" '! grep -q -i "proxyport" "${s}"'
check "no extra write permission" '! grep -q allowWrite "${s}"'
check "the linked bwrap runs" '"${TMP}/bin/bwrap" --version >/dev/null'
check "socat forces IPv4" 'grep -q "socat.bin\" -4" "${kit}/linux-x86_64/socat"'
check "every binary has its source listed" 'for f in bwrap socat.bin lib/libwrap.so.0; do grep -q "\`${f}\`" "${kit}/linux-x86_64/SOURCES.md" || exit 1; done'

mkdir -p "${TMP}/p2/.claude"
STEWIE_SANDBOX_BIN="${TMP}/missing" CLAUDE_PROJECT_DIR="${TMP}/p2" bash "${kit}/activate.sh"
check "no link directory: nothing done" '[[ ! -e "${TMP}/p2/.claude/settings.local.json" ]]'
if [[ $(id -u) -ne 0 ]]; then
  mkdir -p "${TMP}/ro"; chmod a-w "${TMP}/ro"
  STEWIE_SANDBOX_BIN="${TMP}/ro" CLAUDE_PROJECT_DIR="${TMP}/p2" bash "${kit}/activate.sh"
  check "no writable directory: nothing done" '[[ ! -e "${TMP}/p2/.claude/settings.local.json" ]]'
fi

finish "sandbox kit"
