# monkey

Monkey creates or enters a Git worktree from your current Zsh session.

```console
monkey feat/login
```

If `feat/login` already has a worktree, Monkey enters it. Otherwise, Monkey creates the branch and worktree, then enters it.

## install

Run the installer, then start a new Zsh session:

```console
zsh scripts/install.zsh
exec zsh
```

The installer copies the shell function to:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/monkey/monkey.zsh
```

It also adds one source line to `${ZDOTDIR:-$HOME}/.zshrc`. Repeated installation does not add duplicate lines.

To try Monkey without installation, source the repository file:

```zsh
source shell/monkey.zsh
```

Monkey must run as a sourced shell function because it changes the current shell directory.

## usage

Run Monkey inside a Git worktree:

```console
monkey <branch>
```

For a missing worktree, Monkey uses this destination:

```text
<primary-parent>/.worktrees/<repository>/<branch-with-slashes-replaced-by-hyphens>
```

Monkey handles three cases:

- a registered worktree exists, so Monkey enters its exact path
- a local branch exists without a worktree, so Monkey attaches it
- the branch is missing, so Monkey creates it from the current `HEAD`

After success, Monkey prints `entered <path>` or `created <path>`.

Monkey rejects invalid branch names and occupied destinations. It does not remove worktrees or copy ignored dependency directories.

## test

Run both test suites:

```console
zsh -f tests/monkey.zsh
zsh -f tests/pty.zsh
```

The first suite tests Git behavior in disposable repositories. The second suite tests interactive directory changes through `zsh/zpty`.

Version zero targets Zsh on macOS and uses Git worktrees only. Rift snapshots, Jujutsu workspaces, and a REPL remain future work.
