function monkey() {
  emulate -L zsh
  setopt localoptions no_shwordsplit

  if (( $# != 1 )); then
    print -u2 -r -- "usage: monkey <name>"
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

  local primary_root=${worktree_paths[1]}
  local slug=${name//\//-}
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
