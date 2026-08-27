# Monkey version-zero plan

## Status

The current working tree implements all eight phases. The repository and PTY suites are the completion evidence.

## Context

Monkey removes the repeated branch, path, worktree, and `cd` steps from local work. The first release needs one reliable command.

The architecture uses a sourced Zsh function. Git remains the workspace database.

## Scope

This plan includes:

- Entering an existing worktree by its exact branch.
- Creating a worktree for an existing branch.
- Creating a worktree and branch from the current `HEAD`.
- Deterministic sibling storage under `.worktrees`.
- Safe failure, retry, interruption, and same-name races.
- User-level Zsh installation.
- Disposable repository and PTY verification.

This plan excludes:

- Rift snapshot creation.
- Jujutsu workspace creation.
- REPL, daemon, JSON, MCP, and agent protocols.
- Worktree removal, garbage collection, or automatic repair.
- Bash, Fish, Nushell, Linux, and Windows support.
- Arbitrary destination paths or a Monkey registry.
- aggit object storage and remote sync.

## Constraints

- `monkey <name>` must change the current Zsh directory.
- Git `2.55` behavior is the current reference.
- Git worktree records are the only durable workspace state.
- Monkey preserves unknown files and ambiguous Git state.
- The first release adds no runtime dependency or package manager.
- Every user-visible claim needs a disposable-repository or PTY check.

## Alternatives

| Design | Decision | Reason |
| --- | --- | --- |
| One sourced Zsh function | Chosen | It provides `cd` and adds no second runtime or state store. |
| Typed executable with a Zsh wrapper | Rejected | It adds a binary, protocol, and recovery state before evidence requires them. |
| JSON command for shells and agents | Rejected | It publishes future contracts and complicates the human path. |

## Applicable skills

The implementer must use these skills:

- `poteto-mode` for the execution and review standard.
- `how` before changing an unfamiliar Git or Zsh boundary.
- `coding-standards` if typed code enters the design.
- `unslop` and `technical-writing` for documentation.
- `writing-for-agents` for `README.md` and `goal.md` changes.
- `interrogate` if implementation evidence contests this architecture.

## Throughput checkpoint

- **Blocking first steps.** Build the disposable repository and PTY harness first.
- **Independent workstreams.** Documentation can follow verified command behavior. Runtime phases share one file and remain sequential.
- **Shared mutable state.** Each test owns a separate temporary repository and shell.
- **Smallest safe decomposition.** One implementation owner protects the single runtime file and its ordered invariants.

## Phases

1. [Build the test scaffold](phase-1-test-scaffold.md).
2. [Model Git worktrees](phase-2-worktree-model.md).
3. [Enter registered worktrees](phase-3-enter-existing.md).
4. [Attach existing branches](phase-4-attach-branch.md).
5. [Create new branches](phase-5-create-branch.md).
6. [Handle retry and interruption](phase-6-retry-interrupt.md).
7. [Install the shell function](phase-7-install.md).
8. [Verify and document the command](phase-8-acceptance.md).

## Verification

Run these project-level checks:

```console
for file in shell/monkey.zsh scripts/install.zsh; do zsh -n "$file" || exit; done
zsh -f tests/monkey.zsh
zsh -f tests/pty.zsh
git diff --check
python3 /Users/thor/.codex/skills/product-description/references/check-links.py .
```

Read [testing.md](testing.md) for the complete behavior matrix.

## Implementation guidance

Use `how` before changing unfamiliar Git porcelain parsing or Zsh PTY behavior.

Keep the runtime in one file. Split only when a second owner removes real branching or duplicated rules.

Run a focused cleanup pass before each commit. Apply `unslop` to every prose change.

Use `show-me-your-work` if implementation spans sessions or needs an auditable decision trail.

Use `interrogate` if tests disprove the branch, path, race, or interruption model.

After opening a pull request, monitor checks and review feedback. Opening or merging requires explicit authority.

## Delivery shape

Each phase must pass its listed checks before the next phase starts. Keep commits in phase order.

Do not commit, push, or open a pull request unless Thoriq asks.
