#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.."
failed=()
for bench in tests/test-*.sh; do
  if bash "${bench}" > "${TMPDIR:-/tmp}/stewie-bench.log" 2>&1; then
    echo "pass  ${bench}"
  else
    echo "FAIL  ${bench}"; sed 's/^/      /' "${TMPDIR:-/tmp}/stewie-bench.log"; failed+=("${bench}")
  fi
done
rm -f "${TMPDIR:-/tmp}/stewie-bench.log"
[[ ${#failed[@]} -eq 0 ]] && echo "every bench passed" || echo "${#failed[@]} failing: ${failed[*]}"
exit "${#failed[@]}"
