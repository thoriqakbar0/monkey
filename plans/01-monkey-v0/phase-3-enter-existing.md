# Phase 3: enter registered worktrees

[Back to the overview](overview.md).

## Goal

Make `monkey <name>` enter any registered worktree using that exact branch.

## Changes

- Complete the enter resolution in `shell/monkey.zsh`.
- Verify the selected path still belongs to the same common Git repository.
- Print `entered <absolute-path>` only after `builtin cd` succeeds.
- Add entry and failure cases to `tests/pty.zsh`.

## Data structures

- `WorkspaceResolution.Enter` contains one canonical registered worktree path.

## Verification

Static:

```console
for file in shell/monkey.zsh tests/pty.zsh; do zsh -n "$file" || exit; done
```

Runtime:

```console
zsh -f tests/pty.zsh enter-existing
```

Assert stdout, stderr, status, `PWD`, branch, and unchanged Git metadata.
