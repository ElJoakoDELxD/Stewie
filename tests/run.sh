#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.."
failed=()
log="$(mktemp)"
trap 'rm -f "${log}"' EXIT
for bench in tests/test-*.sh; do
  if bash "${bench}" > "${log}" 2>&1; then
    echo "pass  ${bench}"
  else
    echo "FAIL  ${bench}"; sed 's/^/      /' "${log}"; failed+=("${bench}")
  fi
done
[[ ${#failed[@]} -eq 0 ]] && echo "every bench passed" || echo "${#failed[@]} failing: ${failed[*]}"
exit "${#failed[@]}"
