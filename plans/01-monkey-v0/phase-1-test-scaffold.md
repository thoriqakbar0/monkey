# Phase 1: build the test scaffold

[Back to the overview](overview.md).

## Goal

Create disposable Git repositories and interactive Zsh sessions before runtime logic.

## Changes

- Add `tests/helpers/repo.zsh` for isolated repositories and exact Git configuration.
- Add `tests/monkey.zsh` for non-interactive command assertions.
- Add `tests/pty.zsh` with `zsh/zpty` for shell-directory assertions.

## Data structures

- `TestRepository` names the root, primary worktree, branch, and cleanup path.
- `ShellObservation` records stdout, stderr, status, `PWD`, branch, and worktree records.

## Verification

Static:

```console
for file in tests/helpers/repo.zsh tests/monkey.zsh tests/pty.zsh; do zsh -n "$file" || exit; done
```

Runtime:

```console
zsh -f tests/monkey.zsh --self-test
zsh -f tests/pty.zsh --self-test
```

Both commands must create separate repositories and leave the Monkey checkout unchanged.
