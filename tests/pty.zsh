#!/bin/zsh

emulate -L zsh
setopt nounset pipefail
zmodload zsh/zpty

typeset -g SUITE_ROOT=$(command mktemp -d "${TMPDIR:-/tmp}/monkey-pty.XXXXXX")
SUITE_ROOT=${SUITE_ROOT:A}
typeset -gr SUITE_ROOT
typeset -gr PROJECT_ROOT=${0:A:h:h}
export HOME="$SUITE_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export ZDOTDIR="$HOME"
command mkdir -p -- "$HOME"

source "$PROJECT_ROOT/tests/helpers/repo.zsh"

function read_until() {
  local session=$1 marker=$2 chunk
  local attempts=0
  REPLY=''
  while (( attempts < 200 )); do
    if zpty -r -t "$session" chunk; then
      REPLY+=$chunk
      [[ $REPLY == *$marker* ]] && return 0
    else
      sleep 0.05
    fi
    (( attempts += 1 ))
  done
  print -u2 -r -- "timed out waiting for ${(qqq)marker}"
  return 1
}

function start_session() {
  local session=$1
  zpty "$session" zsh -df
  zpty -w "$session" 'unsetopt zle; stty -echo; PS1=; RPS1=; print -r -- __MONKEY_READY__'$'\n'
  read_until "$session" $'__MONKEY_READY__\r\n' || return
}

function same_shell_cd() {
  local repo="$SUITE_ROOT/same-shell/repo"
  local destination="$SUITE_ROOT/same-shell/.worktrees/repo/pty-proof"
  new_repo "$repo"
  start_session monkey_same_shell || return
  zpty -w monkey_same_shell "source ${(q)PROJECT_ROOT}/shell/monkey.zsh"$'\n'
  zpty -w monkey_same_shell "cd ${(q)repo}"$'\n'
  zpty -w monkey_same_shell 'print -r -- __MONKEY_SETUP__'$'\n'
  read_until monkey_same_shell $'__MONKEY_SETUP__\r\n' || return
  zpty -w monkey_same_shell "monkey pty/proof"$'\n'
  zpty -w monkey_same_shell 'print -r -- "__MONKEY_PWD__${PWD}"'$'\n'
  read_until monkey_same_shell '__MONKEY_PWD__' || return
  local output=${REPLY//$'\r'/}
  zpty -d monkey_same_shell
  [[ $output == *"created $destination"* ]] || return 1
  [[ $output == *"__MONKEY_PWD__$destination"* ]] || return 1
}

function installed_shell_cd() {
  local repo="$SUITE_ROOT/installed/repo"
  local destination="$SUITE_ROOT/installed/.worktrees/repo/installed-proof"
  new_repo "$repo"
  "$PROJECT_ROOT/scripts/install.zsh" || return

  zpty monkey_installed env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" ZDOTDIR="$ZDOTDIR" zsh -di
  zpty -w monkey_installed 'unsetopt zle; stty -echo; PS1=; RPS1=; print -r -- __MONKEY_READY__'$'\n'
  read_until monkey_installed $'__MONKEY_READY__\r\n' || return
  zpty -w monkey_installed "cd ${(q)repo}"$'\n'
  zpty -w monkey_installed "monkey installed/proof"$'\n'
  zpty -w monkey_installed 'print -r -- "__MONKEY_PWD__${PWD}"'$'\n'
  read_until monkey_installed '__MONKEY_PWD__' || return
  local output=${REPLY//$'\r'/}
  zpty -d monkey_installed
  [[ $output == *"created $destination"* ]] || return 1
  [[ $output == *"__MONKEY_PWD__$destination"* ]] || return 1
}

function interrupt_returns_130() {
  local repo="$SUITE_ROOT/interrupt/repo"
  local bin="$SUITE_ROOT/interrupt/bin"
  local marker="$SUITE_ROOT/interrupt/git-started"
  local real_git=$(command -v git)
  new_repo "$repo"
  command mkdir -p -- "$bin"
  {
    print -r -- '#!/bin/zsh'
    print -r -- 'if [[ $1 == worktree && $2 == add ]]; then'
    print -r -- '  : > "$MONKEY_GIT_MARKER"'
    print -r -- '  sleep 30'
    print -r -- 'fi'
    print -r -- 'exec "$MONKEY_REAL_GIT" "$@"'
  } > "$bin/git"
  command chmod +x "$bin/git"
  export MONKEY_GIT_MARKER=$marker
  export MONKEY_REAL_GIT=$real_git
  export PATH="$bin:$PATH"

  start_session monkey_interrupt || return
  zpty -w monkey_interrupt "source ${(q)PROJECT_ROOT}/shell/monkey.zsh"$'\n'
  zpty -w monkey_interrupt "cd ${(q)repo}"$'\n'
  zpty -w monkey_interrupt 'print -r -- __MONKEY_SETUP__'$'\n'
  read_until monkey_interrupt $'__MONKEY_SETUP__\r\n' || return
  zpty -w monkey_interrupt "monkey pty/interrupt"$'\n'

  local attempts=0 pending='' chunk
  while [[ ! -e $marker && $attempts -lt 100 ]]; do
    if zpty -r -t monkey_interrupt chunk; then
      pending+=$chunk
    fi
    sleep 0.05
    (( attempts += 1 ))
  done
  [[ -e $marker ]] || {
    print -u2 -r -- "$pending"
    return 1
  }

  zpty -w monkey_interrupt $'\C-c'
  sleep 0.1
  zpty -w monkey_interrupt 'print -r -- "__MONKEY_STATUS__${?} __MONKEY_PWD__${PWD}"'$'\n'
  read_until monkey_interrupt '__MONKEY_STATUS__' || return
  local output=${REPLY//$'\r'/}
  zpty -d monkey_interrupt
  [[ $output == *"__MONKEY_STATUS__130 __MONKEY_PWD__$repo"* ]] || {
    print -u2 -r -- "$output"
    return 1
  }
}

run_test 'zpty proves monkey changes the current shell directory' same_shell_cd
run_test 'zpty proves the installed startup file loads monkey' installed_shell_cd
run_test 'zpty proves Ctrl+C returns 130 and preserves PWD' interrupt_returns_130

print -r -- "1..$TEST_COUNT"
(( TEST_FAILURES == 0 ))
