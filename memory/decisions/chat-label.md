---
title: A chat always names itself with a short hash, which is not a leak
status: current
date: 2026-11-15
by: the person
---
Every chat identifies itself with its own label, a very simple hash, always. That label, and the clock record of when a chat started, are not personal data and are not a leak on a public branch. Paraphrased, not quoted: the branch is public.

Today the label is the platform's session id (`.claude/hooks/lib/chat.sh:103`); moving it to a short hash is a system change, pending.
