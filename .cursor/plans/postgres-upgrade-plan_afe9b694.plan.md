---
name: postgres-upgrade-plan
overview: Upgrade PostgreSQL runtime in pg_install to a CVE-clean target version with a safe migration path, then validate the Teller freshness gate passes.
todos:
  - id: select-target
    content: Select target PostgreSQL major/minor that remediates the 8 CVEs (prefer newest supported major if 15.x remains vulnerable).
    status: completed
  - id: parameterize-version
    content: Update pg_install version source-of-truth and remove hardcoded @15 references so installer output and paths stay consistent.
    status: completed
  - id: migration-guardrails
    content: Add/confirm preflight and migration flow for existing data directory compatibility when major version changes.
    status: completed
  - id: execute-and-verify
    content: Run standup with the upgraded version and verify service, SQL connectivity, and reported server/client versions.
    status: completed
  - id: cve-validation
    content: Re-run Teller freshness checks and confirm CVE assurance flips from known-vulnerable to passing state.
    status: completed
isProject: false
---

# PostgreSQL Runtime Upgrade Plan (pg_install)

## Goal
Move the installer-managed PostgreSQL runtime to a version that clears the Teller CVE gate, while keeping setup/teardown behavior predictable and data-safe.

## Scope
- Installer/version controls in [`/Users/phil/local/src/pg_install/vars/postgres.yml`](/Users/phil/local/src/pg_install/vars/postgres.yml)
- Standup UX/output consistency in [`/Users/phil/local/src/pg_install/04_standup_postgres.sh`](/Users/phil/local/src/pg_install/04_standup_postgres.sh)
- Install/verification flow in [`/Users/phil/local/src/pg_install/setup.yml`](/Users/phil/local/src/pg_install/setup.yml)
- Operator docs in [`/Users/phil/local/src/pg_install/README.md`](/Users/phil/local/src/pg_install/README.md)

## Implementation Plan
1. **Pick a remediation target version**
   - Use the failing Teller CVE output as the acceptance baseline: target must eliminate the 8 medium+ vulnerabilities.
   - Prefer the newest stable PostgreSQL major supported by your runtime constraints if `15.x` still fails CVE policy.

2. **Centralize version bump in installer vars**
   - Update `postgres_version`, `postgres_formula`, `postgres_service_name`, and all versioned directories in [`/Users/phil/local/src/pg_install/vars/postgres.yml`](/Users/phil/local/src/pg_install/vars/postgres.yml).
   - Keep this file as the single source of truth for `@<major>` paths.

3. **Remove hardcoded major-version literals from standup script output**
   - Replace `postgresql@15` literals in [`/Users/phil/local/src/pg_install/04_standup_postgres.sh`](/Users/phil/local/src/pg_install/04_standup_postgres.sh) success text so operational guidance matches the configured version.
   - Ensure displayed paths/service names are derived from the same vars strategy (or updated in lockstep).

4. **Add upgrade preflight + migration-safe behavior**
   - In [`/Users/phil/local/src/pg_install/setup.yml`](/Users/phil/local/src/pg_install/setup.yml), add a preflight check that compares existing data-dir `PG_VERSION` with target major.
   - If majors differ, fail fast with explicit migration instruction (or run a documented migration path) instead of starting mismatched binaries against old data.
   - Keep existing idempotency for same-major reruns.

5. **Update docs for operator workflow**
   - In [`/Users/phil/local/src/pg_install/README.md`](/Users/phil/local/src/pg_install/README.md), document:
     - target version policy,
     - major-upgrade migration requirement,
     - verification commands after standup.

6. **Validation and acceptance**
   - Run standup flow and confirm `brew services` + SQL connectivity checks still pass.
   - Re-run Teller dependency freshness (`./04_run_dependency_freshness_checks.sh`) and require:
     - `CVE evaluation status: pass`
     - `CVE assurance` no longer `known-vulnerable`
     - `CVE vulnerabilities found: 0` (or approved policy-compliant exception).

## Risks and Mitigations
- **Major-version data-dir incompatibility**: Guard with preflight check before service start.
- **Path drift from hardcoded `@15` strings**: eliminate/align literals in standup output and docs.
- **False confidence from install-only idempotency**: explicitly verify reported runtime version after standup.

## Success Criteria
- Installer provisions the new PostgreSQL target version from `pg_install` without manual patching.
- Standup output, service name, and filesystem paths reflect configured version.
- Teller CVE gate passes on the upgraded runtime.