# Phase 2: model Git worktrees

[Back to the overview](overview.md).

## Goal

Derive one validated workspace resolution from Git and the current directory.

## Changes

- Add `shell/monkey.zsh` with argument validation and repository discovery.
- Parse `git worktree list --porcelain -z` without losing path characters.
- Derive the primary root, current `HEAD`, exact branch, slug, and destination.
- Add focused model cases to `tests/monkey.zsh`.

## Data structures

- `WorktreeRecord` contains a path, `HEAD`, branch, lock state, and prune state.
- `WorkspaceRequest` contains the exact branch and captured base commit.
- `WorkspaceResolution` is enter, attach, create, or conflict.

## Verification

Static:

```console
for file in shell/monkey.zsh tests/monkey.zsh; do zsh -n "$file" || exit; done
```

Runtime:

```console
zsh -f tests/monkey.zsh model
```

Cover spaces, newlines, slash branches, invalid refs, linked worktrees, and slug collisions.
