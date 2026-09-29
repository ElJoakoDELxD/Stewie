#!/usr/bin/env bash

set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/command.sh"

command="$(hook_command)"

[[ "${STEWIE_DURABLE_HOME:-0}" == "1" ]] && exit 0
[[ -e "${HOME}/.stewie-durable" ]] && exit 0

cmd="$(executable_text "${command}" | tr -d "\"'")"
segments="$(command_segments "${cmd}")"

pipes_to_shell=0
printf '%s' "${cmd}" | grep -qE '(curl|wget).*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|k)?sh([[:space:]]|$)' && pipes_to_shell=1

agent_dir='(~|\$HOME|/root|/home/[^/[:space:]]+)/\.(claude|codex|factory|config/opencode)(/|[[:space:]]|$)'

reason=""
while IFS= read -r seg; do
  [[ -z "${seg// }" ]] && continue

  read -r -a words <<< "${seg}"
  prog=""
  for w in "${words[@]}"; do
    case "${w}" in
      sudo|env|command|exec|nohup|time) continue ;;
      *=*) continue ;;
      -*) continue ;;
      *) prog="${w##*/}"; break ;;
    esac
  done
  [[ -z "${prog}" ]] && continue

  args=" ${seg#*"${prog}"} "

  case "${prog}" in
    uv)
      [[ "${args}" =~ [[:space:]]tool[[:space:]]+install[[:space:]] ]] \
        && reason="installs a tool onto this machine"
      ;;
    uvx)
      [[ "${args}" =~ [[:space:]]--from[[:space:]] ]] \
        && reason="installs a tool onto this machine"
      ;;
    pipx|cargo|gem|go)
      [[ "${args}" =~ [[:space:]]install[[:space:]] ]] \
        && reason="installs a tool onto this machine"
      ;;
    npm|pnpm|yarn|bun)
      if [[ "${args}" =~ [[:space:]](install|i|add|create)[[:space:]] \
            && "${args}" =~ [[:space:]](-g|--global|--location=global)[[:space:]] ]]; then
        reason="installs a package globally"
      elif [[ "${args}" =~ [[:space:]]global[[:space:]]+add[[:space:]] ]]; then
        reason="installs a package globally"
      fi
      ;;
    pip|pip3)
      [[ "${args}" =~ [[:space:]]install[[:space:]] && "${args}" =~ [[:space:]]--user[[:space:]] ]] \
        && reason="installs into the user site-packages"
      ;;
    apt|apt-get|dnf|yum|zypper|apk|brew)
      [[ "${args}" =~ [[:space:]](install|add)[[:space:]] ]] \
        && reason="installs a system package"
      ;;
    pacman)
      [[ "${args}" =~ [[:space:]]-S([[:space:]]|y|u) ]] \
        && reason="installs a system package"
      ;;
    git|cp|mv|ln|rsync|tar|unzip|mkdir|install)
      [[ "${args}" =~ ${agent_dir} ]] \
        && reason="writes into an agent directory outside the repository"
      ;;
    curl|wget)
      [[ "${pipes_to_shell}" -eq 1 ]] \
        && reason="pipes a downloaded installer into a shell"
      [[ "${args}" =~ ${agent_dir} ]] \
        && reason="writes into an agent directory outside the repository"
      ;;
  esac

  [[ -n "${reason}" ]] && break
done <<< "${segments}"

if [[ -n "${reason}" ]]; then
  cat >&2 <<EOF
BLOCKED by guard-install.sh: that command ${reason}, and this session's
filesystem does not survive it.

Do not retry it, and do not commit a script that promises to run it later. Say
plainly that the install cannot be made durable here, name what is needed and
why, write it in .agent/memory/backlog.md under "The person", and hand it to a
session on the person's own machine.

If this machine's home directory does persist, declare it once and this guard
stands aside:  touch ~/.stewie-durable
EOF
  exit 2
fi

exit 0
