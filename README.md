# deps/egm

A disposable branch that holds Google's Elephant-Goldfish Model (EGM) plugin for Claude Code, so a later session can load it without fetching it again. It lasts until the branch is deleted, or until a pull request the person approves brings it into `main` as a dependency.

## What is here

`plugin/`: https://github.com/google/elephant-goldfish-model at commit `5382b17619be07811a14b2146c7672620b34a791` (version 0.1.1), unmodified, under the Apache License 2.0 in `plugin/LICENSE`.

## What it does

The session that holds the context (the elephant) drafts. Reviewers with no earlier conversation (the goldfish) read the draft and its sources. The person decides what to address.

## Use

Load it for one session with Claude Code's own plugin loader:

```
claude --plugin-dir .claude/worktrees/deps-egm/plugin
```

Then, for example, `/egm:egm-review <file>` or `/egm:egm-review-loop`.

## What it costs, and how it fits Stewie

- **Start:** all seven skills are invoked by the person, so they add nothing to the start.
- **Hooks:** it has none, so nothing runs at activation.
- **Reviewers:** eight of its ten reviewers can only read. The orchestrator and the synthesizer can also write.
- **A review read its skills, agents and the files they load, and found nothing malicious.** What to keep in mind:
  - **Where it writes.** Reports go to the working directory unless the task names an `EGM artifact directory:`. Name one outside the repository.
  - **No `CLAUDE.md` for reviewers.** They run with `omitClaudeMd: true`, so Stewie's rules do not reach them. They can still read any file the session can.
  - **Writers.** The synthesizer can write anywhere, and "write only the report" is an instruction, not a limit. The bootstrap orchestrator also has Bash.
  - **Fetched pages.** URLs given as context are fetched and saved as files beside the reports. Pass local files instead.
  - **How it talks.** Its skills set rules on how the agent speaks, and Stewie's `CLAUDE.md` comes before them.
  - **Personal data.** brainstorm and draft read `git config user.name` for the author field.
- **Models:** its reviewers inherit the session's model. `delegation-model.sh` lets `egm-*` through on purpose, as it does `malicious-code-review`.
