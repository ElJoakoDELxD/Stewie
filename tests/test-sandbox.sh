#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
kit="${STEWIE}/memory/_example/tools/sandbox"
[[ "$(uname -s)/$(uname -m)" == "Linux/x86_64" ]] || { echo "sandbox kit: bench skipped (not Linux x86_64)"; exit 0; }

mkdir -p "${TMP}/bin" "${TMP}/proj/.claude"
STEWIE_SANDBOX_BIN="${TMP}/bin" CLAUDE_PROJECT_DIR="${TMP}/proj" HTTPS_PROXY=http://proxy.invalid:8080 bash "${kit}/activate.sh"
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

mkdir -p "${TMP}/bin3" "${TMP}/bin5"
fixture "${TMP}/pt" scout
git -C "${TMP}/pt" worktree add -q "${TMP}/pt/.agent" agent/scout
printf '\ntouch "${SENTINEL}"\n' >> "${TMP}/pt/.agent/tools/sandbox/activate.sh"
( cd "${TMP}/pt" && SENTINEL="${TMP}/ran" STEWIE_SANDBOX_BIN="${TMP}/bin3" HTTPS_PROXY=http://proxy.invalid:8080 "${STEWIE}/tools/bin/attach" scout >"${TMP}/at.out" 2>"${TMP}/at.err" )
check "a kit that is not the template's is not run" '[[ ! -e "${TMP}/ran" && ! -e "${TMP}/pt/.claude/settings.local.json" ]] && grep -q "was not run" "${TMP}/at.err"'
check "and the agent cannot be declared" 'grep -q "cannot be declared" "${TMP}/at.out"'

fixture "${TMP}/pv" scout
git -C "${TMP}/pv" worktree add -q "${TMP}/pv/.agent" agent/scout
for d in "${TMP}/pv/memory/_example/tools/sandbox" "${TMP}/pv/.agent/tools/sandbox"; do printf '\ntouch "${SENTINEL}"\n' >> "${d}/activate.sh"; done
( cd "${TMP}/pv" && SENTINEL="${TMP}/ran2" STEWIE_SANDBOX_BIN="${TMP}/bin5" HTTPS_PROXY=http://proxy.invalid:8080 "${STEWIE}/tools/bin/attach" scout >"${TMP}/av.out" 2>"${TMP}/av.err" )
check "a template edited alongside the kit is not trusted: only the committed one counts" '[[ ! -e "${TMP}/ran2" ]] && grep -q "was not run" "${TMP}/av.err" && grep -q "cannot be declared" "${TMP}/av.out"'

fixture "${TMP}/px" scout
git -C "${TMP}/px" worktree add -q "${TMP}/px/.agent" agent/scout
rm "${TMP}/px/.agent/tools/sandbox/activate.sh"
( cd "${TMP}/px" && STEWIE_SANDBOX_BIN="${TMP}/bin6" HTTPS_PROXY=http://proxy.invalid:8080 "${STEWIE}/tools/bin/attach" scout >"${TMP}/ax.out" 2>"${TMP}/ax.err" )
check "a kit without its activate.sh is not the template's either" 'grep -q "was not run" "${TMP}/ax.err" && grep -q "cannot be declared" "${TMP}/ax.out"'

fixture "${TMP}/pw" scout
git -C "${TMP}/pw" worktree add -q "${TMP}/pw/.agent" agent/scout
rm -rf "${TMP}/pw/.agent/tools/sandbox/linux-x86_64/lib"; ln -s /etc "${TMP}/pw/.agent/tools/sandbox/linux-x86_64/lib"
( cd "${TMP}/pw" && STEWIE_SANDBOX_BIN="${TMP}/bin6" HTTPS_PROXY=http://proxy.invalid:8080 "${STEWIE}/tools/bin/attach" scout >"${TMP}/aw.out" 2>"${TMP}/aw.err" )
check "a symlink where the template has a directory is not the template's" 'grep -q "was not run" "${TMP}/aw.err"'

fixture "${TMP}/pu" scout
git -C "${TMP}/pu" worktree add -q "${TMP}/pu/.agent" agent/scout
mkdir -p "${TMP}/bin4"
( cd "${TMP}/pu" && STEWIE_SANDBOX_BIN="${TMP}/bin4" HTTPS_PROXY=http://proxy.invalid:8080 "${STEWIE}/tools/bin/attach" scout >"${TMP}/au.out" 2>"${TMP}/au.err" )
check "the template's own kit is run" '[[ -f "${TMP}/pu/.claude/settings.local.json" ]] && ! grep -q "was not run" "${TMP}/au.err"'

finish "sandbox kit"
