#!/usr/bin/env bats

load "helpers/common.bash"

setup_fixture() {
  create_repo_fixture
  copy_script_to_fixture "08_teardown_postgres.sh"
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

@test "08 fails with activation guidance when no venv is active" {
  #R200
  run env -i HOME="${HOME}" PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "${FIXTURE_ROOT}/08_teardown_postgres.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No virtual environment is currently active"* ]]
  [[ "$output" == *"source ${FIXTURE_VENV}/bin/activate"* ]]
}

@test "08 fails with reactivation guidance when a different venv is active" {
  #R210
  WRONG_VENV="${TEST_TMPDIR}/some-other-venv"
  mkdir -p "${WRONG_VENV}/bin"
  run env -i HOME="${HOME}" PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" \
    VIRTUAL_ENV="${WRONG_VENV}" \
    bash "${FIXTURE_ROOT}/08_teardown_postgres.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"A different virtual environment is active"* ]]
  [[ "$output" == *"deactivate"* ]]
  [[ "$output" == *"source ${FIXTURE_VENV}/bin/activate"* ]]
}

@test "08 cancels without invoking the playbook when confirmation token is not 'yes'" {
  #R220
  run bash -c "echo no | env -i HOME='${HOME}' PATH='${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin' VIRTUAL_ENV='${FIXTURE_VENV}' bash '${FIXTURE_ROOT}/08_teardown_postgres.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Teardown cancelled."* ]]
  [[ "$output" != *"ansible-playbook teardown.yml"* ]]
}

@test "08 reaches the playbook invocation when preflight and confirmation succeed" {
  #R001 #R220
  run bash -c "echo yes | env -i HOME='${HOME}' PATH='${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin' VIRTUAL_ENV='${FIXTURE_VENV}' bash '${FIXTURE_ROOT}/08_teardown_postgres.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ansible-playbook teardown.yml -e confirm_teardown=yes"* ]]
  [[ "$output" == *"PostgreSQL Teardown Complete"* ]]
}
