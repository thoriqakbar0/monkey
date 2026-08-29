#!/bin/bash

set -u
set -o pipefail

SUITE_ROOT=$(command mktemp -d "${TMPDIR:-/tmp}/monkey-bash.XXXXXX")
SUITE_ROOT=$(cd "$SUITE_ROOT" && pwd -P)
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd -P)
export HOME="$SUITE_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export ZDOTDIR="$HOME"
command mkdir -p -- "$HOME"

source "$PROJECT_ROOT/shell/monkey.bash"

TEST_COUNT=0
TEST_FAILURES=0

test_ok() {
  TEST_COUNT=$((TEST_COUNT + 1))
  printf 'ok %s - %s\n' "$TEST_COUNT" "$1"
}

test_not_ok() {
  TEST_COUNT=$((TEST_COUNT + 1))
  TEST_FAILURES=$((TEST_FAILURES + 1))
  printf 'not ok %s - %s\n' "$TEST_COUNT" "$1" >&2
}

run_test() {
  local label=$1
  shift
  if ( "$@" ); then
    test_ok "$label"
  else
    test_not_ok "$label"
  fi
}

assert_equal() {
  local expected=$1 actual=$2 label=$3
  if [[ $actual != "$expected" ]]; then
    printf '%s\n' "$label" >&2
    printf 'expected: %q\n' "$expected" >&2
    printf 'actual:   %q\n' "$actual" >&2
    return 1
  fi
}

assert_file_contains() {
  local file=$1 text=$2
  command grep -Fq -- "$text" "$file" || {
    printf 'missing %q in %s\n' "$text" "$file" >&2
    return 1
  }
}

new_repo() {
  local repo_dir=$1
  command mkdir -p -- "$repo_dir"
  command git -C "$repo_dir" init -q -b main
  command git -C "$repo_dir" config user.name 'Monkey Test'
  command git -C "$repo_dir" config user.email 'monkey@example.test'
  printf '%s\n' initial > "$repo_dir/tracked.txt"
  command git -C "$repo_dir" add tracked.txt
  command git -C "$repo_dir" commit -qm initial
}

cleanup_rift_test() {
  local repo=$1 root=$2
  builtin cd /tmp
  command rift remove --children "$repo" >/dev/null 2>&1 || true
  command rift remove -f "$repo" >/dev/null 2>&1 || true
  command trash "$root" >/dev/null 2>&1 || true
}

default_create_and_repeat() {
  local repo="$SUITE_ROOT/default/repo"
  local destination="$SUITE_ROOT/default/.worktrees/repo/feat-login"
  new_repo "$repo"
  {
    printf '%s\n' 'node_modules/'
    printf '%s\n' '.venv/'
    printf '%s\n' 'target/'
  } > "$repo/.gitignore"
  command git -C "$repo" add .gitignore
  command git -C "$repo" commit -qm ignores
  command mkdir -p -- "$repo/node_modules" "$repo/.venv" "$repo/target"
  builtin cd -- "$repo"

  monkey feat/login > "$SUITE_ROOT/default/create.out" 2> "$SUITE_ROOT/default/create.err" || return
  assert_equal "$destination" "$PWD" 'Bash create did not enter the destination' || return
  assert_equal "created $destination" "$(<"$SUITE_ROOT/default/create.out")" 'Bash create output changed' || return
  assert_equal feat/login "$(command git branch --show-current)" 'Bash create branch changed' || return
  [[ ! -e node_modules && ! -e .venv && ! -e target ]] || return 1

  builtin cd -- "$repo"
  monkey feat/login > "$SUITE_ROOT/default/repeat.out" 2> "$SUITE_ROOT/default/repeat.err" || return
  assert_equal "$destination" "$PWD" 'Bash repeat did not enter the worktree' || return
  assert_equal "entered $destination" "$(<"$SUITE_ROOT/default/repeat.out")" 'Bash repeat output changed'
}

registered_worktree_uses_exact_path() {
  local repo="$SUITE_ROOT/registered/repo"
  local linked="$SUITE_ROOT/registered/manual linked"
  new_repo "$repo"
  command git -C "$repo" worktree add -q -b feat/registered "$linked"
  builtin cd -- "$repo"
  monkey feat/registered > "$SUITE_ROOT/registered/out" 2> "$SUITE_ROOT/registered/err" || return
  assert_equal "$linked" "$PWD" 'Bash did not enter the registered path'
}

unusual_primary_path_survives() {
  local unusual_name=$'space ünicode\nsource'
  local repo="$SUITE_ROOT/$unusual_name"
  new_repo "$repo"
  builtin cd -- "$repo"
  local destination="${repo%/*}/.worktrees/${repo##*/}/feat-unusual"
  monkey feat/unusual > "$SUITE_ROOT/unusual.out" 2> "$SUITE_ROOT/unusual.err" || return
  assert_equal "$destination" "$PWD" 'Bash changed an unusual primary path'
}

full_snapshot_create_and_repeat() {
  command -v rift >/dev/null 2>&1 || return 0
  local root="$SUITE_ROOT/rift"
  local repo="$root/repo"
  local destination="$root/.rifts/repo/feat-copy"
  command mkdir -p -- "$root"
  trap "cleanup_rift_test $(printf %q "$repo") $(printf %q "$root")" EXIT
  new_repo "$repo"
  printf '%s\n' 'node_modules/' > "$repo/.gitignore"
  command git -C "$repo" add .gitignore
  command git -C "$repo" commit -qm ignores
  command mkdir -p -- "$repo/node_modules/pkg"
  printf '%s\n' dependency > "$repo/node_modules/pkg/file.txt"
  printf '%s\n' dirty-in-source > "$repo/tracked.txt"
  printf '%s\n' untracked > "$repo/untracked.txt"
  local source_status
  source_status=$(command git -C "$repo" status --short)
  builtin cd -- "$repo"

  monkey -c feat/copy > "$root/create.out" 2> "$root/create.err" || return
  assert_equal "$destination" "$PWD" 'Bash copy did not enter the snapshot' || return
  assert_equal feat/copy "$(command git branch --show-current)" 'Bash copy branch changed' || return
  assert_equal dependency "$(<node_modules/pkg/file.txt)" 'Bash copy omitted ignored dependencies' || return
  assert_equal untracked "$(<untracked.txt)" 'Bash copy omitted untracked files' || return
  assert_equal "$source_status" "$(command git -C "$repo" status --short)" 'Bash copy changed source Git state' || return

  builtin cd -- "$repo"
  monkey -c feat/copy > "$root/repeat.out" 2> "$root/repeat.err" || return
  assert_equal "$destination" "$PWD" 'Bash copy retry did not enter the snapshot' || return
  assert_equal "entered $destination" "$(<"$root/repeat.out")" 'Bash copy retry output changed'
}

copy_mode_does_not_enter_normal_worktree() {
  command -v rift >/dev/null 2>&1 || return 0
  local root="$SUITE_ROOT/mode"
  local repo="$root/repo"
  local linked="$root/normal-worktree"
  local destination="$root/.rifts/repo/feat-same"
  command mkdir -p -- "$root"
  trap "builtin cd /tmp; command rift remove --children $(printf %q "$repo") >/dev/null 2>&1 || true; command rift remove -f $(printf %q "$repo") >/dev/null 2>&1 || true; command git -C $(printf %q "$repo") worktree remove --force $(printf %q "$linked") >/dev/null 2>&1 || true; command trash $(printf %q "$root") >/dev/null 2>&1 || true" EXIT
  new_repo "$repo"
  command git -C "$repo" worktree add -q -b feat/same "$linked"
  builtin cd -- "$repo"

  monkey -c feat/same > "$root/out" 2> "$root/err" || return
  assert_equal "$destination" "$PWD" 'Bash copy mode entered a normal worktree' || return
  assert_equal feat/same "$(command git branch --show-current)" 'Bash copy mode used the wrong branch'
}

installer_loads_fresh_bash() {
  printf '%s\n' 'export EXISTING_BASH=1' > "$HOME/.bashrc"
  printf '%s\n' 'export EXISTING_PROFILE=1' > "$HOME/.bash_profile"
  "$PROJECT_ROOT/scripts/install.zsh" || return
  "$PROJECT_ROOT/scripts/install.zsh" || return
  command cmp -s "$PROJECT_ROOT/shell/monkey.bash" "$XDG_CONFIG_HOME/monkey/monkey.bash" || return 1
  assert_equal 1 "$(command grep -Fc 'source "${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.bash"' "$HOME/.bashrc")" 'Bash rc source line duplicated' || return
  assert_equal 1 "$(command grep -Fc 'source "${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.bash"' "$HOME/.bash_profile")" 'Bash profile source line duplicated' || return
  HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" /bin/bash --noprofile --rcfile "$HOME/.bashrc" -i -c 'type monkey >/dev/null' >/dev/null 2>&1
}

copy_interrupt_returns_130_and_releases_lock() {
  command -v expect >/dev/null 2>&1 || return 0
  local root="$SUITE_ROOT/interrupt"
  local repo="$root/repo"
  local bin="$root/bin"
  local marker="$root/rift-started"
  local lock_file="$root/.rifts/repo/.monkey.lock"
  command mkdir -p -- "$bin"
  new_repo "$repo"
  {
    printf '%s\n' '#!/bin/bash'
    printf '%s\n' 'if [[ $1 == init ]]; then'
    printf '%s\n' '  printf "%s\n" test-rift > "$3/.rift"'
    printf '%s\n' '  : > "$MONKEY_RIFT_MARKER"'
    printf '%s\n' '  sleep 30'
    printf '%s\n' 'fi'
    printf '%s\n' 'exit 1'
  } > "$bin/rift"
  command chmod +x "$bin/rift"

  MONKEY_PROJECT_ROOT="$PROJECT_ROOT" \
    MONKEY_TEST_REPO="$repo" \
    MONKEY_RIFT_MARKER="$marker" \
    MONKEY_LOCK_FILE="$lock_file" \
    PATH="$bin:$PATH" \
    command expect -f "$PROJECT_ROOT/tests/bash-pty.exp" >/dev/null
}

run_test 'Bash creates and re-enters a Git worktree' default_create_and_repeat
run_test 'Bash enters a registered worktree at its exact path' registered_worktree_uses_exact_path
run_test 'Bash preserves spaces, Unicode, and newline paths' unusual_primary_path_survives
run_test 'Bash creates and re-enters a real Rift snapshot' full_snapshot_create_and_repeat
run_test 'Bash copy mode does not enter a normal worktree' copy_mode_does_not_enter_normal_worktree
run_test 'installer loads Monkey in a fresh interactive Bash' installer_loads_fresh_bash
run_test 'Bash copy interruption returns 130 and releases its lock' copy_interrupt_returns_130_and_releases_lock

printf '1..%s\n' "$TEST_COUNT"
(( TEST_FAILURES == 0 ))
