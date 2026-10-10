#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d)"; trap 'rm -rf "${work}"' EXIT
POOL="http://archive.ubuntu.com/ubuntu/pool/"
fail=0
checked=0
while IFS= read -r -d '' sources; do
  here="$(dirname "${sources}")"
  while IFS='|' read -r url digest; do
    [[ "${url}" == "${POOL}"* ]] || { echo "FAIL  ${url}: not from ${POOL}"; fail=1; continue; }
    deb="${work}/$(basename "${url}")"
    curl -fsSL --retry 3 -o "${deb}" "${url}" || { echo "FAIL  cannot download ${url}"; fail=1; continue; }
    [[ "$(sha256sum "${deb}" | cut -d' ' -f1)" == "${digest}" ]] || { echo "FAIL  ${url}: hash differs"; fail=1; continue; }
    mkdir -p "${deb%.deb}" && dpkg-deb -x "${deb}" "${deb%.deb}" || { echo "FAIL  cannot unpack ${url}"; fail=1; continue; }
    echo "ok    ${url}"
  done < <(sed -n 's#^| \(https\?://[^ |]*\.deb\) | `\([0-9a-f]\{64\}\)` |$#\1|\2#p' "${sources}")
  matched=" "
  while IFS='|' read -r file name version inner; do
    matched+="${file} "
    unpacked="$(ls -d "${work}/${name}_${version}_"*/ 2>/dev/null | head -1)"
    [[ -n "${unpacked}" ]] || { echo "FAIL  ${file}: no package ${name} ${version}"; fail=1; continue; }
    if cmp -s "$(readlink -f "${unpacked}${inner}")" "${here}/${file}"; then
      echo "ok    ${file} is ${name} ${version}:${inner}"; checked=$((checked + 1))
    else
      echo "FAIL  ${file} differs from ${name} ${version}:${inner}"; fail=1
    fi
  done < <(sed -n 's#^| `\([^`]*\)` | `[0-9a-f]\{64\}` | \([a-z0-9.+-]*\) \([0-9][^,]*\), `\([^`]*\)` | .*$#\1|\2|\3|\4#p' "${sources}")
  while IFS= read -r file; do
    [[ "${matched}" == *" ${file} "* ]] && continue
    if [[ "$(head -c 4 "${here}/${file}" | od -An -c | tr -d ' ')" == '177ELF' ]]; then
      echo "FAIL  ${file}: a binary with no package to come from"; fail=1
    fi
  done < <(sed -n 's#^| `\([^`]*\)` | `[0-9a-f]\{64\}` |.*$#\1#p' "${sources}")
done < <(git ls-files -z '*SOURCES.md')
[[ ${checked} -gt 0 ]] || { echo "FAIL  no binary was checked against a package"; fail=1; }
exit "${fail}"
