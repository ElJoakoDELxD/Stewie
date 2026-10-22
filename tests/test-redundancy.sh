#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
D="${TMP}/docs"; mkdir -p "${D}"
printf '# A\n\nThe agent drafts every public message and the person publishes it after reading each line.\n' > "${D}/a.md"
printf '# B\n\nThe agent drafts every public message and the person publishes it after reading each line.\n' > "${D}/b.md"
printf '# C\n\nA wholly different sentence about clocks, rain, gardens, rivers and distant mountains.\n' > "${D}/c.md"
R="${STEWIE}/tools/redundancy.py"
check "the same sentence in two files is a pair" 'python3 -I "${R}" "${D}/a.md" "${D}/b.md" | grep -q "^redundancy: 1 candidate pairs"'
check "different sentences are not"              'python3 -I "${R}" "${D}/a.md" "${D}/c.md" | grep -q "^redundancy: 0 candidate pairs"'

finish "redundancy report"
