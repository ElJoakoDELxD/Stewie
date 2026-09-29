# Stewie

Stewie turns Claude Code and a GitHub repository into an assistant that remembers. Each chat picks up where the last one stopped, because your assistant keeps its memory and its work in your own repository, and saves them at the end of every chat. (Stewie's own files call your assistant an *agent*.)

You do not need to program.

## Start

1. You need a GitHub account and a Claude plan that includes Claude Code on the web: Pro, Max, Team or Enterprise.
2. Open this repository on GitHub and press **Use this template**, then **Create a new repository**. Choose **Private**: your assistant's memory will live there. Leave **Include all branches** unticked.
3. Go to [claude.ai/code](https://claude.ai/code). The first time, connect your GitHub account, and when GitHub asks, let the Claude GitHub app reach your new repository.
4. Start a chat on your new repository and say hi.

The chat asks you at most four things: your assistant's name, the language to use, your timezone, and your goal. Then it saves your assistant and tells you it is ready.

## Every day

Open a new chat on your repository. With one assistant, the chat starts with it. With several, the chat asks which one; you can also ask it to create another. One chat works with one assistant from start to end.

Every reply begins with a line in square brackets: the date and time, your assistant, where it is working, and the model that answered. A ✓ at the end means the assistant checked that date and time and they agree; without the ✓, it will ask you which is right.

At the end of a chat, say you are done, or ask for a *handoff*: your assistant writes down where things stand and what comes next, and saves it, so the next chat can continue.

## Good to know

- Each assistant lives on its own branch of your repository, apart from Stewie itself, so an update to Stewie reaches all of them at once.
- The assistant never spends money, signs anything, or promises anything in your name. It prepares drafts; you publish them.
- Changes to Stewie itself, such as an update when the chat says your copy is behind, are made by its *custodian*: start a new chat, ask for the custodian, and ask it to update. It prepares the change as a pull request; to approve it, open the pull request on GitHub and press **Merge**.
- On Claude Code on the web, your assistant switches on a safety lock that keeps its commands inside your repository. On other computers that lock may not be available, and then a command can change files your assistant's permissions would otherwise protect.

## More

- [CHANGELOG.md](CHANGELOG.md): what changed in each version.
- [CONTRIBUTING.md](CONTRIBUTING.md): for people who improve Stewie itself.
- [LICENSE](LICENSE): MIT.
