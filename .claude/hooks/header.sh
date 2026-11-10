#!/usr/bin/env bash

set -uo pipefail

bin="$(dirname "${BASH_SOURCE[0]}")/../../tools/bin"
IFS=$'\t' read -r transcript session <<< "$(python3 -I -c '
import json, sys
d = json.load(sys.stdin)
clean = lambda v: str(v or "-").replace("\t", " ").replace("\n", " ")
print(clean(d.get("transcript_path")) + "\t" + clean(d.get("session_id")))
' 2>/dev/null)"
[[ -n "${transcript:-}" && "${transcript}" != "-" ]] && export STEWIE_TRANSCRIPT="${transcript}"
[[ -n "${session:-}" && "${session}" != "-" && -z "${CLAUDE_CODE_SESSION_ID:-}" ]] && export CLAUDE_CODE_SESSION_ID="${session}"

err="$(mktemp 2>/dev/null)" || exit 0
trap 'rm -f "${err}"' EXIT
stamp="$("${bin}/clock" 2>"${err}")" || exit 0
[[ -n "${stamp}" ]] || exit 0
line="$(printf '%s\n' "${stamp}" | "${bin}/header" 2>/dev/null)" || exit 0
[[ "${line}" == \[*\] ]] || exit 0
printf '%s\n' "${line}"
grep '^DESFASE' "${err}" 2>/dev/null
exit 0
