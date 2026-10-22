#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=bench GIT_AUTHOR_EMAIL=bench@example.invalid
export GIT_COMMITTER_NAME=bench GIT_COMMITTER_EMAIL=bench@example.invalid
work="$(mktemp -d)" || exit 1
trap 'rm -rf "${work}"' EXIT
git ls-files -z -co --exclude-standard > "${work}/files" 2>/dev/null && [[ -s "${work}/files" ]] \
  || { echo "FAIL  not a git checkout: nothing to copy"; exit 1; }
python3 -I -c '
import os, shutil, stat, sys
dst, listing = sys.argv[1], sys.argv[2]
for p in open(listing, "rb").read().decode().split("\0"):
    if p and os.path.lexists(p) and stat.S_ISREG(os.lstat(p).st_mode):
        os.makedirs(os.path.join(dst, os.path.dirname(p)), exist_ok=True)
        shutil.copy2(p, os.path.join(dst, p))
' "${work}/base" "${work}/files" || { echo "FAIL  the checkout could not be copied"; exit 1; }

targets=("baseline -")
for f in .claude/hooks/*.sh .claude/hooks/gatekeeper.md .claude/hooks/lib/*.sh .claude/hooks/lib/*.py tools/bin/* tools/*.py \
         memory/_example/tools/sandbox/*.sh memory/_example/tools/sandbox/*/socat; do
  [[ -f "${f}" ]] && targets+=("code ${f}")
done

mutate() {
  local kind="$1" file="$2" dir="$3"
  case "${kind}:${file}" in
    baseline:*) ;;
    code:*.md) : > "${dir}/${file}" ;;
    code:*.py) printf 'import sys\nsys.exit(0)\n' > "${dir}/${file}" ;;
    code:*/lib/*.sh) : > "${dir}/${file}" ;;
    code:*) printf '#!/usr/bin/env bash\nexit 0\n' > "${dir}/${file}" ;;
  esac
}

run() {
  local n="$1" kind="$2" file="$3" dir="${work}/copy-$1" b rc
  cp -a "${work}/base" "${dir}" || return
  mutate "${kind}" "${file}" "${dir}"
  git -C "${dir}" init -q -b main && git -C "${dir}" add -A && git -C "${dir}" commit -q -m copy || return
  for b in "${dir}"/tests/test-*.sh; do
    bash "${b}" >/dev/null 2>&1; rc=$?
    printf '%s\t%s\n' "${b##*/}" "${rc}"
  done > "${work}/benches-${n}"
  printf '%s\t%s\n' "${kind}" "${file}" > "${work}/target-${n}"
  rm -rf "${dir}"
}

jobs_max="$(nproc 2>/dev/null || echo 1)"
(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3) )) || jobs_max=1
n=0
for t in "${targets[@]}"; do
  n=$((n + 1))
  if (( jobs_max > 1 )); then
    run "${n}" "${t%% *}" "${t#* }" &
    while (( $(jobs -rp | wc -l) >= jobs_max )); do wait -n; done
  else
    run "${n}" "${t%% *}" "${t#* }"
  fi
done
wait

fail=0
if [[ ! -s "${work}/benches-1" ]]; then
  echo "FAIL  the tree as it is could not be run"; exit 1
fi
broken="$(awk -F'\t' '$2 != 0 {print $1}' "${work}/benches-1" | tr '\n' ' ')"
if [[ -n "${broken}" ]]; then
  echo "FAIL  these benches fail on the tree as it is, so they prove nothing below: ${broken}"; fail=1
else
  echo "ok    the tree passes every bench as it is"
fi
for i in $(seq 2 "${n}"); do
  if [[ ! -s "${work}/target-${i}" ]]; then
    echo "FAIL  ${targets[$((i - 1))]}: its run did not finish"; fail=1; continue
  fi
  IFS=$'\t' read -r kind file < "${work}/target-${i}"
  caught="$(awk -F'\t' 'NR == FNR {base[$1] = $2; next} $2 != 0 && base[$1] == 0 {print $1}' "${work}/benches-1" "${work}/benches-${i}" | tr '\n' ' ')"
  if [[ -n "${caught}" ]]; then
    echo "ok    ${kind} ${file}: fails ${caught}"
  else
    echo "FAIL  ${kind} ${file}: no bench fails when it does nothing"; fail=1
  fi
done
exit "${fail}"
