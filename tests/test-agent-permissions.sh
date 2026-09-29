#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
H="${STEWIE}/.claude/hooks/agent-permissions.sh"
bin="${STEWIE}/tools/bin"
fixture "${TMP}/p" scout
P="${TMP}/p"; A="${P}/.agent"
cd "${P}" && "${bin}/attach" scout >/dev/null 2>&1
tr="${TMP}/t.jsonl"; : > "${tr}"
run() { hook "${H}" "$(payload "$@")"; }

echo "=== before a declaration: the control ==="
check "Write anywhere passes" '[[ $(run Write "${P}" "${tr}" file_path=README.md) == PASS ]]'

d="$(STEWIE_TRANSCRIPT="${tr}" STEWIE_CHAT=chat-a "${bin}/header" --declare agent=scout 2>&1)"; result "${d}" >> "${tr}"
check "the declaration is accepted" '[[ "${d}" == "${MARK} agent=scout chat=chat-a" ]]'
check "a second declaration is refused" '! STEWIE_TRANSCRIPT="${tr}" "${bin}/header" --declare agent=other 2>/dev/null'

echo "=== once declared: effects are the permissions ==="
check "a declared path is allowed"         '[[ $(run Write "${P}" "${tr}" file_path=.agent/memory/notes.md) == PASS ]]'
check "another declared path is allowed"   '[[ $(run Edit "${A}" "${tr}" file_path=projects/garden/plan.md) == PASS ]]'
check "this chat's own file is allowed"    '[[ $(run Write "${P}" "${tr}" file_path=.agent/chats/chat-a.md) == PASS ]]'
check "an undeclared path is blocked"      '[[ $(run Write "${P}" "${tr}" file_path=README.md) == BLOCK ]]'
check "and the refusal names it"           'grep -q "declares no effect that writes README.md" "${TMP}/hook.err"'
check "the agent's own file is blocked"    '[[ $(run Edit "${P}" "${tr}" file_path=.agent/agent.md) == BLOCK ]]'
check "and the refusal says why"           'grep -q "may not change its own definition" "${TMP}/hook.err"'
check "a notebook is held the same way"    '[[ $(run NotebookEdit "${P}" "${tr}" notebook_path=/tmp/x.ipynb) == BLOCK ]]'
check "a traversal out of a declared path is blocked" '[[ $(run Write "${P}" "${tr}" file_path=.agent/memory/../agent.md) == BLOCK ]]'
check "a deeper traversal is blocked"      '[[ $(run Write "${P}" "${tr}" file_path=.agent/memory/../../README.md) == BLOCK ]]'
check "reading is not writing"             '[[ $(run Read "${P}" "${tr}" file_path=README.md) == PASS ]]'

echo "=== a chat reads only its own memory ==="
echo other > "${A}/chats/chat-b.md"
check "its own file reads"                 '[[ $(run Read "${P}" "${tr}" file_path=.agent/chats/chat-a.md) == PASS ]]'
check "another chat's file is refused"     '[[ $(run Read "${P}" "${tr}" file_path=.agent/chats/chat-b.md) == BLOCK ]]'
check "and the refusal names the file"     'grep -q "chats/chat-b.md is another chat" "${TMP}/hook.err"'
check "a search over chats/ is refused"    '[[ $(run Grep "${P}" "${tr}" pattern=x path=.agent/chats) == BLOCK ]]'
check "a search over .agent/ is refused"   '[[ $(run Grep "${A}" "${tr}" pattern=x) == BLOCK ]]'
check "a search over memory/ reads"        '[[ $(run Grep "${P}" "${tr}" pattern=x path=.agent/memory) == PASS ]]'
check "a glob into chats/ is refused"      '[[ $(run Glob "${P}" "${tr}" pattern=.agent/chats/*.md) == BLOCK ]]'
check "Bash on another chat is refused"    '[[ $(run Bash "${P}" "${tr}" command="cat .agent/chats/chat-b.md") == BLOCK ]]'
check "Bash on all chats is refused"       '[[ $(run Bash "${A}" "${tr}" command="grep -r plan chats/") == BLOCK ]]'
check "Bash on its own file reads"         '[[ $(run Bash "${P}" "${tr}" command="cat .agent/chats/chat-a.md") == PASS ]]'
check "it holds before a declaration too"  '[[ $(STEWIE_CHAT=chat-a run Read "${P}" /dev/null file_path=.agent/chats/chat-b.md) == BLOCK ]]'

echo "=== pushes come only from a declared path ==="
check "a push from .agent/ passes"         '[[ $(run Bash "${A}" "${tr}" command="git push") == PASS ]]'
check "a push from the project is refused" '[[ $(run Bash "${P}" "${tr}" command="git push origin HEAD") == BLOCK ]]'
check "and the refusal says how"           'grep -q "cd .agent" "${TMP}/hook.err"'
check "a chained push is judged where it runs" '[[ $(run Bash "${P}" "${tr}" command="cd .agent && git push") == BLOCK ]]'
check "a push named in a message is not a push" '[[ $(run Bash "${A}" "${tr}" command="git commit -m \"push later\"") == PASS ]]'
check "other commands pass"                '[[ $(run Bash "${P}" "${tr}" command="ls -la") == PASS ]]'

echo "=== the custodian: its role file on main, the template its effect ==="
fixture "${TMP}/c"
C="${TMP}/c"
git -C "${C}" worktree add -q --orphan -b custodian "${C}/.agent" 2>/dev/null
git -C "${C}/.agent" commit -q --allow-empty -m seed
tc="${TMP}/c.jsonl"; : > "${tc}"
d="$(cd "${C}" && STEWIE_TRANSCRIPT="${tc}" STEWIE_CHAT=chat-c "${bin}/header" --declare agent=custodian 2>&1)"; result "${d}" >> "${tc}"
check "the custodian is declared"          '[[ "${d}" == "${MARK} agent=custodian chat=chat-c" ]]'
check "it writes the template"             '[[ $(run Write "${C}" "${tc}" file_path=README.md) == PASS ]]'
check "never its own role file"            '[[ $(run Edit "${C}" "${tc}" file_path=.claude/agents/custodian.md) == BLOCK ]]'

finish ".claude/hooks/agent-permissions.sh"
