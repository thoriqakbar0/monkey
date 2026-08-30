# Glossary

The vocabulary used across the Monkey product description.

## Repositories and workspaces

**Source repository.** The existing Git repository from which Monkey creates a workspace.

**Workspace.** A destination directory associated with the source Git repository and intended for isolated work. Monkey does not use this term for an unrelated copied directory.

**Workspace name.** The argument to `monkey <name>`. Version zero uses the exact name as the Git branch name.

**Git worktree.** A workspace created through Git's worktree mechanism. It has its own checked-out files and index, while Git shares repository object storage.

**Full snapshot.** A workspace created by `monkey -c <name>`. Rift copies tracked files, ignored files, and heavy dependency directories with copy-on-write storage.

**Rift.** An experimental snapshot tool used as Monkey's optional `-c` backend. Rift creates filesystem-level copy-on-write clones.

## Storage

**Logical copy.** The complete directory tree visible in a full snapshot. Tools that total file sizes may count both source and destination, even when the filesystem shares their physical blocks.

**Copy-on-write clone.** A filesystem copy whose source and destination initially share physical data blocks. A later write allocates private blocks for the changed data.

**Shared block.** Physical file data referenced by both the source and full snapshot before either copy changes it. Shared blocks do not mean that edits appear in both directories.

**Divergence.** The storage growth that occurs after either side changes cloned data. Unchanged data can remain shared while changed data consumes additional blocks.

**Heavy directory.** An ignored or generated directory whose contents can be expensive to recreate, such as `node_modules`, `.venv`, `target`, `dist`, `build`, or `coverage`.

## Repository hooks

**Git hook.** An executable script that Git runs for a named event, such as `pre-commit` or `pre-push`.

**Hook directory.** The checked-in `.monkey/hooks` directory selected through Git's `core.hooksPath` setting.

**Hook manager.** A tool that owns `core.hooksPath`. Monkey preserves another hook manager's value instead of replacing it.

## Invocations and endings

**Invocation.** One execution of Monkey, including argument validation, workspace creation, output, and exit.

**Complete.** The invocation reaches a defined result and exits with its documented exit code.

**Cancel.** The user asks Monkey to stop, normally with Ctrl+C.

**Interrupt.** Monkey stops because the shell, operating system, filesystem, another process, or a changed source prevents normal completion.

**Safe to interrupt.** An invocation phase where stopping Monkey leaves no partial destination or registry entry. The implementation and verification documents must define when this stops being true.
