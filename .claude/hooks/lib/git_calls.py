import json
import re
import shlex
import sys

GLOBAL_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace",
                "--exec-path", "--super-prefix", "--attr-source", "--config-env"}
PREFIX = {"sudo", "doas", "env", "command", "builtin", "exec", "nohup", "time", "xargs",
          "parallel", "nice", "ionice", "timeout", "stdbuf", "setsid", "flock", "chronic",
          "unbuffer", "strace", "ltrace", "watch"}
KEYWORDS = {"if", "then", "else", "elif", "do", "while", "until", "!", "{", "}", "coproc"}
REDIRECT = {">", ">>", "<", "<<", "<<<", "2>", "&>", ">|"}
ASSIGN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")
SHELLS = {"sh", "bash", "zsh", "ksh", "dash", "busybox"}
DASH_C = re.compile(r"-[A-Za-z]*c[A-Za-z]*")
HEADS = SHELLS | PREFIX | {"eval", "git", "gh", "cd", "pushd", "popd", "attach"}
PUSH_OPTS = ["--all", "--branches", "--mirror", "--tags", "--follow-tags", "--delete", "--prune",
             "--force", "--force-with-lease", "--force-if-includes", "--atomic", "--dry-run",
             "--porcelain", "--verbose", "--quiet", "--progress", "--no-verify", "--verify",
             "--set-upstream", "--thin", "--no-thin", "--receive-pack", "--exec", "--repo",
             "--push-option", "--signed", "--no-signed", "--recurse-submodules", "--ipv4", "--ipv6"]


def segments(text):
    lexer = shlex.shlex(text, posix=True, punctuation_chars="();<>|&\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    lexer.commenters = ""
    out, cur = [], []
    for tok in lexer:
        if tok and all(c in ";|&\n()" for c in tok):
            out.append(cur)
            cur = []
        else:
            cur.append(tok)
    out.append(cur)
    return out


def base(word):
    return word.split("/")[-1]


def substitutions(text):
    outer, inner, i, single = [], [], 0, False
    while i < len(text):
        if text[i] == "'" and (single or text.count("'", i + 1)):
            single = not single
            outer.append(text[i])
            i += 1
        elif single:
            outer.append(text[i])
            i += 1
        elif text[i] == "\\" and i + 1 < len(text):
            outer.append(text[i:i + 2])
            i += 2
        elif text.startswith("$(", i) and not text.startswith("$((", i):
            depth, j = 1, i + 2
            while j < len(text) and depth:
                depth += {"(": 1, ")": -1}.get(text[j], 0)
                j += 1
            inner.append(text[i + 2:j - 1])
            outer.append("$SUBST")
            i = j
        elif text[i] == "`":
            j = text.find("`", i + 1)
            j = len(text) if j < 0 else j
            inner.append(text[i + 1:j])
            outer.append("$SUBST")
            i = j + 1
        else:
            outer.append(text[i])
            i += 1
    return "".join(outer), inner


def programs(text, depth=0, out=None):
    out = [] if out is None else out
    text, inner = substitutions(text)
    if depth < 3:
        for t in inner:
            programs(t, depth + 1, out)
    for tokens in segments(text):
        words, skip = [], False
        for tok in tokens:
            if skip:
                skip = False
            elif tok in REDIRECT:
                skip = True
            else:
                words.append(tok)
        i, stdin = 0, False
        while i < len(words):
            if ASSIGN.match(words[i]) or words[i] in KEYWORDS:
                i += 1
            elif base(words[i]) in PREFIX:
                stdin = stdin or base(words[i]) in ("xargs", "parallel")
                i += 1
                while i < len(words) and base(words[i]) not in HEADS:
                    i += 1
            else:
                break
        if i >= len(words):
            continue
        prog = base(words[i])
        if depth < 3 and prog in SHELLS:
            for j in range(i + 1, len(words)):
                if DASH_C.fullmatch(words[j]):
                    script = next((w for w in words[j + 1:] if not w.startswith("-")), None)
                    if script is not None:
                        programs(script, depth + 1, out)
                    break
            continue
        if depth < 3 and prog == "find":
            for j, w in enumerate(words):
                if w in ("-exec", "-execdir", "-ok", "-okdir"):
                    rest = words[j + 1:]
                    end = next((k for k, x in enumerate(rest) if x in (";", "+", "\\;")), len(rest))
                    if rest[:end]:
                        out.append({"words": rest[:end], "stdin": True})
            continue
        if depth < 3 and prog == "eval":
            programs(" ".join(w for w in words[i + 1:] if not w.startswith("-")), depth + 1, out)
            continue
        out.append({"words": words[i:], "stdin": stdin})
    return out


def expand(arg):
    name, eq, value = arg.partition("=")
    if not name.startswith("--") or name in PUSH_OPTS:
        return arg
    hits = [o for o in PUSH_OPTS if o.startswith(name)]
    return hits[0] + eq + value if len(hits) == 1 else arg


def analyse(text, depth=0, out=None):
    out = [] if out is None else out
    for p in programs(text):
        words = p["words"]
        if base(words[0]) != "git":
            continue
        i, cdirs, config, elsewhere = 1, [], [], False
        while i < len(words) and words[i].startswith("-"):
            name, _, value = words[i].partition("=")
            given = value if value else (words[i + 1] if i + 1 < len(words) else "")
            if name == "-C":
                cdirs.append(given)
            elif name in ("-c", "--config-env"):
                config.append(given)
            elif name in ("--git-dir", "--work-tree"):
                elsewhere = True
            i += 2 if (name in GLOBAL_VALUE and not value) else 1
        if i < len(words):
            sub, args = words[i], words[i + 1:]
            if sub == "push":
                args = [expand(a) for a in args]
            out.append({"C": cdirs, "c": config, "elsewhere": elsewhere, "stdin": p["stdin"], "sub": sub, "args": args})
    return out


if __name__ == "__main__":
    try:
        for call in analyse(sys.stdin.read()):
            print(json.dumps(call))
    except ValueError:
        print(json.dumps({"unparsed": True}))
