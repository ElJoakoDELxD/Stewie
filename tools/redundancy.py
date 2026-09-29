#!/usr/bin/env python3
import itertools
import re
import subprocess
import sys

STOP = set("""a an and are as at be because by can do does each every for from
has have if in into is it its may must no not of on one only or so than that
the their then there these they this to was what when where which while who
will with without you your yours its it's""".split())

def files_in_repo():
    out = subprocess.run(["git", "ls-files", "-co", "--exclude-standard", "*.md"],
                         capture_output=True, text=True, check=False).stdout
    return [f for f in out.splitlines() if f]

def sentences(path):
    out = []
    in_front = False
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            if line.strip() == "---":
                in_front = not in_front if number == 1 or in_front else in_front
                continue
            if in_front or line.lstrip().startswith(("```", "|---")):
                continue
            text = re.sub(r"[`*_>#|\[\]()]", " ", line)
            for sentence in re.split(r"(?<=[.!?:;])\s+", text):
                words = {w for w in re.findall(r"[a-z0-9]+", sentence.lower())
                         if w not in STOP and len(w) > 2}
                if len(words) >= 6:
                    out.append((number, " ".join(sentence.split()), words))
    return out

def main(argv):
    threshold = 0.5
    if "--threshold" in argv:
        i = argv.index("--threshold")
        threshold = float(argv[i + 1])
        del argv[i:i + 2]
    paths = argv or files_in_repo()
    items = [(p, n, s, w) for p in paths for (n, s, w) in sentences(p)]
    pairs = []
    for a, b in itertools.combinations(items, 2):
        if a[0] == b[0] and a[1] == b[1]:
            continue
        score = len(a[3] & b[3]) / len(a[3] | b[3])
        if score >= threshold:
            pairs.append((score, a, b))
    pairs.sort(key=lambda x: -x[0])
    print("redundancy: %d candidate pairs at or above %.2f, over %d sentences in %d files"
          % (len(pairs), threshold, len(items), len(paths)))
    for score, a, b in pairs:
        print("\n%.2f  %s:%d  |  %s:%d" % (score, a[0], a[1], b[0], b[1]))
        print("      %s" % a[2][:160])
        print("      %s" % b[2][:160])
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
