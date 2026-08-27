# Monkey version-zero architecture

Monkey version zero is one sourced Zsh function. Git owns every durable workspace fact. The current working tree implements this design.

## Caller usage

The user loads Monkey once:

```zsh
source "${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.zsh"
```

The same command enters an existing worktree or creates one:

```console
$ monkey feat/login
created /Users/thor/work/.worktrees/project/feat-login
$ pwd
/Users/thor/work/.worktrees/project/feat-login
```

A repeated call enters the registered worktree:

```console
$ monkey feat/login
entered /Users/thor/work/.worktrees/project/feat-login
```

Any failure leaves the current shell directory unchanged.

## Product boundary

Only sourced shell code can change the current shell directory. A standalone process cannot provide the complete `monkey <name>` experience.

Version zero supports Zsh on macOS. The workspace name is also the exact Git branch name. Monkey only enters registered worktrees.

Git worktree creation is the only backend. Rift snapshots, Jujutsu workspaces, a REPL, and agent protocols remain future modules.

## Data shape

The function derives one request and one resolution. These concepts define the data even though Zsh does not provide static types.

| Value | Rule |
| --- | --- |
| `name` | The exact user input after Git accepts it as a branch name. |
| `branch` | The branch named by `name`, without a Monkey prefix. |
| `current_root` | The worktree containing the current directory. |
| `primary_root` | The primary worktree from `git worktree list --porcelain -z`. |
| `base_commit` | The current worktree's `HEAD`, captured once before creation. |
| `destination` | `<primary-parent>/.worktrees/<primary-name>/<branch-slug>`. |
| `worktrees` | Git's NUL-delimited worktree records. |
| `resolution` | Enter an existing worktree, attach an existing branch, create a branch, or fail. |

The branch slug replaces `/` with `-`. A path collision fails without changing either path.

## Public signature

```text
monkey <name> -> changes PWD on success and returns a shell status
```

Version zero has no public internal API. The function calls Git directly.

## Resolution rules

Monkey applies these rules in order:

1. Validate one argument and the Git branch name.
2. Discover the current and primary worktrees.
3. Parse all registered worktrees with NUL framing.
4. Enter a worktree already using the exact branch.
5. Attach an existing unclaimed branch at the deterministic destination.
6. Create a missing branch from the captured `HEAD`.
7. Enter the destination only after Git succeeds.

Git remains the sole source of truth. Monkey writes no registry, journal, intent file, stage directory, or lock file.

## Failure and retry

Git arbitrates branch and worktree races with its own locks. One same-name creator can succeed. A losing invocation returns nonzero and leaves its shell unchanged.

A retry re-reads Git state. It enters a completed worktree or attaches an existing unclaimed branch.

Monkey preserves ambiguous directories and stale registrations. It reports the conflict and requires explicit Git recovery.

Ctrl+C returns `130` when Zsh receives the interrupt. Monkey never changes directory before Git completes.

## Output contract

Successful interactive calls print one line to stdout:

```text
created <absolute-path>
entered <absolute-path>
```

Usage and state errors go to stderr. Version zero uses status `2` for invalid invocation and nonzero Git statuses for Git failures.

The command has no JSON mode. PTY tests own the human contract.

## Module map

```text
shell/monkey.zsh
  monkey()
    validates input
    reads Git worktree state
    resolves enter or create
    changes the current Zsh directory

scripts/install.zsh
  installs the sourced file for one user

tests/
  disposable Git repositories and Zsh PTY checks
```

The runtime call path stays in one file. The installer and tests do not add runtime layers.

## Synthesis decision

Three designs were compared. The sourced Zsh design became the base.

The selected design takes two ideas from the larger candidates. It uses NUL-safe Git parsing and captures `HEAD` once.

The design rejects a compiled core, public JSON protocol, backend interface, registry, journal, staging directory, and custom lock.

The [pnpm worktree workflow](https://github.com/pnpm/pnpm/blob/main/CONTRIBUTING.md#working-with-git-worktrees) supports using one name for the branch and command. [Rift shell integration](https://github.com/anomalyco/rift#shell-integration) confirms that the wrapper must own `cd`.

[aggit](https://github.com/AstraBert/aggit) stores agent objects and syncs them to S3. It does not manage Git worktrees, so version zero borrows no storage model from it.

## Tradeoffs accepted

- We accept Zsh-only installation for the complete one-command experience.
- We accept explicit retry after a creation race instead of adding a lock manager.
- We accept manual recovery for ambiguous Git state instead of guessing ownership.
- We accept no machine protocol until a real second caller needs one.
- We accept a fixed destination rule until real use proves configuration necessary.

## Remaining risks

- The PTY suite verifies status `130` and unchanged `PWD`. It does not force every partial Git checkout state.
- Path slug collisions fail safely, but only the exact occupied path appears in the diagnostic.
- Git worktrees with detached `HEAD` cannot match a branch argument.
- Submodules, filters, and checkout hooks may change creation failure behavior.

## Next product step

Use version zero in daily work before adding another backend or configuration option.
