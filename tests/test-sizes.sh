#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

check "sizes.sh fixes its own locale" "grep -qx 'export LC_ALL=C' '${STEWIE}/tests/sizes.sh'"
LC_ALL=C bash "${STEWIE}/tests/sizes.sh" > "${TMP}/c.out" 2>&1
LC_ALL=C.UTF-8 bash "${STEWIE}/tests/sizes.sh" > "${TMP}/utf8.out" 2>&1
check "sizes.sh prints the same under C and C.UTF-8" "cmp -s '${TMP}/c.out' '${TMP}/utf8.out'"

finish "sizes"
