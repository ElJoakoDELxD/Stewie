#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
H="${STEWIE}/.claude/hooks/guard-main.sh"
fixture "${TMP}/p" scout
P="${TMP}/p"; A="${P}/.agent"
cd "${P}" && "${STEWIE}/tools/bin/attach" scout >/dev/null 2>&1
git -C "${P}" worktree add -q -b feature "${TMP}/f" 2>/dev/null
F="${TMP}/f"
bash_at() { hook "${H}" "$(payload Bash "$1" /dev/null command="$2")"; }
write_at() { hook "${H}" "$(payload "$1" "$2" /dev/null file_path="$3")"; }
want() { local got; got="$(bash_at "$2" "$3")"; check "$1: $3" '[[ "${got}" == '"$1"' ]]'; }

echo "=== standing on main: a chat writes in .agent/ ==="
check "Write to the template is blocked"   '[[ $(write_at Write "${P}" README.md) == BLOCK ]]'
check "and the refusal says where to write" 'grep -q "Write in .agent/" "${TMP}/hook.err"'
check "Edit of a hook is blocked"           '[[ $(write_at Edit "${P}" .claude/settings.json) == BLOCK ]]'
check "a traversal back into main is blocked" '[[ $(write_at Write "${P}" .agent/../README.md) == BLOCK ]]'
check "Write in .agent/ passes"             '[[ $(write_at Write "${P}" .agent/memory/x.md) == PASS ]]'
check "Write outside the project passes"    '[[ $(write_at Write "${P}" "${TMP}/scratch.md") == PASS ]]'
want BLOCK "${P}" "git commit -m x"
want BLOCK "${P}" "git merge feature"
want BLOCK "${P}" "git reset --hard HEAD~1"
want BLOCK "${P}" "git pull"
want BLOCK "${P}" "git push"
want BLOCK "${P}" "echo ok; git commit -am x"
want BLOCK "${P}" "bash -c \"git commit -m x\""
want PASS  "${A}" "git commit -m x"
want PASS  "${A}" "git push"
want PASS  "${P}" "git -C .agent commit -m x"
want PASS  "${P}" "git status"
want PASS  "${P}" "git log --oneline"
want PASS  "${P}" "git checkout -b feature-2"
want PASS  "${P}" "clock | header"
want PASS  "${P}" "ls -la"

echo "=== anywhere: main is never pushed to, moved or deleted ==="
want BLOCK "${F}" "git push origin main"
want BLOCK "${F}" "git push origin HEAD:main"
want BLOCK "${F}" "git push origin +main"
want BLOCK "${F}" "git push origin refs/heads/main"
want BLOCK "${F}" "git push --all origin"
want BLOCK "${F}" "git push --mirror origin"
want BLOCK "${F}" "git push origin \"main\""
want BLOCK "${F}" "git branch -D main"
want BLOCK "${F}" "git branch -f main HEAD"
want BLOCK "${F}" "git update-ref refs/heads/main HEAD"
want BLOCK "${F}" "sudo git push origin main"
want BLOCK "${F}" "GIT_TRACE=1 git push origin main"
want BLOCK "${F}" "git -c core.pager=cat push origin main"
want BLOCK "${A}" "git push origin HEAD:main"
want BLOCK "${F}" "eval \"git push origin main\""
want BLOCK "${F}" "git push origin main \""

echo "=== off main: ordinary work passes ==="
check "Write to the template on a branch passes" '[[ $(write_at Write "${F}" README.md) == PASS ]]'
want PASS "${F}" "git commit -m 'do not push to main from here'"
want PASS "${F}" "git commit -m 'main is the template' -m 'second paragraph'"
want PASS "${F}" "git push -u origin feature"
want PASS "${F}" "git push origin maintenance"
want PASS "${F}" "git log main..HEAD"
want PASS "${F}" "git checkout main"
want PASS "${F}" "echo main && echo main"
want PASS "${F}" "git -C /elsewhere/fixture push origin main"

echo "=== a body bound for a file is data; a body bound for a shell is not ==="
want PASS  "${F}" "$(printf 'cat > fixture.sh <<EOF\ngit push origin main\nEOF\n')"
want BLOCK "${F}" "$(printf 'cat <<EOF | bash\ngit push origin main\nEOF\n')"

finish ".claude/hooks/guard-main.sh"
