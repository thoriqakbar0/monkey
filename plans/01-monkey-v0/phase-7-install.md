# Phase 7: install the shell function

[Back to the overview](overview.md).

## Goal

Install Monkey for one user's future Zsh sessions without duplicate shell configuration.

## Changes

- Add `scripts/install.zsh` with an explicit user-level destination.
- Install `shell/monkey.zsh` under the user's configuration directory.
- Add one idempotent source line to the selected Zsh startup file.
- Test installation with temporary `HOME` and `ZDOTDIR` values.

## Data structures

- `InstallPlan` contains the source file, installed file, startup file, and source line.

## Verification

Static:

```console
for file in scripts/install.zsh shell/monkey.zsh; do zsh -n "$file" || exit; done
```

Runtime:

```console
zsh -f tests/monkey.zsh install
```

Run installation twice. The second run must leave one source line and the same installed file.
