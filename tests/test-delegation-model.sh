#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
HOOK="${STEWIE}/.claude/hooks/delegation-model.sh"

run() { printf '%s' "$1" | bash "${HOOK}" >/dev/null 2>&1; }
blocks() { run "$1"; [[ $? -eq 2 ]]; }
agent() { printf '{"tool_name":"Agent","tool_input":%s}' "$1"; }

check "no model is blocked"                         'blocks "$(agent "{\"prompt\":\"x\"}")"'
check "an empty model is blocked"                   'blocks "$(agent "{\"model\":\"\"}")"'
check "a model of spaces is blocked"                'blocks "$(agent "{\"model\":\"   \"}")"'
check "a number as model is blocked"                'blocks "$(agent "{\"model\":5}")"'
check "true as model is blocked"                    'blocks "$(agent "{\"model\":true}")"'
check "a list as model is blocked"                  'blocks "$(agent "{\"model\":[\"x\"]}")"'
check "an agent type with a tail is blocked"        'blocks "$(agent "{\"subagent_type\":\"malicious-code-review\\nx\"}")"'
check "an agent type in other case is blocked"      'blocks "$(agent "{\"subagent_type\":\"Malicious-Code-Review\"}")"'
check "an EGM reviewer inherits"                    'run "$(agent "{\"subagent_type\":\"egm:egm-design\"}")" && run "$(agent "{\"subagent_type\":\"egm-zoom-out\"}")"'
check "a look-alike of EGM is blocked"              'blocks "$(agent "{\"subagent_type\":\"egm:egm-design x\"}")" && blocks "$(agent "{\"subagent_type\":\"xegm-design\"}")" && blocks "$(agent "{\"subagent_type\":\"egm-\"}")"'
check "another agent type still needs a model"      'blocks "$(agent "{\"subagent_type\":\"general-purpose\"}")"'
check "a null tool_input is blocked"                'blocks "{\"tool_input\":null}"'
check "unreadable input is blocked"                 'blocks "not json"'
check "empty input is blocked"                      'blocks ""'
check "without python3 it blocks"                   'printf "{}" | env PATH=/nonexistent /bin/bash "${HOOK}" >/dev/null 2>&1; [[ $? -eq 2 ]]'
check "a named model passes"                        'run "$(agent "{\"model\":\"haiku\"}")"'
check "the malicious-code review inherits"          'run "$(agent "{\"subagent_type\":\"malicious-code-review\"}")"'
check "the block names its rule"                    '[[ "$(printf "{}" | bash "${HOOK}" 2>&1)" == *"BLOCKED by delegation-model.sh"* ]]'
check "the hook is wired to Agent"                  'python3 -I -c "import json,sys; s=json.load(open(sys.argv[1])); sys.exit(0 if any(g.get(\"matcher\")==\"Agent\" and any(\"delegation-model.sh\" in h.get(\"command\",\"\") for h in g[\"hooks\"]) for g in s[\"hooks\"][\"PreToolUse\"]) else 1)" "${STEWIE}/.claude/settings.json"'

finish "delegation-model.sh"
