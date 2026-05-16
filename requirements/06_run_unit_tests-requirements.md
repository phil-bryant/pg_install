# Run Unit Tests Requirements

## Scope

Applies to `06_run_unit_tests.sh`.

R001 Statement: Run in strict shell mode from repository root.
Design: Use `set -euo pipefail`, resolve `${BASH_SOURCE[0]}`, and `cd` to script directory before discovery.
Tests:
- Run from non-repo cwd and verify discovery still targets repo-local paths.

R005 Statement: Autodiscover Bats tests and run them as a suite.
Design: Discover `tests/sh/*.bats`; run via `bats` when available, fail if test files exist but bats is unavailable.
Tests:
- Add temporary `.bats` files and verify Bats suite executes.

R010 Statement: Python test suites are out of scope for this repository step.
Design: `06_run_unit_tests.sh` does not discover or run pytest/unittest suites; shell and ansible validation suites remain in scope.
Tests:
- Verify output does not include `Pytest` or `Python unittest` suite entries.

R020 Statement: Run ansible syntax checks for repo playbooks.
Design: When `setup.yml` or `teardown.yml` exists, run `ansible-playbook --syntax-check` for each present playbook.
Tests:
- Stub `ansible-playbook` and verify syntax checks execute.

R025 Statement: Require ansible-lint when playbooks are present.
Design: If `setup.yml` or `teardown.yml` exists, `ansible-lint` must be available and succeeds for present playbooks; missing command is a failing suite with setup guidance.
Tests:
- Stub `ansible-lint` and verify invocation path.
- Verify missing `ansible-lint` with discovered playbooks causes failure and prints remediation guidance.

R030 Statement: Continue through suite failures and report full outcomes.
Design: Execute discovered suites independently and keep running subsequent suites even after a failure.
Tests:
- Force one suite to fail and verify later suites still run.

R035 Statement: Emit final summary and pass/fail exit code.
Design: Print suite counts and finish with success/failure summary; return non-zero when any suite fails.
Tests:
- Verify passing run exits zero with success summary.
- Verify failing run exits non-zero with failure summary.

## Changelog

- 2026-05-15: Migrated from 1psa baseline, renumbered to step-06, removed Go suite, added ansible validation suites.
