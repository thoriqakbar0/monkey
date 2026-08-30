# Phase 9: activate repository hooks

[Back to the overview](overview.md).

## Goal

Activate checked-in Git hooks without adding a package manager or replacing another hook manager.

## Contract

`monkey hook install` requires a real `.monkey/hooks` directory. It sets local `core.hooksPath` to `.monkey/hooks`.

The install command is idempotent. It preserves `PWD` and refuses a different effective `core.hooksPath` value.

`monkey hook uninstall` removes only a local `.monkey/hooks` value. It preserves the scripts and every other value.

## Verification

Use a disposable repository for each case:

1. Reject a missing or symbolic-link hook directory.
2. Install the hook directory twice.
3. Commit a change and observe the executable `pre-commit` script.
4. Uninstall the hook directory twice.
5. Configure `.husky/_` and verify that Monkey preserves it.
6. Run the same contract through Zsh and Bash.

## Completion criterion

Both shell suites pass every hook case. The final diff preserves the existing workspace and copy-mode contracts.
