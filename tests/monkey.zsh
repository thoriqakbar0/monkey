#!/bin/zsh

emulate -L zsh
setopt nounset pipefail

typeset -g SUITE_ROOT=$(command mktemp -d "${TMPDIR:-/tmp}/monkey-tests.XXXXXX")
SUITE_ROOT=${SUITE_ROOT:A}
typeset -gr SUITE_ROOT
typeset -gr PROJECT_ROOT=${0:A:h:h}
export HOME="$SUITE_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export ZDOTDIR="$HOME"
command mkdir -p -- "$HOME"

source "$PROJECT_ROOT/shell/monkey.zsh"
source "$PROJECT_ROOT/tests/helpers/repo.zsh"

function invalid_invocations() {
  local repo="$SUITE_ROOT/invalid/repo"
  new_repo "$repo"
  builtin cd -- "$repo"
  local before=$PWD exit_code

  monkey > "$SUITE_ROOT/invalid/no-args.out" 2> "$SUITE_ROOT/invalid/no-args.err"
  exit_code=$?
  assert_equal 2 "$exit_code" 'no-argument status changed' || return
  assert_equal "$before" "$PWD" 'no-argument call changed PWD' || return
  assert_equal '' "$(<"$SUITE_ROOT/invalid/no-args.out")" 'usage wrote stdout' || return

  monkey -c > "$SUITE_ROOT/invalid/copy-no-name.out" 2> "$SUITE_ROOT/invalid/copy-no-name.err"
  exit_code=$?
  assert_equal 2 "$exit_code" 'copy without a name status changed' || return
  assert_equal "$before" "$PWD" 'copy without a name changed PWD' || return

  monkey 'bad name' > "$SUITE_ROOT/invalid/bad.out" 2> "$SUITE_ROOT/invalid/bad.err"
  exit_code=$?
  assert_equal 2 "$exit_code" 'invalid-branch status changed' || return
  assert_equal "$before" "$PWD" 'invalid branch changed PWD' || return
  [[ ! -e "$SUITE_ROOT/invalid/.worktrees" ]] || return 1

  monkey hook unknown > "$SUITE_ROOT/invalid/hook.out" 2> "$SUITE_ROOT/invalid/hook.err"
  exit_code=$?
  assert_equal 2 "$exit_code" 'invalid hook action status changed' || return
  assert_equal "$before" "$PWD" 'invalid hook action changed PWD'
}

function outside_git() {
  local outside="$SUITE_ROOT/outside"
  command mkdir -p -- "$outside"
  builtin cd -- "$outside"
  local before=$PWD exit_code
  monkey feature > out 2> err
  exit_code=$?
  (( exit_code != 0 )) || return 1
  assert_equal "$before" "$PWD" 'outside-git call changed PWD'
}

function missing_rift_preserves_state() {
  local repo="$SUITE_ROOT/missing-rift/repo"
  local bin="$SUITE_ROOT/missing-rift/bin"
  local real_git=$(command -v git)
  new_repo "$repo"
  command mkdir -p -- "$bin"
  command ln -s -- "$real_git" "$bin/git"
  builtin cd -- "$repo"
  local before=$PWD exit_code
  PATH="$bin" monkey -c feat/missing-rift > "$SUITE_ROOT/missing-rift/out" 2> "$SUITE_ROOT/missing-rift/err"
  exit_code=$?
  assert_equal 127 "$exit_code" 'missing-Rift status changed' || return
  assert_equal "$before" "$PWD" 'missing-Rift failure changed PWD' || return
  [[ ! -e "$repo/.rift" && ! -e "$SUITE_ROOT/missing-rift/.rifts" ]] || return 1
  assert_file_contains "$SUITE_ROOT/missing-rift/err" 'copy mode requires rift'
}

function create_and_repeat() {
  local repo="$SUITE_ROOT/create/repo"
  new_repo "$repo"
  print -r -- 'node_modules/' '.venv/' 'target/' > "$repo/.gitignore"
  command git -C "$repo" add .gitignore
  command git -C "$repo" commit -qm ignores
  command mkdir -p -- "$repo/node_modules" "$repo/.venv" "$repo/target"
  local captured=$(command git -C "$repo" rev-parse HEAD)
  local destination="$SUITE_ROOT/create/.worktrees/repo/feat-login"
  builtin cd -- "$repo"

  monkey feat/login > "$SUITE_ROOT/create/create.out" 2> "$SUITE_ROOT/create/create.err" || return
  assert_equal "$destination" "$PWD" 'create did not enter destination' || return
  assert_equal "created $destination" "$(<"$SUITE_ROOT/create/create.out")" 'create output changed' || return
  assert_equal "$captured" "$(command git rev-parse HEAD)" 'new branch used the wrong commit' || return
  assert_equal 'feat/login' "$(command git branch --show-current)" 'new branch name changed' || return
  [[ ! -e node_modules && ! -e .venv && ! -e target ]] || return 1

  builtin cd -- "$repo"
  monkey feat/login > "$SUITE_ROOT/create/repeat.out" 2> "$SUITE_ROOT/create/repeat.err" || return
  assert_equal "$destination" "$PWD" 'repeat did not enter destination' || return
  assert_equal "entered $destination" "$(<"$SUITE_ROOT/create/repeat.out")" 'repeat output changed'
}

function existing_registered_worktree() {
  local repo="$SUITE_ROOT/existing/repo"
  local linked="$SUITE_ROOT/existing/manual linked"
  new_repo "$repo"
  command git -C "$repo" worktree add -q -b 'feat/existing' "$linked"
  builtin cd -- "$repo"
  monkey 'feat/existing' > "$SUITE_ROOT/existing/out" 2> "$SUITE_ROOT/existing/err" || return
  assert_equal "$linked" "$PWD" 'registered worktree path changed' || return
  assert_equal "entered $linked" "$(<"$SUITE_ROOT/existing/out")" 'registered output changed'
}

function attach_existing_branch() {
  local repo="$SUITE_ROOT/attach/repo"
  local destination="$SUITE_ROOT/attach/.worktrees/repo/feat-attach"
  new_repo "$repo"
  command git -C "$repo" branch 'feat/attach'
  builtin cd -- "$repo"
  monkey 'feat/attach' > "$SUITE_ROOT/attach/out" 2> "$SUITE_ROOT/attach/err" || return
  assert_equal "$destination" "$PWD" 'existing branch used the wrong destination' || return
  assert_equal 'feat/attach' "$(command git branch --show-current)" 'existing branch was not attached' || return
  assert_equal "created $destination" "$(<"$SUITE_ROOT/attach/out")" 'attach output changed'
}

function occupied_destination() {
  local repo="$SUITE_ROOT/occupied/repo"
  local destination="$SUITE_ROOT/occupied/.worktrees/repo/feat-collision"
  new_repo "$repo"
  command mkdir -p -- "$destination"
  print -r -- keep > "$destination/unknown.txt"
  builtin cd -- "$repo"
  local before=$PWD exit_code
  monkey 'feat/collision' > "$SUITE_ROOT/occupied/out" 2> "$SUITE_ROOT/occupied/err"
  exit_code=$?
  (( exit_code != 0 )) || return 1
  assert_equal "$before" "$PWD" 'collision changed PWD' || return
  assert_equal keep "$(<"$destination/unknown.txt")" 'collision changed unknown file' || return
  assert_file_contains "$SUITE_ROOT/occupied/err" 'destination already exists'
}

function stale_registration() {
  local repo="$SUITE_ROOT/stale/repo"
  local linked="$SUITE_ROOT/stale/linked"
  local saved="$SUITE_ROOT/stale/saved"
  new_repo "$repo"
  command git -C "$repo" worktree add -q -b stale "$linked"
  command mv -- "$linked" "$saved"
  builtin cd -- "$repo"
  local before=$PWD exit_code
  monkey stale > "$SUITE_ROOT/stale/out" 2> "$SUITE_ROOT/stale/err"
  exit_code=$?
  (( exit_code != 0 )) || return 1
  assert_equal "$before" "$PWD" 'stale registration changed PWD' || return
  [[ -e "$saved/tracked.txt" ]] || return 1
  assert_file_contains "$SUITE_ROOT/stale/err" 'git worktree prune'
}

function unusual_primary_path() {
  local unusual_name=$'space ünicode\nsource'
  local repo="$SUITE_ROOT/$unusual_name"
  new_repo "$repo"
  builtin cd -- "$repo"
  local destination="${repo:h}/.worktrees/${repo:t}/feat-unusual"
  monkey 'feat/unusual' > "$SUITE_ROOT/unusual.out" 2> "$SUITE_ROOT/unusual.err" || return
  assert_equal "$destination" "$PWD" 'unusual primary path was not preserved' || return
  assert_equal "created $destination" "$(<"$SUITE_ROOT/unusual.out")" 'unusual path output changed'
}

function captured_head_survives_source_move() {
  local repo="$SUITE_ROOT/captured/repo"
  local bin="$SUITE_ROOT/captured/bin"
  local real_git=$(command -v git)
  new_repo "$repo"
  local captured=$(command git -C "$repo" rev-parse HEAD)
  local moved=$(print -r -- moved | command git -C "$repo" commit-tree "$captured^{tree}" -p "$captured")
  command mkdir -p -- "$bin"
  {
    print -r -- '#!/bin/zsh'
    print -r -- 'if [[ $1 == worktree && $2 == list ]]; then'
    print -r -- '  "$REAL_GIT" "$@"'
    print -r -- '  exit_code=$?'
    print -r -- '  "$REAL_GIT" update-ref refs/heads/main "$MOVED_COMMIT"'
    print -r -- '  exit $exit_code'
    print -r -- 'fi'
    print -r -- 'exec "$REAL_GIT" "$@"'
  } > "$bin/git"
  command chmod +x "$bin/git"
  builtin cd -- "$repo"
  REAL_GIT=$real_git MOVED_COMMIT=$moved PATH="$bin:$PATH" monkey captured > "$SUITE_ROOT/captured/out" 2> "$SUITE_ROOT/captured/err" || return
  assert_equal "$captured" "$(command git rev-parse HEAD)" 'creation did not use captured HEAD'
}

function same_name_race() {
  local repo="$SUITE_ROOT/race/repo"
  local bin="$SUITE_ROOT/race/bin"
  local barrier="$SUITE_ROOT/race/barrier"
  local real_git=$(command -v git)
  new_repo "$repo"
  command mkdir -p -- "$bin" "$barrier"
  {
    print -r -- '#!/bin/zsh'
    print -r -- 'if [[ $1 == worktree && $2 == add ]]; then'
    print -r -- '  if mkdir "$RACE_BARRIER/first" 2>/dev/null; then'
    print -r -- '    : > "$RACE_BARRIER/ready"'
    print -r -- '    while [[ ! -e "$RACE_BARRIER/second" ]]; do sleep 0.01; done'
    print -r -- '  else'
    print -r -- '    : > "$RACE_BARRIER/second"'
    print -r -- '    while [[ ! -e "$RACE_BARRIER/ready" ]]; do sleep 0.01; done'
    print -r -- '  fi'
    print -r -- 'fi'
    print -r -- 'exec "$REAL_GIT" "$@"'
  } > "$bin/git"
  command chmod +x "$bin/git"

  REAL_GIT=$real_git RACE_BARRIER=$barrier PATH="$bin:$PATH" zsh -f -c 'source "$1"; cd "$2"; monkey race' _ "$PROJECT_ROOT/shell/monkey.zsh" "$repo" > "$SUITE_ROOT/race/one.out" 2> "$SUITE_ROOT/race/one.err" &
  local first_pid=$!
  REAL_GIT=$real_git RACE_BARRIER=$barrier PATH="$bin:$PATH" zsh -f -c 'source "$1"; cd "$2"; monkey race' _ "$PROJECT_ROOT/shell/monkey.zsh" "$repo" > "$SUITE_ROOT/race/two.out" 2> "$SUITE_ROOT/race/two.err" &
  local second_pid=$!
  wait $first_pid
  local first_status=$?
  wait $second_pid
  local second_status=$?

  local successes=0
  (( first_status == 0 )) && (( successes += 1 ))
  (( second_status == 0 )) && (( successes += 1 ))
  assert_equal 1 "$successes" 'same-name race did not produce one winner' || return
  assert_equal 1 "$(command git -C "$repo" worktree list --porcelain | command grep -c '^branch refs/heads/race$')" 'race registered the branch more than once' || return

  builtin cd -- "$repo"
  monkey race > "$SUITE_ROOT/race/retry.out" 2> "$SUITE_ROOT/race/retry.err" || return
  assert_file_contains "$SUITE_ROOT/race/retry.out" 'entered '
}

function branch_lookup_failure() {
  local repo="$SUITE_ROOT/lookup-failure/repo"
  local bin="$SUITE_ROOT/lookup-failure/bin"
  local mutation="$SUITE_ROOT/lookup-failure/worktree-add-ran"
  local real_git=$(command -v git)
  new_repo "$repo"
  command mkdir -p -- "$bin"
  {
    print -r -- '#!/bin/zsh'
    print -r -- 'if [[ $1 == show-ref ]]; then exit 42; fi'
    print -r -- 'if [[ $1 == worktree && $2 == add ]]; then : > "$MONKEY_MUTATION"; fi'
    print -r -- 'exec "$MONKEY_REAL_GIT" "$@"'
  } > "$bin/git"
  command chmod +x "$bin/git"
  builtin cd -- "$repo"
  local before=$PWD exit_code
  MONKEY_MUTATION=$mutation MONKEY_REAL_GIT=$real_git PATH="$bin:$PATH" monkey lookup-failure > "$SUITE_ROOT/lookup-failure/out" 2> "$SUITE_ROOT/lookup-failure/err"
  exit_code=$?
  assert_equal 42 "$exit_code" 'branch lookup failure status changed' || return
  assert_equal "$before" "$PWD" 'branch lookup failure changed PWD' || return
  [[ ! -e $mutation ]] || return 1
  assert_file_contains "$SUITE_ROOT/lookup-failure/err" 'could not inspect branch'
}

function installer_is_idempotent() {
  print -r -- 'export EXISTING=1' > "$HOME/.zshrc"
  print -r -- 'export BASHRC_EXISTING=1' > "$HOME/.bashrc"
  print -r -- 'export BASH_PROFILE_EXISTING=1' > "$HOME/.bash_profile"
  "$PROJECT_ROOT/scripts/install.zsh" || return
  "$PROJECT_ROOT/scripts/install.zsh" || return
  command cmp -s "$PROJECT_ROOT/shell/monkey.zsh" "$XDG_CONFIG_HOME/monkey/monkey.zsh" || return 1
  command cmp -s "$PROJECT_ROOT/shell/monkey.bash" "$XDG_CONFIG_HOME/monkey/monkey.bash" || return 1
  assert_equal 1 "$(command grep -Fc 'source "${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.zsh"' "$HOME/.zshrc")" 'installer duplicated the Zsh source line' || return
  assert_equal 1 "$(command grep -Fc 'source "${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.bash"' "$HOME/.bashrc")" 'installer duplicated the Bash rc source line' || return
  assert_equal 1 "$(command grep -Fc 'source "${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.bash"' "$HOME/.bash_profile")" 'installer duplicated the Bash profile source line' || return
  assert_file_contains "$HOME/.zshrc" 'export EXISTING=1' || return
  assert_file_contains "$HOME/.bashrc" 'export BASHRC_EXISTING=1' || return
  assert_file_contains "$HOME/.bash_profile" 'export BASH_PROFILE_EXISTING=1'
}

function hook_installation_is_safe() {
  local repo="$SUITE_ROOT/hooks/repo"
  local marker="$SUITE_ROOT/hooks/ran"
  new_repo "$repo"
  builtin cd -- "$repo"
  local before=$PWD exit_code

  monkey hook install > "$SUITE_ROOT/hooks/missing.out" 2> "$SUITE_ROOT/hooks/missing.err"
  exit_code=$?
  assert_equal 1 "$exit_code" 'missing hook directory status changed' || return
  assert_equal "$before" "$PWD" 'missing hook directory changed PWD' || return
  assert_equal '' "$(command git config --local --get core.hooksPath)" 'missing hook directory changed Git config' || return

  command mkdir -p -- "$repo/.monkey/hook-target"
  command ln -s -- hook-target "$repo/.monkey/hooks"
  monkey hook install > "$SUITE_ROOT/hooks/symlink.out" 2> "$SUITE_ROOT/hooks/symlink.err"
  exit_code=$?
  assert_equal 1 "$exit_code" 'symbolic-link hook directory status changed' || return
  assert_equal '' "$(command git config --local --get core.hooksPath)" 'symbolic-link hook directory changed Git config' || return

  command rm -- "$repo/.monkey/hooks"
  command mkdir -p -- "$repo/.monkey/hooks"
  {
    print -r -- '#!/bin/sh'
    print -r -- ': > "$MONKEY_HOOK_MARKER"'
  } > "$repo/.monkey/hooks/pre-commit"
  command chmod +x "$repo/.monkey/hooks/pre-commit"

  monkey hook install > "$SUITE_ROOT/hooks/install.out" 2> "$SUITE_ROOT/hooks/install.err" || return
  monkey hook install > "$SUITE_ROOT/hooks/reinstall.out" 2> "$SUITE_ROOT/hooks/reinstall.err" || return
  assert_equal '.monkey/hooks' "$(command git config --local --get core.hooksPath)" 'hook path changed' || return
  assert_equal "$before" "$PWD" 'hook installation changed PWD' || return

  print -r -- changed > "$repo/tracked.txt"
  command git add tracked.txt
  MONKEY_HOOK_MARKER=$marker command git commit -qm 'run hook' || return
  [[ -f $marker ]] || return 1

  monkey hook uninstall > "$SUITE_ROOT/hooks/uninstall.out" 2> "$SUITE_ROOT/hooks/uninstall.err" || return
  monkey hook uninstall > "$SUITE_ROOT/hooks/reuninstall.out" 2> "$SUITE_ROOT/hooks/reuninstall.err" || return
  assert_equal '' "$(command git config --local --get core.hooksPath)" 'hook uninstall left local Git config' || return

  command git config --local core.hooksPath '.husky/_'
  monkey hook install > "$SUITE_ROOT/hooks/conflict.out" 2> "$SUITE_ROOT/hooks/conflict.err"
  exit_code=$?
  assert_equal 1 "$exit_code" 'existing hook manager conflict status changed' || return
  assert_equal '.husky/_' "$(command git config --local --get core.hooksPath)" 'existing hook manager was overwritten' || return
  assert_file_contains "$SUITE_ROOT/hooks/conflict.err" 'another hook manager owns core.hooksPath'
}

run_test 'invalid invocation preserves state' invalid_invocations
run_test 'outside Git preserves PWD' outside_git
run_test 'missing Rift preserves state' missing_rift_preserves_state
run_test 'missing branch creates from HEAD and repeat enters' create_and_repeat
run_test 'registered worktree enters its exact path' existing_registered_worktree
run_test 'existing unclaimed branch attaches' attach_existing_branch
run_test 'occupied destination preserves unknown files' occupied_destination
run_test 'stale registration names explicit recovery' stale_registration
run_test 'spaces, Unicode, and newline paths survive parsing' unusual_primary_path
run_test 'source branch movement does not change captured HEAD' captured_head_survives_source_move
run_test 'same-name race has one creator and retry converges' same_name_race
run_test 'branch lookup failure does not start creation' branch_lookup_failure
run_test 'installer rerun stays idempotent' installer_is_idempotent
run_test 'hook install runs scripts and preserves other managers' hook_installation_is_safe

print -r -- "1..$TEST_COUNT"
(( TEST_FAILURES == 0 ))
