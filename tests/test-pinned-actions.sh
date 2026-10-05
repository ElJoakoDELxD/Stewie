#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"

unpinned() {
  python3 - "$1" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
key = re.compile(r'(^|[\s{,-])["\']?uses["\']?\s*:')
line_re = re.compile(r'^\s*(?:-\s+)?uses\s*:\s*(?P<v>"[^"]*"|\'[^\']*\'|[^\s#"\']+)\s*(?:#.*)?$')
pinned = re.compile(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40}$')
bad = 0
files = sorted(p for p in root.rglob("*") if p.is_file() and p.suffix in (".yml", ".yaml"))
for path in files:
    for n, text in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if text.lstrip().startswith("#") or not key.search(text.split(" #", 1)[0]):
            continue
        m = line_re.match(text)
        v = m.group("v").strip("\"'") if m else ""
        if m and (v.startswith("./") or pinned.match(v)):
            continue
        print(f"{path.relative_to(root)}:{n}: {text.strip()}")
        bad = 1
sys.exit(bad)
PY
}

check "this repository's workflows pin every action" 'unpinned "${STEWIE}/.github" >&2'

sha=11d5960a326750d5838078e36cf38b85af677262
w="${TMP}/wf"; mkdir -p "${w}"
case_of() { printf 'jobs:\n  j:\n    steps:\n%s\n' "$1" > "${w}/x.yml"; }
refuse() { case_of "$2"; check "refuses: $1" '! unpinned "${w}" >/dev/null'; }
accept() { case_of "$2"; check "accepts: $1" 'unpinned "${w}" >/dev/null'; }

accept "a full SHA" "      - uses: actions/checkout@${sha}"
accept "a full SHA with the version in a comment" "      - uses: actions/checkout@${sha} # v4.4.0"
accept "a quoted full SHA" "      - uses: 'actions/checkout@${sha}'"
accept "a local action" "      - uses: ./.github/actions/x"
accept "a pinned reusable workflow" "    uses: org/repo/.github/workflows/w.yml@${sha}"
refuse "a tag" "      - uses: actions/checkout@v4"
refuse "a branch" "      - uses: actions/checkout@main"
refuse "no ref at all" "      - uses: actions/checkout"
refuse "a short SHA" "      - uses: actions/checkout@${sha:0:39}"
refuse "a SHA too long" "      - uses: actions/checkout@${sha}0"
refuse "an uppercase SHA" "      - uses: actions/checkout@${sha^^}"
refuse "the SHA only in a comment" "      - uses: actions/checkout@v4 # ${sha}"
refuse "a docker image by tag" "      - uses: docker://alpine:3"
refuse "a quoted tag" "      - uses: \"actions/checkout@v4\""
refuse "a flow mapping" "      - { uses: actions/checkout@v4 }"
refuse "an unpinned reusable workflow" "    uses: org/repo/.github/workflows/w.yml@main"
refuse "a key in quotes" "      - \"uses\": actions/checkout@v4"
refuse "a folded value" "      - uses: >-"
case_of "      - uses: actions/checkout@v4"; mv "${w}/x.yml" "${w}/x.yaml"
check "refuses: a tag in a .yaml file" '! unpinned "${w}" >/dev/null'

finish "pinned actions"
