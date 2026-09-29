#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
H="${STEWIE}/.claude/hooks/anchor.sh"
v="$(sed -n 's/^## \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "${STEWIE}/CHANGELOG.md" | head -1)"
start() {
  printf '{"session_id":"sid","transcript_path":"%s","source":"startup"}' "${2:-/dev/null}" \
    | CLAUDE_PROJECT_DIR="$1" TS_ZONE=UTC STEWIE_CLOCK_REFERENCE_EPOCH="$(date -u +%s)" bash "${H}" 2>/dev/null
}

git init -q -b main "${TMP}/canon"
git -C "${TMP}/canon" commit -q --allow-empty -m one && git -C "${TMP}/canon" tag "v${v}"
git -C "${TMP}/canon" commit -q --allow-empty -m two && git -C "${TMP}/canon" tag "v${v%%.*}.99.0"
export STEWIE_CANON="${TMP}/canon"

echo "=== a copy with no agent ==="
fixture "${TMP}/none"
out="$(STEWIE_OFFLINE=1 start "${TMP}/none")"
check "the time and branch come first" '[[ "${out}" =~ ^Session\ start:\ [0-9]{2}-[0-9]{2}-[0-9]{4}\ [0-9]{2}:[0-9]{2}\ \+00\ ·\ branch\ main\ ·\ a\ copy\ of\ the\ canon\. ]]'
check "it sends the chat to onboard" '[[ "${out}" == *"Begin onboarding"* ]]'

echo "=== a copy with one agent, behind the canon ==="
fixture "${TMP}/one" scout
out="$(start "${TMP}/one")"
check "behind is said, with both versions" '[[ "${out}" == *"behind the canon: ${v} here, ${v%%.*}.99.0 released"* ]]'
check "the lone agent is attached" '[[ -d "${TMP}/one/.agent/memory" && "${out}" == *"only agent here"* ]]'
check "and the chat is told to declare it" '[[ "${out}" == *"header --declare agent=scout"* ]]'
check "the attached branch is the agent's" '[[ $(git -C "${TMP}/one/.agent" branch --show-current) == agent/scout ]]'
echo 'x' > "${TMP}/one/.agent/memory/draft.md"
check "an earlier chat's uncommitted work is never dropped" '! (cd "${TMP}/one" && STEWIE_TRANSCRIPT=/dev/null "${STEWIE}/tools/bin/attach" other 2>/dev/null) && [[ -f "${TMP}/one/.agent/memory/draft.md" ]]'

echo "=== a copy with several agents ==="
fixture "${TMP}/two" river scout
out="$(start "${TMP}/two")"
check "they are listed, and the chat asks" '[[ "${out}" == *"Agents here: river, scout. Ask which one"* ]]'
check "nothing is attached before the answer" '[[ ! -e "${TMP}/two/.agent" ]]'
(cd "${TMP}/two" && STEWIE_TRANSCRIPT=/dev/null "${STEWIE}/tools/bin/attach" scout >/dev/null 2>&1)
check "a new chat may switch a worktree an earlier chat left" '(cd "${TMP}/two" && STEWIE_TRANSCRIPT=/dev/null "${STEWIE}/tools/bin/attach" river >/dev/null 2>&1) && [[ $(git -C "${TMP}/two/.agent" branch --show-current) == agent/river ]]'
result "${MARK} agent=river chat=chat-q" > "${TMP}/q.jsonl"
check "a chat that declared its agent may not switch" '! (cd "${TMP}/two" && STEWIE_TRANSCRIPT="${TMP}/q.jsonl" "${STEWIE}/tools/bin/attach" scout 2>/dev/null)'
git -C "${TMP}/two" worktree remove --force "${TMP}/two/.agent"

echo "=== a restart keeps the agent the chat declared ==="
result "${MARK} agent=river chat=chat-r" > "${TMP}/r.jsonl"
out="$(start "${TMP}/two" "${TMP}/r.jsonl")"
check "it re-attaches that agent" '[[ $(git -C "${TMP}/two/.agent" branch --show-current) == agent/river ]]'
check "and does not ask again" '[[ "${out}" == *"already runs as river; do not ask again"* && "${out}" != *"Ask which"* ]]'
check "it names the chat's own file" '[[ "${out}" == *".agent/chats/chat-r.md"* ]]'

echo "=== versions that share no release line are not ordered ==="
sed -i "0,/^## ${v}/s//## 7.7.7/" "${TMP}/none/CHANGELOG.md"
out="$(start "${TMP}/none")"
check "a version the canon never released claims no direction" '[[ "${out}" == *"(7.7.7) is not a release of the canon"* && "${out}" != *behind* ]]'
out="$(STEWIE_CANON="${TMP}/nowhere" start "${TMP}/none")"
check "an unreachable canon is said, not taken for parity" '[[ "${out}" == *"Update check unavailable"* ]]'

echo "=== the canon, and a repository with no origin ==="
fixture "${TMP}/c"
git -C "${TMP}/c" push -q origin main:custodian 2>/dev/null
out="$(STEWIE_CANON="${TMP}/c.origin" start "${TMP}/c")"
check "the canon is named" '[[ "${out}" == *"· the canon."* ]]'
check "no agent is created there" '[[ "${out}" == *"No agent is created on the canon"* && ! -e "${TMP}/c/.agent" ]]'
check "the custodian is never attached unasked" '[[ "${out}" == *"only when the person asks for the custodian"* ]]'
git -C "${TMP}/none" remote remove origin
out="$(STEWIE_OFFLINE=1 start "${TMP}/none")"
check "no origin: undetermined, and the chat asks" '[[ "${out}" == *"undetermined"* && "${out}" == *"Ask the person"* ]]'

echo "=== path.sh ==="
env_file="${TMP}/env"; : > "${env_file}"
CLAUDE_ENV_FILE="${env_file}" CLAUDE_PROJECT_DIR="${TMP}/one" bash "${STEWIE}/.claude/hooks/path.sh"
CLAUDE_ENV_FILE="${env_file}" CLAUDE_PROJECT_DIR="${TMP}/one" bash "${STEWIE}/.claude/hooks/path.sh"
check "tools/bin goes on PATH once" '[[ $(grep -c "${TMP}/one/tools/bin" "${env_file}") -eq 1 ]]'
check "the line it writes runs" '(source "${env_file}"; [[ ":${PATH}:" == *":${TMP}/one/tools/bin:"* ]])'

finish "session start (anchor.sh, attach, path.sh)"
