import json
import re
import shlex
import sys

GLOBAL_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace",
                "--exec-path", "--super-prefix"}
PREFIX = {"sudo", "env", "command", "exec", "nohup", "time", "xargs",
          "sh", "bash", "zsh", "ksh", "dash", "python", "python3",
          "node", "perl", "ruby", "eval", "source"}
REDIRECT = {">", ">>", "<", "<<", "2>", "&>", ">|"}
ASSIGN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")
SHELLS = {"sh", "bash", "zsh", "ksh", "dash", "busybox"}
DASH_C = re.compile(r"-[A-Za-z]*c")

def segments(text):
    lexer = shlex.shlex(text, posix=True, punctuation_chars="();<>|&\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    out, cur = [], []
    for tok in lexer:
        if tok and all(c in ";|&\n()" for c in tok):
            out.append(cur)
            cur = []
        else:
            cur.append(tok)
    out.append(cur)
    return out

def calls(tokens, depth, out):
    words, skip = [], False
    for tok in tokens:
        if skip:
            skip = False
            continue
        if tok in REDIRECT:
            skip = True
            continue
        words.append(tok)

    i = 0
    while i < len(words) and ASSIGN.match(words[i]):
        i += 1
    if depth < 3 and i < len(words):
        prog = words[i].split("/")[-1]
        if prog in SHELLS:
            for j in range(i + 1, len(words) - 1):
                if DASH_C.fullmatch(words[j]):
                    analyse(words[j + 1], depth + 1, out)
                    return
        elif prog == "eval":
            for w in words[i + 1:]:
                if not w.startswith("-"):
                    analyse(w, depth + 1, out)
            return
    while i < len(words) and (words[i].split("/")[-1] in PREFIX or ASSIGN.match(words[i])):
        i += 1
    if i >= len(words) or words[i].split("/")[-1] != "git":
        return
    i += 1
    cdirs = []
    while i < len(words) and words[i].startswith("-"):
        name, _, value = words[i].partition("=")
        if name == "-C":
            cdirs.append(value if value else (words[i + 1] if i + 1 < len(words) else ""))
        i += 2 if (name in GLOBAL_VALUE and not value) else 1
    if i < len(words):
        out.append({"C": cdirs, "sub": words[i], "args": words[i + 1:]})

def analyse(text, depth=0, out=None):
    out = [] if out is None else out
    for tokens in segments(text):
        calls(tokens, depth, out)
    return out

if __name__ == "__main__":
    try:
        for call in analyse(sys.stdin.read()):
            print(json.dumps(call))
    except ValueError:
        print(json.dumps({"unparsed": True}))
