# Goldfish Annotated Review Report

**Target:** `README.md` (`1-35`, full file), on candidate/2.0.0 plus the delegation guard
**Round:** 1 of at most 2
**Reviewers, all completed:** zoom_out (zoom-out-standard), design_critic (heilmeier-standard), comprehension (a newcomer understands from this file alone), codebase_details (every claim matches the code)
**Question:** does Stewie work as a product for someone who did not build it, is it worth more than plain Claude Code with a good CLAUDE.md, and what should be better or different?

Findings raised by several reviewers are merged and keep every reviewer's id. Each fix is marked by where it lands:
- **README** edits the target file.
- **System** needs its own change and pull request.
- **Person** waits on the person's decision.

## Prioritized Findings & AI Suggestions

### [Issue 1] [`zoom_out`, `design_critic`, `codebase_details`, `comprehension`] - Severity: Blocker
*   **Affected Scope:** [Lines 3, 22](README.md#L3-L22) (top, Use)
*   **Discrepancy Description:** Line 3 promises the assistant saves "at the end of every chat". Line 22 makes saving depend on the person saying "done" or asking for a handoff. Nothing enforces either: `.claude/settings.json` has no Stop, SessionEnd or PreCompact hook. A chat closed without a handoff loses its notes.
*   **Rationale:** This is the product's main promise, and failure mode 1 in CLAUDE.md, "work evaporates". It is held by prose, while lesser concerns get hooks with benches. It already happened in this project: three reviewed commits were lost with a reclaimed container.
*   ***AI Suggestion:*** PROPOSE FIX (System, then README)
*   ***Justification:*** Valid, and verified in `.claude/settings.json`.
*   ***Proposed Edit:***
    *   System: a Stop hook that commits and pushes `.agent/` when it has changes, with a bench. Pushing at handoff is already the design; the hook only makes it automatic.
    *   README line 22, once the hook lands: "It saves as it goes. A handoff adds a note on where things stand for the next chat."

### [Issue 2] [`design_critic`] - Severity: Blocker
*   **Affected Scope:** [Lines 10, 26, 28](README.md#L10-L28) (Start, How it works)
*   **Discrepancy Description:** The canon's default branch is `candidate/2.0.0`, and it has no `main` and no tags. The elephant verified this with `git ls-remote --symref` this turn. A copy made with *Use this template* therefore has no `main`. Then:
    *   `guard-main.sh` protects nothing, since it guards a branch named `main`;
    *   the update skill and every "pull request to `main`" have no target;
    *   `anchor.sh` tells every copy "the canon did not answer" when the canon only has no tags;
    *   CHANGELOG line 9 calls 2.0.0 a release, yet no `v2.0.0` tag exists.
*   **Rationale:** The README sends people to a template that produces a broken copy today.
*   ***AI Suggestion:*** PROPOSE FIX (Person, then System)
*   ***Justification:*** Valid and verified. Whether the canon should look like this before the release is the person's call.
*   ***Proposed Edit:***
    *   Person: release 2.0.0. Make `main` the default branch and tag `v2.0.0`, each with `/principal-approves`.
    *   System: `anchor.sh` tells "no tags" apart from "no answer"; CI checks that the default branch is `main` and that the top CHANGELOG version is tagged.

### [Issue 3] [`codebase_details`, `design_critic`, `comprehension`] - Severity: Blocker
*   **Affected Scope:** [Line 28](README.md#L28) (How it works)
*   **Discrepancy Description:** "Start a new chat, ask for the custodian, and ask it to update" has no working path in a fresh copy:
    *   no skill or tool creates the `custodian` branch;
    *   `attach custodian` fails, and its message sends the person to onboard;
    *   onboard creates `agent/custodian`, which `attach` and `anchor.sh` never find;
    *   the custodian acts only on `claude-opus-5-5` (`knowledge/models.md`).
    *   "Custodian" is never defined for the reader.
*   **Rationale:** The update promise in lines 26 and 28 cannot be kept.
*   ***AI Suggestion:*** PROPOSE FIX (System, then README)
*   ***Justification:*** Valid. `codebase_details` reproduced the `attach` failure in a scratch copy.
*   ***Proposed Edit:***
    *   System: onboard offers to create the custodian, as an orphan `custodian` branch, and a bench covers it.
    *   README line 28: say in one clause what the custodian is ("a role that updates Stewie itself, and only on your yes"), how to call it, and that it needs Claude Opus 5.5.

### [Issue 4] [`design_critic`, `zoom_out`, `comprehension`] - Severity: Blocker
*   **Affected Scope:** [Lines 1-5, 14](README.md#L1-L14) (top, Start)
*   **Discrepancy Description:** The README never compares Stewie with what a reader already has: a CLAUDE.md, Claude's own memory, Projects. It gives no example of what an assistant does, and no example of a goal for question four. The real differences, the three failure modes, live only in CLAUDE.md, which is written for the agent.
*   **Rationale:** A reader cannot tell whether it is for them.
*   ***AI Suggestion:*** PROPOSE FIX (README)
*   ***Justification:*** Valid. A human reader needs this, not only a reviewer.
*   ***Proposed Edit:*** After line 5, add "Why not just a chat". Plain Claude Code loses work between chats, grades its own work, and drifts into improving itself. For each, name what Stewie adds: memory in your own repository saved every chat, success counted only as something an outsider does, and a bound on meta-work. Then add one example: "for example, a writing assistant that keeps your drafts and remembers your style".

### [Issue 5] [`codebase_details`, `zoom_out`, `design_critic`, `comprehension`] - Severity: Blocker
*   **Affected Scope:** [Line 29](README.md#L29) (How it works)
*   **Discrepancy Description:** The safety-lock sentence does not match the code:
    *   **What turns it on:** `activate.sh` turns it on for any Linux x86_64 machine with a writable `/usr/local/bin`, not "Claude Code on the web". It runs only after `attach`, so it is off during onboarding.
    *   **What it protects:** it keeps commands inside the repository, not inside the assistant's permissions. `agent-permissions.sh` does not check Bash writes, so `sed -i README.md` passes with the lock on.
    *   **What it leaves out:** git runs outside it, network access is limited to Anthropic and GitHub, and Bash runs without prompts.
    *   **What the reader can't tell:** "other computers" leaves open whether local use is supported.
*   **Rationale:** It is a safety claim that is wrong in both directions, and the reader can do nothing with it.
*   ***AI Suggestion:*** PROPOSE FIX (README, and a System gap)
*   ***Justification:*** Valid, and confirmed in `activate.sh` and `agent-permissions.sh`.
*   ***Proposed Edit:***
    *   README line 29: "On Claude Code on the web, each assistant's commands run in a sandbox: they can reach only Anthropic and GitHub, cannot install software, and stay inside your repository. Stewie is made for the web; on your own computer, these limits are not set for you."
    *   System gap, recorded only: Bash writes are not checked against an assistant's declared effects.

### [Issue 6] [`zoom_out`] - Severity: Major
*   **Affected Scope:** [Lines 18, 26, 28](README.md#L18-L28)
*   **Discrepancy Description:** The machinery is large next to what one non-programmer gets:
    *   6 hooks, 3 tools, 5 skills and 7 rules;
    *   about 1,600 lines of shell and Python, and about 600 KB of bundled binaries.
    *   Several assistants in one repository drive most of it, while *Use this template* already gives one repository per assistant.
*   **Rationale:** YAGNI, and CONTRIBUTING.md line 7: "No new rule without a failure a user saw".
*   ***AI Suggestion:*** ESCALATE
*   ***Justification:*** Whether several assistants per repository stays in scope is a product decision outside the files.

### [Issue 7] [`zoom_out`] - Severity: Major
*   **Affected Scope:** [Lines 26, 28](README.md#L26-L28)
*   **Discrepancy Description:** The update path (the template and agent split, the custodian, the `update` skill, the version check) reinvents Claude Code plugins and marketplaces. If Stewie shipped as a plugin, a user's repository would hold only memory, output and a thin CLAUDE.md.
*   **Rationale:** Platform standards: this very review runs from a plugin.
*   ***AI Suggestion:*** ESCALATE
*   ***Justification:*** It is an architecture choice. It rests on an unverified fact: whether a plugin declared in a project's settings installs itself on Claude Code on the web.

### [Issue 8] [`zoom_out`, `design_critic`] - Severity: Major
*   **Affected Scope:** whole project
*   **Discrepancy Description:** The ten commits since 2.0.0 are all governance or meta-work, and none touches the Start path. No outsider has used the product, though `custodian.md` and CLAUDE.md count only outside signals as success. The README gives no setup time and no check that onboarding worked.
*   **Rationale:** This is failure mode 3, "process eats product", in the canon itself.
*   ***AI Suggestion:*** ESCALATE (the evidence of use) and PROPOSE FIX (the README check)
*   ***Justification:*** Only the person can bring outsiders.
*   ***Proposed Edit:*** README Start: "Setup takes about ten minutes. It worked if, after the first chat, your repository has a branch `agent/<name>` with a first commit." Verify the time on a throwaway copy before publishing it.

### [Issue 9] [`zoom_out`, `design_critic`] - Severity: Major
*   **Affected Scope:** [Lines 3, 10, 26](README.md#L3-L26)
*   **Discrepancy Description:** The README never says where the assistant's notes and work are: on branch `agent/<name>`, which GitHub's default page does not show. Nor does it say how to stop, export or delete, while CLAUDE.md says the person stays free to stop.
*   ***AI Suggestion:*** PROPOSE FIX (README)
*   ***Proposed Edit:*** Add under Use: "Your assistant's notes and work are on the branch `agent/<name>`: choose it in GitHub's branch menu. To stop, just stop. Everything stays in your repository; deleting the branch deletes the assistant."

### [Issue 10] [`zoom_out`, `design_critic`, `comprehension`] - Severity: Major
*   **Affected Scope:** [Lines 3, 5, 22, 26, 28](README.md#L3-L28)
*   **Discrepancy Description:** "You do not need to program" sits next to branch, pull request, custodian, handoff, "a copy is behind" and "safety lock", none explained. That breaks the custodian's own rule that no public file carries vocabulary a user must learn.
*   ***AI Suggestion:*** PROPOSE FIX (README)
*   ***Proposed Edit:*** Gloss each term in one plain clause where it first appears, or move lines 26 and 28-29 under a heading "If you know git".

### [Issue 11] [`zoom_out`, `design_critic`, `comprehension`, `codebase_details`] - Severity: Major
*   **Affected Scope:** [Line 20](README.md#L20) (Use)
*   **Discrepancy Description:** Every reply carries a status line. The README does not say what "they agree" compares, what to answer without the ✓, or that the line has a cost. It also lists fewer fields than `tools/bin/header` prints.
*   ***AI Suggestion:*** PROPOSE FIX (README) for the meaning, and ESCALATE for whether the line stays on by default
*   ***Justification:*** The line is a rule the person chose, written in CLAUDE.md under "A reply opens". Its meaning is a comprehension gap, which per this skill's rules is never contested.
*   ***Proposed Edit:*** Line 20: "Each reply starts with a line showing the date and time, which assistant is working, and where. The ✓ means the date matches what the assistant was told and the time runs on from its previous reply. Without it, the assistant asks you which is right."

### [Issue 12] [`comprehension`, `zoom_out`, `design_critic`] - Severity: Major
*   **Affected Scope:** [Lines 10, 26, 28](README.md#L10-L28)
*   **Discrepancy Description:** "Open this repository on GitHub" assumes the reader is on the canon. The README is the same file in every copy, the canon is never named, and the reader cannot tell where updates come from.
*   ***AI Suggestion:*** PROPOSE FIX (README)
*   ***Proposed Edit:*** Line 10: "Open https://github.com/ElJoakoDELxD/Stewie, choose *Use this template* …". Line 26: "updates come from that repository, and your copy is told when it is behind".

### [Issue 13] [`codebase_details`] - Severity: Major
*   **Affected Scope:** [Line 26](README.md#L26)
*   **Discrepancy Description:** "An update reaches all of them at once" is only partly true. Hooks, skills and tools do reach every assistant. The sandbox kit and the agent form are copied into each agent's branch at creation, and an update never touches them.
*   ***AI Suggestion:*** PROPOSE FIX (README)
*   ***Proposed Edit:*** "An update to Stewie's rules and tools reaches all of them at once; each assistant keeps its own memory and settings."

### [Issue 14] [`codebase_details`] - Severity: Nit
*   **Discrepancy Description:** The benches are not sealed off from untracked worktrees. `tests/lib.sh` `fixture()` copies `.claude/worktrees/`, and `test-anchor.sh` fails one check while one exists.
*   ***AI Suggestion:*** PROPOSE FIX (System)
*   ***Proposed Edit:*** In `fixture()`, remove `.claude/worktrees` and `settings.local.json` after the copy, as feat/memory-graph already does.

### [Issue 15] [`codebase_details`] - Severity: Nit
*   **Affected Scope:** [Line 27](README.md#L27)
*   **Discrepancy Description:** "It prepares drafts; you publish them" holds for the assistant. But the custodian opens issues and merges pull requests itself, each on the person's yes.
*   ***AI Suggestion:*** PROPOSE FIX (README)
*   ***Proposed Edit:*** "It prepares drafts; you publish them, or say yes to each one it publishes for you."

### [Issue 16] [several] - Severity: Nit
*   **Discrepancy Description:**
    *   The plan list on line 9 has no source.
    *   Onboarding can ask a fifth question.
    *   Two chats of one assistant can collide on `git pull --rebase`.
    *   The "agent" and "assistant" terms are split.
    *   Requirements go unstated: git 2.42 or later, and installs are blocked.
    *   The plan limits a chat uses go unstated.
*   ***AI Suggestion:*** DECLINE, except the line 9 source, which is PROPOSE FIX: link Anthropic's plans page.

## Not run

None. All four reviewers completed round 1.
