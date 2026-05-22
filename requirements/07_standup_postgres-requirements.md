# Standup Postgres Requirements

## Scope

Applies to `07_standup_postgres.sh`.

R001 Statement: Orchestrate PostgreSQL installation, configuration, and verification via the Ansible setup playbook.
Design: `07_standup_postgres.sh` invokes `${VENV_DIR}/bin/ansible-playbook setup.yml` after preflight checks succeed.
Tests:
- `tests/sh/07_standup_postgres.bats` confirms the script exists, is executable, and reaches the playbook invocation under preflight-pass conditions.

R200 Statement: Abort with guidance when no Python virtual environment is active.
Design: Read `$VIRTUAL_ENV`; when empty, print activation instructions referencing `source ${VENV_DIR}/bin/activate` and exit non-zero before invoking ansible.
Rationale: The script depends on tools provided by the project venv (ansible-playbook, psycopg2-binary). Failing fast with instructions prevents partial runs against a system Python or another project's venv.
Tests:
- `tests/sh/07_standup_postgres.bats` verifies the script exits non-zero and prints activation guidance when `VIRTUAL_ENV` is unset.

R210 Statement: Abort with guidance when the active virtual environment is not the expected project venv.
Design: Resolve both expected (`${SCRIPT_DIR}/${repo}-venv`) and current (`$VIRTUAL_ENV`) to absolute paths and compare; on mismatch, print deactivate/reactivate guidance and exit non-zero before invoking ansible.
Rationale: A different venv may have an incompatible ansible/psycopg2 set, leading to confusing playbook failures or destructive partial runs.
Tests:
- `tests/sh/07_standup_postgres.bats` verifies the script exits non-zero and prints deactivate/reactivate guidance when `VIRTUAL_ENV` points at a different directory than the project venv.

R300 Statement: Parse TLS-related CLI flags into wrapper-script variables.
Design: Recognize `--regenerate-cert`, `--ssl-backend=disk|1psa`, `--ssl-dir=PATH`, `--ssl-1psa-item=NAME`, and `-h/--help`. Unknown flags exit non-zero with usage. `--help` exits zero with usage.
Rationale: Surface the TLS knobs as first-class CLI options so operators can pick storage backend and force regeneration without editing `vars/postgres.yml`.
Tests:
- `tests/sh/07_standup_postgres.bats` verifies `--help` exits 0 and prints usage.
- `tests/sh/07_standup_postgres.bats` verifies an unknown flag exits non-zero.

R310 Statement: Pass parsed TLS flags through to the ansible playbook as extra-vars.
Design: Build a bash array `EXTRA_VARS` populated only with set values, then invoke `ansible-playbook setup.yml -e "${EXTRA_VARS[*]}"` so the play sees `postgres_ssl_regenerate`, `postgres_ssl_backend`, `postgres_ssl_disk_dir`, and `postgres_ssl_1psa_item`.
Rationale: Keep the wrapper thin and let ansible own the runtime decisions.
Tests:
- `tests/sh/07_standup_postgres.bats` verifies that the captured ansible-playbook invocation contains the expected extra-vars when flags are passed.

R320 Statement: Provide TLS configuration defaults in `vars/postgres.yml` that are inert while ssl is disabled.
Design: Define `postgres_ssl_regenerate`, `postgres_ssl_backend`, `postgres_ssl_disk_dir`, `postgres_ssl_1psa_item`, `postgres_ssl_san`, `postgres_ssl_days`, `postgres_ssl_key_bits`, `postgres_ssl_min_protocol_version`, and `postgres_ssl_renew_within_days` with safe defaults. While `postgres_ssl == "off"`, no playbook task references these vars, so behavior is unchanged.
Rationale: Land the variable surface ahead of the consumers so later slices (cert generation, postgresql.conf wiring, hba enforcement) reference an already-stable schema.
Tests:
- `tests/sh/07_standup_postgres.bats` confirms the script reaches the playbook invocation and that no TLS-related task error is raised on a default run (covered transitively via the existing playbook-reach happy-path test plus ansible-syntax/lint inside `06_run_unit_tests.sh`).

R330 Statement: Generate a local self-signed CA and SAN-signed server cert via openssl when TLS material must be created.
Design: `tasks/tls_material.yml` builds an openssl extfile pinning `subjectAltName` to `postgres_ssl_san`, generates a 4096-bit RSA root CA (self-signed) and a server CSR signed by that CA with `extendedKeyUsage = serverAuth`, validity capped at `postgres_ssl_days`.
Rationale: A local CA enables `sslmode=verify-ca`/`verify-full` on clients that import `root.crt`; SAN entries make the cert match `localhost`/`127.0.0.1`/`::1` regardless of how clients address the server.
Alternatives: Single self-signed leaf (rejected: no `verify-ca` path); mkcert (rejected: external dependency).
Tests:
- `tests/sh/07_standup_postgres.bats` confirms the default-off path does not invoke this task (gated by `when: postgres_ssl == "on"`); ansible-syntax-check and ansible-lint inside `06_run_unit_tests.sh` validate that the task file parses and lints cleanly.

R340 Statement: Regenerate TLS material when forced, missing, or within a renewal window.
Design: `tls_regenerate_now` is true when `postgres_ssl_regenerate | bool`, when no usable material is present in the selected backend, or when the existing server cert expires within `postgres_ssl_renew_within_days` days (default 30).
Rationale: "Fully automated infra" means certs renew themselves; the explicit force flag covers the operator-driven case.
Tests:
- `tests/sh/07_standup_postgres.bats` confirms the default-off path does not invoke this decision; ansible-lint validates the conditional logic.

R350 Statement: Persist disk-backend TLS material under a gitignored directory with restrictive permissions.
Design: When `postgres_ssl_backend == "disk"`, store `server.crt`, `server.key`, `root.crt`, `root.key` in `postgres_ssl_disk_dir` (default `<repo>/.secrets/tls`) with mode 0700 on the directory and 0600 on the files. `.gitignore` excludes `.secrets/`. Existing files are moved to `~/.Trash/pg_install_tls_<ts>/` before being overwritten (no `rm`).
Rationale: Local disk is the simplest backend for solo dev/test; keeping it gitignored prevents accidental commit of private keys.
Tests:
- `tests/sh/07_standup_postgres.bats` confirms the default-off path does not invoke disk-backend writes; the `.gitignore` entry is checked transitively by repository-level traceability.

R360 Statement: Install staged TLS material into the PostgreSQL data directory.
Design: After staging or regeneration, `tasks/tls_material.yml` copies `server.crt`, `server.key`, and (when present) `root.crt` into `{{ postgres_data_dir }}` with mode 0600, then notifies the standard `restart postgresql` handler.
Rationale: PostgreSQL reads cert files relative to the data directory by default; placing them inside the data dir avoids absolute-path config.
Tests:
- `tests/sh/07_standup_postgres.bats` confirms the default-off path does not touch the data directory beyond existing behavior; ansible-syntax-check validates the file copies are well-formed.

R370 Statement: Configure PostgreSQL to use TLS settings when ssl is enabled.
Design: When `postgres_ssl == "on"`, `setup.yml` writes `ssl = on`, `ssl_cert_file = 'server.crt'`, `ssl_key_file = 'server.key'`, `ssl_ca_file = 'root.crt'`, and `ssl_min_protocol_version = '{{ postgres_ssl_min_protocol_version }}'` (default `TLSv1.3`) into `postgresql.conf`. The `ssl = ...` line is always written so the value flips correctly when ssl is toggled off.
Rationale: Without these directives PostgreSQL ignores the cert files even if they are present in the data dir.
Tests:
- `tests/sh/07_standup_postgres.bats` confirms the default-off path keeps `ssl = off` and does not write the additional ssl_* lines (covered transitively via the playbook-reach happy-path test plus ansible-syntax/lint inside `06_run_unit_tests.sh`).

R380 Statement: Require TLS on host connections via pg_hba.conf when ssl is enabled.
Design: The final pg_hba content is conditional. When `postgres_ssl == "on"`: `local ... scram-sha-256`, `hostssl ... scram-sha-256` for IPv4/IPv6 loopback, `hostnossl all all all reject`, and `host all all 0.0.0.0/0 reject`. When `postgres_ssl == "off"`: the original `host ... scram-sha-256` rules are retained.
Rationale: Configuring `ssl = on` without enforcing it in pg_hba would still allow plaintext host connections; the `hostnossl ... reject` rule closes that gap.
Alternatives: A separate playbook step that rewrites pg_hba after standup (rejected: leaves a window of plaintext-allowed traffic during standup).
Tests:
- `tests/sh/07_standup_postgres.bats` confirms the default-off path produces the original pg_hba content (covered transitively via the playbook-reach happy-path test plus ansible-syntax/lint inside `06_run_unit_tests.sh`).

R390 Statement: Default `postgres_ssl` to `"on"` so standup is TLS-required out of the box.
Design: `vars/postgres.yml` ships with `postgres_ssl: "on"`. Operators who explicitly want plaintext can override via `-e postgres_ssl=off` or by editing the var file.
Rationale: "Local-only and unencrypted" is not aligned with the goal of fully automated, secure-by-default infrastructure. Flipping the default makes the secure path the easy path.
Alternatives: Keep ssl opt-in (rejected; conflicts with the stated goal). Default to `on` only when an env var is set (rejected; adds friction for the common case).
Tests:
- `tests/sh/07_standup_postgres.bats` confirms the playbook-reach happy-path remains green with the new default; ansible-syntax-check and ansible-lint validate that the wired-up TLS tasks parse cleanly under the new default.

R400 Statement: Read existing TLS material from a 1Password Secure Note via the `1psa` CLI when the backend is `1psa`.
Design: When `postgres_ssl_backend == "1psa"`, `tasks/tls_material.yml` invokes `../1psa/bin/1psa -f <item> <field>` for cert, key, and ca. When fields return non-empty content, they are staged to the same tempfile paths used by the disk backend so downstream install logic is shared.
Rationale: 1psa is read-only (no put/edit), but read is sufficient to detect existing material and feed expiry inspection.
Tests:
- `tests/sh/07_standup_postgres.bats` confirms the playbook-reach happy-path is independent of backend; ansible-syntax-check validates that the conditional read tasks parse correctly.

R410 Statement: Write regenerated TLS material to 1Password via the `op` CLI when the backend is `1psa`.
Design: After regeneration, slurp the staged cert/key/ca files; check whether the configured 1psa item exists via `op item get`; on absence, run `op item create --category 'Secure Note' --title <item> cert[text]=... key[concealed]=... ca[text]=...`; on presence, run `op item edit ...` with the same field assignments. Optional `postgres_ssl_1psa_vault` is appended as `--vault <name>` when set. All tasks that handle key bytes have `no_log: true`.
Rationale: The `op` CLI is the only reliable way to write Secure Note items from automation; using its native field-type syntax (`[text]`, `[concealed]`) preserves the right concealment behavior in the 1Password UI.
Tests:
- `tests/sh/07_standup_postgres.bats` confirms the playbook-reach happy-path runs without invoking 1psa write tasks under the disk-backend default; ansible-syntax-check validates that the conditional write tasks parse correctly.

R420 Statement: Fail with clear guidance when the `1psa` backend is selected for write but `op` is unavailable.
Design: Before invoking `op`, run `which op`. If exit is non-zero, fail with a message naming `brew install --cask 1password-cli` and `op signin` (or service-account token) as remediation.
Rationale: 1psa-backend regeneration cannot succeed without `op`; failing fast with a clear remediation avoids leaving the operator with a half-written secret in a tempfile.
Tests:
- `tests/sh/07_standup_postgres.bats` confirms the playbook-reach happy-path remains green under the disk-backend default; ansible-syntax-check validates that the conditional `op`-detection task parses correctly.
