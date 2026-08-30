# 🐒 monkey

Open a Git branch in its own workspace, then enter it.

> [!CAUTION]
> Monkey is highly experimental. Commands, paths, and recovery behavior can change.
>
> Use it only with repositories you can recover. Monkey does not remove or repair worktrees.
>
> A full snapshot is a working copy, not a backup. Keep the source repository until you finish.
>
> Copy mode includes ignored files. Review a snapshot before you share it.
>
> Inspect `.monkey/hooks` before `monkey hook install`. Git runs installed hooks on your machine.

<p align="center">
  <img src="assets/monkey-demo.gif" alt="Monkey creates and enters a Git worktree, then creates a full snapshot with Rift." width="760">
</p>

## install

Monkey requires macOS, Git, and Zsh or the system Bash `3.2`.

```console
git clone https://github.com/thoriqakbar0/monkey.git
cd monkey
zsh scripts/install.zsh
```

Start a new Zsh or Bash session after installation.

The installer adds one source line to `${ZDOTDIR:-$HOME}/.zshrc`, `$HOME/.bashrc`, and `$HOME/.bash_profile`.

It copies the shell functions to `${XDG_CONFIG_HOME:-$HOME/.config}/monkey/`.

Install Rift only for copy mode:

```console
npm install -g rift-snapshot
```

## use

```console
monkey feat/login
monkey -c feat/login
```

- `monkey <branch>` opens or creates a Git worktree.
- `monkey -c <branch>` copies tracked, dirty, untracked, and ignored files with Rift.
- Both commands enter the workspace in your current shell.
- If the branch is missing, Monkey creates it from the current `HEAD`.
- If an operation fails, Monkey keeps your current directory and preserves conflicting files.

Run copy mode from the primary worktree. Monkey stops if Rift or copy-on-write support is unavailable.

## hooks

```console
monkey hook install
monkey hook uninstall
```

`install` uses checked-in scripts from `.monkey/hooks`. Monkey preserves another hook manager's `core.hooksPath` value.

## test

```console
zsh -f tests/monkey.zsh
zsh -f tests/pty.zsh
zsh -f tests/rift.zsh
/bin/bash tests/bash.bash
```

## uninstall

Remove Monkey's source lines from `${ZDOTDIR:-$HOME}/.zshrc`, `$HOME/.bashrc`, and `$HOME/.bash_profile`.

Delete `monkey.zsh` and `monkey.bash` from `${XDG_CONFIG_HOME:-$HOME/.config}/monkey/`.

Read [How Monkey works](docs/how-monkey-works.md) for paths, storage, failures, and recovery.

Monkey uses the [MIT License](LICENSE).
