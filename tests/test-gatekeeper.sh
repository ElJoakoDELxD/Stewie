#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
S="${STEWIE}/.claude/settings.json"

gk() { python3 -I - "${S}" "$@" <<'PY'
import json, re, sys
s = json.load(open(sys.argv[1]))["hooks"]
what, *args = sys.argv[2:]
def hits(m, name):
    if m in ("", "*"): return True
    if re.fullmatch(r"[A-Za-z0-9_\- ,|]+", m): return name in {x.strip() for x in re.split(r"[|,]", m)}
    return re.search(m, name) is not None
def agents(event):
    for group in s.get(event, []):
        for h in group.get("hooks", []):
            if h.get("type") == "agent" and "gatekeeper.md" in h.get("prompt", ""):
                yield group.get("matcher", ""), h
def rule(pattern, command):
    p = re.fullmatch(r"Bash\((.*)\)", pattern).group(1)
    rx = ".*".join(map(re.escape, p.split("*")))
    if p.endswith(" *") and p.count("*") == 1: rx = "(?:" + rx + "|" + re.escape(p[:-2]) + ")"
    for sub in re.split(r"&&|\|\||\|&|[;|&\n]", command):
        sub = re.sub(r"^\s*(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*", "", sub).strip()
        if re.fullmatch(rx, sub): return True
    return False
every = [h for e in ("PreToolUse", "Stop") for _, h in agents(e)]
if what == "wired":
    sys.exit(0 if every and all(h.get("model") and re.search(r"<hook-input>\s*\$ARGUMENTS\s*</hook-input>", h["prompt"]) for h in every) else 1)
if what == "stop":
    sys.exit(0 if any(h.get("model") and not h.get("if") for _, h in agents("Stop")) else 1)
if what == "bash":
    sys.exit(0 if any(hits(m, "Bash") and h.get("if") and rule(h["if"], args[0]) for m, h in agents("PreToolUse")) else 1)
if what == "tool":
    sys.exit(0 if any(hits(m, args[0]) for m, h in agents("PreToolUse") if not h.get("if")) else 1)
PY
}

echo "=== the gatekeeper is wired ==="
check "the criterion file exists"                         '[[ -s "${STEWIE}/.claude/hooks/gatekeeper.md" ]]'
check "every judge has a model and the marked input"      'gk wired'
check "a Stop judge that always runs"                     'gk stop'

echo
echo "=== pushes and gh api are judged ==="
for c in "git push" "git push -u origin fix" "cd .agent && git push" "FOO=1 git push origin fix" \
         "git -C .agent push" "git -c push.default=current push origin fix" "gh api repos/o/r/pulls -f title=x"; do
  check "${c}" "gk bash '${c}'"
done
for c in "git status" "git commit -m fix" "ls -la"; do
  check "${c} is not judged" "! gk bash '${c}'"
done

echo
echo "=== tools that may write outside are judged ==="
for t in mcp__github__create_pull_request mcp__github__push_files mcp__github__merge_pull_request \
         mcp__github__add_issue_comment mcp__github__issue_write mcp__github__create_or_update_file \
         mcp__github__subscribe_pr_activity mcp__Claude_Code_Remote__create_trigger \
         mcp__Claude_Code_Remote__send_later mcp__Claude_Code_Remote__fire_trigger \
         mcp__Claude_Code_Remote__watch_url mcp__Claude_Docs__batch mcp__Claude_Docs__create \
         mcp__gmail__send_email Artifact ArtifactData; do
  check "${t} is judged" "gk tool ${t}"
done

echo
echo "=== tools that only read pass unjudged ==="
for t in mcp__github__get_file_contents mcp__github__list_branches mcp__github__search_code \
         mcp__github__pull_request_read mcp__github__issue_read mcp__Claude_Code_Remote__list_triggers \
         mcp__Claude_Code_Remote__get_session mcp__Claude_Code_Remote__read_documentation \
         mcp__Claude_Docs__read mcp__Claude_Docs__query Read Grep Glob Bash; do
  check "${t} is not judged" "! gk tool ${t}"
done

finish "gatekeeper wiring"
