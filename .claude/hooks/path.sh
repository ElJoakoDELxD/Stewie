#!/usr/bin/env bash

set -uo pipefail
[[ -n "${CLAUDE_ENV_FILE:-}" ]] || exit 0
bin="${CLAUDE_PROJECT_DIR:-$(pwd)}/tools/bin"
grep -qF "${bin}" "${CLAUDE_ENV_FILE}" 2>/dev/null && exit 0
printf 'case ":$PATH:" in *":%s:"*) ;; *) export PATH="%s:$PATH" ;; esac\n' "${bin}" "${bin}" >> "${CLAUDE_ENV_FILE}"
exit 0
