# Models

The cited list that the custodian and the `orchestrate` skill read. Match the model field of the reply header exactly. A model acts as the custodian only when it is listed here with the published evaluation that qualifies it. Any other model may still read, answer, and write a suggestion down. Only a model marked *orchestrates* may delegate work through the `orchestrate` skill.

| Model | Published evaluation | Custodian | Orchestrates |
|---|---|---|---|
| `claude-opus-5-5` | Anthropic, *System Card: Claude Opus 5.5*, 22-09-2026, https://www.anthropic.com/system-cards | yes | yes |

A model joins the list by a pull request that cites its published evaluation, and the person who owns the canon approves it.
