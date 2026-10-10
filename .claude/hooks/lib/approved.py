import fcntl
import json
import os
import re
import shutil
import subprocess
import sys
import types

SHARED = re.compile(r"^(?:refs/)?(?:heads/)?(?:candidate/.+|custodian)$")
TAG = re.compile(r"^(?:refs/)?tags/.|^v\d+\.\d+")
UNREAD = re.compile(r"[$*?\[]|\{[^}]*(?:,|\.\.)[^}]*\}")
CLUSTER = re.compile(r"-[A-Za-z]+")
VALUED = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
GUARDED_OPTS = ["--force", "--force-with-lease", "--force-if-includes", "--delete", "--prune", "--mirror", "--all",
                "--branches", "--tags", "--follow-tags"]
APPROVAL = re.compile(r"^\s*<command-message>[^<]*</command-message>\s*<command-name>/principal-approves</command-name>")
CONFIG = re.compile(r"^(?:alias|remote|push|branch|include|includeif)\.", re.I)
ENVCONFIG = re.compile(r"\b(?:GIT_(?:CONFIG|DIR|WORK_TREE|NAMESPACE)\w*|HOME|XDG_CONFIG_HOME)=")
VARPUSH = re.compile(r"(?:^|[\s;&|(])\$\{?\w+\}?(?:\s+-\S+)*\s+push\b")
GH_PATH = re.compile(r"/git/(?:refs|tags)|/merges\b|/merge-upstream\b|/pulls/\d+/(?:merge|update-branch)|/contents/|/releases|/branches/[^/\s]+/rename")
GH_REPO = re.compile(r"^/?repos/[^/\s]+/[^/\s]+/?$")
GH_MUTATION = re.compile(r"\b(?:mergePullRequest|enablePullRequestAutoMerge|enqueuePullRequest|createRef|updateRefs?|deleteRef|createCommitOnBranch|mergeBranch)\b")
OPENER = re.compile(r"(?<!<)<<(?!<)-?\s*([\x27\"]?)\\?([A-Za-z_][A-Za-z0-9_]*)\1")
FEEDS = re.compile(r"(?:^|[\s/;&|(])(?:(?:ba|z|k|da)?sh|eval|source|xargs|parallel)\b")
MCP = re.compile(r"^mcp__.+__([A-Za-z_]+)$")
SYSPATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
BUILTIN = set("""add am annotate apply archive bisect blame branch bundle cat-file check-attr check-ignore checkout
checkout-index cherry cherry-pick clean clone column commit commit-tree config count-objects describe diff
diff-files diff-index diff-tree difftool fetch fetch-pack for-each-ref format-patch fsck gc grep hash-object help
index-pack init interpret-trailers log ls-files ls-remote ls-tree maintenance merge merge-base mergetool mktag mv
name-rev notes pack-objects pack-refs prune pull push range-diff read-tree rebase reflog remote repack replace
rerere reset restore rev-list rev-parse revert rm shortlog show show-ref sparse-checkout stash status stripspace
submodule switch symbolic-ref tag update-index update-ref var verify-commit verify-tag version whatchanged
worktree write-tree""".split())


def load(name):
    path = os.path.join(os.path.dirname(os.path.realpath(__file__)), name + ".py")
    module = types.ModuleType(name)
    with open(path) as f:
        exec(compile(f.read(), path, "exec"), module.__dict__)
    return module


git_calls = load("git_calls")
GIT = shutil.which("git", path=SYSPATH) or "/usr/bin/git"


def git(where, *args):
    try:
        out = subprocess.run([GIT, "-c", "core.fsmonitor=false", "-C", where, *args], capture_output=True, text=True,
                             timeout=10, env=dict(os.environ, PATH=SYSPATH))
        return out.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def settings(where):
    out = {}
    for entry in git(where, "config", "--list", "-z").split("\0"):
        key, _, value = entry.partition("\n")
        if key:
            out.setdefault(key.lower(), []).append(value)
    return out


def data_heredocs_removed(text):
    out, delim = [], None
    for line in text.split("\n"):
        if delim is not None:
            if line.strip() == delim:
                delim = None
            continue
        out.append(line)
        m = OPENER.search(line)
        if m and not FEEDS.search(line):
            delim = m.group(2)
    return "\n".join(out)


def push(c, cwd, moved, command):
    where = cwd
    for d in c["C"]:
        where = os.path.join(where, os.path.expanduser(d))
    flags, words, skip = [], [], False
    for a in c["args"]:
        if skip:
            skip = False
        elif a in VALUED:
            skip = True
        elif a.startswith("-"):
            flags.append(a.split("=")[0])
        else:
            words.append(a)
    flags += [o for f in flags if f.startswith("--") and len(f) > 3 for o in GUARDED_OPTS if o.startswith(f) and o != f]
    refs, why = words[1:], []
    remote = words[0] if words else ""
    short = "".join(f[1:] for f in flags if CLUSTER.fullmatch(f))
    if any(f.startswith("--force") for f in flags) or "f" in short or any(r.startswith("+") for r in refs):
        why.append("rewrites history")
    if any(f in ("--delete", "--prune", "--mirror") for f in flags) or "d" in short or any(r.startswith(":") for r in refs):
        why.append("deletes or mirrors refs")
    if any(f in ("--all", "--branches") for f in flags):
        why.append("sends every branch")
    if any(f in ("--tags", "--follow-tags") for f in flags):
        why.append("sends tags")
    if any(CONFIG.match(x) for x in c["c"]) or ENVCONFIG.search(command):
        why.append("is reconfigured on the command line")
    if c.get("stdin") or any(UNREAD.search(w) for w in words):
        why.append("goes to refs that cannot be read before it runs")
    cfg = settings(where)
    if any(k.startswith("remote.") and k.endswith(".mirror") and "true" in v for k, v in cfg.items()):
        why.append("mirrors refs, by git config")
    if "true" in cfg.get("push.followtags", []):
        why.append("sends tags")
    mapped = any(k.startswith("remote.") and k.endswith(".push") for k in cfg)
    upstream = cfg.get("push.default", [""])[-1] in ("upstream", "tracking")
    targets = []
    if not refs or any(r.lstrip("+") in ("HEAD", "@") for r in refs):
        if moved or c["elsewhere"]:
            why.append("goes to a branch that cannot be read before it runs")
        else:
            targets.append(git(where, "symbolic-ref", "--short", "-q", "HEAD"))
            targets.append(git(where, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{push}").split("/", 1)[-1])
            if cfg.get("push.default", [""])[-1] == "matching":
                why.append("sends every matching branch")
    if mapped and any(":" not in r for r in refs or [""]):
        why.append("follows a push refspec in git config")
    for r in refs:
        src, _, dst = r.lstrip("+").rpartition(":") if ":" in r else ("", "", r.lstrip("+"))
        src = src or dst
        if dst in ("HEAD", "@"):
            continue
        targets.append(dst)
        if ":" not in r and upstream:
            targets.append(cfg.get("branch.%s.merge" % src.lower(), [""])[-1])
        if TAG.match(dst) or TAG.match(src) or git(where, "rev-parse", "--verify", "-q", "refs/tags/" + src):
            why.append("sends a tag")
    shared = sorted({t for t in targets if t and SHARED.match(t)})
    if shared:
        why.append("goes to " + ", ".join(shared))
    if remote and UNREAD.search(remote):
        why.append("goes to a remote that cannot be read before it runs")
    return "a push that " + ", ".join(dict.fromkeys(why)) if why else None


def gh(words, command):
    if words[1:3] in (["pr", "merge"], ["release", "create"], ["repo", "sync"]):
        return "a merge, release or sync through gh"
    if words[1:2] != ["api"]:
        return None
    rest = words[2:]
    method, write, paths, files = None, False, [], False
    i = 0
    while i < len(rest):
        w = rest[i]
        m = re.fullmatch(r"(?:-X|--method)(?:=)?(\w*)", w)
        if m:
            method = (m.group(1) or (rest[i + 1] if i + 1 < len(rest) else "")).upper()
            i += 1 if m.group(1) else 2
            continue
        if re.match(r"-[fF]|--field|--raw-field|--input", w):
            write = True
            files = files or w.startswith("--input") or "=@" in w or (w in ("-F", "--field") and i + 1 < len(rest) and "=@" in rest[i + 1])
            i += 1 if (w.startswith("--") and "=" in w) or len(w) > 2 and not w.startswith("--") else 2
            continue
        if not w.startswith("-"):
            paths.append(w)
        i += 1
    if method:
        write = method != "GET"
    if not write:
        return None
    if any("$" in p for p in paths):
        return "a write through gh api to an endpoint that cannot be read"
    if any(p.strip("/") == "graphql" for p in paths):
        if files or GH_MUTATION.search(command):
            return "a merge or ref change through gh api graphql"
        return None
    branch = re.search(r"\bbranch=([\w./-]+)", " ".join(rest))
    for p in paths:
        if "/contents/" in p and branch and not (SHARED.match(branch.group(1)) or branch.group(1) == "main"):
            continue
        if GH_PATH.search(p) or (method == "PATCH" and GH_REPO.match(p)):
            return "a write through gh api to refs, merges, releases, files or the repository"
    return None


def custodian_branch(sub, args):
    if sub == "worktree":
        if args[:1] != ["add"]:
            return False
        args = args[1:]
    if "--" in args and sub == "checkout":
        return False
    created = [args[i + 1] for i, a in enumerate(args[:-1]) if a in ("-b", "-B", "-c", "-C", "--create", "--force-create", "--orphan")]
    if created:
        return any(SHARED.match(b) and "custodian" in b for b in created)
    operands = [a for a in args if not a.startswith("-")]
    return bool(operands) and operands[-1] in ("custodian", "refs/heads/custodian")


def bash(command, cwd):
    acts = []
    text = command.replace("`", " ; ")
    try:
        progs, calls = git_calls.programs(text), git_calls.analyse(text)
    except ValueError:
        text = data_heredocs_removed(text)
        try:
            progs, calls = git_calls.programs(text), git_calls.analyse(text)
        except ValueError:
            if re.search(r"\bgit\b[^\n]*\bpush\b|send-pack|http-push|\bgh\s+api\b|\battach\b", text):
                acts.append("a command that cannot be read and names a push, gh api or attach")
            return acts
    if VARPUSH.search(text):
        acts.append("a push through a variable")
    moved = False
    for p in progs:
        words = p["words"]
        prog = words[0].split("/")[-1]
        if prog in ("cd", "pushd", "popd"):
            moved = True
        elif prog == "attach" and words[1:2] == ["custodian"]:
            acts.append("attaching the custodian")
        elif prog == "gh":
            act = gh(words, text)
            if act:
                acts.append(act)
    for c in calls:
        sub, args = c["sub"], c["args"]
        if sub == "push":
            act = push(c, cwd, moved, text)
            if act:
                acts.append(act)
        elif re.search(r"[$`{]", sub):
            acts.append("a git command whose name cannot be read before it runs")
        elif sub in ("send-pack", "http-push"):
            acts.append("a push through plumbing")
        elif sub in ("worktree", "checkout", "switch") and custodian_branch(sub, args):
            acts.append("checking out the custodian")
        elif sub == "rebase":
            for i, a in enumerate(args):
                script = args[i + 1] if a in ("-x", "--exec") and i + 1 < len(args) else a[7:] if a.startswith("--exec=") else None
                if script:
                    acts += bash(script, cwd)
        elif sub not in BUILTIN:
            alias = next((x.split("=", 1)[1] for x in c["c"] if x.lower().startswith("alias." + sub.lower() + "=")), None)
            if alias is None:
                alias = git(cwd, "config", "--get", "alias." + sub)
            if alias and re.search(r"\bpush\b|send-pack|http-push", alias):
                acts.append("a push through the alias git " + sub)
    return acts


def guarded(tool, tin, cwd):
    if tool == "Bash":
        return bash(str(tin.get("command", "")), cwd)
    m = MCP.match(tool or "")
    if not m:
        return []
    name, branch = m.group(1), str(tin.get("branch") or "")
    if name in ("merge_pull_request", "enable_pr_auto_merge", "update_pull_request_branch"):
        return ["a merge of a pull request"]
    if name in ("push_files", "create_or_update_file", "delete_file") and (not branch or branch == "main" or SHARED.match(branch)):
        return ["a write to " + (branch or "the default branch")]
    if name == "create_branch" and SHARED.match(branch):
        return ["creating " + branch]
    return []


def human(e):
    if e.get("type") == "user" and (e.get("origin") or {}).get("kind") == "human" and not e.get("isMeta"):
        return True
    a = e.get("attachment") or {}
    return a.get("type") == "queued_command" and (a.get("origin") or {}).get("kind") == "human"


def approval(path):
    token = None
    with open(path, "rb") as f:
        for n, raw in enumerate(f, 1):
            if b"human" not in raw:
                continue
            try:
                e = json.loads(raw.decode("utf-8", "replace"))
            except ValueError:
                continue
            if not isinstance(e, dict) or not human(e):
                continue
            content = (e.get("message") or {}).get("content")
            ok = e.get("type") == "user" and isinstance(content, str) and APPROVAL.match(content)
            token = (e.get("uuid") or "%s:%d" % (os.path.realpath(path), n)) if ok else None
    return token


def spend(token):
    state = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "stewie")
    os.makedirs(state, mode=0o700, exist_ok=True)
    fd = os.open(os.path.join(state, "approvals-spent"), os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "r+") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        if token in f.read().split("\n"):
            return False
        f.seek(0, 2)
        f.write(token + "\n")
        f.flush()
        return True


def main(raw):
    data = json.loads(raw)
    acts = guarded(data.get("tool_name", ""), data.get("tool_input") or {}, data.get("cwd") or ".")
    if not acts:
        return 0
    if len(acts) > 1:
        print("BLOCKED by approved.py: one guarded act per call, and this call has " + str(len(acts)) + ": " + "; ".join(acts) + ". Split it.", file=sys.stderr)
        return 2
    try:
        token = approval(data.get("transcript_path") or "")
        spent = bool(token) and spend(token)
    except OSError:
        spent = False
    if spent:
        return 0
    print("BLOCKED by approved.py: " + acts[0] + " needs the person to type /principal-approves. Each approval unlocks one act, "
          "and lapses when the person sends another message first. Ask them; say what it is for.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raw = sys.stdin.read()
    try:
        sys.exit(main(raw))
    except Exception:
        if re.search(r"\bgit\b|push|merge|attach|\bgh\b|_files?\b|create_branch|custodian", raw):
            print("BLOCKED by approved.py: it could not check this call, which may be a guarded act, so it blocks it.", file=sys.stderr)
            sys.exit(2)
        sys.exit(0)
