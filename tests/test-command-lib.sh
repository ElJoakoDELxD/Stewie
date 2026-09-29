#!/usr/bin/env bash

set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${here}/../.claude/hooks/lib/command.sh"

fails=0
MARK="MARKER_PAYLOAD"

has() {
  if executable_text "$1" | grep -q "${MARK}"; then printf 'ok   %s\n' "$2"
  else printf 'FAIL %s: marker was dropped, wanted it kept\n' "$2"; fails=$((fails + 1)); fi
}
hasnt() {
  if executable_text "$1" | grep -q "${MARK}"; then
    printf 'FAIL %s: marker survived, wanted it dropped\n' "$2"; fails=$((fails + 1))
  else printf 'ok   %s\n' "$2"; fi
}

echo "=== a body on its way to a file is data ==="
hasnt "$(printf 'cat > /tmp/x.sh <<%sEOF%s\n%s\nEOF\n' "'" "'" "${MARK}")" \
      "quoted here-document into a file"
hasnt "$(printf 'cat > /tmp/x.sh <<EOF\n%s\nEOF\n' "${MARK}")" \
      "unquoted here-document into a file"
hasnt "$(printf 'cat >> /tmp/x.sh <<EOF\n%s\nEOF\n' "${MARK}")" \
      "appending here-document"
hasnt "$(printf 'cat <<-EOF > /tmp/x.sh\n\t%s\n\tEOF\n' "${MARK}")" \
      "tab-stripping here-document, indented terminator"
hasnt "$(printf 'cat <<EOF\n%s\nEOF\n' "${MARK}")" \
      "a here-document that only prints"
hasnt "$(printf 'cat > /tmp/a <<EOF\n%s\nEOF\necho after\n' "${MARK}")" \
      "text after the terminator is read again"

echo
echo "=== a body reaching an interpreter is a command ==="
has "$(printf 'cat <<EOF | bash\n%s\nEOF\n' "${MARK}")"   "piped into a shell"
has "$(printf 'bash <<EOF\n%s\nEOF\n' "${MARK}")"          "fed straight to a shell"
has "$(printf 'python3 - <<EOF\n%s\nEOF\n' "${MARK}")"     "fed to an interpreter"
has "$(printf 'cat <<EOF | tee /tmp/a | sh\n%s\nEOF\n' "${MARK}")" \
    "written to a file AND piped onward"
has "$(printf 'eval "$(cat <<EOF\n%s\nEOF\n)"\n' "${MARK}")" \
    "wrapped in a substitution"

echo
echo "=== ordinary commands are untouched ==="
has "echo ${MARK}"                                   "a plain command survives"
has "cd /tmp && ${MARK} --now"                       "a later segment survives"

echo
echo "=== segments are separated, so one is never evidence about the next ==="
n="$(command_segments 'echo one && echo two; echo three | echo four' | grep -c 'echo')"
if [[ "${n}" == 4 ]]; then printf 'ok   %s\n' "four operators, four segments"
else printf 'FAIL four operators: wanted 4 segments, got %s\n' "${n}"; fails=$((fails + 1)); fi

if (( fails )); then echo ".claude/hooks/lib/command.sh: bench FAILED"; exit 1; fi
echo ".claude/hooks/lib/command.sh: bench passed"
