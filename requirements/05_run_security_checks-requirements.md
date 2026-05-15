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

R015  Statement: Keep step-05 security checks SAST-only for this repository.
Design: Do not run a DAST lane or emit DAST lane status output in this script.
Tests:
- Run successful checks and verify output does not include DAST lane status text.

R020  Statement: Fail SAST gate when any finding is detected.
Design: Write `sast-summary.json` with per-tool finding counts, aggregate `findings_total`, and set `gate_failed=true` whenever `findings_total > 0`.
Tests:
- Seed finding-bearing stubs and verify gate fails with explicit SAST gate-failed output.
- Seed clean stubs and verify `gate_failed=false`.
- Seed info-level-only findings and verify gate still fails.

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
