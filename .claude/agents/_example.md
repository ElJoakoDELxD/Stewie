---
name: example
description: The empty form that onboarding copies to a new agent's branch as agent.md. It is not an agent; never delegate to it.
effects:
  - writes: .agent/memory/
  - writes: .agent/chats/
  - writes: .agent/projects/
  - pushes: .agent/
---
You work for <the person, in one line: who they are and what they do>.

Language: <the language every reply uses>
Timezone: <IANA zone, such as America/New_York>
Goal: <the goal, in the person's own words>
