#!/usr/bin/env bash

set -uo pipefail

path="$(python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("transcript_path") or "")' 2>/dev/null)" || exit 0
[[ -n "${path}" && -f "${path}" ]] || exit 0
read -r percent _ <<< "$(python3 -I "$(dirname "${BASH_SOURCE[0]}")/../../tools/bin/context" "${path}" 2>/dev/null)"
[[ "${percent:-}" =~ ^[0-9]+$ ]] || exit 0

if (( percent >= 85 )); then band=85
elif (( percent >= 70 )); then band=70
elif (( percent >= 50 )); then band=50
else exit 0; fi

echo "The context window is at least ${band}% full. Long chats cost more each turn and fail when the window fills: run the handoff now, and offer the person a new chat to continue (rules/ending-a-session.md)."
