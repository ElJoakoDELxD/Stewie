#!/usr/bin/env bash

set -uo pipefail
here="$(dirname "${BASH_SOURCE[0]}")"
source "${here}/lib/command.sh"

input="$(cat)"
tool="" cwd="" path="" command=""
eval "$(printf '%s' "${input}" | python3 -c '
import json, shlex, sys
d = json.load(sys.stdin)
ti = d.get("tool_input") or {}
for k, v in (("tool", d.get("tool_name", "")), ("cwd", d.get("cwd", "")),
             ("path", ti.get("file_path") or ti.get("notebook_path") or ""),
             ("command", ti.get("command", ""))):
    print("%s=%s" % (k, shlex.quote(v or "")))
' 2>/dev/null)" || exit 0

projects="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${CLAUDE_CONFIG_DIR:-${HOME}/.claude}/projects")"
deny() { echo "BLOCKED by guard-transcript.sh: $1 Transcripts are the evidence hooks read (who declared what, who approved what); nothing may write them. Read them freely." >&2; exit 2; }

case "${tool}" in
  Write|Edit|MultiEdit|NotebookEdit)
    [[ -n "${path}" ]] || exit 0
    abs="$(python3 -c 'import os,sys; print(os.path.realpath(os.path.join(sys.argv[1], sys.argv[2])))' "${cwd:-$PWD}" "${path}")"
    [[ "${abs}" == "${projects}" || "${abs}" == "${projects}/"* ]] && deny "${tool} into ${abs}."
    exit 0 ;;
  Bash) ;;
  *) exit 0 ;;
esac

config="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${CLAUDE_CONFIG_DIR:-${HOME}/.claude}")"
text="" literal=""
eval "$(python3 -c '
import codecs, shlex, sys
src = sys.argv[1]
def glue(t): return t.replace(" ", "\x01").replace("\t", "\x01")
text, literal, i, n = [], [], 0, len(src)
while i < n:
    c = src[i]
    if src.startswith("\\\n", i):
        i += 2
    elif c == "\\" and i + 1 < n:
        text.append(glue(src[i + 1])); literal.append(src[i + 1]); i += 2
    elif src.startswith("$\x27", i):
        j = i + 2
        while j < n and src[j] != "\x27": j += 2 if src[j] == "\\" else 1
        try: text.append(glue(codecs.decode(src[i + 2:j], "unicode_escape")))
        except Exception: text.append(glue(src[i + 2:j]))
        i = j + 1
    elif c == "\x27":
        j = src.find("\x27", i + 1); j = n if j < 0 else j
        text.append(glue(src[i + 1:j])); i = j + 1
    elif c == "\"":
        j = i + 1
        while j < n and src[j] != "\"":
            if src.startswith("\\\n", j): j += 2; continue
            if src[j] == "\\" and j + 1 < n and src[j + 1] in "$`\"\\": j += 1
            text.append(glue(src[j])); j += 1
        i = j + 1
    else:
        text.append(c); literal.append(c); i += 1
print("text=%s literal=%s" % (shlex.quote("".join(text)), shlex.quote("".join(literal))))
' "${command}")"
zone="$(command_segments "${text}" | python3 -c '
import os, re, sys
config, here = sys.argv[1], sys.argv[2]
def under(p): return p == config or p.startswith(config + "/")
def above(p): return p == "/" or config.startswith(p.rstrip("/") + "/")
def found(): print("zone"); sys.exit()
known = {"HOME": os.path.expanduser("~"), "PWD": here}
VAR = re.compile(r"\$(\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*)|\{[^}]*\}|[0-9@*#?$!_-])")
def ev(w):
    w = re.sub(r"(^|[=:])~[+-]?[0-9]+", r"\1*", w)
    w = w.replace("~+", known["PWD"]).replace("~-", "*")
    return tilde(VAR.sub(lambda m: known.get(m.group(2) or m.group(3) or "", "*"), w))
def tilde(w):
    if w == "~" or w.startswith("~/"): return known["HOME"] + w[1:]
    return os.path.expanduser(w)
def resolve(w, cwd): return os.path.realpath(os.path.join(cwd, tilde(ev(w))))
def dynamic(v): return "$(" in v or "`" in v
if under(here): found()
cwd = here
name = os.path.basename(config)
assign = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\+?=(.*)$")
setters = ("read", "mapfile", "readarray", "getopts", "declare", "typeset", "local", "export", "readonly", "printf")
segs = sys.stdin.read()
for tail in re.findall(r"[)`]([^\s;|&)`]+)", segs):
    if name in tail or re.search(r"[*?\[{$]", tail): found()
bases, unknown, lost = [], False, False
for seg in segs.split("\n"):
    words = [w.replace("\x01", " ") for w in seg.split()]
    first = words[0].lstrip("({!") if words else ""
    bare = bool(words) and words[0] == "cd" and (len(words) == 1 or (len(words) == 2 and not words[1].startswith("-")))
    if first in ("cd", "pushd", "popd", "builtin", "command") and not bare: lost = unknown = True
    known["PWD"] = "*" if lost else cwd
    for k, w in enumerate(words):
        a = assign.match(w)
        if a: known[a.group(1)] = "*" if dynamic(a.group(2)) else tilde(ev(a.group(2)))
        elif w == "in" and k >= 2 and words[k - 2] == "for":
            vals = words[k + 1:]
            known[words[k - 1]] = tilde(ev(vals[0])) if len(vals) == 1 and not dynamic(vals[0]) else "*"
        elif first in setters and k > 0 and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", w):
            known[w] = "*"
    if "CLAUDE_CONFIG_DIR" in seg: found()
    if first in ("cd", "pushd") and any(dynamic(x) or "*" in tilde(ev(x)) for x in words[1:]): unknown = True
    for k, w in enumerate(words):
        opt, _, val = w.partition("=")
        short = re.match(r"^(-[Cdt])(.+)$", w)
        if short: opt, val = short.groups()
        if opt in ("-C", "-d", "-t", "--directory", "--target-directory"):
            val = val or (words[k + 1] if k + 1 < len(words) else "")
            if dynamic(val) or "*" in ev(val): unknown = True
    if unknown and name in seg: found()
    if words and words[0] == "cd":
        cwd = resolve(words[1] if len(words) > 1 else "~", cwd)
        if under(cwd): found()
        if "*" in cwd: unknown = True
        known["PWD"] = "*" if lost else cwd
    flat = [x for w in words for x in re.split(r"[=(),:<>]", tilde(ev(w))) if x]
    bases += [b for b in {resolve(x, cwd) for x in flat if not re.search(r"[*?\[{]", x)} if above(b) and b not in bases]
    for x in flat:
        if not x.startswith(("/", "~", "-", "*")) and any(under(resolve(x, b)) for b in bases): found()
    for w in words:
        w = tilde(ev(w))
        if w.startswith("*") and name in w: found()
        parts = [x for x in re.split(r"[=(),:<>]", w) if x]
        for x in parts:
            for i in (x.find("/"), x.find("~")):
                if i > 0 and under(resolve(re.split(r"[*?\[{]", x[i:])[0], cwd)): found()
        for part in parts:
            m = re.search(r"[*?\[{]", part)
            if m:
                if above(resolve(os.path.dirname(part[:m.start()]) or ".", cwd)): found()
            elif under(resolve(part, cwd)):
                found()
' "${config}" "$(cd "${cwd:-$PWD}" 2>/dev/null && pwd -P)")"
[[ "${zone}" == zone ]] || exit 0

[[ "${text}" == *'$('* || "${text}" == *'`'* || "${text}" == *'<('* ]] \
  && deny "near Claude Code's configuration, a command may not run another inside it."
quiet() { sed -E 's#[0-9]*>&([0-9]+|-)([[:space:]]|$)#\2#g; s#[0-9&]*>>?[[:space:]]*/dev/null([[:space:]]|$)#\1#g'; }
literal="$(quiet <<< "${literal}")"
[[ "${literal}" == *">"* ]] && deny "near Claude Code's configuration, output may go only to /dev/null."
readers=' ls cat grep egrep fgrep zgrep head tail wc jq stat cut tr find du cd pwd echo printf realpath readlink basename dirname test [ [[ true diff cmp sha256sum md5sum od strings column nl tac '
assign='^[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?\+?='
while IFS= read -r seg; do
  read -r -a words <<< "${seg}"
  i=0
  while (( i < ${#words[@]} )) && [[ "${words[i]}" =~ ${assign} ]]; do
    [[ "${words[i]}" =~ ^(PATH|HOME|CDPATH|LD_[A-Z_]+|BASH_ENV|ENV|IFS|BASHOPTS|SHELLOPTS|GLOBIGNORE)(\+?=|\[) ]] \
      && deny "near Claude Code's configuration, ${words[i]%%=*} may not change."
    i=$((i + 1))
  done
  (( i < ${#words[@]} )) || continue
  (( i == 0 )) || deny "near Claude Code's configuration, a command may not run with its environment changed."
  prog="${words[i]}"
  [[ "${prog}" == */* ]] && deny "near Claude Code's configuration, a program is named by its name, not a path (${prog})."
  [[ "${readers}" == *" ${prog} "* ]] || deny "near Claude Code's configuration, only read-only commands run (${prog} is not one)."
  [[ "${prog}" == printf && " ${seg} " == *" -v"* ]] && deny "near Claude Code's configuration, printf -v may not assign."
  if [[ "${prog}" == find && " ${seg} " =~ [[:space:]]-(exec|execdir|delete|ok|okdir|fprint|fprint0|fprintf|fls)[[:space:]] ]]; then
    deny "find may not act on what it finds there."
  fi
done <<< "$(command_segments "$(quiet <<< "${text}")")"
exit 0
