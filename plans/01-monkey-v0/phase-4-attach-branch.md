# Phase 4: attach existing branches

[Back to the overview](overview.md).

## Goal

Create a deterministic worktree when the branch exists but has no worktree.

## Changes

- Complete the attach resolution in `shell/monkey.zsh`.
- Create the `.worktrees/<repository>` parent only when creation starts.
- Preserve occupied destinations and stale registrations.
- Add existing-branch and conflict cases to both test files.

## Data structures

- `WorkspaceResolution.Attach` contains the branch and deterministic destination.

## Verification

Static:

```console
for file in shell/monkey.zsh tests/monkey.zsh tests/pty.zsh; do zsh -n "$file" || exit; done
```

Runtime:

```console
zsh -f tests/monkey.zsh attach-branch
zsh -f tests/pty.zsh attach-branch
```

Assert that errors preserve the original `PWD`, branch, destination, and files.
