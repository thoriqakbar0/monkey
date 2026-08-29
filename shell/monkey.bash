monkey() {
  local mode=worktree
  if (( $# == 2 )) && [[ $1 == '-c' ]]; then
    mode=copy
    shift
  elif (( $# != 1 )); then
    printf '%s\n' 'usage: monkey [-c] <name>' >&2
    return 2
  fi

  local name=$1
  if ! command git check-ref-format --branch "$name" >/dev/null 2>&1; then
    printf 'monkey: invalid branch name: %s\n' "$name" >&2
    return 2
  fi

  local base_commit
  base_commit=$(command git rev-parse --verify HEAD) || return $?

  local field record_path='' record_branch=''
  local -a worktree_paths=() worktree_branches=()
  while IFS= read -r -d '' field; do
    if [[ -z $field ]]; then
      if [[ -n $record_path ]]; then
        worktree_paths[${#worktree_paths[@]}]=$record_path
        worktree_branches[${#worktree_branches[@]}]=$record_branch
      fi
      record_path=''
      record_branch=''
      continue
    fi

    if [[ $field == 'worktree '* ]]; then
      record_path=${field#worktree }
    elif [[ $field == 'branch '* ]]; then
      record_branch=${field#branch }
    fi
  done < <(command git worktree list --porcelain -z)

  if (( ${#worktree_paths[@]} == 0 )); then
    printf '%s\n' 'monkey: git reported no worktrees' >&2
    return 1
  fi

  local expected_branch="refs/heads/$name"
  local index
  if [[ $mode == worktree ]]; then
    for (( index = 0; index < ${#worktree_paths[@]}; index++ )); do
      if [[ ${worktree_branches[$index]} == "$expected_branch" ]]; then
        local existing_path=${worktree_paths[$index]}
        if ! builtin cd -- "$existing_path"; then
          printf 'monkey: registered worktree is unavailable: %s\n' "$existing_path" >&2
          printf "%s\n" "monkey: inspect it, then run 'git worktree prune' if the registration is stale" >&2
          return 1
        fi
        printf 'entered %s\n' "$PWD"
        return 0
      fi
    done
  fi

  local primary_root=${worktree_paths[0]}
  local slug=${name//\//-}

  if [[ $mode == copy ]]; then
    if ! command -v rift >/dev/null 2>&1; then
      printf '%s\n' 'monkey: copy mode requires rift' >&2
      printf '%s\n' 'monkey: install the rift-snapshot package, then retry' >&2
      return 127
    fi
    if ! command -v shlock >/dev/null 2>&1; then
      printf '%s\n' 'monkey: copy mode requires the macOS shlock command' >&2
      return 127
    fi

    local current_root git_dir git_common_dir
    current_root=$(command git rev-parse --show-toplevel) || return $?
    git_dir=$(command git rev-parse --path-format=absolute --git-dir) || return $?
    git_common_dir=$(command git rev-parse --path-format=absolute --git-common-dir) || return $?

    if [[ $git_dir != "$git_common_dir" ]]; then
      printf '%s\n' 'monkey: copy mode cannot snapshot a linked Git worktree' >&2
      printf '%s\n' 'monkey: enter the primary worktree, then retry' >&2
      return 1
    fi

    if [[ $current_root == *$'\n'* || $primary_root == *$'\n'* ]]; then
      printf '%s\n' 'monkey: copy mode does not support a source path containing a newline' >&2
      return 2
    fi

    local primary_parent=${primary_root%/*}
    local primary_name=${primary_root##*/}
    [[ -n $primary_parent ]] || primary_parent=/
    local destination_root="$primary_parent/.rifts/$primary_name"
    local destination="$destination_root/$slug"
    local lock_file="$destination_root/.monkey.lock"
    local rift_output rift_status rift_children child
    local snapshot_registered=0 snapshot_created=0 copy_status=0 copy_interrupted=0

    command mkdir -p -- "$destination_root" || return $?
    if ! command shlock -f "$lock_file" -p $$; then
      printf 'monkey: another copy operation is active for: %s\n' "$current_root" >&2
      printf '%s\n' 'monkey: retry after it finishes' >&2
      return 75
    fi

    local previous_int_trap
    previous_int_trap=$(trap -p INT)
    trap 'copy_interrupted=1' INT

    while :; do
      if [[ ! -e $destination && ! -L $destination ]]; then
        rift_output=$(command rift init --here "$current_root" 2>&1)
        rift_status=$?
        if (( rift_status != 0 )); then
          if (( ! copy_interrupted )); then
            printf 'monkey: rift could not initialize: %s\n' "$current_root" >&2
            [[ -z $rift_output ]] || printf '%s\n' "$rift_output" >&2
          fi
          copy_status=$rift_status
          break
        fi
      elif [[ ! -f $current_root/.rift ]]; then
        printf 'monkey: destination already exists: %s\n' "$destination" >&2
        copy_status=1
        break
      fi

      rift_children=$(command rift list "$current_root" 2>&1)
      rift_status=$?
      if (( rift_status != 0 )); then
        if (( ! copy_interrupted )); then
          printf 'monkey: rift could not inspect snapshots for: %s\n' "$current_root" >&2
          [[ -z $rift_children ]] || printf '%s\n' "$rift_children" >&2
        fi
        copy_status=$rift_status
        break
      fi

      while IFS= read -r child; do
        if [[ $child == "$destination" ]]; then
          snapshot_registered=1
          break
        fi
      done <<< "$rift_children"

      if (( snapshot_registered )); then
        if [[ ! -d $destination ]]; then
          printf 'monkey: registered snapshot is unavailable: %s\n' "$destination" >&2
          copy_status=1
          break
        fi
      else
        if [[ -e $destination || -L $destination ]]; then
          printf 'monkey: destination already exists: %s\n' "$destination" >&2
          copy_status=1
          break
        fi

        rift_output=$(command rift create "$current_root" --name "$slug" --into "$destination_root" --copy-all --no-hooks)
        rift_status=$?
        if (( rift_status != 0 )); then
          copy_status=$rift_status
          break
        fi
        if [[ $rift_output != "$destination" ]]; then
          printf 'monkey: rift created an unexpected path: %s\n' "$rift_output" >&2
          copy_status=1
          break
        fi
        snapshot_created=1
      fi

      if (( snapshot_created )); then
        local snapshot_git_dir copied_worktrees saved_worktrees
        snapshot_git_dir=$(command git -C "$destination" rev-parse --path-format=absolute --git-dir) || {
          copy_status=$?
          break
        }
        if [[ $snapshot_git_dir != "$destination/.git" ]]; then
          printf 'monkey: snapshot has an unexpected Git directory: %s\n' "$snapshot_git_dir" >&2
          copy_status=1
          break
        fi
        copied_worktrees="$snapshot_git_dir/worktrees"
        saved_worktrees="$snapshot_git_dir/monkey-source-worktrees"
        if [[ -e $copied_worktrees || -L $copied_worktrees ]]; then
          if [[ -e $saved_worktrees || -L $saved_worktrees ]]; then
            printf 'monkey: snapshot Git metadata backup already exists: %s\n' "$saved_worktrees" >&2
            copy_status=1
            break
          fi
          command mv -- "$copied_worktrees" "$saved_worktrees" || {
            copy_status=$?
            break
          }
        fi
      fi

      local snapshot_branch branch_status
      snapshot_branch=$(command git -C "$destination" branch --show-current) || {
        copy_status=$?
        break
      }
      if [[ -z $snapshot_branch ]]; then
        if command git -C "$destination" show-ref --verify --quiet "$expected_branch"; then
          branch_status=0
        else
          branch_status=$?
        fi
        if (( branch_status == 0 )); then
          command git -C "$destination" switch --quiet "$name" || {
            copy_status=$?
            break
          }
        elif (( branch_status == 1 )); then
          command git -C "$destination" switch --quiet -c "$name" "$base_commit" || {
            copy_status=$?
            break
          }
        else
          printf 'monkey: could not inspect snapshot branch: %s\n' "$name" >&2
          copy_status=$branch_status
          break
        fi
      elif [[ $snapshot_branch != "$name" ]]; then
        printf 'monkey: snapshot uses branch %s: %s\n' "$snapshot_branch" "$destination" >&2
        copy_status=1
        break
      fi

      break
    done

    command rm -f -- "$lock_file" || true
    if [[ -n $previous_int_trap ]]; then
      eval "$previous_int_trap"
    else
      trap - INT
    fi

    (( copy_interrupted )) && return 130
    (( copy_status == 0 )) || return "$copy_status"
    builtin cd -- "$destination" || return $?
    if (( snapshot_created )); then
      printf 'created %s\n' "$PWD"
    else
      printf 'entered %s\n' "$PWD"
    fi
    return 0
  fi

  local primary_parent=${primary_root%/*}
  local primary_name=${primary_root##*/}
  [[ -n $primary_parent ]] || primary_parent=/
  local destination="$primary_parent/.worktrees/$primary_name/$slug"

  for (( index = 0; index < ${#worktree_paths[@]}; index++ )); do
    if [[ ${worktree_paths[$index]} == "$destination" ]]; then
      printf 'monkey: destination conflicts with a registered worktree: %s\n' "$destination" >&2
      return 1
    fi
  done

  if [[ -e $destination || -L $destination ]]; then
    printf 'monkey: destination already exists: %s\n' "$destination" >&2
    return 1
  fi

  local branch_status
  if command git show-ref --verify --quiet "$expected_branch"; then
    branch_status=0
  else
    branch_status=$?
  fi
  if (( branch_status == 0 )); then
    command git worktree add --quiet -- "$destination" "$name" || return $?
  elif (( branch_status == 1 )); then
    command git worktree add --quiet -b "$name" -- "$destination" "$base_commit" || return $?
  else
    printf 'monkey: could not inspect branch: %s\n' "$name" >&2
    return "$branch_status"
  fi

  builtin cd -- "$destination" || return $?
  printf 'created %s\n' "$PWD"
}
