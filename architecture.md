# Monkey architecture

Monkey has one sourced function for Zsh and one for Bash. Git owns worktree facts. Rift owns copy-on-write snapshot facts.

## Caller usage

The user loads Monkey once:

```zsh
source "${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.zsh"
```

Bash loads its native function:

```bash
source "${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.bash"
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

Copy mode creates and enters a full snapshot:

```console
$ monkey -c feat/login
created /Users/thor/work/.rifts/project/feat-login
```

Any failure leaves the current shell directory unchanged.

## Product boundary

Only sourced shell code can change the current shell directory. A standalone process cannot provide the complete `monkey <name>` experience.

Monkey supports Zsh and the macOS system Bash `3.2`. The workspace name is also the exact Git branch name.

Git worktrees remain the default. `-c` creates a full snapshot through Rift. Jujutsu workspaces, a REPL, and agent protocols remain future modules.

Copy mode requires the primary Git worktree because Rift rejects linked Git worktree sources. It requires a copy-on-write filesystem and never falls back to a full byte copy.

## Data shape

Each shell function derives one request and one resolution. These concepts define the shared data even though shell code has no static types.

| Value | Rule |
| --- | --- |
| `name` | The exact user input after Git accepts it as a branch name. |
| `mode` | Default Git worktree creation or explicit Rift copy creation. |
| `branch` | The branch named by `name`, without a Monkey prefix. |
| `current_root` | The worktree containing the current directory. |
| `primary_root` | The primary worktree from `git worktree list --porcelain -z`. |
| `base_commit` | The current worktree's `HEAD`, captured once before creation. |
| `destination` | A `.worktrees` path for default mode or `.rifts` path for copy mode. |
| `worktrees` | Git's NUL-delimited worktree records. |
| `resolution` | Enter or create a workspace in the selected mode, or fail without changing `PWD`. |

The branch slug replaces `/` with `-`. A path collision fails without changing either path.

## Public signature

```text
monkey [-c] <name> -> changes PWD on success and returns a shell status
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

Git remains the source of truth for worktrees. Rift owns its source marker and snapshot registry. Monkey writes no separate durable registry.

Copy mode applies these rules:

1. Require Rift and a primary Git worktree source.
2. Acquire one process lock for Rift operations on that source.
3. Initialize the source as a Rift root when needed.
4. Enter an existing snapshot registered at the deterministic `.rifts` path.
5. Otherwise, run Rift with `--copy-all --no-hooks`.
6. Move copied source worktree records aside inside the snapshot's private `.git` directory.
7. Attach or create the requested branch inside the copied repository.
8. Enter the snapshot only after Git branch setup succeeds.

## Failure and retry

Git arbitrates branch and worktree races with its own locks. One same-name creator can succeed. A losing invocation returns nonzero and leaves its shell unchanged.

A retry re-reads Git state. It enters a completed worktree or attaches an existing unclaimed branch.

A copy retry reads Rift state. It enters the registered snapshot instead of copying it again.

Monkey serializes Rift operations with `shlock` because Rift `0.0.10` cannot initialize one source concurrently. A competing call returns status `75` and asks the user to retry.

Monkey preserves ambiguous directories and stale registrations. It reports the conflict and requires explicit Git recovery.

Ctrl+C returns `130` when Zsh receives the interrupt. Monkey never changes directory before backend and branch setup complete.

## Output contract

Successful interactive calls print one line to stdout:

```text
created <absolute-path>
entered <absolute-path>
```

Usage and state errors go to stderr. Invalid invocation uses status `2`. Missing copy dependencies use `127`, and an active copy lock uses `75`.

The command has no JSON mode. PTY tests own the human contract.

## Module map

```text
shell/monkey.zsh
  native Zsh monkey function

shell/monkey.bash
  native Bash monkey function

scripts/install.zsh
  installs both functions for one macOS user

tests/
  disposable Git repositories, shell integration checks, and real Rift checks
```

The runtime call path stays in one file. The installer and tests do not add runtime layers.

## Synthesis decision

Three designs were compared. A sourced shell function became the base because only the caller can change its current directory.

The selected design uses NUL-safe Git parsing and captures `HEAD` once. Explicit copy mode delegates filesystem cloning and snapshot registration to Rift.

The design rejects a compiled core, public JSON protocol, backend interface, registry, journal, and staging directory. One process lock contains a verified Rift race.

The [pnpm worktree workflow](https://github.com/pnpm/pnpm/blob/main/CONTRIBUTING.md#working-with-git-worktrees) supports using one name for the branch and command. [Rift shell integration](https://github.com/anomalyco/rift#shell-integration) confirms that the wrapper must own `cd`.

[aggit](https://github.com/AstraBert/aggit) stores agent objects and syncs them to S3. It does not manage Git worktrees, so version zero borrows no storage model from it.

## Tradeoffs accepted

- We maintain separate Zsh and Bash functions so both shells can change their own current directory.
- We accept explicit retry after a Git worktree creation race instead of adding a Git lock manager.
- We accept manual recovery for ambiguous Git state instead of guessing ownership.
- We accept Rift as an optional dependency only for explicit copy mode.
- We accept no machine protocol until a real second caller needs one.
- We accept a fixed destination rule until real use proves configuration necessary.

## Remaining risks

- The PTY suite verifies status `130` and unchanged `PWD`. It does not force every partial Git checkout state.
- Path slug collisions fail safely, but only the exact occupied path appears in the diagnostic.
- Git worktrees with detached `HEAD` cannot match a branch argument.
- Submodules, filters, and checkout hooks may change creation failure behavior.
- Rift CLI listing uses newline-delimited paths, so copy mode rejects source paths containing a newline.
- Rift snapshot creation can succeed before Git branch setup fails. A retry completes setup from detached `HEAD`.

## Next product step

Use both modes in daily work before adding Jujutsu or destination configuration.
