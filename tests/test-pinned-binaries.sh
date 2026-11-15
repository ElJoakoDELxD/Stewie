#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"

audit() {
  python3 -I - "$@" <<'PY'
import hashlib, pathlib, re, subprocess, sys
root = pathlib.Path(sys.argv[1])
names = subprocess.run(["git", "-C", str(root), "ls-files", "-z", "-co", "--exclude-standard"], capture_output=True, text=True).stdout
files = {root / n for n in names.split("\0") if n and (root / n).is_file()}
sources = sorted(p for p in files if p.name == "SOURCES.md")
bad = 0
listed = set()
for s in sources:
    text = re.sub(r"<!--.*?(-->|\Z)", "", s.read_text(), flags=re.S)
    rows = re.findall(r"^\|\s*`([^`]+)`\s*\|\s*`([0-9a-f]{64})`", text, re.M)
    pinned = {}
    for rel, digest in rows:
        if rel in pinned:
            print(f"{s}: lists {rel} twice"); bad = 1
        pinned[rel] = digest
    for path in sorted(p for p in files if s.parent in p.parents and p.name != "SOURCES.md"):
        rel = str(path.relative_to(s.parent))
        listed.add(path)
        if rel not in pinned:
            print(f"{path}: not listed in {s}"); bad = 1
        elif hashlib.sha256(path.read_bytes()).hexdigest() != pinned.pop(rel):
            print(f"{path}: hash differs from {s}"); bad = 1
    for rel in pinned:
        print(f"{s}: lists {rel}, which is missing"); bad = 1
for path in sorted(p for p in files if p not in listed):
    if path.read_bytes()[:4] == b"\x7fELF":
        print(f"{path}: a binary with no SOURCES.md"); bad = 1
sys.exit(bad)
PY
}

check "every shipped file matches its pinned hash"   'audit "${STEWIE}" >&2'

copy="${TMP}/kit"; mkdir -p "${copy}"; cp -R "${STEWIE}/memory" "${copy}/"; git -C "${copy}" init -q
kit="${copy}/memory/_example/tools/sandbox/linux-x86_64"
printf 'x' >> "${kit}/bwrap"
check "a changed binary is caught"                  '! audit "${copy}" 2>/dev/null'
cp "${STEWIE}/memory/_example/tools/sandbox/linux-x86_64/bwrap" "${kit}/bwrap"
printf 'echo x\n' >> "${kit}/socat"
check "a changed wrapper is caught"                 '! audit "${copy}" 2>/dev/null'
cp "${STEWIE}/memory/_example/tools/sandbox/linux-x86_64/socat" "${kit}/socat"
cp "${kit}/bwrap" "${kit}/extra"
check "an unlisted file is caught"                  '! audit "${copy}" 2>/dev/null'
rm "${kit}/extra"; cp "${kit}/bwrap" "${copy}/memory/stray"
check "a binary outside a listed folder is caught"  '! audit "${copy}" 2>/dev/null'
rm "${copy}/memory/stray"
printf '<!--\n| `bwrap` | `%064d` | x | x |\n-->\n' 0 >> "${kit}/SOURCES.md"
check "a hidden row changes nothing"                'audit "${copy}" 2>/dev/null'

finish "pinned binaries"
