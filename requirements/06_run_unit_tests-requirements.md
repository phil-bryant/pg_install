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

R010 Statement: Autodiscover pytest-style Python tests.
Design: Discover `tests/py/test_*.py`; run `python3 -m pytest` when pytest is installed, otherwise fail the suite.
Tests:
- Verify pytest discovery runs when files exist.
- Verify missing pytest with discovered files causes failure.

R015 Statement: Autodiscover unittest-style Python tests.
Design: Discover `python/test_*.py`; run `python3 -m unittest discover -s python -p 'test_*.py'`.
Tests:
- Add unittest module under `python/` and verify execution.

R020 Statement: Run ansible syntax checks for repo playbooks.
Design: When `setup.yml` or `teardown.yml` exists, run `ansible-playbook --syntax-check` for each present playbook.
Tests:
- Stub `ansible-playbook` and verify syntax checks execute.

R025 Statement: Run ansible-lint when available for present playbooks.
Design: If playbooks exist and `ansible-lint` is installed, run `ansible-lint setup.yml teardown.yml`; otherwise mark suite skipped.
Tests:
- Stub `ansible-lint` and verify invocation path.
- Verify suite skip when command is unavailable.

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
