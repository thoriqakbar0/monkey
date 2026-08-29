#!/bin/zsh

emulate -L zsh
setopt nounset pipefail

typeset -g SUITE_ROOT=$(command mktemp -d "${TMPDIR:-/tmp}/monkey-rift.XXXXXX")
SUITE_ROOT=${SUITE_ROOT:A}
typeset -gr SUITE_ROOT
typeset -gr PROJECT_ROOT=${0:A:h:h}

source "$PROJECT_ROOT/shell/monkey.zsh"
source "$PROJECT_ROOT/tests/helpers/repo.zsh"

if ! command -v rift >/dev/null 2>&1; then
  print -r -- 'ok 1 - real Rift integration # SKIP rift is not installed'
  print -r -- '1..1'
  exit 0
fi

function cleanup_rift_test() {
  local repo=$1 root=$2
  builtin cd /tmp
  command rift remove --children "$repo" >/dev/null 2>&1 || true
  command rift remove -f "$repo" >/dev/null 2>&1 || true
  command trash "$root" >/dev/null 2>&1 || true
}

function full_snapshot_create_and_repeat() {
  local root="$SUITE_ROOT/full"
  local repo="$root/repo"
  local destination="$root/.rifts/repo/feat-copy"
  command mkdir -p -- "$root"
  trap "cleanup_rift_test ${(q)repo} ${(q)root}" EXIT

  new_repo "$repo"
  {
    print -r -- 'node_modules/'
    print -r -- '.venv/'
    print -r -- 'target/'
  } > "$repo/.gitignore"
  command git -C "$repo" add .gitignore
  command git -C "$repo" commit -qm ignores
  command mkdir -p -- "$repo/node_modules/pkg" "$repo/.venv" "$repo/target"
  print -r -- dependency > "$repo/node_modules/pkg/file.txt"
  print -r -- virtualenv > "$repo/.venv/file.txt"
  print -r -- rust > "$repo/target/file.txt"
  print -r -- dirty-in-source > "$repo/tracked.txt"
  print -r -- untracked > "$repo/untracked.txt"
  local source_status=$(command git -C "$repo" status --short)
  builtin cd -- "$repo"

  monkey -c feat/copy > "$root/create.out" 2> "$root/create.err" || return
  assert_equal "$destination" "$PWD" 'copy mode did not enter its destination' || return
  assert_equal "created $destination" "$(<"$root/create.out")" 'copy output changed' || return
  assert_equal 'feat/copy' "$(command git branch --show-current)" 'copy branch changed' || return
  [[ -f node_modules/pkg/file.txt && -f .venv/file.txt && -f target/file.txt ]] || return 1
  assert_equal dirty-in-source "$(<tracked.txt)" 'copy omitted the dirty tracked file' || return
  assert_equal untracked "$(<untracked.txt)" 'copy omitted the untracked file' || return
  assert_equal "$source_status" "$(command git -C "$repo" status --short)" 'Rift initialization changed source Git state' || return

  print -r -- changed-in-copy > tracked.txt
  assert_equal dirty-in-source "$(<"$repo/tracked.txt")" 'copy write changed the source file' || return

  builtin cd -- "$repo"
  monkey -c feat/copy > "$root/repeat.out" 2> "$root/repeat.err" || return
  assert_equal "$destination" "$PWD" 'repeat did not enter the snapshot' || return
  assert_equal "entered $destination" "$(<"$root/repeat.out")" 'repeat output changed' || return
  assert_equal "$destination" "$(command rift list "$repo")" 'Rift did not register the snapshot'
}

function linked_worktree_is_rejected() {
  local root="$SUITE_ROOT/linked"
  local repo="$root/repo"
  local linked="$root/linked"
  command mkdir -p -- "$root"
  trap "builtin cd /tmp; command git -C ${(q)repo} worktree remove --force ${(q)linked} >/dev/null 2>&1 || true; command trash ${(q)root} >/dev/null 2>&1 || true" EXIT

  new_repo "$repo"
  command git -C "$repo" worktree add -q -b linked "$linked"
  builtin cd -- "$linked"
  local before=$PWD exit_code
  monkey -c linked/copy > "$root/out" 2> "$root/err"
  exit_code=$?
  (( exit_code != 0 )) || return 1
  assert_equal "$before" "$PWD" 'linked-worktree failure changed PWD' || return
  [[ ! -e "$linked/.rift" && ! -e "$root/.rifts" ]] || return 1
  assert_file_contains "$root/err" 'cannot snapshot a linked Git worktree'
}

function occupied_snapshot_destination_is_preserved() {
  local root="$SUITE_ROOT/occupied"
  local repo="$root/repo"
  local destination="$root/.rifts/repo/feat-collision"
  command mkdir -p -- "$root"
  trap "cleanup_rift_test ${(q)repo} ${(q)root}" EXIT

  new_repo "$repo"
  command mkdir -p -- "$destination"
  print -r -- keep > "$destination/unknown.txt"
  builtin cd -- "$repo"
  local before=$PWD exit_code
  monkey -c feat/collision > "$root/out" 2> "$root/err"
  exit_code=$?
  (( exit_code != 0 )) || return 1
  assert_equal "$before" "$PWD" 'snapshot collision changed PWD' || return
  assert_equal keep "$(<"$destination/unknown.txt")" 'snapshot collision changed unknown data' || return
  [[ ! -e "$repo/.rift" ]] || return 1
  assert_file_contains "$root/err" 'destination already exists'
}

function same_name_copy_race_converges() {
  local root="$SUITE_ROOT/race"
  local repo="$root/repo"
  local destination="$root/.rifts/repo/feat-race"
  local monkey_source="$PROJECT_ROOT/shell/monkey.zsh"
  command mkdir -p -- "$root"
  trap "cleanup_rift_test ${(q)repo} ${(q)root}" EXIT

  new_repo "$repo"
  command zsh -f -c 'source "$1"; cd "$2"; monkey -c feat/race' _ "$monkey_source" "$repo" > "$root/one.out" 2> "$root/one.err" &
  local first_pid=$!
  command zsh -f -c 'source "$1"; cd "$2"; monkey -c feat/race' _ "$monkey_source" "$repo" > "$root/two.out" 2> "$root/two.err" &
  local second_pid=$!
  wait $first_pid
  local first_status=$?
  wait $second_pid
  local second_status=$?

  (( first_status == 0 || first_status == 75 )) || return 1
  (( second_status == 0 || second_status == 75 )) || return 1
  (( first_status == 0 || second_status == 0 )) || return 1
  assert_equal "$destination" "$(command rift list "$repo")" 'copy race did not converge on one snapshot' || return
  [[ -f "$repo/.rift" && ! -e "$root/.rifts/repo/.monkey.lock" ]] || return 1

  builtin cd -- "$repo"
  monkey -c feat/race > "$root/retry.out" 2> "$root/retry.err" || return
  assert_equal "$destination" "$PWD" 'copy race retry did not enter the snapshot' || return
  assert_equal "entered $destination" "$(<"$root/retry.out")" 'copy race retry output changed'
}

function copy_mode_does_not_enter_normal_worktree() {
  local root="$SUITE_ROOT/mode"
  local repo="$root/repo"
  local linked="$root/normal-worktree"
  local destination="$root/.rifts/repo/feat-same"
  command mkdir -p -- "$root"
  trap "builtin cd /tmp; command rift remove --children ${(q)repo} >/dev/null 2>&1 || true; command rift remove -f ${(q)repo} >/dev/null 2>&1 || true; command git -C ${(q)repo} worktree remove --force ${(q)linked} >/dev/null 2>&1 || true; command trash ${(q)root} >/dev/null 2>&1 || true" EXIT

  new_repo "$repo"
  command git -C "$repo" worktree add -q -b feat/same "$linked"
  builtin cd -- "$repo"
  monkey -c feat/same > "$root/out" 2> "$root/err" || return

  assert_equal "$destination" "$PWD" 'copy mode entered a normal worktree' || return
  assert_equal feat/same "$(command git branch --show-current)" 'copy mode used the wrong branch' || return
  [[ -d "$destination/.git/monkey-source-worktrees" && -d $linked ]] || return 1
  assert_equal 1 "$(command git -C "$repo" worktree list --porcelain | command grep -c '^branch refs/heads/feat/same$')" 'copy mode changed source worktree metadata' || return
  assert_equal 1 "$(command git -C "$destination" worktree list --porcelain | command grep -c '^worktree ')" 'snapshot retained source worktree registrations'
}

run_test 'real Rift copy includes dependencies, isolates writes, and retries' full_snapshot_create_and_repeat
run_test 'copy mode rejects linked Git worktree sources' linked_worktree_is_rejected
run_test 'copy mode preserves an occupied destination' occupied_snapshot_destination_is_preserved
run_test 'same-name copy race converges without corrupting Rift state' same_name_copy_race_converges
run_test 'copy mode stays separate from a normal worktree on the same branch' copy_mode_does_not_enter_normal_worktree

print -r -- "1..$TEST_COUNT"
(( TEST_FAILURES == 0 ))
