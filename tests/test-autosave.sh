#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
HOOK="${STEWIE}/.claude/hooks/autosave.sh"
R="${TMP}/r"

save() { printf '{"hook_event_name":"Stop"}' | CLAUDE_PROJECT_DIR="${R}" bash "${HOOK}" 2>&1; }
quiet() { local out; out="$(save)" && [[ -z "${out}" ]]; }
head_of() { git -C "$1" rev-parse -q --verify "$2" 2>/dev/null; }

fixture "${R}" ana
check "no agent attached: silent"                 'quiet'
git -C "${R}" fetch -q origin agent/ana:agent/ana
git -C "${R}" worktree add -q "${R}/.agent" agent/ana
before="$(head_of "${R}/.agent" HEAD)"
check "nothing to save: silent, and no commit"     'quiet && [[ "$(head_of "${R}/.agent" HEAD)" == "${before}" ]]'

printf 'draft\n' > "${R}/.agent/draft.md"
printf 'root edit\n' >> "${R}/CHANGELOG.md"
root_before="$(head_of "${R}" HEAD)"
check "changes are saved in silence"               'quiet'
check "they are committed as <agent>: autosave"    '[[ "$(git -C "${R}/.agent" log -1 --format=%s)" == "ana: autosave" && -z "$(git -C "${R}/.agent" status --porcelain)" ]]'
check "and pushed to the agent branch"             '[[ "$(head_of "${R}.origin" refs/heads/agent/ana)" == "$(head_of "${R}/.agent" HEAD)" ]]'
check "nothing outside .agent/ is touched"         '[[ "$(head_of "${R}" HEAD)" == "${root_before}" && -n "$(git -C "${R}" status --porcelain CHANGELOG.md)" ]]'

git -C "${R}/.agent" remote set-url origin "${TMP}/gone.origin"
printf 'more\n' >> "${R}/.agent/draft.md"
out="$(save)"; rc=$?
check "a failed push still exits 0"                '[[ ${rc} -eq 0 ]]'
check "and says, in one line, committed not pushed" '[[ "$(printf "%s\n" "${out}" | wc -l)" -eq 1 && "${out}" == *"committed"* && "${out}" == *"not pushed"* ]]'
check "the work is committed"                      '[[ -z "$(git -C "${R}/.agent" status --porcelain)" && "$(head_of "${R}/.agent" HEAD)" != "$(head_of "${R}.origin" refs/heads/agent/ana)" ]]'

git -C "${R}/.agent" remote set-url origin "${R}.origin"
git -C "${R}/.agent" push -q origin HEAD:refs/heads/agent/ana

git -C "${R}/.agent" config push.default nothing
git -C "${R}/.agent" tag agent/ana
printf 'explicit\n' >> "${R}/.agent/draft.md"
check "the push names its destination"             'quiet && [[ "$(head_of "${R}.origin" refs/heads/agent/ana)" == "$(head_of "${R}/.agent" HEAD)" ]]'
git -C "${R}/.agent" config --unset push.default
git -C "${R}/.agent" tag -d agent/ana >/dev/null

for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD; do
  path="$(git -C "${R}/.agent" rev-parse --path-format=absolute --git-path "${state}")"
  head_of "${R}/.agent" HEAD > "${path}"
  printf '%s\n' "${state}" >> "${R}/.agent/draft.md"
  before="$(head_of "${R}/.agent" HEAD)"
  check "a ${state} in progress: silent, and no commit" 'quiet && [[ "$(head_of "${R}/.agent" HEAD)" == "${before}" && -n "$(git -C "${R}/.agent" status --porcelain)" ]]'
  rm -f "${path}"
done
quiet

origin_before="$(head_of "${R}.origin" refs/heads/agent/ana)"
printf 'canon\n' >> "${R}/.agent/draft.md"
out="$(STEWIE_CANON="FILE://${R}.origin.git/" save)"
check "origin is the canon: committed, not pushed, silent" '[[ -z "${out}" && -z "$(git -C "${R}/.agent" status --porcelain)" && "$(head_of "${R}.origin" refs/heads/agent/ana)" == "${origin_before}" ]]'
git -C "${R}/.agent" push -q origin HEAD:refs/heads/agent/ana

git -C "${R}.origin" update-ref -d refs/heads/agent/ana
printf 'first\n' >> "${R}/.agent/draft.md"
out="$(save)"
check "a branch not on origin: committed, not pushed" '[[ -z "$(git -C "${R}/.agent" status --porcelain)" && -z "$(head_of "${R}.origin" refs/heads/agent/ana)" ]]'
check "and says, in one line, the first push waits for the handoff" '[[ "$(printf "%s\n" "${out}" | wc -l)" -eq 1 && "${out}" == *"not pushed"* && "${out}" == *"handoff"* ]]'
git -C "${R}/.agent" push -q origin HEAD:refs/heads/agent/ana

git -C "${R}" branch -q custodian main
git -C "${R}" worktree remove --force "${R}/.agent"
git -C "${R}" worktree add -q "${R}/.agent" custodian
printf 'c\n' > "${R}/.agent/c.md"
out="$(save)"
check "the custodian is committed, never pushed"   '[[ "$(git -C "${R}/.agent" log -1 --format=%s)" == "custodian: autosave" && -z "$(head_of "${R}.origin" refs/heads/custodian)" && "${out}" == *"not pushed"* ]]'
git -C "${R}" worktree remove --force "${R}/.agent"
git -C "${R}" worktree add -q "${R}/.agent" agent/ana

git -C "${R}" remote remove origin
printf 'local\n' >> "${R}/.agent/draft.md"
check "no remote: committed in silence"            'quiet && [[ -z "$(git -C "${R}/.agent" status --porcelain)" ]]'

git -C "${R}" worktree remove --force "${R}/.agent"
git -C "${R}" worktree add -q "${TMP}/elsewhere" agent/ana
ln -s "${TMP}/elsewhere" "${R}/.agent"
printf 'linked\n' > "${TMP}/elsewhere/linked.md"
check "a symbolic link at .agent: silent, and no commit" 'quiet && [[ -n "$(git -C "${TMP}/elsewhere" status --porcelain)" ]]'
rm "${R}/.agent"
git -C "${R}" worktree remove --force "${TMP}/elsewhere"

git clone -q -b agent/ana "${R}.origin" "${R}/.agent"
printf 'clone\n' > "${R}/.agent/clone.md"
check "a separate clone at .agent: silent, and no commit" 'quiet && [[ -n "$(git -C "${R}/.agent" status --porcelain)" ]]'
rm -rf "${R}/.agent"

mkdir -p "${R}/.agent"; printf 'x\n' > "${R}/.agent/loose.md"
check "a folder that is no worktree: silent"       'quiet && [[ -f "${R}/.agent/loose.md" ]]'
check "bad input, no output and no failure"        'out="$(printf "x" | CLAUDE_PROJECT_DIR="${TMP}/none" bash "${HOOK}" 2>&1)"; [[ $? -eq 0 && -z "${out}" ]]'
check "the hook is wired to Stop"                  'python3 -I -c "import json,sys; s=json.load(open(sys.argv[1])); sys.exit(0 if any(\"autosave.sh\" in h.get(\"command\",\"\") for g in s[\"hooks\"].get(\"Stop\",[]) for h in g[\"hooks\"]) else 1)" "${STEWIE}/.claude/settings.json"'

finish "autosave"
