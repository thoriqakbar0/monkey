# Monkey version-zero testing

[Back to the overview](overview.md).

## Static checks

Run syntax checks for every Zsh and Bash file. Run `git diff --check` and the product-description link checker.

## Runtime matrix

Every case records stdout, stderr, status, final `PWD`, branch, and `git worktree list --porcelain -z`.

| Case | Required result |
| --- | --- |
| Invalid argument count | Status `2`; no Git or directory change. |
| Invalid branch | Status `2`; no destination created. |
| Outside Git | Nonzero status; original `PWD` remains. |
| Existing worktree | Enter its registered path without mutation. |
| Existing unclaimed branch | Create and enter the deterministic destination. |
| Missing branch | Create from the captured source `HEAD`. |
| Repeated call | Enter the same registered worktree. |
| Occupied destination | Preserve the path and report a conflict. |
| Stale registration | Preserve state and name the explicit Git recovery step. |
| Same-name race | At most one creator mutates Git; the loser preserves `PWD`. |
| Ctrl+C | Status `130`; no automatic deletion. |
| Source branch moves | New branch still starts at the captured commit. |
| Ignored dependencies | `node_modules`, `.venv`, and `target` remain absent. |
| Spaces and Unicode | Enter the exact canonical path. |
| Newline in source path | NUL-delimited parsing preserves the path. |
| Installer rerun | One installed file and one startup source line remain. |
| Installed Zsh session | `.zshrc` loads Monkey, then Monkey creates and enters a worktree. |
| Full snapshot | Rift copies ignored dependencies, creates the requested branch, and changes `PWD`. |
| Snapshot write | A write in the snapshot does not change the source file. |
| Repeated copy | Enter the registered Rift snapshot without copying again. |
| Linked source | Reject a linked Git worktree before Rift initialization. |
| Snapshot collision | Preserve an occupied destination and the source repository. |
| Snapshot race | One operation creates the snapshot; every retry converges on the registered path. |
| Snapshot Ctrl+C | Status `130`; preserve `PWD` and release the process lock. |
| Same branch in both modes | Copy mode enters the snapshot and preserves the normal worktree registration. |
| Bash current shell | Both workspace modes change the calling Bash process directory. |
| Bash startup | `.bashrc` and `.bash_profile` load the installed native function once. |
| Hook install | Set local `core.hooksPath` to `.monkey/hooks` and preserve `PWD`. |
| Hook execution | A real Git commit runs the matching executable script. |
| Hook reinstall | Keep the same local value and report success. |
| Hook conflict | Preserve another hook manager's effective value. |
| Hook uninstall | Unset only Monkey's local value and preserve all scripts. |

## Real surface

Use `zsh/zpty` for automated interactive checks. It verifies that `builtin cd` changes the same shell process.

After automation passes, run one installed Zsh session manually. Create, leave, and re-enter one disposable worktree.

## Failure policy

An inconclusive PTY observation is not a pass. Preserve the repository and capture the exact command output.

Do not test automatic deletion. Version zero performs no removal or garbage collection.
