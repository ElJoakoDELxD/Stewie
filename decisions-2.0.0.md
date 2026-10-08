# Decisions of the 2.0.0 review

The decisions taken while reviewing candidate/2.0.0, and their state. "Done" names the commit on fix/2.0.0-review. Everything else waits in the batch.

## Done

- **Identity comes only from a real header call.** A declaration counts only when the harness records a Bash call of exactly `header --declare …` and its result. Text that merely looks like the marker counts for nothing. (8ef3998)
- **Actions pinned by commit SHA.** The version goes in the commit message, because the benches forbid comments. (8ef3998)
- **guard-install catches pipe-to-shell installers.** This includes sudo flags that take values and pipes split across lines. (3bd0103, 3c6e65c)
- **The bench log is a private temporary file per run.** (3bd0103)
- **sizes.sh counts every Markdown file except CHANGELOG.** The ceiling was raised once, to the count at that time. (9b46ca2)
- **CI runs the Version check only on pull requests into main.** (9b46ca2)
- **The repository is marked as a template.**
- **An agent works only with the Bash sandbox on.** The sandbox, not a Stewie guard, keeps transcripts, hooks and settings out of Bash's reach. The header shows the sandbox state. The lexical transcript guard was retired. (9b46ca2, 68598ca, 53ef59c)

## Approved, to build

- **Sandbox policy.** The policy lives in the versioned `.claude/settings.json`. Sandboxed Bash is not auto-approved; an allowlist covers reads and Stewie's tools instead. The kit writes only machine-specific settings.
- **Environment awareness.** One function names where a session runs: cloud, CLI, desktop or IDE. The kit never replaces an existing bwrap or socat. On a person's own machine it advises installing them.
- **Pinned kit binaries.** SOURCES.md lists the SHA-256 and exact URL of each package. CI checks the hashes.
- **Installs in the cloud.** First, run what can run straight from git. Second, install for the session only, with the step recorded in git. Third, anything that must persist goes to the person's machine.
- **CONTRIBUTING.md is for people.** It says how to propose and what happens next. The rules move to the custodian's file.
- **Onboarding test.** The principal runs it in a disposable copy. The CHANGELOG says there is no outside use yet.
- **A real `/principal-approves <item>` command.** A hook checks it without reading natural language. It is required for every guarded act: a merge or push to a shared branch, a release, a history rewrite, creating a role in the canon, and attaching the custodian.
- **Code that runs automatically outside the sandbox must come from main or carry an approved hash.**
- **A learning verifier.** At the end of each reply, a cheaper model checks the agent's learning note against evidence.
- **A register of the principal's pending decisions.** It is resolved in order, and no question goes unrecorded.
- **Continuity between local and cloud sessions through GitHub.**
- **Procedures that fail as prose become skills, plus a hook that checks their effect.**
- **Features accumulate on the candidate until the principal names a release.** The agent suggests; it never decides.
- **Memory.**
  - Chat notes live on disposable branches and are written clean from the start.
  - They are reviewed before every push.
  - Fixed memory is a single-commit snapshot that can be rewritten.
  - A `forget` skill removes what the principal asks for.
  - Memory never travels through pull requests, issues or comments.
  - Promotion to fixed memory needs `/principal-approves`.
- **Public text is permanent.** Issues, pull requests, comments, pushes and releases can be archived anywhere, so they carry no personal data, no quotes and no private reasoning.
- **Network.** When a host is refused, the agent reads the proxy record. If the gateway refused it, the agent suggests adding the host to the cloud environment.
- **Roles.**
  - A role is named without superlatives and comes with concrete standards.
  - A role the agent adopts is a skill; a role it delegates to is a subagent.
  - Each role has an auditor subagent on a different model, which judges by evidence it produces itself.
- **Contrast with the web.** A skill for any task or plan that involves design decisions.
- **Routines.** The routines' prompts become skills in the repository. After the bootstrap, the routines point to this repository.
- **Review cap.** At most two rounds per change. In round two, a contract violation is fixed and reported. A deliberate construction against a parser is declared as a limit instead.
- **Leak checkpoint.** Before the bootstrap, the candidate tree passes three context-free reviewers, one each for personal data, words and thoughts, and environment and secrets. They report location and type, never a quote. This becomes the `leak-check` skill.
- **Staying current by pointers.** A file holds only links to primary sources and a "seen up to" link, never content. At session start the agent reads what is new. A fact that can change is answered from the source, read in that turn.
- **Proactivity.** At most one proposal per reply, with its cost, asked before the cost is spent.
- **Commits to public branches carry no session link.**

## Open findings

- `executable_text` detects heredocs with a regex that a fake opener can fool, so guard-main and guard-install can miss the lines after one.
- Each guard should declare whether it fails open or closed.
- Whether git can run inside the sandbox still has to be measured. Today the kit runs git outside it.
- A force push to the custodian branch should be blocked unless `/principal-approves` is given.

## Dropped

- An explicit `denyWrite` on the config directory. The sandbox already protects it, and an `allowWrite` cannot lift that protection.

## Learned

- A fact that can change, such as a model, a version, a price or whether something exists, is checked against its primary source before it is stated. This applies most of all before contradicting the principal.
- Before ignoring a file, find out what produces it and whether it should exist at all.
