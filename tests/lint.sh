#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
for tool in git shellcheck ruff; do
  command -v "${tool}" >/dev/null || { echo "FAIL  ${tool} is not installed"; exit 1; }
done
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "FAIL  not a git checkout: nothing to list"; exit 1; }
listed() { git ls-files -z -co --exclude-standard -- "$@" | while IFS= read -r -d '' f; do [[ -f "${f}" ]] && printf '%s\0' "${f}"; done; }
mapfile -d '' -t shells < <(listed '*.sh' 'tools/bin/*' 'memory/_example/tools/sandbox/linux-x86_64/socat')
mapfile -d '' -t pys < <(listed '*.py')
(( ${#shells[@]} && ${#pys[@]} )) || { echo "FAIL  no scripts or no Python files found"; exit 1; }
fail=0
echo "$(shellcheck --version | sed -n 2p), ${#shells[@]} scripts; $(ruff --version), ${#pys[@]} files"
shellcheck -S warning -- "${shells[@]}" || fail=1
ruff check --quiet -- "${pys[@]}" || fail=1
(( fail == 0 )) && echo "lint: nothing found"
exit "${fail}"
