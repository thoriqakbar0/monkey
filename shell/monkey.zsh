function monkey() {
  emulate -L zsh
  setopt localoptions no_shwordsplit

  local mode=worktree
  if (( $# == 2 )) && [[ $1 == '-c' ]]; then
    mode=copy
    shift
  elif (( $# != 1 )); then
    print -u2 -r -- "usage: monkey [-c] <name>"
    return 2
  fi

  local name=$1
  if ! command git check-ref-format --branch "$name" >/dev/null 2>&1; then
    print -u2 -r -- "monkey: invalid branch name: $name"
    return 2
  fi

  local base_commit
  base_commit=$(command git rev-parse --verify HEAD) || return $?

  local field record_path='' record_branch=''
  local -a worktree_paths worktree_branches
  while IFS= read -r -d '' field; do
    if [[ -z $field ]]; then
      if [[ -n $record_path ]]; then
        worktree_paths+=("$record_path")
        worktree_branches+=("$record_branch")
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

  if (( ${#worktree_paths} == 0 )); then
    print -u2 -r -- "monkey: git reported no worktrees"
    return 1
  fi

  local expected_branch="refs/heads/$name"
  local index
  if [[ $mode == worktree ]]; then
    for (( index = 1; index <= ${#worktree_paths}; index++ )); do
      if [[ ${worktree_branches[index]} == "$expected_branch" ]]; then
        local existing_path=${worktree_paths[index]}
        if ! builtin cd -- "$existing_path"; then
          print -u2 -r -- "monkey: registered worktree is unavailable: $existing_path"
          print -u2 -r -- "monkey: inspect it, then run 'git worktree prune' if the registration is stale"
          return 1
        fi
        print -r -- "entered $PWD"
        return 0
      fi
    done
  fi

  local primary_root=${worktree_paths[1]}
  local slug=${name//\//-}

  if [[ $mode == copy ]]; then
    if ! command -v rift >/dev/null 2>&1; then
      print -u2 -r -- "monkey: copy mode requires rift"
      print -u2 -r -- "monkey: install the rift-snapshot package, then retry"
      return 127
    fi
    if ! command -v shlock >/dev/null 2>&1; then
      print -u2 -r -- "monkey: copy mode requires the macOS shlock command"
      return 127
    fi

    local current_root git_dir git_common_dir
    current_root=$(command git rev-parse --show-toplevel) || return $?
    git_dir=$(command git rev-parse --path-format=absolute --git-dir) || return $?
    git_common_dir=$(command git rev-parse --path-format=absolute --git-common-dir) || return $?

    if [[ ${git_dir:A} != ${git_common_dir:A} ]]; then
      print -u2 -r -- "monkey: copy mode cannot snapshot a linked Git worktree"
      print -u2 -r -- "monkey: enter the primary worktree, then retry"
      return 1
    fi

    if [[ $current_root == *$'\n'* || $primary_root == *$'\n'* ]]; then
      print -u2 -r -- "monkey: copy mode does not support a source path containing a newline"
      return 2
    fi

    local destination_root="${primary_root:h}/.rifts/${primary_root:t}"
    local destination="$destination_root/$slug"
    local lock_file="$destination_root/.monkey.lock"
    local rift_output rift_status rift_children child
    local snapshot_registered=0 snapshot_created=0

    command mkdir -p -- "$destination_root" || return $?
    if ! command shlock -f "$lock_file" -p $$; then
      print -u2 -r -- "monkey: another copy operation is active for: $current_root"
      print -u2 -r -- "monkey: retry after it finishes"
      return 75
    fi

    setopt localtraps
    trap 'return 130' INT
    {
      if [[ ! -e $destination && ! -L $destination ]]; then
        rift_output=$(command rift init --here "$current_root" 2>&1)
        rift_status=$?
        if (( rift_status != 0 )); then
          print -u2 -r -- "monkey: rift could not initialize: $current_root"
          [[ -n $rift_output ]] && print -u2 -r -- "$rift_output"
          return "$rift_status"
        fi
      elif [[ ! -f "$current_root/.rift" ]]; then
        print -u2 -r -- "monkey: destination already exists: $destination"
        return 1
      fi

      rift_children=$(command rift list "$current_root" 2>&1)
      rift_status=$?
      if (( rift_status != 0 )); then
        print -u2 -r -- "monkey: rift could not inspect snapshots for: $current_root"
        [[ -n $rift_children ]] && print -u2 -r -- "$rift_children"
        return "$rift_status"
      fi

      for child in ${(f)rift_children}; do
        if [[ $child == "$destination" ]]; then
          snapshot_registered=1
          break
        fi
      done

      if (( snapshot_registered )); then
        if [[ ! -d $destination ]]; then
          print -u2 -r -- "monkey: registered snapshot is unavailable: $destination"
          return 1
        fi
      else
        if [[ -e $destination || -L $destination ]]; then
          print -u2 -r -- "monkey: destination already exists: $destination"
          return 1
        fi

        rift_output=$(command rift create "$current_root" --name "$slug" --into "$destination_root" --copy-all --no-hooks)
        rift_status=$?
        (( rift_status == 0 )) || return "$rift_status"
        if [[ $rift_output != "$destination" ]]; then
          print -u2 -r -- "monkey: rift created an unexpected path: $rift_output"
          return 1
        fi
        snapshot_created=1
      fi

      if (( snapshot_created )); then
        local snapshot_git_dir copied_worktrees saved_worktrees
        snapshot_git_dir=$(command git -C "$destination" rev-parse --path-format=absolute --git-dir) || return $?
        if [[ ${snapshot_git_dir:A} != ${destination:A}/.git ]]; then
          print -u2 -r -- "monkey: snapshot has an unexpected Git directory: $snapshot_git_dir"
          return 1
        fi
        copied_worktrees="$snapshot_git_dir/worktrees"
        saved_worktrees="$snapshot_git_dir/monkey-source-worktrees"
        if [[ -e $copied_worktrees || -L $copied_worktrees ]]; then
          if [[ -e $saved_worktrees || -L $saved_worktrees ]]; then
            print -u2 -r -- "monkey: snapshot Git metadata backup already exists: $saved_worktrees"
            return 1
          fi
          command mv -- "$copied_worktrees" "$saved_worktrees" || return $?
        fi
      fi

      local snapshot_branch branch_status
      snapshot_branch=$(command git -C "$destination" branch --show-current) || return $?
      if [[ -z $snapshot_branch ]]; then
        command git -C "$destination" show-ref --verify --quiet "$expected_branch"
        branch_status=$?
        if (( branch_status == 0 )); then
          command git -C "$destination" switch --quiet "$name" || return $?
        elif (( branch_status == 1 )); then
          command git -C "$destination" switch --quiet -c "$name" "$base_commit" || return $?
        else
          print -u2 -r -- "monkey: could not inspect snapshot branch: $name"
          return "$branch_status"
        fi
      elif [[ $snapshot_branch != "$name" ]]; then
        print -u2 -r -- "monkey: snapshot uses branch $snapshot_branch: $destination"
        return 1
      fi

      builtin cd -- "$destination" || return $?
      if (( snapshot_created )); then
        print -r -- "created $PWD"
      else
        print -r -- "entered $PWD"
      fi
      return 0
    } always {
      command rm -f -- "$lock_file" || true
    }
  fi

  local destination="${primary_root:h}/.worktrees/${primary_root:t}/$slug"

  for (( index = 1; index <= ${#worktree_paths}; index++ )); do
    if [[ ${worktree_paths[index]} == "$destination" ]]; then
      print -u2 -r -- "monkey: destination conflicts with a registered worktree: $destination"
      return 1
    fi
  done

  if [[ -e $destination || -L $destination ]]; then
    print -u2 -r -- "monkey: destination already exists: $destination"
    return 1
  fi

  local branch_status
  command git show-ref --verify --quiet "$expected_branch"
  branch_status=$?
  if (( branch_status == 0 )); then
    command git worktree add --quiet -- "$destination" "$name" || return $?
  elif (( branch_status == 1 )); then
    command git worktree add --quiet -b "$name" -- "$destination" "$base_commit" || return $?
  else
    print -u2 -r -- "monkey: could not inspect branch: $name"
    return "$branch_status"
  fi

  builtin cd -- "$destination" || return $?
  print -r -- "created $PWD"
}
