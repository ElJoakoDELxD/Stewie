---
name: 5s
description: Run 5S (sort, set in order, shine, standardize, sustain) over the public documents, the repository tree, or an agent's memory. Use when asked to tidy, prune or clean up one of them, and on the documents before every release.
---
# 5S

The target is `documents` (the public `*.md` files), `tree` (every tracked file) or `memory` (`.agent/memory/`).

1. **Sort.** List every item. Remove what fails the removal test in `CONTRIBUTING.md`. In memory, remove what stopped being true.
2. **Set in order.** Each fact has one home, and every other mention links to it.
3. **Shine.** Ask of each pair: *is this said twice? is this the same thing said in other words? do these two disagree?* For documents, `python3 tools/redundancy.py` ranks the candidate pairs; read every pair it prints.
4. **Standardize.** One name for each thing, one format for each kind of file.
5. **Sustain.** Fix what you can in the same change. Record every finding with its verdict: the custodian in its memory, an agent in its own. Report the words and files before and after.
