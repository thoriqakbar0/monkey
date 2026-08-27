typeset -gi TEST_COUNT=0
typeset -gi TEST_FAILURES=0

function test_ok() {
  (( TEST_COUNT += 1 ))
  print -r -- "ok $TEST_COUNT - $1"
}

function test_not_ok() {
  (( TEST_COUNT += 1 ))
  (( TEST_FAILURES += 1 ))
  print -u2 -r -- "not ok $TEST_COUNT - $1"
}

function run_test() {
  local label=$1
  shift
  if ( "$@" ); then
    test_ok "$label"
  else
    test_not_ok "$label"
  fi
}

function assert_equal() {
  local expected=$1 actual=$2 label=$3
  if [[ $actual != "$expected" ]]; then
    print -u2 -r -- "$label"
    print -u2 -r -- "expected: ${(qqq)expected}"
    print -u2 -r -- "actual:   ${(qqq)actual}"
    return 1
  fi
}

function assert_file_contains() {
  local file=$1 text=$2
  command grep -Fq -- "$text" "$file" || {
    print -u2 -r -- "missing ${(qqq)text} in $file"
    return 1
  }
}

function new_repo() {
  local repo_dir=$1
  command mkdir -p -- "$repo_dir"
  command git -C "$repo_dir" init -q -b main
  command git -C "$repo_dir" config user.name 'Monkey Test'
  command git -C "$repo_dir" config user.email 'monkey@example.test'
  print -r -- initial > "$repo_dir/tracked.txt"
  command git -C "$repo_dir" add tracked.txt
  command git -C "$repo_dir" commit -qm initial
}
