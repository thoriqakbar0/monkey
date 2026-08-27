# Phase 8: verify and document the command

[Back to the overview](overview.md).

## Goal

Prove the complete command on interactive Zsh and align every product document.

## Changes

- Update `README.md` with installation, usage, outputs, limits, and verified behavior.
- Update product documents only where runtime evidence resolves planned claims.
- Add the final matrix cases from `testing.md`.

## Data structures

- `VerificationResult` records the case, tool versions, command, result, and evidence path.

## Verification

Static:

```console
for file in shell/monkey.zsh scripts/install.zsh tests/monkey.zsh tests/pty.zsh; do zsh -n "$file" || exit; done
git diff --check
python3 /Users/thor/.codex/skills/product-description/references/check-links.py .
```

Runtime:

```console
zsh -f tests/monkey.zsh
zsh -f tests/pty.zsh
```

Run one manual installed-shell pass after the automated PTY checks pass.
