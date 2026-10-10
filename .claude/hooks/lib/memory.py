import fnmatch
import hashlib
import json
import os
import re
import sqlite3
import stat
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
STORE = ROOT / ".memory"
ARCH = re.compile(r"^(CLAUDE\.md|README\.md|CONTRIBUTING\.md|rules/.+\.md|knowledge/.+\.md|memory/_example/.+\.md"
                  r"|\.claude/(skills|agents)/.+\.md|\.claude/hooks/.+|\.claude/settings\.json|tools/bin/[^/]+"
                  r"|tests/[^/]+\.sh|\.github/workflows/.+\.ya?ml)$")
CODE = re.compile(r"\.(sh|py|ya?ml)$|^tools/bin/")
HEAD = re.compile(r"^(#{1,4})\s+(.+?)\s*#*\s*$")
ITEM = re.compile(r"^(?:[-*]|\d+\.)\s+(.*)$")
ROW = re.compile(r"^\|(.+)\|\s*$")
SEP = re.compile(r"^\|[\s:|-]+\|\s*$")
PATHISH = re.compile(r"(?<![\w$/{])((?:\.{0,2}[\w-]+/)*[\w.-]+\.(?:md|sh|py|json|ya?ml)|(?:tools/bin|\.claude/hooks|\.claude/skills|\.claude/agents|rules|knowledge|tests)/[\w.-]+)")
TICK = re.compile(r"`([\w][\w-]*)`")
SKILLWORD = re.compile(r"\b([\w-]+) skill\b")
COMMITS = re.compile(r"\(((?:[0-9a-f]{7,40}(?:,\s*)?)+)\)")
CODELINE = re.compile(r"BLOCKED|echo |printf |reason|usage|^\s*def |^\s*[\w-]+\(\)\s*\{")
OPENER = re.compile(r"(?<!<)<<(?!<)-?\s*([\x27\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
QUOTED = re.compile(r"'[^']*'|\"(?:[^\"\\]|\\.)*\"")
FENCE = re.compile(r"^\s{0,3}(```|~~~)")
FRONT = re.compile(r"\A---[ \t]*\n(.*?)^---[ \t]*(?:\n|\Z)", re.S | re.M)
MACHINE = ("<command-", "<local-command-")
BOM = chr(0xFEFF)


def git(*args):
    try:
        return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def frontmatter(text):
    text = text.lstrip(BOM).replace("\r\n", "\n")
    m = FRONT.match(text)
    if not m:
        return {}, text
    meta = {}
    for line in m.group(1).split("\n"):
        key, sep, value = line.partition(":")
        if sep and key.strip() and not key.startswith((" ", "\t")):
            meta.setdefault(key.strip(), []).append(value.strip())
    return meta, text[m.end():].lstrip("\n")


def unfenced(lines):
    fence = False
    for line in lines:
        if FENCE.match(line):
            fence = not fence
        elif not fence:
            yield line


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:48] or "section"


def plain(text):
    return re.sub(r"\]\([^)]*\)|[*`\[\]]", "", text).strip()


def label(text):
    bold = re.match(r"\*\*(.+?)\*\*", text)
    words = plain(bold.group(1) if bold else text).split()
    return " ".join(words[:14]) + ("…" if len(words) > 14 and not bold else "")


class Graph:
    def __init__(self, paths, tools, skills):
        self.nodes, self.edges = {}, set()
        self.paths, self.tools, self.skills = paths, tools, skills
        self.bases = {}
        for p in paths:
            self.bases.setdefault(p.rsplit("/", 1)[-1], []).append(p)

    def node(self, nid, kind, path, line, title, body, parent=None, meta=None):
        base, n = nid, 2
        while nid in self.nodes:
            nid, n = f"{base}-{n}", n + 1
        self.nodes[nid] = dict(id=nid, kind=kind, path=path, line=line, title=title, body=body.strip(), meta=meta or {})
        if parent:
            self.edges.add((nid, parent, "part-of"))
        return nid

    def resolve(self, ref):
        ref = ref.strip().rstrip("/")
        if ref.startswith("./"):
            ref = ref[2:]
        if ref in self.nodes or ref in self.paths:
            return ref
        if ref.startswith(".claude/skills/") and ref.count("/") == 2:
            return ref + "/SKILL.md" if ref + "/SKILL.md" in self.paths else None
        if ref.startswith("tools/bin/") and ref in self.paths:
            return ref
        hits = [p for p in self.paths if p.endswith("/" + ref)] or self.bases.get(ref, [])
        return hits[0] if len(hits) == 1 else None

    def refs(self, text):
        out = set()
        text = re.sub(r"\$\{?\w+\}?\"?/", " ", text)
        for m in PATHISH.finditer(text):
            r = self.resolve(m.group(1))
            if r:
                out.add(r)
        for name in TICK.findall(text):
            if name in self.tools:
                out.add("tools/bin/" + name)
        for name in SKILLWORD.findall(text):
            if name in self.skills:
                out.add(f".claude/skills/{name}/SKILL.md")
        return out

    def markdown(self, path, text, kind):
        text = text.lstrip(BOM).replace("\r\n", "\n")
        meta, body = frontmatter(text)
        offset = text[:len(text) - len(body)].count("\n")
        lines = body.split("\n")
        first = next((heading(l) for l in unfenced(lines) if heading(l)), None)
        title = meta.get("title", [None])[0] or (first.group(2) if first and len(first.group(1)) == 1 else path)
        fid = self.node(path, meta.get("kind", [kind])[0], path, 1, title, "", None, meta)
        stack, cur, intro, item, rows = [(0, fid)], fid, [], None, 0

        def close_item():
            nonlocal item
            if item:
                nid, ln, buf = item
                self.node(nid, "item", path, ln, label(buf[0]), "\n".join(buf), cur)
                item = None

        def close_section():
            close_item()
            self.nodes[cur]["body"] = (self.nodes[cur]["body"] + "\n" + "\n".join(intro)).strip()
            intro.clear()

        count, fence = 0, False
        for i, line in enumerate(lines, offset + 1):
            if fence or FENCE.match(line):
                fence = fence != bool(FENCE.match(line))
                if item:
                    item[2].append(line.strip())
                else:
                    intro.append(line)
                continue
            h = heading(line)
            if h:
                if len(h.group(1)) == 1 and cur == fid and not intro and count == 0:
                    count += 1
                    continue
                close_section()
                level = len(h.group(1))
                while stack and stack[-1][0] >= level:
                    stack.pop()
                parent = stack[-1][1] if stack else fid
                cur = self.node(f"{path}#{slug(h.group(2))}", "section", path, i, plain(h.group(2)), "", parent)
                stack.append((level, cur))
                rows = 0
                continue
            it = ITEM.match(line)
            row = ROW.match(line)
            if it:
                close_item()
                count += 1
                item = (f"{cur}/{count}", i, [it.group(1)])
            elif row and not SEP.match(line):
                close_item()
                rows += 1
                if rows > 1:
                    count += 1
                    cells = [c.strip() for c in row.group(1).split("|")]
                    self.node(f"{cur}/{count}", "item", path, i, label(cells[0]), " | ".join(cells), cur)
            elif item and line.strip() and (line[:1] in " \t" or item[2][-1].strip()):
                item[2].append(line.strip())
            else:
                close_item()
                if line.strip() and not SEP.match(line):
                    intro.append(line)
                if not row:
                    rows = 0
        close_section()
        for link in meta.get("links", []):
            for part in re.split(r",\s*", link.strip("[] ")):
                typ, sep, target = part.partition(":")
                if sep and target:
                    self.edges.add((fid, target.strip(), typ.strip()))
        for about in meta.get("about", []):
            m = re.match(r"(\S+)", about)
            if m and self.resolve(m.group(1)):
                self.edges.add((fid, self.resolve(m.group(1)), "about"))

    def code(self, path, text):
        body = "\n".join(l.strip() for l in text.split("\n") if CODELINE.search(l))[:4000]
        fid = self.node(path, "code", path, 1, path, body)
        for r in self.refs(text):
            if r != path:
                self.edges.add((fid, r, "tests" if path.startswith("tests/") else "uses"))

    def settings(self, path, text):
        fid = self.node(path, "config", path, 1, path, "")
        try:
            hooks = json.loads(text).get("hooks", {})
        except ValueError:
            return
        for event, groups in hooks.items():
            for gi, group in enumerate(groups):
                for hi, h in enumerate(group.get("hooks", [])):
                    what = "agent judge, " + h.get("model", "") if h.get("type") == "agent" else h.get("command", "")
                    cond = f" if {h['if']}" if h.get("if") else ""
                    title = f"{event} {group.get('matcher') or '*'}{cond}: {what}"[:160]
                    nid = self.node(f"{path}#{slug(event)}-{gi + 1}-{hi + 1}", "wiring", path, 1, title, h.get("prompt", "")[:300], fid)
                    for r in self.refs(h.get("command", "") + " " + h.get("prompt", "")):
                        self.edges.add((nid, r, "wires"))

    def link(self):
        for nid, n in list(self.nodes.items()):
            if n["kind"] in ("code", "wiring", "config"):
                continue
            text = n["title"] + "\n" + n["body"]
            for r in self.refs(text):
                if r != n["path"]:
                    self.edges.add((nid, r, "mentions"))
            commits = [c for group in COMMITS.findall(text) for c in re.split(r",\s*", group)]
            commits += [v.split()[0] for v in n["meta"].get("verified", []) if v.split()]
            if commits:
                n["meta"]["commits"] = commits


def tracked():
    out = git("ls-files", "-co", "--exclude-standard").split("\n")
    return sorted(p for p in out if p and (ROOT / p).is_file() and not (ROOT / p).is_symlink())


def md_files(d):
    out = []
    for base, subdirs, names in os.walk(d, followlinks=False):
        subdirs.sort()
        out += [Path(base) / n for n in sorted(names) if n.endswith(".md") and not (Path(base) / n).is_symlink()]
    return out


def notes_dirs(extra):
    dirs = [Path(d) for d in extra]
    agent = ROOT / ".agent" / "memory"
    if agent.is_dir():
        dirs.append(agent)
    return dirs


def build(extra=()):
    files = [p for p in tracked() if ARCH.match(p)]
    tools = {p.split("/")[-1] for p in files if p.startswith("tools/bin/")}
    skills = {p.split("/")[2] for p in files if p.startswith(".claude/skills/")}
    notes = []
    for d in notes_dirs(extra):
        for f in md_files(d):
            try:
                rel = str(f.resolve().relative_to(ROOT.resolve()))
            except ValueError:
                rel = str(f)
            notes.append((rel, f))
    g = Graph(set(files) | {r for r, _ in notes}, tools, skills)
    for p in files:
        text = (ROOT / p).read_text(errors="replace")
        if p == ".claude/settings.json":
            g.settings(p, text)
        elif p.endswith(".md"):
            kind = "rule" if p.startswith("rules/") else "knowledge" if p.startswith("knowledge/") else "doc"
            g.markdown(p, text, kind)
        else:
            g.code(p, text)
    for rel, f in notes:
        g.markdown(rel, f.read_text(errors="replace"), "note")
    g.link()
    return g


def signature(extra=()):
    rows = [p for p in tracked() if ARCH.match(p)]
    rows += [str(f) for d in notes_dirs(extra) for f in md_files(d)]
    out = []
    for p in rows:
        try:
            s = (ROOT / p).stat()
        except OSError:
            continue
        out.append(f"{p} {s.st_mtime_ns} {s.st_size}")
    return hashlib.sha256("\n".join(out).encode()).hexdigest()


def ready(extra=()):
    sig = signature(extra)
    path = STORE / "graph.db"
    if path.is_file():
        try:
            db = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)
            try:
                row = db.execute("select value from info where key = 'signature'").fetchone()
            finally:
                db.close()
            if row and row[0] == sig:
                return
        except sqlite3.Error:
            pass
    index(extra, sig)


def connect():
    return sqlite3.connect((STORE / "graph.db").as_uri() + "?mode=ro", uri=True)


def index(extra=(), sig=None):
    sig = sig or signature(extra)
    if STORE.is_symlink():
        raise SystemExit("memory: .memory is a symlink; it writes nothing outside the copy")
    g = build(extra)
    tmp = STORE / "graph.db.new"
    STORE.mkdir(exist_ok=True)
    if tmp.exists():
        tmp.unlink()
    db = sqlite3.connect(tmp)
    db.executescript("""
        create table node(id text primary key, kind text, path text, line int, title text, body text, meta text);
        create table edge(src text, dst text, type text);
        create index edge_src on edge(src);
        create index edge_dst on edge(dst);
        create virtual table fts using fts5(id unindexed, title, body, tokenize='porter unicode61 remove_diacritics 2');
        create table info(key text primary key, value text);
    """)
    db.execute("insert into info values('signature', ?)", (sig,))
    for n in g.nodes.values():
        db.execute("insert into node values(?,?,?,?,?,?,?)",
                   (n["id"], n["kind"], n["path"], n["line"], n["title"], n["body"], json.dumps(n["meta"])))
        if n["kind"] not in ("config",):
            db.execute("insert into fts values(?,?,?)", (n["id"], n["title"], n["body"]))
    db.executemany("insert into edge values(?,?,?)", sorted(g.edges))
    db.commit()
    db.close()
    os.replace(tmp, STORE / "graph.db")
    return len(g.nodes), len(g.edges)


def query(q, limit=5, kinds=None):
    terms = [t for t in re.findall(r"\w+", q.lower()) if len(t) > 1]
    if not terms:
        return []
    db = connect()
    match = " OR ".join('"%s" OR "%s"*' % (t, t) for t in terms)
    rows = db.execute("select fts.id, snippet(fts, 2, '[', ']', '…', 12), bm25(fts, 0.0, 2.0, 1.0) r, node.kind, node.title, node.path, node.line "
                      "from fts join node on node.id = fts.id where fts match ? order by r limit ?", (match, limit * 6)).fetchall()
    out = []
    for nid, snip, _, kind, title, path, line in rows:
        if kinds and kind not in kinds:
            continue
        out.append(dict(id=nid, kind=kind, title=title, path=path, line=line, snippet=snip.replace("\n", " ")))
        if len(out) >= limit:
            break
    return out


def neighbours(db, nid, limit=6):
    rows = db.execute("select '→', type, dst from edge where src = ? union all select '←', type, src from edge where dst = ? and type != 'part-of'",
                      (nid, nid)).fetchall()
    rows.sort(key=lambda r: (r[1] == "part-of", r[1]))
    titles = dict(db.execute("select id, title from node where id in (%s)" % ",".join("?" * len(rows)), [r[2] for r in rows]).fetchall()) if rows else {}
    return [f"{d} {t} {o}" + (f" ({titles[o][:50]})" if o in titles and titles[o] != o else "") for d, t, o in rows[:limit]]


def cmd_find(args):
    ready()
    db = connect()
    hits = query(" ".join(args.terms), args.limit, set(args.kind) if args.kind else None)
    if not hits:
        print("no match")
        return 1
    for h in hits:
        print(f"{h['id']}  [{h['kind']}]  {h['title'][:90]}")
        if h["snippet"] and h["snippet"] != h["title"]:
            print(f"    {h['snippet'][:160]}")
        for n in neighbours(db, h["id"], args.hops * 6):
            print(f"    {n}")
    return 0


def cmd_show(args):
    ready()
    db = connect()
    row = db.execute("select id, kind, path, line, title, body from node where id = ?", (args.id,)).fetchone()
    if not row:
        print("no such node")
        return 1
    print(f"{row[0]}  [{row[1]}]  {row[2]}:{row[3]}\n{row[4]}\n{row[5]}")
    for n in neighbours(db, row[0], 30):
        print(f"  {n}")
    return 0


def cmd_stale(args):
    ready(args.notes)
    db = connect()
    found = 0
    for nid, meta, path in db.execute("select id, meta, path from node").fetchall():
        commits = json.loads(meta).get("commits") or []
        known = [c for c in commits if git("cat-file", "-t", c).strip() == "commit"]
        if not known:
            continue
        base = max(known, key=lambda c: int(git("show", "-s", "--format=%ct", c).strip() or 0))
        targets = [r[0] for r in db.execute("select dst from edge where src = ? and type in ('mentions', 'about')", (nid,))]
        changed = [t for t in targets if (ROOT / t).exists() and (git("log", "-1", "--format=%h", f"{base}..HEAD", "--", t).strip()
                                                                  or git("status", "--porcelain", "--", t).strip())]
        if changed:
            found += 1
            print(f"{nid}: checked at {base}; changed since: {', '.join(changed)}")
    for nid, body, path in db.execute("select id, body, path from node where kind not in ('code', 'wiring', 'config')").fetchall():
        for m in PATHISH.finditer(body):
            ref = m.group(1)
            if "/" in ref and ref.split("/")[0] in ("rules", "knowledge", "tools", "tests", ".claude", "memory") \
               and not (ROOT / ref).exists() and not (ROOT / ".agent" / ref).exists() and "*" not in ref and "<" not in ref:
                found += 1
                print(f"{nid}: points to a missing path: {ref}")
    if not found:
        print("nothing stale")
    return 0


def transcript(path):
    with open(path, errors="replace") as f:
        for n, line in enumerate(f, 1):
            try:
                yield n, json.loads(line)
            except ValueError:
                continue


def human(e):
    if (e.get("origin") or {}).get("kind") == "human" and e.get("type") == "user":
        c = e["message"]["content"]
        return c if isinstance(c, str) else " ".join(x.get("text", "") for x in c if isinstance(x, dict))
    a = e.get("attachment") or {}
    if a.get("type") == "queued_command" and (a.get("origin") or {}).get("kind") == "human":
        return a.get("prompt", "")
    return None


def strip_heredocs(text):
    out, delim = [], None
    for line in text.split("\n"):
        if delim is not None:
            if line.strip() == delim:
                delim = None
            continue
        out.append(line)
        m = OPENER.search(line)
        if m:
            delim = m.group(2)
    return "\n".join(out)


def inside(path):
    real = os.path.realpath(path)
    return real == str(ROOT) or real.startswith(str(ROOT) + os.sep)


def safe_read(path, limit=65536):
    if not inside(path):
        return None
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except OSError:
        return None
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
            return None
        if os.path.isdir("/proc/self/fd") and not inside(f"/proc/self/fd/{fd}"):
            return None
        chunks, size = [], 0
        while size < limit:
            chunk = os.read(fd, limit - size)
            if not chunk:
                break
            chunks.append(chunk)
            size += len(chunk)
        return b"".join(chunks).decode(errors="replace")
    except OSError:
        return None
    finally:
        os.close(fd)


GUARDED = ROOT / ".claude" / "hooks" / "lessons"


def guarded(lesson):
    return lesson["path"].startswith(str(GUARDED.relative_to(ROOT)) + "/")


def lessons():
    out = []
    dirs = [GUARDED, ROOT / "knowledge" / "lessons", ROOT / "rules", ROOT / ".agent" / "memory"]
    for d in dirs:
        if not d.is_dir() or d.is_symlink() or not inside(d):
            continue
        files = []
        for base, subdirs, names in os.walk(d, followlinks=False):
            subdirs.sort()
            files += [Path(base) / n for n in sorted(names) if n.endswith(".md")]
        for f in files:
            text = safe_read(f)
            if text is None:
                continue
            meta, body = frontmatter(text)
            triggers = []
            for t in meta.get("trigger", []):
                kind, _, rest = t.partition(" ")
                rest = rest.strip()
                if kind in ("bash", "prompt", "fail", "tool", "reply") and rest and len(rest) <= 300:
                    try:
                        triggers.append((kind, re.compile(rest)))
                    except re.error:
                        continue
                elif kind in ("edit", "read") and rest:
                    triggers.append((kind, rest))
            if triggers:
                out.append(dict(path=str(f.relative_to(ROOT)), meta=meta, body=body, triggers=triggers))
    return out


def fired(lesson, event, data):
    tool = data.get("tool_name", "")
    tin = data.get("tool_input") or {}
    command = strip_heredocs(str(tin.get("command", "")))
    if enforced(lesson, event):
        command = QUOTED.sub("''", command)
    for kind, pat in lesson["triggers"]:
        if kind == "bash" and event == "PreToolUse" and tool == "Bash" and pat.search(command):
            return True
        if kind == "tool" and event == "PreToolUse" and pat.fullmatch(tool):
            return True
        if kind == "prompt" and event == "UserPromptSubmit" and pat.search(data.get("prompt", "")):
            return True
        if kind == "reply" and event == "Stop" and not data.get("stop_hook_active") \
           and pat.search(str(data.get("last_assistant_message", ""))):
            return True
        if kind == "fail" and event == "PostToolUseFailure" and pat.search(str(data.get("error", ""))):
            return True
        if kind in ("edit", "read") and event == "PreToolUse":
            want = {"edit": ("Write", "Edit", "MultiEdit", "NotebookEdit"), "read": ("Read",)}[kind]
            fp = tin.get("file_path") or tin.get("notebook_path") or ""
            if tool in want and fp:
                try:
                    rel = str(Path(fp).resolve().relative_to(ROOT.resolve()))
                except ValueError:
                    continue
                if fnmatch.fnmatch(rel, pat):
                    return True
    return False


def heading(line):
    return HEAD.match(line) if len(line) <= 300 else None


def live_line(about):
    m = re.match(r'(\S+)\s+"(.+)"', about)
    if not m:
        return ""
    text = safe_read(ROOT / m.group(1))
    for line in (text or "").split("\n"):
        if m.group(2) in line:
            return f"{m.group(1)}: {line.strip().lstrip('-* ')}"[:400]
    return ""


def title_of(lesson):
    return next((heading(l).group(2) for l in unfenced(lesson["body"].split("\n")) if heading(l)), lesson["path"])[:120]


def message(lesson, count):
    meta, body = lesson["meta"], lesson["body"]
    head = title_of(lesson)
    paragraphs = [p for p in body.split("\n\n") if p.strip() and not heading(p.strip().split("\n")[0])]
    text = " ".join(l.strip() for l in (paragraphs[0] if paragraphs else "").split("\n"))[:400]
    lines = [f"Stewie memory, {lesson['path']}: {head}" + (f" (recalled {count}× before)" if count else "")]
    for about in meta.get("about", []):
        live = live_line(about)
        if live:
            lines.append(live)
    if text:
        lines.append(text)
    return "\n".join(lines)


def hits_fd(flags):
    try:
        STORE.mkdir(exist_ok=True)
        d = os.open(STORE, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except OSError:
        return None
    try:
        fd = os.open("hits.jsonl", flags | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600, dir_fd=d)
    except OSError:
        return None
    finally:
        os.close(d)
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
        os.close(fd)
        return None
    return fd


def log_open():
    fd = hits_fd(os.O_WRONLY | os.O_APPEND | os.O_CREAT)
    return os.fdopen(fd, "a") if fd is not None else None


def past_hits(session):
    fd = hits_fd(os.O_RDONLY)
    if fd is None:
        return []
    with os.fdopen(fd, "rb") as f:
        f.seek(max(0, os.fstat(f.fileno()).st_size - 400000))
        rows = []
        for line in f.read().decode(errors="replace").split("\n"):
            try:
                row = json.loads(line)
                if isinstance(row, dict):
                    rows.append(row)
            except ValueError:
                continue
        return rows


def in_force(hits):
    rows = []
    for lesson in lessons():
        if "every" in lesson["meta"].get("repeat", []) or guarded(lesson):
            n = sum(1 for h in hits if h.get("lesson") == lesson["path"])
            rows.append((n, f"- {clean(title_of(lesson), 120)} ({clean(lesson['path'], 120)}" + (f", recalled {n}×)" if n else ")")))
    rows.sort(key=lambda r: -r[0])
    if not rows:
        return ""
    return ("Lessons in force; each comes back when its trigger fires:\n" + "\n".join(r for _, r in rows[:10]))[:2000]


def clean(text, limit):
    return re.sub(r"[\x00-\x1f\x7f]+", " ", text).replace("BLOCKED by", "blocked by")[:limit]


def enforced(lesson, event):
    return event == "PreToolUse" and guarded(lesson) and "deny" in lesson["meta"].get("enforce", []) \
        and all(kind == "bash" for kind, _ in lesson["triggers"])


def cmd_recall(args):
    try:
        data = json.load(sys.stdin)
        event = data.get("hook_event_name", "")
        session = data.get("session_id", "")
        hits = past_hits(session)
        if event == "SessionStart":
            text = in_force(hits)
            if text:
                print(json.dumps({"hookSpecificOutput": {"hookEventName": event, "additionalContext": text}}, ensure_ascii=False))
            return 0
        ls = lessons()
        found = [l for l in ls if enforced(l, event) and safely_fired(l, event, data)]
        if not found:
            found = [l for l in ls if not enforced(l, event) and safely_fired(l, event, data)]
        agent = str(data.get("agent_id") or "")
        said, notes, deny = [], [], False
        for lesson in found:
            if len(said) >= 3:
                break
            path = lesson["path"]
            strict = enforced(lesson, event)
            before = sum(1 for h in hits if h.get("lesson") == path)
            if once(lesson, event) and any(h.get("lesson") == path and h.get("session") == session
                                           and str(h.get("agent") or "") == agent for h in hits):
                continue
            try:
                said.append(message(lesson, before).replace("BLOCKED by", "blocked by")[:900])
            except Exception:
                continue
            notes.append(path)
            deny = deny or strict
        if not said:
            return 0
        try:
            log = log_open()
            if log:
                with log:
                    for path in notes:
                        log.write(json.dumps(dict(ts=int(time.time()), session=session, agent=agent, event=event,
                                                  tool=data.get("tool_name", ""), lesson=path, denied=deny)) + "\n")
        except Exception:
            pass
        text = "\n\n".join(said)[:2000]
        if event == "Stop":
            print("Stewie memory: your reply repeats an error a lesson names. Correct the reply before ending the turn.\n" + text, file=sys.stderr)
            return 2
        if deny:
            print("BLOCKED by memory.py: a lesson the person escalated because reminding did not teach it.\n" + text, file=sys.stderr)
            return 2
        print(json.dumps({"hookSpecificOutput": {"hookEventName": event, "additionalContext": text}}, ensure_ascii=False))
    except Exception:
        return 0
    return 0


def safely_fired(lesson, event, data):
    try:
        return fired(lesson, event, data)
    except Exception:
        return False


def once(lesson, event):
    return not enforced(lesson, event) and "every" not in lesson["meta"].get("repeat", [])


def kind_of(lesson):
    return "pointer to" if lesson["path"].startswith("rules/") else "lesson"


def cmd_repeats(args):
    uses, groups = {}, {}
    ls = lessons()
    for n, e in transcript(args.transcript):
        msg = e.get("message") or {}
        content = msg.get("content") if isinstance(msg.get("content"), list) else []
        for c in content:
            if not isinstance(c, dict):
                continue
            if c.get("type") == "tool_use":
                uses[c.get("id")] = (c.get("name"), c.get("input") or {})
                data = dict(tool_name=c.get("name"), tool_input=c.get("input") or {})
                for lesson in ls:
                    key = f"{kind_of(lesson)} {lesson['path']}"
                    if not (once(lesson, "PreToolUse") and key in groups) and fired(lesson, "PreToolUse", data):
                        groups.setdefault(key, []).append(n)
            if c.get("type") == "tool_result" and c.get("is_error"):
                raw = c.get("content")
                text = raw if isinstance(raw, str) else " ".join(x.get("text", "") for x in raw or [] if isinstance(x, dict))
                name, tin = uses.get(c.get("tool_use_id"), ("?", {}))
                m = re.search(r"BLOCKED by ([\w.-]+)", text)
                if m and text.startswith("PreToolUse:"):
                    key = f"blocked by {m.group(1)}"
                else:
                    first = next((l for l in text.split("\n") if l.strip() and not l.startswith("Exit code")), text[:80])
                    first = re.sub(r"(/[\w.@-]+)+|\b\d+\b|'[^']*'|\"[^\"]*\"", "_", first)[:90]
                    prog = (tin.get("command", "").split() or [""])[0] if name == "Bash" else ""
                    key = f"failed {name} {prog}: {first}".strip()
                groups.setdefault(key, []).append(n)
                if name == "Bash":
                    data = dict(tool_name="Bash", tool_input=tin, error=text)
                    for lesson in ls:
                        key = f"{kind_of(lesson)} {lesson['path']}"
                        if not (once(lesson, "PostToolUseFailure") and key in groups) and fired(lesson, "PostToolUseFailure", data):
                            groups.setdefault(key, []).append(n)
    rows = sorted(((k, v) for k, v in groups.items() if len(v) >= args.min), key=lambda kv: -len(kv[1]))
    for k, v in rows:
        print(f"{len(v):4d}  {k}  (lines {', '.join(map(str, v[:3]))}{', …' if len(v) > 3 else ''})")
    if not rows:
        print("no repetition")
    return 0


def cmd_retro(args):
    for n, e in transcript(args.transcript):
        text = human(e)
        if text and not text.lstrip().startswith(MACHINE):
            print(f"{n}: {' '.join(text.split())[:800]}")
    return 0


def cmd_index(args):
    n, e = index(args.notes)
    print(f"indexed {n} nodes, {e} edges into {STORE / 'graph.db'}")
    return 0


def main(argv):
    import argparse
    ap = argparse.ArgumentParser(prog="memory")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("index")
    p.add_argument("--notes", action="append", default=[])
    p.set_defaults(fn=cmd_index)
    p = sub.add_parser("find")
    p.add_argument("terms", nargs="+")
    p.add_argument("--limit", type=int, default=5)
    p.add_argument("--kind", action="append")
    p.add_argument("--hops", type=int, default=1)
    p.set_defaults(fn=cmd_find)
    p = sub.add_parser("show")
    p.add_argument("id")
    p.set_defaults(fn=cmd_show)
    p = sub.add_parser("stale")
    p.add_argument("--notes", action="append", default=[])
    p.set_defaults(fn=cmd_stale)
    p = sub.add_parser("repeats")
    p.add_argument("transcript")
    p.add_argument("--min", type=int, default=2)
    p.set_defaults(fn=cmd_repeats)
    p = sub.add_parser("retro")
    p.add_argument("transcript")
    p.set_defaults(fn=cmd_retro)
    p = sub.add_parser("recall")
    p.set_defaults(fn=cmd_recall)
    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    try:
        code = main(sys.argv[1:])
        sys.stdout.flush()
    except BrokenPipeError:
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        code = 0
    sys.exit(code)
