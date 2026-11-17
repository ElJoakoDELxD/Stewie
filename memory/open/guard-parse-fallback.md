---
title: The commit guard lets a cd-then-commit through when the command does not parse
status: dropped
owner: agent
opened: 2026-11-16
closed: 2026-11-17
source: .claude/hooks/lib/approved.py:202, transcript of chat cse_017LRgRV3k6jW45L7yXMQHDJ
---
Not a hole. The observation was wrong: matching each historical commit call to its result in the transcript, every call that changes directory first (`cd`, `pushd`, `popd`) was refused and every call without one ran, with no exception. The call that seemed to pass had no `cd`. The guard refuses a commit when the call moves, because it cannot know the branch the commit lands on; the same commit run alone passes. Whether a push or merge to `main`, `candidate/*` or `custodian` can pass unguarded stays unchecked.
