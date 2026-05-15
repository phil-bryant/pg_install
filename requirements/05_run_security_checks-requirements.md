# Run Security Checks Requirements

## Scope

Applies to `05_run_security_checks.sh`.

R001  Statement: Run security checks in strict fail-fast mode from repository root.
Design: Use strict shell mode, resolve `${BASH_SOURCE[0]}`, and `cd` to script root before running checks.
Tests:
- Run from non-repo cwd and verify report artifacts still land in script-root `.security-reports`.

R005  Statement: Fail fast with installer guidance when required SAST tools are missing.
Design: Check required commands before execution and print `./01_install_prerequisites.sh` guidance on missing tools.
Tests:
- Run with missing `semgrep` and verify non-zero exit plus installer guidance output.

R010  Statement: Run repo-relevant SAST checks for shell, python, secrets, and ansible.
Design: Run `semgrep`, `shellcheck`, `gitleaks`, `detect-secrets`, ansible syntax checks for `setup.yml` and `teardown.yml`, plus optional `ansible-lint` when available.
Tests:
- Verify expected report files are written for semgrep, shellcheck, gitleaks, detect-secrets, ansible-lint, and ansible syntax logs.

R015  Statement: Support deterministic DAST behavior without manifold-specific assumptions.
Design: Keep `RUN_DAST=false` default; when `RUN_DAST=true`, fail clearly that DAST is not configured for this infra repo.
Tests:
- Run with default config and verify deterministic `DAST lane skipped.` output.
- Run with `RUN_DAST=true` and verify explicit non-zero configuration error.

R020  Statement: Produce machine-readable SAST summary and gate evaluation.
Design: Write `sast-summary.json` with per-tool counts, ansible syntax/lint signals, `high_critical_total`, and `gate_failed` controlled by `SECURITY_FAIL_ON_HIGH_CRITICAL`.
Tests:
- Seed finding-bearing stubs and verify gate fails with explicit SAST gate-failed output.
- Seed clean stubs and verify `gate_failed=false`.

R025  Statement: Exclude configured detect-secrets paths from gate totals.
Design: Apply `DETECT_SECRETS_EXCLUDE_FILES_REGEX` while counting detect-secrets findings for summary and gating.
Tests:
- Verify excluded-path findings do not increment `detect_secrets_findings`.
- Verify in-scope findings increment `detect_secrets_findings` and can fail the gate.

R030  Statement: Emit deterministic completion output including report location.
Design: Print final success line with `Security checks completed. Reports: <dir>` for automation.
Tests:
- Verify successful run output contains `Security checks completed. Reports:`.

## Changelog

- 2026-05-15: Migrated from manifold baseline and adapted to pg_install shell/python/ansible scope.
