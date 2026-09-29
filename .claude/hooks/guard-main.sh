#!/usr/bin/env bash

set -uo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/lib/command.sh"
source "${here}/lib/chat.sh"

input="$(cat)"
eval "$(printf '%s' "${input}" | python3 -c '
import json, shlex, sys
d = json.load(sys.stdin)
ti = d.get("tool_input") or {}
for k, v in (("tool", d.get("tool_name", "")), ("cwd", d.get("cwd", "")),
             ("path", ti.get("file_path") or ti.get("notebook_path") or ""),
             ("command", ti.get("command", ""))):
    print("%s=%s" % (k, shlex.quote(v or "")))
' 2>/dev/null)" || exit 0
cwd="${cwd:-$PWD}"
root="$(cd "${cwd}" 2>/dev/null && stewie_root)"; root="${root:-$(stewie_root)}"
branch="$(git -C "${root}" branch --show-current 2>/dev/null)"
deny() { echo "BLOCKED by guard-main.sh: $1" >&2; exit 2; }

case "${tool}" in
  Write|Edit|MultiEdit|NotebookEdit)
    [[ "${branch}" == "main" && -n "${path}" ]] || exit 0
    abs="$(python3 -c 'import os,sys; print(os.path.realpath(os.path.join(sys.argv[1], sys.argv[2])))' "${cwd}" "${path}")"
    real="$(cd "${root}" && pwd -P)"
    if [[ "${abs}" == "${real}" || "${abs}" == "${real}"/* ]] && [[ "${abs}" != "${real}/.agent/"* ]]; then
      deny "main is read-only. Write in .agent/, your agent's branch; a change to the template goes on another branch, by a pull request the person approves."
    fi
    exit 0 ;;
  Bash) ;;
  *) exit 0 ;;
esac

reason="$(executable_text "${command}" | python3 "${here}/lib/git_calls.py" | python3 -c '
import json, os, re, sys
cwd, root, branch = sys.argv[1], os.path.realpath(sys.argv[2]), sys.argv[3]
agent = os.path.join(root, ".agent")
MAIN = "main"
COMMITTING = {"commit", "merge", "rebase", "reset", "cherry-pick", "revert", "am", "pull"}

def to_main(word):
    return word == MAIN or bool(re.fullmatch(r".*[:+/]" + MAIN, word))

for line in sys.stdin:
    c = json.loads(line)
    if c.get("unparsed"):
        print("could not be read, and it names a push to main" if re.search(r"push.*\bmain\b", sys.argv[4]) else "")
        break
    where = cwd
    for d in c["C"]:
        where = os.path.join(where, d)
    where = os.path.realpath(where)
    if c["C"] and not (where == root or where.startswith(root + os.sep)):
        continue
    sub, args = c["sub"], c["args"]
    flags = [a for a in args if a.startswith("-")]
    operands = [a for a in args if not a.startswith("-")]
    if sub == "push" and (any(f in ("--all", "--mirror") for f in flags) or any(to_main(o) for o in operands)):
        print("pushes to main"); break
    if sub == "branch" and MAIN in operands and any(re.fullmatch(r"-[A-Za-z]*[fdDmMcC][A-Za-z]*", f) for f in flags):
        print("moves, renames or deletes main"); break
    if sub in ("update-ref", "symbolic-ref") and any(o in (MAIN, "refs/heads/" + MAIN) for o in operands):
        print("rewrites main through ref plumbing"); break
    in_main_tree = (where == root or where.startswith(root + os.sep)) and not (where == agent or where.startswith(agent + os.sep))
    if branch == MAIN and in_main_tree and (sub in COMMITTING or sub == "push"):
        print("would change main from its own worktree (git %s)" % sub); break
' "${cwd}" "${root}" "${branch}" "${command}" 2>/dev/null)"

if [[ -n "${reason}" ]]; then
  deny "that command ${reason}. main is read-only: work in .agent/, and a template change goes on another branch, by a pull request the person approves."
fi
exit 0
