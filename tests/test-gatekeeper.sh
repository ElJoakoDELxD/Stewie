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
check "every gatekeeper carries its criterion in its prompt, word for word" 'python3 -I "${STEWIE}/tools/gatekeeper-prompt.py" --check >/dev/null'
check "and the bench sees it without the script"          'python3 -I -c "
import json, sys
c = open(sys.argv[2], encoding=\"utf-8\").read().strip()
ps = [h[\"prompt\"] for e in json.load(open(sys.argv[1]))[\"hooks\"].values() for g in e for h in g[\"hooks\"] if h.get(\"type\") == \"agent\"]
ok = lambda p: p.split(\"<criterion>\\n\", 1)[1].split(\"\\n</criterion>\", 1)[0] == c and p.index(\"</criterion>\") < p.index(\"<hook-input>\") and p.count(\"\$ARGUMENTS\") == 1
sys.exit(0 if len(ps) == 6 and all(ok(p) for p in ps) else 1)" "${S}" "${STEWIE}/.claude/hooks/gatekeeper.md"'
check "and none is told to look for it"                  '! grep -q "highest directory\|the criterion was not found" "${S}"'
check "every gatekeeper runs on the more capable model"   'python3 -I -c "import json,sys; h=[x for e in json.load(open(sys.argv[1]))[\"hooks\"].values() for g in e for x in g[\"hooks\"] if x.get(\"type\")==\"agent\"]; sys.exit(0 if len(h)==6 and all(x.get(\"model\")==\"claude-sonnet-5-5\" for x in h) else 1)" "${S}"'
check "and is told to spend only what the answer needs"  'G2="${STEWIE}/.claude/hooks/gatekeeper.md"; grep -q "^## Spend only what is needed" "${G2}" && grep -q "stop at the first answer" "${G2}" && grep -q "Make no call the answer does not need" "${G2}" && grep -q "Never list every hit or read a whole file at once" "${G2}" && grep -q "If K is 0 there is no block yet" "${G2}"'
mkdir -p "${TMP}/drift"; cp -R "${STEWIE}/.claude" "${STEWIE}/tools" "${TMP}/drift/"
printf "\nA drifted line.\n" >> "${TMP}/drift/.claude/hooks/gatekeeper.md"
D="${TMP}/drift/tools/gatekeeper-prompt.py"
check "a criterion edited without its prompts is caught" 'out="$(python3 -I "${D}" --check)"; [[ $? -eq 1 ]] && grep -q "out of date" <<< "${out}"'
check "writing the prompts brings them back in line"     'python3 -I "${D}" | grep -q "wrote 6" && python3 -I "${D}" --check | grep -q "match" && grep -q "A drifted line." "${TMP}/drift/.claude/settings.json"'
check "a mistyped option writes nothing"                 'cp "${TMP}/drift/.claude/settings.json" "${TMP}/before.json"; ! python3 -I "${D}" --chek >/dev/null && cmp -s "${TMP}/before.json" "${TMP}/drift/.claude/settings.json"'
check "every judge has a model and the marked input"      'gk wired'
check "a Stop judge that always runs"                     'gk stop'

check "isolated local acts are left to code"            'grep -q "is authorized unjudged only when it runs isolated" "${STEWIE}/.claude/hooks/gatekeeper.md"'
check "elsewhere a local act is judged"                   'grep -q "Otherwise judge the local act as an outward one" "${STEWIE}/.claude/hooks/gatekeeper.md"'
I="${STEWIE}/.claude/hooks/isolation.sh"; P="${TMP}/proj"; mkdir -p "${P}/.claude"; H="${TMP}/home"; mkdir -p "${H}/.claude"
iso() { printf '{"hook_event_name":"%s"}' "${EV:-SessionStart}" | env -i PATH="${PATH}" HOME="${H}" CLAUDE_PROJECT_DIR="${P}" "$@" bash "${I}" | python3 -I -c 'import json,sys,os; o=json.load(sys.stdin)["hookSpecificOutput"]; print(o["hookEventName"] + " " + o["additionalContext"])'; }
cloud="CLAUDE_CODE_REMOTE=true CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE=cloud_default"
check "a cloud container says so"                         '[[ "$(iso ${cloud})" == "SessionStart Stewie isolation: a cloud container." ]]'
check "and says it again at each message"                 '[[ "$(EV=UserPromptSubmit iso ${cloud})" == "UserPromptSubmit Stewie isolation: a cloud container." ]]'
check "this machine with no sandbox says so"              '[[ "$(iso)" == "SessionStart Stewie isolation: this machine, with no sandbox." ]]'
G="${STEWIE}/.claude/hooks/gatekeeper.md"
check "the gatekeeper is told to read one principal line, not all" 'grep -q "Read only the latest such line, in three calls" "${G}" && grep -q "offset N−1, and take the line number L of the last line" "${G}" && grep -q "at offset L with limit 1" "${G}"'
check "and told to read one isolation record, from the transcript" 'grep -q "read only it, in the same three calls" "${G}" && grep -q "None found means not isolated" "${G}" && ! grep -q "\.isolation" "${G}"'
check "a remote flag alone is not a cloud"                '[[ "$(iso CLAUDE_CODE_REMOTE=true)" == "SessionStart Stewie isolation: this machine, with no sandbox." ]]'
printf '{"env":{"CLAUDE_CODE_REMOTE":"true"}}' > "${P}/.claude/settings.json"
check "a cloud the settings claim is not a cloud"         '[[ "$(iso ${cloud})" == "SessionStart Stewie isolation: this machine, with no sandbox." ]]'
rm "${P}/.claude/settings.json"
printf '{"sandbox":{"enabled":true}}' > "${H}/.claude/settings.json"
check "a sandbox that may fall back is no sandbox"        '[[ "$(iso)" == "SessionStart Stewie isolation: this machine, with no sandbox." ]]'
printf '{"sandbox":{"enabled":true,"failIfUnavailable":true,"excludedCommands":["git *"]}}' > "${H}/.claude/settings.json"
check "a sandbox that must run counts, with its exclusions" '[[ "$(iso)" == "SessionStart Stewie isolation: this machine, with the Bash sandbox on; these run outside it: git *." ]]'
printf '{"sandbox":{"enabled":true,"failIfUnavailable":true},"permissions":{"additionalDirectories":["~"]}}' > "${H}/.claude/settings.json"
check "a sandbox that can write the home folder is no sandbox" '[[ "$(iso)" == "SessionStart Stewie isolation: this machine, with no sandbox." ]]'
printf '{"sandbox":{"enabled":true,"failIfUnavailable":true,"enableWeakerNestedSandbox":true}}' > "${H}/.claude/settings.json"
check "a weaker sandbox is no sandbox"                    '[[ "$(iso)" == "SessionStart Stewie isolation: this machine, with no sandbox." ]]'
mkdir -p "${TMP}/cfg"; printf '{"sandbox":{"enabled":true,"failIfUnavailable":true,"filesystem":{"disabled":true}}}' > "${TMP}/cfg/settings.json"
check "the configured user folder is read, and an open filesystem is no sandbox" '[[ "$(iso CLAUDE_CONFIG_DIR="${TMP}/cfg")" == "SessionStart Stewie isolation: this machine, with no sandbox." ]]'
printf '{"sandbox":{"enabled":false}}' > "${P}/.claude/settings.local.json"
check "any setting that turns it off wins"                '[[ "$(iso)" == "SessionStart Stewie isolation: this machine, with no sandbox." ]]'
check "it runs at session start and at each message"      'python3 -I -c "import json,sys; h=json.load(open(sys.argv[1]))[\"hooks\"]; sys.exit(0 if all(any(\"isolation.sh\" in x.get(\"command\",\"\") for g in h[e] for x in g[\"hooks\"]) for e in (\"SessionStart\",\"UserPromptSubmit\")) else 1)" "${S}"'
check "and outward acts still need the principal"         'grep -q "It is \*\*not authorized\*\*" "${STEWIE}/.claude/hooks/gatekeeper.md"'
check "Stop counts local acts off the cloud"              'grep -q "the local ones that did not run isolated" "${STEWIE}/.claude/hooks/gatekeeper.md"'

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
