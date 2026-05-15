# Install Prerequisites Requirements

## Scope

Applies to `01_install_prerequisites.sh`.

R001 Statement: Run prerequisites installer in strict mode from repository root.
Design: Use `umask 007`, `set -euo pipefail`, and `cd` to script directory before any checks.
Tests:
- Run from non-repo cwd and verify prerequisite checks still execute against script-root relative paths.

R005 Statement: Fail fast when Homebrew is missing.
Design: Validate `brew` command at startup and print explicit Homebrew installation guidance before exit.
Tests:
- Run with `brew` absent from PATH and verify non-zero exit with Homebrew guidance output.

R010 Statement: Keep 1psa source dependency present and current.
Design: Clone `../1psa` when missing and run `git -C ../1psa pull --ff-only` when repository already exists.
Tests:
- Verify script invokes `git clone` when `../1psa/.git` is absent.
- Verify script invokes `git -C ../1psa pull --ff-only` when `../1psa/.git` exists.

R015 Statement: Ensure required Python runtime exists for venv setup.
Design: Require `python3.12`; install `python@3.12` via brew when missing, then re-check command presence.
Tests:
- Verify missing `python3.12` triggers `brew install python@3.12`.
- Verify script fails with explicit message when Python remains missing after install attempt.

R020 Statement: Ensure required security and AV CLI tools are installed.
Design: Require `semgrep`, `shellcheck`, `gitleaks`, `detect-secrets`, `clamscan`, and `freshclam`; install missing tools with Homebrew formulas and verify each command after install.
Tests:
- Verify each missing tool triggers corresponding brew install invocation.
- Verify script fails when a required tool is still unavailable after attempted install.

R025 Statement: Emit deterministic completion summary for automation visibility.
Design: Print concise final success line once all prerequisites are satisfied.
Tests:
- Verify successful run output ends with completion summary line.

## Changelog

- 2026-05-15: Added concrete prerequisite requirements for Python, security tooling, and AV tooling used by steps 04/05.
