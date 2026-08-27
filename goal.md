# Goal: complete the Monkey product description

Work in `/Users/thor/work/monkey`. Read `README.md` and `glossary.md` before drafting. The README defines the current user-facing product boundary.

Read `architecture.md` before implementation planning. Follow `plans/01-monkey-v0/overview.md` for version-zero sequencing.

## Source of truth

The Monkey repository is the source for implemented behavior. The version-zero implementation is committed on `main`.

Run `tests/monkey.zsh` and `tests/pty.zsh` before changing a verified claim. `architecture.md` owns version-zero runtime boundaries.

For external behavior, inspect the exact installed Git, Jujutsu, and Rift versions. Prefer official documentation and direct local tests over assumptions.

## Writing rules

- Describe what the user sees, runs, and finds on disk.
- Use the eight-section template in `README.md` for every feature document.
- Keep the interrupt rows and cross-cutting order identical across feature documents.
- Use terms from `glossary.md`; define a missing term before using it.
- Use direct sentences and sentence-case headings.
- Put essential mechanisms only in `> Technical note:` blocks.
- Mark unsupported behavior as an open question.
- Never present planned behavior as implemented or verified.
- Link to the document that owns a rule instead of repeating it.

## Things already established

- The common command shape is `monkey <name>`.
- Version zero is a simple shell-friendly command, not a REPL.
- Every destination is Git-backed.
- Git worktree is the default creation mode.
- Default worktrees do not copy ignored dependency directories.
- Full snapshot is an explicit future mode backed by Rift.
- Full snapshot includes ignored files and heavy directories such as `node_modules`, `.venv`, and `target`.
- On macOS, a successful Rift copy-on-write clone on the same APFS filesystem initially shares physical data blocks.
- Source and snapshot remain separate paths; later writes allocate private blocks for changed data.
- Logical size tools may count both directory trees even while physical blocks remain shared.
- Cross-filesystem destinations cannot use APFS block sharing.
- Behavior when copy-on-write cloning is unavailable remains an open product decision.
- Jujutsu support is a future configurable module, not a version-zero requirement.
- REPL and agent integrations are future work.

## Order of work

1. Draft `foundations/invocation.md` and `foundations/workspace.md`.
2. Draft and verify `workspaces/create.md` as the pilot.
3. Draft `cross-cutting/storage.md`.
4. Draft `workspaces/full-snapshot.md` and verify it on APFS.
5. Run a consistency and link pass, then update the coverage table.

## Working rules

- Do not commit, push, or release unless Thoriq asks.
- Preserve unrelated and untracked files.
- Use disposable repositories for destructive verification.
- Record exact tool versions and the Monkey commit used for verification.
- Update the version-zero plan when adding a document.
- Move unresolved behavior to open questions and continue.
