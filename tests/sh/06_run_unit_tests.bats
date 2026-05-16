#!/usr/bin/env bats

setup() { REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"; }

@test "06 script exists and is executable" {
  #R001 #R005 #R010 #R020 #R025 #R030 #R035
  run test -x "${REPO_ROOT}/06_run_unit_tests.sh"
  [ "$status" -eq 0 ]
}

@test "06 reports green checkmark when discovered suites pass" {
  workdir="$(mktemp -d)"; mockbin="${workdir}/mockbin"
  mkdir -p "${mockbin}" "${workdir}/tests/sh"
  cp "${REPO_ROOT}/06_run_unit_tests.sh" "${workdir}/06_run_unit_tests.sh"; chmod +x "${workdir}/06_run_unit_tests.sh"
  cp "${REPO_ROOT}/setup.yml" "${workdir}/setup.yml"; cp "${REPO_ROOT}/teardown.yml" "${workdir}/teardown.yml"
  touch "${workdir}/tests/sh/sample.bats"
  cat > "${mockbin}/bats" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat > "${mockbin}/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat > "${mockbin}/ansible-lint" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${mockbin}/bats" "${mockbin}/ansible-playbook" "${mockbin}/ansible-lint"
  run env PATH="${mockbin}:/usr/bin:/bin" /bin/bash "${workdir}/06_run_unit_tests.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Suites failed:     0"* ]]
  [[ "$output" != *"Pytest"* ]]
  [[ "$output" != *"Python unittest"* ]]
  [[ "$output" == *"All discovered unit test suites passed."* ]]
}

@test "06 reports red x and non-zero when a discovered suite fails but continues" {
  workdir="$(mktemp -d)"; mockbin="${workdir}/mockbin"
  mkdir -p "${mockbin}" "${workdir}/tests/sh"
  cp "${REPO_ROOT}/06_run_unit_tests.sh" "${workdir}/06_run_unit_tests.sh"; chmod +x "${workdir}/06_run_unit_tests.sh"
  cp "${REPO_ROOT}/setup.yml" "${workdir}/setup.yml"; cp "${REPO_ROOT}/teardown.yml" "${workdir}/teardown.yml"
  touch "${workdir}/tests/sh/sample.bats"
  cat > "${mockbin}/bats" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  cat > "${mockbin}/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat > "${mockbin}/ansible-lint" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${mockbin}/bats" "${mockbin}/ansible-playbook" "${mockbin}/ansible-lint"
  run env PATH="${mockbin}:/usr/bin:/bin" /bin/bash "${workdir}/06_run_unit_tests.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Bats (1 files): FAIL"* ]]
  [[ "$output" == *"Ansible syntax checks: PASS"* ]]
  [[ "$output" == *"One or more discovered unit test suites failed."* ]]
}

@test "06 fails when ansible-lint is unavailable and playbooks exist" {
  workdir="$(mktemp -d)"; mockbin="${workdir}/mockbin"
  mkdir -p "${mockbin}" "${workdir}/tests/sh"
  cp "${REPO_ROOT}/06_run_unit_tests.sh" "${workdir}/06_run_unit_tests.sh"; chmod +x "${workdir}/06_run_unit_tests.sh"
  cp "${REPO_ROOT}/setup.yml" "${workdir}/setup.yml"; cp "${REPO_ROOT}/teardown.yml" "${workdir}/teardown.yml"
  touch "${workdir}/tests/sh/sample.bats"
  cat > "${mockbin}/bats" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat > "${mockbin}/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${mockbin}/bats" "${mockbin}/ansible-playbook"
  run env PATH="${mockbin}:/usr/bin:/bin" /bin/bash "${workdir}/06_run_unit_tests.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"'ansible-lint' is not available."* ]]
  [[ "$output" == *"Fix: run ./01_install_prerequisites.sh"* ]]
  [[ "$output" == *"Ansible lint: FAIL"* ]]
}

@test "06 fails when ansible-lint returns non-zero" {
  workdir="$(mktemp -d)"; mockbin="${workdir}/mockbin"
  mkdir -p "${mockbin}" "${workdir}/tests/sh"
  cp "${REPO_ROOT}/06_run_unit_tests.sh" "${workdir}/06_run_unit_tests.sh"; chmod +x "${workdir}/06_run_unit_tests.sh"
  cp "${REPO_ROOT}/setup.yml" "${workdir}/setup.yml"; cp "${REPO_ROOT}/teardown.yml" "${workdir}/teardown.yml"
  touch "${workdir}/tests/sh/sample.bats"
  cat > "${mockbin}/bats" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat > "${mockbin}/ansible-playbook" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat > "${mockbin}/ansible-lint" <<'EOF'
#!/usr/bin/env bash
exit 2
EOF
  chmod +x "${mockbin}/bats" "${mockbin}/ansible-playbook" "${mockbin}/ansible-lint"
  run env PATH="${mockbin}:$PATH" bash "${workdir}/06_run_unit_tests.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Ansible lint: FAIL"* ]]
  [[ "$output" == *"Suites failed:     1"* ]]
}
