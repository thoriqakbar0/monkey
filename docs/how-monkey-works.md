# How Monkey works

Monkey turns a branch name into a workspace, then moves the current shell into it.

The default mode uses a Git worktree. Copy mode uses Rift to make a full copy-on-write snapshot.

```console
monkey feat/login
monkey -c feat/login
```

Both commands use `feat/login` as the exact Git branch name. The `/` becomes `-` only in the destination path.

## Why Monkey is a shell function

A normal executable runs in a child process. It can change its own directory, but it cannot change its parent shell directory.

Monkey therefore runs as a sourced Zsh or Bash function. Its final `cd` changes the shell where the user entered the command.

The installer puts the matching function under `${XDG_CONFIG_HOME:-$HOME/.config}/monkey/`. It then adds a source line to the shell startup files.

## Shared request path

Every call starts with the same checks:

1. Monkey accepts one branch name, with optional `-c` before it.
2. Git validates the branch name.
3. Monkey captures the current `HEAD` commit.
4. Git reports every registered worktree with NUL-delimited records.
5. Monkey finds the primary worktree and builds the destination path.

Capturing `HEAD` once gives creation a stable starting commit. A moving source branch cannot change that commit during the call.

Monkey changes `PWD` only after workspace creation and branch setup succeed.

## Default Git worktree flow

`monkey <branch>` treats Git as the source of truth.

| Git state | Monkey action |
| --- | --- |
| The branch already has a registered worktree | Enter its registered path. |
| The branch exists without a worktree | Add a worktree for that branch, then enter it. |
| The branch does not exist | Create it from the captured `HEAD`, add its worktree, then enter it. |

New worktrees use this path:

```text
<primary-parent>/.worktrees/<repository>/<branch-slug>
```

For example, `/work/app` and `feat/login` produce `/work/.worktrees/app/feat-login`.

Git worktrees share the repository object database. Each worktree keeps its own checked-out files and index.

Ignored directories are not copied. A new worktree must install or build dependencies when it needs them.

## Copy-on-write flow

`monkey -c <branch>` asks Rift for a full snapshot of the primary worktree.

The snapshot includes tracked changes, untracked files, ignored files, and heavy directories such as `node_modules`, `.venv`, and `target`.

New snapshots use this path:

```text
<primary-parent>/.rifts/<repository>/<branch-slug>
```

The creation path is:

1. Monkey requires `rift`, macOS `shlock`, and the primary Git worktree.
2. Monkey acquires `.rifts/<repository>/.monkey.lock` for that source.
3. Rift initializes the source when it has no `.rift` marker.
4. Rift creates the snapshot with `--copy-all --no-hooks`.
5. Monkey isolates copied linked-worktree records inside the snapshot.
6. Git attaches or creates the requested branch in the copied repository.
7. Monkey enters the completed snapshot and releases the lock.

Rift uses APFS clones on supported macOS filesystems. The two paths initially share physical data blocks.

A write changes only one path. The filesystem allocates new blocks for changed data while unchanged data can remain shared.

Logical size tools can count both directory trees. That does not prove that APFS stored two physical copies.

Monkey does not fall back to a byte-for-byte copy. It stops when Rift or copy-on-write support is unavailable.

## State and ownership

Monkey has no workspace database.

| State | Owner |
| --- | --- |
| Branches and normal worktree registrations | Git |
| Snapshot source marker and snapshot registrations | Rift |
| Copy-operation lock | Monkey, through `shlock` |
| Current directory | The calling shell |

The Zsh and Bash implementations use the same paths and visible behavior. Each shell has native code so it can change its own directory.

## Retry and interruption

A repeated default call re-reads Git. It enters the completed worktree or finishes attaching an unclaimed branch.

A repeated copy call re-reads Rift. It enters the registered snapshot instead of copying it again.

Git handles normal worktree creation races. Monkey adds a copy lock because Rift `0.0.10` cannot initialize one source safely from two processes.

A competing copy call returns status `75` and asks the user to retry. Ctrl+C returns `130` and releases the copy lock.

Monkey preserves ambiguous paths, stale registrations, and partial backend state. It reports the conflict instead of deleting or repairing data automatically.

## Output and failures

A successful call prints one line:

```text
created <absolute-path>
entered <absolute-path>
```

Errors go to stderr. The main status codes are:

| Status | Meaning |
| --- | --- |
| `0` | Monkey entered the workspace. |
| `1` or backend status | Git, Rift, or workspace state prevented completion. |
| `2` | The invocation or branch name is invalid. |
| `75` | Another copy operation holds the source lock. |
| `127` | Copy mode is missing Rift or `shlock`. |
| `130` | The user interrupted the operation. |

On failure, Monkey leaves `PWD` unchanged. It never removes a worktree or snapshot.

## Current boundaries

Monkey currently supports Zsh and macOS Bash `3.2`.

Copy mode must start in the primary worktree. Rift rejects linked Git worktrees as snapshot sources.

Copy mode rejects a source path containing a newline because Rift lists snapshots with newline-delimited paths.

Jujutsu workspaces, configurable destinations, a REPL, and agent protocols remain future modules.

## Verification

The disposable Git suites verify branch creation, worktree entry, collisions, retries, interrupts, and unusual paths.

The real Rift suite verifies complete snapshots, isolated writes, repeated entry, locking, and linked-worktree rejection.

The Bash and PTY suites verify that Monkey changes the calling shell directory. See the [test commands](../README.md#test) and the [runtime matrix](../plans/01-monkey-v0/testing.md).
