#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"

scan() {
  python3 - "$@" <<'PY'
import ast, re, sys, pathlib
TRAIL = re.compile(r"^.*?\S\s+#\s[^'\"]*$")
LEAK = re.compile("|".join(["co-" + "authored-by:", "claude-" + "session:", r"claude\.ai/code/" + "session"]), re.I)
bad = []
for p in sys.argv[1:]:
    f = pathlib.Path(p)
    try:
        text = f.read_text()
    except (UnicodeDecodeError, IsADirectoryError):
        continue
    lines = text.split("\n")
    if LEAK.search(text):
        bad.append(f"{p}: authorship or session line")
    if not re.search(r"\.(sh|py|ya?ml)$", p) and not lines[0].startswith("#!"):
        continue
    for i, l in enumerate(lines, 1):
        if i == 1 and l.startswith("#!"):
            continue
        if l.lstrip().startswith("#") or TRAIL.match(l):
            bad.append(f"{p}:{i}: comment")
    if p.endswith(".py") or "python" in lines[0]:
        for n in ast.walk(ast.parse(text)):
            if isinstance(n, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) and n.body \
               and isinstance(n.body[0], ast.Expr) and isinstance(n.body[0].value, ast.Constant) \
               and isinstance(n.body[0].value.value, str):
                bad.append(f"{p}:{n.body[0].lineno}: docstring")
print("\n".join(bad))
PY
}

files=()
while IFS= read -r -d '' f; do files+=("${STEWIE}/${f}"); done < <(git -C "${STEWIE}" ls-files -z -co --exclude-standard)
found="$(scan "${files[@]}")"
[[ -n "${found}" ]] && printf '%s\n' "${found}"
check "the code holds only code, and no file carries authorship lines" '[[ -z "${found}" ]]'

printf '#!/usr/bin/env bash\n# a comment\necho "${#x} # data"\n' > "${TMP}/a.sh"
printf 'x=1  # trailing\n' > "${TMP}/b.sh"
printf '"""doc"""\nx = 1\n' > "${TMP}/c.py"
printf '#!/usr/bin/env bash\necho "${#x}" '"'"'# data'"'"'\n' > "${TMP}/d.sh"
printf '%s-Authored-By: someone\n' Co > "${TMP}/e.md"
check "a comment line is caught" '[[ "$(scan "${TMP}/a.sh")" == *"a.sh:2: comment"* ]]'
check "a trailing comment is caught" '[[ -n "$(scan "${TMP}/b.sh")" ]]'
check "a docstring is caught" '[[ -n "$(scan "${TMP}/c.py")" ]]'
check "a # inside data is not a comment" '[[ -z "$(scan "${TMP}/d.sh")" ]]'
check "an authorship line is caught" '[[ -n "$(scan "${TMP}/e.md")" ]]'

finish "code only"
