#!/usr/bin/env bats

load "helpers/common.bash"

setup_fixture() {
  create_repo_fixture
  copy_script_to_fixture "07_standup_postgres.sh"
  mkdir -p "${FIXTURE_ROOT}/vars"
  cat > "${FIXTURE_ROOT}/vars/postgres.yml" <<'YAML'
---
postgres_formula: "postgresql@17"
postgres_port: 5432
app_database: "myapp_db"
YAML
  # Match the directory-name convention the script uses to compute VENV_DIR.
  FIXTURE_VENV="${FIXTURE_ROOT}/$(basename "${FIXTURE_ROOT}")-venv"
  mkdir -p "${FIXTURE_VENV}/bin"
  cat > "${FIXTURE_VENV}/bin/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
echo "ansible-playbook $*"
exit 0
EOF
  chmod +x "${FIXTURE_VENV}/bin/ansible-playbook"
  export FIXTURE_VENV
}

setup() { setup_shell_test; setup_fixture; }
teardown() { teardown_shell_test; }

@test "07 fails with activation guidance when no venv is active" {
  #R200
  run env -i HOME="${HOME}" PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "${FIXTURE_ROOT}/07_standup_postgres.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No virtual environment is currently active"* ]]
  [[ "$output" == *"source ${FIXTURE_VENV}/bin/activate"* ]]
}

@test "07 fails with reactivation guidance when a different venv is active" {
  #R210
  WRONG_VENV="${TEST_TMPDIR}/some-other-venv"
  mkdir -p "${WRONG_VENV}/bin"
  run env -i HOME="${HOME}" PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    VIRTUAL_ENV="${WRONG_VENV}" \
    bash "${FIXTURE_ROOT}/07_standup_postgres.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"A different virtual environment is active"* ]]
  [[ "$output" == *"deactivate"* ]]
  [[ "$output" == *"source ${FIXTURE_VENV}/bin/activate"* ]]
}

@test "07 reaches the playbook invocation when preflight passes" {
  #R001 #R320 #R330 #R340 #R350 #R360 #R370 #R380 #R390 #R400 #R410 #R420
  run env -i HOME="${HOME}" PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    VIRTUAL_ENV="${FIXTURE_VENV}" \
    bash "${FIXTURE_ROOT}/07_standup_postgres.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ansible-playbook setup.yml"* ]]
  [[ "$output" == *"PostgreSQL Setup Complete"* ]]
}

@test "07 --help exits 0 and prints usage" {
  #R300
  run env -i HOME="${HOME}" PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "${FIXTURE_ROOT}/07_standup_postgres.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--regenerate-cert"* ]]
  [[ "$output" == *"--ssl-backend=disk|1psa"* ]]
}

@test "07 unknown flag exits non-zero" {
  #R300
  run env -i HOME="${HOME}" PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "${FIXTURE_ROOT}/07_standup_postgres.sh" --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown option: --bogus"* ]]
}

@test "07 passes TLS flags through to ansible-playbook as extra-vars" {
  #R310
  run env -i HOME="${HOME}" PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    VIRTUAL_ENV="${FIXTURE_VENV}" \
    bash "${FIXTURE_ROOT}/07_standup_postgres.sh" \
    --regenerate-cert --ssl-backend=1psa --ssl-1psa-item=foo --ssl-dir=/tmp/bar
  [ "$status" -eq 0 ]
  [[ "$output" == *"postgres_ssl_regenerate=true"* ]]
  [[ "$output" == *"postgres_ssl_backend=1psa"* ]]
  [[ "$output" == *"postgres_ssl_1psa_item=foo"* ]]
  [[ "$output" == *"postgres_ssl_disk_dir=/tmp/bar"* ]]
}
