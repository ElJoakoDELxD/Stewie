#!/usr/bin/env bash

set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)/linux-x86_64"
bin="${STEWIE_SANDBOX_BIN:-/usr/local/bin}"
case "$(uname -s)/$(uname -m)" in
  Darwin/*) ;;
  Linux/x86_64)
    [[ -x "${here}/bwrap" && -w "${bin}" ]] || exit 0
    ln -sf "${here}/bwrap" "${bin}/bwrap"
    ln -sf "${here}/socat" "${bin}/socat"
    ;;
  *) exit 0 ;;
esac

project="${CLAUDE_PROJECT_DIR:-$PWD}"
mkdir -p "${project}/.claude"
printf '%s\n' '{"sandbox":{"enabled":true,"enableWeakerNestedSandbox":true,"autoAllowBashIfSandboxed":true,"excludedCommands":["git *"],"network":{"allowedDomains":["api.anthropic.com","github.com","*.github.com","raw.githubusercontent.com"]}}}' \
  > "${project}/.claude/settings.local.json"
exit 0
