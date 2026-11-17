# Stewie

Stewie turns Claude Code and a GitHub repository into an assistant that remembers. Each chat picks up where the last one stopped, because your assistant keeps its memory and its work in your own repository, and saves them as it goes. (Stewie's own files call your assistant an *agent*.)

You do not need to program.

## Why not just a chat

A plain chat forgets what you did last time, marks its own homework, and slowly drifts into improving itself instead of your work. Stewie adds, for each: memory in your own repository, saved as you go; success counted only when something outside it shows the work was useful; and a limit on time spent improving the tool itself. An example: a writing assistant that keeps your drafts and remembers your style.

## Start

1. You need a GitHub account and a Claude plan that includes Claude Code on the web: Pro, Max, Team or Enterprise.
2. Open https://github.com/ElJoakoDELxD/Stewie and press **Use this template**, then **Create a new repository**. Choose **Private**: your assistant's memory will live there. Leave **Include all branches** unticked.
3. Go to [claude.ai/code](https://claude.ai/code). The first time, connect your GitHub account, and when GitHub asks, let the Claude GitHub app reach your new repository.
4. Start a chat on your new repository and say hi.

The chat asks you at most four things: your assistant's name, the language to use, your timezone, and your goal. Then it saves your assistant and tells you it is ready. It worked if, after the first chat, your repository has a branch called `agent/<name>` with a first save in it.

## Every day

Open a new chat on your repository. With one assistant, the chat starts with it. With several, the chat asks which one; you can also ask it to create another. One chat works with one assistant from start to end.

Every reply begins with a line in square brackets: the date and time, your assistant, where it is working, and the model that answered. A ✓ at the end means the date matches what your assistant was told and the time runs on from its previous reply; without the ✓, it will ask you which is right.

Your assistant saves as it goes. At the end of a chat, say you are done, or ask for a *handoff*: your assistant writes down where things stand and what comes next, so the next chat can continue.

Your assistant's notes and work are on the branch `agent/<name>`: choose it in GitHub's branch menu (a *branch* is a separate line of saved work inside your repository, and the default view does not show it). To stop, just stop: everything stays in your repository, and deleting the branch deletes the assistant.

## Good to know

- Each assistant lives on its own branch of your repository, apart from Stewie itself, so an update to Stewie's rules and tools reaches all of them at once, while each assistant keeps its own memory.
- The assistant never spends money, signs anything, or promises anything in your name. It prepares drafts; you publish them, or say yes to each one it publishes for you.
- Changes to Stewie itself, such as an update when the chat says your copy is behind, are made by its *custodian*, a role that updates Stewie and only with your yes. It runs only on models Stewie has evaluated, listed in `knowledge/models.md`. Start a new chat, ask for the custodian, and ask it to update. It prepares the change as a *pull request* (a proposed change you can read before it is applied) and merges it when you type `/principal-approves`.
- On Claude Code on the web, your assistant switches on a safety lock that keeps most of its commands inside your repository: saving commands run outside it, and the lock links two helper programs into the system's program folder. On other computers that lock may not be available, and then a command can change files your assistant's permissions would otherwise protect.

## More

- [CHANGELOG.md](CHANGELOG.md): what changed in each version.
- [CONTRIBUTING.md](CONTRIBUTING.md): for people who improve Stewie itself.
- [LICENSE](LICENSE): MIT.
