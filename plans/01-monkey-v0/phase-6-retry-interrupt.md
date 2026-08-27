# Phase 6: handle retry and interruption

[Back to the overview](overview.md).

## Goal

Make retries converge without Monkey-owned state or destructive recovery.

## Changes

- Attach an unclaimed branch left by an interrupted creation.
- Preserve stale registrations and unregistered occupied destinations.
- Keep Git's own locks authoritative during same-name races.
- Normalize Ctrl+C behavior without deleting partial state.
- Add race, retry, signal, disk, and lock cases to the tests.

## Data structures

- `WorkspaceResolution.Conflict` contains one reason and one preserved path or ref.

## Verification

Static:

```console
for file in shell/monkey.zsh tests/monkey.zsh tests/pty.zsh; do zsh -n "$file" || exit; done
```

Runtime:

```console
zsh -f tests/monkey.zsh retry-and-race
zsh -f tests/pty.zsh interrupt
```

One racing creator may fail. It must preserve the winner and its original `PWD`.
