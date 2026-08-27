# Phase 5: create new branches

[Back to the overview](overview.md).

## Goal

Create a new branch and worktree from the invocation's captured `HEAD`.

## Changes

- Complete the create resolution in `shell/monkey.zsh`.
- Pass the captured commit explicitly to `git worktree add`.
- Print `created <absolute-path>` after creation and `cd` succeed.
- Add source-change and ignored-directory cases to the tests.

## Data structures

- `WorkspaceResolution.Create` contains the branch, base commit, and destination.

## Verification

Static:

```console
for file in shell/monkey.zsh tests/monkey.zsh tests/pty.zsh; do zsh -n "$file" || exit; done
```

Runtime:

```console
zsh -f tests/monkey.zsh create-branch
zsh -f tests/pty.zsh create-branch
```

Confirm that ignored `node_modules`, `.venv`, and `target` directories remain absent.
