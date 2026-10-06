#!/usr/bin/env bash

source "$(dirname "$0")/lib.sh"
H="${STEWIE}/.claude/hooks/guard-transcript.sh"
unset CLAUDE_CONFIG_DIR
export HOME="${TMP}/home"
T="${HOME}/.claude/projects/p/s.jsonl"
mkdir -p "$(dirname "${T}")" && : > "${T}"
write_to() { hook "${H}" "$(payload "$1" "${TMP}" /dev/null file_path="$2")"; }
run() { hook "${H}" "$(payload Bash "${STEWIE}" /dev/null command="$1")"; }
run_in() { hook "${H}" "$(payload Bash "$1" /dev/null command="$2")"; }
P='~/.claude/projects/p/s.jsonl'

echo "=== the transcript is evidence: nothing writes it ==="
check "Write to the transcript is blocked"    '[[ $(write_to Write "${T}") == BLOCK ]]'
check "and the refusal names the reason"      'grep -q "evidence" "${TMP}/hook.err"'
check "Edit of the transcript is blocked"     '[[ $(write_to Edit "${T}") == BLOCK ]]'
check "a traversal into it is blocked"        '[[ $(write_to Write "${HOME}/.claude/x/../projects/p/s.jsonl") == BLOCK ]]'
check "appending with echo is blocked"        '[[ $(run "echo forged >> ${T}") == BLOCK ]]'
check "tee is blocked"                        '[[ $(run "printf x | tee -a ${T}") == BLOCK ]]'
check "sed -i is blocked"                     '[[ $(run "sed -i s/a/b/ ${P}") == BLOCK ]]'
check "cp over it is blocked"                 '[[ $(run "cp /tmp/x ${P}") == BLOCK ]]'
check "curl -o into it is blocked"            '[[ $(run "curl -so ${P} https://example.com/x") == BLOCK ]]'
check "wget -O into it is blocked"            '[[ $(run "wget -qO ${P} https://example.com/x") == BLOCK ]]'
check "tar extracting there is blocked"       '[[ $(run "tar -xf /tmp/a.tar -C ~/.claude/projects") == BLOCK ]]'
check "touch is blocked"                      '[[ $(run "touch ${P}") == BLOCK ]]'
check "an editor is blocked"                  '[[ $(run "vim ${P}") == BLOCK ]]'
PYW="python3 -c \"open('${T}','a').write('x')\""
check "a python write is blocked"             '[[ $(run "${PYW}") == BLOCK ]]'
check "a path glued to an escape is blocked"  '[[ $(run "python3 -c \"open(\x27${T}\x27,\x27a\x27)\"") == BLOCK ]]'
check "find -delete is blocked"               '[[ $(run "find ~/.claude/projects -name x -delete") == BLOCK ]]'

echo
echo "=== readers that can write are not readers ==="
check "sort -o is blocked"                    '[[ $(run "sort -o ${P} /tmp/a") == BLOCK ]]'
check "uniq with an output file is blocked"   '[[ $(run "uniq /tmp/a ${P}") == BLOCK ]]'
check "xxd -r is blocked"                     '[[ $(run "xxd -r /tmp/a ${P}") == BLOCK ]]'
check "rg --pre is blocked"                   '[[ $(run "rg --pre /tmp/x y ${P}") == BLOCK ]]'
check "less is blocked"                       '[[ $(run "less ${P}") == BLOCK ]]'
check "a writer named by a reader's path"     '[[ $(run "echo forged | /tmp/cat ${P}") == BLOCK ]]'
check "a PATH that hides a writer"            '[[ $(run "PATH=/tmp:\$PATH cat ${P}") == BLOCK ]]'
check "a preloaded library"                   '[[ $(run "LD_PRELOAD=/tmp/x.so cat ${P}") == BLOCK ]]'
check "a program whose name holds ="          '[[ $(run "echo forged | ./x=y cat ${P}") == BLOCK ]]'
check ">& to a file that starts with a digit" '[[ $(run "cd ~/.claude/projects/p && echo forged >&3f2a.jsonl") == BLOCK ]]'
check "\$PWD names the cwd of the call"       '[[ $(run_in "${HOME}" "cp /tmp/x \$PWD/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "PATH set in its own segment"           '[[ $(run "PATH=/tmp; ls ${P}") == BLOCK ]]'
check "printf -v that sets PATH"              '[[ $(run "printf -v PATH %s /tmp; cat ${P}") == BLOCK ]]'
check "a quoted program with a space"         '[[ $(run "echo forged | \"cat /tee\" ${P}") == BLOCK ]]'
check "a program with an escaped space"       '[[ $(run "echo forged | cat\\ /tee ${P}") == BLOCK ]]'
check "a variable set earlier in the command" '[[ $(run "X=~; cp /tmp/x \$X/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "a for loop over home"                  '[[ $(run "for d in ~; do cp /tmp/x \$d/.claude/projects/p/s.jsonl; done") == BLOCK ]]'
check "a cd through a variable"               '[[ $(run "X=\$HOME; cd \$X/.claude/projects/p; cp /tmp/x s.jsonl") == BLOCK ]]'
check "a substitution that cuts the path"     '[[ $(run "cp /tmp/x \$(echo ~)/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "a backtick that cuts the path"         '[[ $(run "cp /tmp/x \`echo ~\`/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "tar -C home, then a relative path"     '[[ $(run "tar -C ~ -xf /tmp/a.tar .claude/projects/p/s.jsonl") == BLOCK ]]'
check "env -C home, then a relative path"     '[[ $(run "env -C ~ touch .claude/projects/p/s.jsonl") == BLOCK ]]'
check "home named after the relative path"   '[[ $(run "cp .claude/projects/p/s.jsonl -t ~") == BLOCK ]]'
check "cd -P home, then a relative write"     '[[ $(run "cd -P ~; cp /tmp/x .claude/projects/p/s.jsonl") == BLOCK ]]'
check "a subshell cd, then a relative write"  '[[ $(run "(cd ~ && cp /tmp/x .claude/projects/p/s.jsonl)") == BLOCK ]]'
check "pushd home, then a relative write"     '[[ $(run "pushd ~; cp /tmp/x .claude/projects/p/s.jsonl") == BLOCK ]]'
check "CDPATH through home"                   '[[ $(run "CDPATH=~; cd .claude/projects/p; cp /tmp/x s.jsonl") == BLOCK ]]'
check "a / from a variable after a substitution" '[[ $(run "S=/; cp /tmp/x \$(cd;pwd)\$S.claude/projects/p/s.jsonl") == BLOCK ]]'
check "an unset variable after the name"      '[[ $(run "cp /tmp/x ~/.claude\$9/projects/p/s.jsonl") == BLOCK ]]'
check "an unset variable inside the name"     '[[ $(run "cp /tmp/x ~/.cla\$9ude/projects/p/s.jsonl") == BLOCK ]]'
check "cd to a quoted substitution"           '[[ $(run "cd \"\$(echo ~)\"; cp /tmp/x .claude/projects/p/s.jsonl") == BLOCK ]]'
check "cd to a backtick substitution"         '[[ $(run "cd \`echo ~\` && cp /tmp/x .claude/projects/p/s.jsonl") == BLOCK ]]'
check "a variable set by a backtick"          '[[ $(run "x=\`echo ~\`; cp /tmp/x \$x/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "two substitutions glued"               '[[ $(run "cp /tmp/x \$(echo ~)\$(echo /.claude)/projects/p/s.jsonl") == BLOCK ]]'
check "\$_ after naming home"                  '[[ $(run "true ~; cp /tmp/x \$_/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "~- after leaving home"                 '[[ $(run "cd ~; cd /tmp; cp /tmp/x ~-/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "a variable set by read"                '[[ $(run "read SHELL <<< ~; cp /tmp/x \$SHELL/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "tar -C to a quoted substitution"       '[[ $(run "tar -C \"\$(echo ~)\" -xf /tmp/a .claude/projects/p/s.jsonl") == BLOCK ]]'
check "cp -t to a backtick, then a relative"  '[[ $(run "cp -t \`echo ~\` /tmp/x; cp /tmp/x .claude/projects/p/s.jsonl") == BLOCK ]]'
check "\$PWD after cd -P"                       '[[ $(run "cd -P ~ && cp /tmp/x \$PWD/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "\$PWD inside a subshell cd"             '[[ $(run "(cd ~ && cp /tmp/x \$PWD/.claude/projects/p/s.jsonl)") == BLOCK ]]'
check "~+ after pushd"                        '[[ $(run "pushd ~; cp /tmp/x ~+/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "~1 from the directory stack"           '[[ $(run "pushd ~; pushd /tmp; cp /tmp/x ~1/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "a new HOME for ~"                      '[[ $(run "HOME=${TMP}; cp /tmp/x ~/home/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "an attached -C with a substitution"    '[[ $(run "tar -C\"\$(echo ~)\" -xf /tmp/a .claude/projects/p/s.jsonl") == BLOCK ]]'
check "a HOME set by read"                    '[[ $(run "read HOME <<< ${TMP}; cp /tmp/x ~/home/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "a HOME set by printf -v"               '[[ $(run "printf -v HOME %s ${TMP}; cp /tmp/x ~/home/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "a bare cd after HOME is unknown"       '[[ $(run "read HOME <<< ~; cd; cp /tmp/x .claude/projects/p/s.jsonl") == BLOCK ]]'
check "cd ~ after HOME is unknown"            '[[ $(run "read HOME <<< ~; cd ~; cp /tmp/x .claude/projects/p/s.jsonl") == BLOCK ]]'
check "pushd ~ after HOME is unknown"         '[[ $(run "read HOME <<< ~; pushd ~; cp /tmp/x .claude/projects/p/s.jsonl") == BLOCK ]]'
check "cd -P ~ after HOME is unknown"         '[[ $(run "read HOME <<< ~; cd -P ~; cp /tmp/x .claude/projects/p/s.jsonl") == BLOCK ]]'
check "tar -C ~ after HOME is unknown"        '[[ $(run "read HOME <<< ~; tar -C ~ -xf /tmp/a .claude/projects/p/s.jsonl") == BLOCK ]]'
check "env -C ~ after HOME is unknown"        '[[ $(run "read HOME <<< ~; env -C ~ touch .claude/projects/p/s.jsonl") == BLOCK ]]'
check "a cd inside a quoted substitution"     '[[ $(run "echo \"\$(cd ~; cp /tmp/x .claude/projects/p/s.jsonl)\"") == BLOCK ]]'
check "a cd inside a quoted backtick"         '[[ $(run "echo \"\`cd ~; cp /tmp/x .claude/projects/p/s.jsonl\`\"") == BLOCK ]]'
HASH="$(printf 'echo "$(echo x # )\ncp /tmp/x $HOME/.claude/projects/p/s.jsonl\n)"')"
CASE="$(printf 'echo "$(case x in y) ;; esac\ncp /tmp/x $HOME/.claude/projects/p/s.jsonl\n)"')"
HERE="$(printf 'echo "$(cat <<E\n)\nE\ncp /tmp/x $HOME/.claude/projects/p/s.jsonl\n)"')"
check "a ) in a comment does not close \$("    '[[ $(run "${HASH}") == BLOCK ]]'
check "a ) in a case pattern does not close"  '[[ $(run "${CASE}") == BLOCK ]]'
check "a ) in a heredoc does not close"       '[[ $(run "${HERE}") == BLOCK ]]'
BRACE="$(printf 'cd ~; echo "$(echo ${x%%)}\ncp /tmp/x .claude/projects/p/s.jsonl\n)"')"
TICK="$(printf 'cd ~; echo "`echo \\`true\\`\ncp /tmp/x .claude/projects/p/s.jsonl\n`"')"
check "a ) in \${…} does not close \$("        '[[ $(run "${BRACE}") == BLOCK ]]'
check "an escaped backtick does not close"    '[[ $(run "${TICK}") == BLOCK ]]'
check "a command substitution is blocked"     '[[ $(run "echo \$(touch ${P})") == BLOCK ]]'
check "a backtick substitution is blocked"    '[[ $(run "cat \`touch ${P}\`") == BLOCK ]]'

echo
echo "=== spelling the path another way does not help ==="
check "a cd first, then a relative write"     '[[ $(run "cd ~/.claude/projects/p && echo x > s.jsonl") == BLOCK ]]'
check "cd home, then .claude relative"        '[[ $(run "cd ~; cp /tmp/x .claude/projects/p/s.jsonl") == BLOCK ]]'
check "cd step by step"                       '[[ $(run "cd ${TMP}; cd home/.claude; cp /tmp/x projects/p/s.jsonl") == BLOCK ]]'
check "a cwd inside the config dir"           '[[ $(run_in "${HOME}/.claude/projects/p" "echo x > s.jsonl") == BLOCK ]]'
check "\$HOME in braces"                      '[[ $(run "cp /tmp/x \${HOME}/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "\${HOME} from a cwd outside home"      '[[ $(run_in "${STEWIE}" "cp /tmp/x \"\${HOME}/.claude/projects/p/s.jsonl\"") == BLOCK ]]'
check "~+ for the cwd"                        '[[ $(run_in "${HOME}" "cp /tmp/x ~+/.claude/projects/p/s.jsonl") == BLOCK ]]'
check "a variable holding the path"          '[[ $(run "X=~/.claude; cp /tmp/x \$X/projects/p/s.jsonl") == BLOCK ]]'
check "empty quotes inside the name"          '[[ $(run "cp /tmp/x ~/.cla\"\"ude/pro\"\"jects/p/s.jsonl") == BLOCK ]]'
check "a backslash inside the name"           '[[ $(run "cp /tmp/x ~/.c\\laude/projects/p/s.jsonl") == BLOCK ]]'
check "a glob for the name"                   '[[ $(run "cp /tmp/x ~/.cl*/projects/p/s.jsonl") == BLOCK ]]'
check "an apostrophe in double quotes"        '[[ $(run "echo \"it'\''s\" > ${P}; echo '\''x'\''") == BLOCK ]]'
check "a substitution in a heredoc body"      '[[ $(run "$(printf "cat <<EOF\n\$(touch %s)\nEOF" "${P}")") == BLOCK ]]'
check "ANSI-C quoting of the name"            '[[ $(run "cp /tmp/x \$'\''${HOME}/.cl\\x61ude/projects/p/s.jsonl'\''") == BLOCK ]]'
check "a quoted <<x does not hide a line"     '[[ $(run "$(printf "echo \x27<<x\x27\ntouch %s" "${P}")") == BLOCK ]]'
check "a commented <<x does not hide a line"  '[[ $(run "$(printf "# <<x\ncp /tmp/x %s" "${P}")") == BLOCK ]]'
check "a here-string does not hide a line"   '[[ $(run "$(printf "cat <<<x\nsed -i s/a/b/ %s" "${P}")") == BLOCK ]]'
check "a line continuation in the name"      '[[ $(run "$(printf "cp /tmp/x ~/.cla\\\\\nude/projects/p/s.jsonl")") == BLOCK ]]'
check "a heredoc that names the config"      '[[ $(run "$(printf "cat > %s/n.md <<\x27EOF\x27\nsee %s\nEOF" "${TMP}" "${P}")") == BLOCK ]]'
check "a heredoc that does not, passes"      '[[ $(run "$(printf "cat > %s/n.md <<\x27EOF\x27\n\$(date)\nEOF" "${TMP}")") == PASS ]]'
check "./ and // in the path"                '[[ $(run "cp /tmp/x ~/./.claude//projects/p/s.jsonl") == BLOCK ]]'
CLAUDE_CONFIG_DIR="${TMP}/cfg"; export CLAUDE_CONFIG_DIR
check "a custom config dir, by variable"      '[[ $(run "sed --in-place s/a/b/ \$CLAUDE_CONFIG_DIR/projects/p/s.jsonl") == BLOCK ]]'
check "a custom config dir, by path"          '[[ $(run "cp /tmp/x ${TMP}/cfg/projects/p/s.jsonl") == BLOCK ]]'
unset CLAUDE_CONFIG_DIR

echo
echo "=== reading it, and writing elsewhere, pass ==="
check "Read is not this guard's business"     '[[ $(write_to Read "${T}") == PASS ]]'
check "listing transcripts passes"            '[[ $(run "ls -t ~/.claude/projects/*/*.jsonl | head -1") == PASS ]]'
check "grep over a transcript passes"         '[[ $(run "grep -c tool_use ${T}") == PASS ]]'
check "grep for a quoted > passes"            '[[ $(run "grep -c \">\" ${T}") == PASS ]]'
check "a read that silences stderr passes"    '[[ $(run "grep -l x ~/.claude/projects/*/*.jsonl 2>/dev/null | head -3") == PASS ]]'
check "a read that merges stderr passes"      '[[ $(run "cat ${T} 2>&1 | wc -l") == PASS ]]'
check "a read that sends stdout to stderr passes" '[[ $(run "ls ~/.claude/projects >&2") == PASS ]]'
check "a quoted | in a grep pattern passes"   '[[ $(run "grep -cE \"tool_use|tool_result\" ${T}") == PASS ]]'
check "a quoted ; or & in a pattern passes"   '[[ $(run "grep -c \"a;b&c\" ${T}") == PASS ]]'
check "a quoted | does not hide a writer"     '[[ $(run "grep \"a|b\" ${T} | tee ${T}") == BLOCK ]]'
check "find without actions passes"         '[[ $(run "find ~/.claude/projects -name \"*.jsonl\"") == PASS ]]'
check "Write elsewhere passes"                '[[ $(write_to Write "${TMP}/notes.md") == PASS ]]'
check "a redirect elsewhere passes"           '[[ $(run "echo ok > ${TMP}/out.txt") == PASS ]]'
check "python away from the config passes"    '[[ $(run "python3 -c \"print(1)\"") == PASS ]]'
check "git and globs in a repo pass"          '[[ $(run_in "${STEWIE}" "git add tests/*.sh && sort -o /tmp/s .claude/hooks/*.sh") == PASS ]]'
COMMIT="$(printf 'git commit -m "$(cat <<%sEOF%s\nfix .claude/hooks guard\nEOF\n)"' "'" "'")"
check "a commit message about the repo's hooks" '[[ $(run_in "${STEWIE}" "${COMMIT}") == PASS ]]'
check "a substitution over the repo's hooks"  '[[ $(run_in "${STEWIE}" "for f in \$(ls .claude/hooks); do bash -n .claude/hooks/\$f; done") == PASS ]]'
check "a substitution glued to a plain path"  '[[ $(run_in "${STEWIE}" "cp /tmp/x \"\$(pwd)/out\"") == PASS ]]'
check "the repo's own .claude is not the config" '[[ $(run_in "${STEWIE}" "cp /tmp/x .claude/settings.local.json") == PASS ]]'

finish "guard-transcript.sh"
