# monkey

Go from (work)tree to (work)tree.

Monkey is a shell function for opening one Git branch in its own directory.

- `monkey feat/login` opens a normal Git worktree.
- `monkey -c feat/login` copies the whole working tree with Rift first.

Monkey creates the destination when it is missing. Then it moves your current shell into that directory.

<p align="center">
  <img src="assets/monkey-demo.gif" alt="Monkey creates and enters a Git worktree, then creates a Rift snapshot." width="760">
</p>

## install

Run the installer:

```console
zsh scripts/install.zsh
```

The installer copies native Zsh and Bash functions to:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.zsh
${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.bash
```

It adds one source line to `${ZDOTDIR:-$HOME}/.zshrc`, `$HOME/.bashrc`, and `$HOME/.bash_profile`. Repeated installation does not add duplicate lines.

Start a fresh shell after installation:

```console
exec zsh
# or
exec bash
```

To try Monkey without installation, source the repository file:

```zsh
source shell/monkey.zsh
```

```bash
source shell/monkey.bash
```

Monkey must run as a sourced shell function because it changes the current shell directory.

Copy mode also requires Rift:

```console
npm install -g rift-snapshot
```

Rift is optional. Normal `monkey <branch>` usage needs only Git and your shell.

Monkey does not require Jujutsu. It uses Rift only when you choose `-c`.

## usage

Open a branch in a normal Git worktree:

```console
monkey feat/login
```

Monkey now handles the branch state for you:

- if the branch already has a worktree, Monkey enters that exact directory
- if the branch exists without a worktree, Monkey creates and enters its worktree
- if the branch is missing, Monkey creates it from your current `HEAD`

For a new worktree, `feat/login` becomes:

```text
/work/.worktrees/app/feat-login
```

The full path rule is:

```text
<primary-parent>/.worktrees/<repository>/<branch-slug>
```

After success, Monkey prints `entered <path>` or `created <path>`.

Monkey rejects invalid branch names and occupied destinations. It does not remove worktrees or copy ignored dependency directories.

For the complete runtime path, storage model, and failure rules, read [How Monkey works](docs/how-monkey-works.md).

## what happens inside

Monkey must run inside the current shell. A standalone program cannot change its parent shell directory.

For `monkey feat/login`, Monkey does this:

1. Git validates the branch name.
2. Monkey captures the current `HEAD` commit.
3. Git reports every registered worktree.
4. Monkey finds the worktree for `feat/login` or creates it.
5. The shell runs `cd` only after Git succeeds.

Monkey keeps no database. Git owns branches and normal worktrees. Rift owns full-copy snapshots.

The two modes save different things:

| Command | What appears in the new directory | What stays shared |
| --- | --- | --- |
| `monkey feat/login` | A clean checkout without ignored dependencies | Git objects |
| `monkey -c feat/login` | Tracked, dirty, untracked, and ignored files | Unchanged APFS data blocks |

A repeat call reads Git or Rift again. It enters the completed workspace instead of creating another one.

## Rift copy mode

[Rift](https://github.com/anomalyco/rift) is an experimental tool for making fast directory snapshots. Monkey uses it without duplicating every disk block immediately.

Run copy mode from the primary Git worktree:

```console
monkey -c feat/login
```

Monkey asks Rift to copy the complete repository with `--copy-all`. The snapshot includes ignored directories such as `node_modules`, `.venv`, and `target`.

The destination is:

```text
<primary-parent>/.rifts/<repository>/<branch-with-slashes-replaced-by-hyphens>
```

Rift uses APFS copy-on-write clones on macOS. The source and snapshot initially share physical data blocks. Changes remain isolated and allocate new blocks.

Copy-on-write means both directories initially point to the same unchanged data on disk. They are still separate directories.

When either side changes a file, APFS writes new blocks for that changed data. The other directory keeps its original data.

This makes a complete snapshot containing `node_modules` cheap at creation time. Disk usage grows as the two directories change.

<p align="center">
  <img src="assets/rift-copy-on-write.gif" alt="Rift creates a full snapshot that shares unchanged APFS blocks, then changed files receive new blocks." width="760">
</p>

Tools such as `du` may count the full logical size of both directories. That number does not show how many physical blocks remain shared.

Monkey disables Rift hooks to preserve the copied state. It attaches or creates the requested branch inside the copied Git repository.

Rift does not accept a linked Git worktree as a snapshot source. Enter the primary worktree before using `-c`.

If Rift or filesystem copy-on-write support is unavailable, Monkey stops without creating a snapshot. It does not fall back to a full byte copy.

## failures and recovery

Monkey leaves the current directory unchanged when an operation fails.

It preserves occupied destinations and stale registrations. Monkey reports the conflict instead of deleting files or guessing which state is correct.

Copy operations use `.rifts/<repository>/.monkey.lock`. Rift `0.0.10` cannot initialize one source safely from two processes.

| Status | Meaning |
| --- | --- |
| `0` | Monkey entered the workspace. |
| `2` | The command or branch name is invalid. |
| `75` | Another copy operation is active. Retry after it finishes. |
| `127` | Copy mode cannot find Rift or macOS `shlock`. |
| `130` | The user interrupted the operation. |

Other nonzero statuses come from Git, Rift, the filesystem, or an invalid workspace state.

## test

Run all test suites:

```console
zsh -f tests/monkey.zsh
zsh -f tests/pty.zsh
zsh -f tests/rift.zsh
/bin/bash tests/bash.bash
```

The first suite tests Git behavior in disposable repositories. The second suite tests interactive directory changes through `zsh/zpty`.

The Rift suite verifies full copies, isolated writes, retry, linked-worktree rejection, and collision safety against the installed Rift.

The Bash suite runs against the macOS system Bash `3.2` and verifies both workspace modes plus fresh-shell installation.

Monkey targets Zsh and Bash on macOS. Git worktrees remain the default. Jujutsu is not a dependency.
