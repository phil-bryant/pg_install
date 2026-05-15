#!/usr/bin/env bats

load "helpers/common.bash"

setup_fixture() {
  create_repo_fixture
  copy_script_to_fixture "05_run_security_checks.sh"
  cat > "${FIXTURE_ROOT}/setup.yml" <<'EOF'
---
- hosts: localhost
  gather_facts: false
  tasks: []
EOF
  cat > "${FIXTURE_ROOT}/teardown.yml" <<'EOF'
---
- hosts: localhost
  gather_facts: false
  tasks: []
EOF
}

setup() { setup_shell_test; setup_fixture; }
teardown() { teardown_shell_test; }

make_semgrep_stub() {
  local body="${1:-{\"results\":[]}}"
  cat > "${STUB_BIN}/semgrep" <<EOF
#!/usr/bin/env bash
out=""
while [ "\$#" -gt 0 ]; do
  if [ "\$1" = "--output" ]; then out="\$2"; shift 2; continue; fi
  shift
done
printf '%s' '${body}' > "\$out"
exit 0
EOF
  chmod +x "${STUB_BIN}/semgrep"
}

make_shellcheck_stub() {
  local body="${1:-[]}"
  local exit_code="${2:-0}"
  cat > "${STUB_BIN}/shellcheck" <<EOF
#!/usr/bin/env bash
printf '%s' '${body}'
exit ${exit_code}
EOF
  chmod +x "${STUB_BIN}/shellcheck"
}

make_gitleaks_stub() {
  local body="${1:-[]}"
  cat > "${STUB_BIN}/gitleaks" <<EOF
#!/usr/bin/env bash
report=""
while [ "\$#" -gt 0 ]; do
  if [ "\$1" = "--report-path" ]; then report="\$2"; shift 2; continue; fi
  shift
done
printf '%s' '${body}' > "\$report"
exit 0
EOF
  chmod +x "${STUB_BIN}/gitleaks"
}

make_detect_secrets_stub() {
  local body="${1:-{\"results\":{}}}"
  cat > "${STUB_BIN}/detect-secrets" <<EOF
#!/usr/bin/env bash
printf '%s' '${body}'
exit 0
EOF
  chmod +x "${STUB_BIN}/detect-secrets"
}

make_ansible_playbook_stub() {
  local setup_exit="${1:-0}" teardown_exit="${2:-0}"
  cat > "${STUB_BIN}/ansible-playbook" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "--syntax-check" ] && [ "\$2" = "setup.yml" ]; then exit ${setup_exit}; fi
if [ "\$1" = "--syntax-check" ] && [ "\$2" = "teardown.yml" ]; then exit ${teardown_exit}; fi
exit 0
EOF
  chmod +x "${STUB_BIN}/ansible-playbook"
}

make_ansible_lint_stub() {
  local body="${1:-[]}" exit_code="${2:-0}"
  cat > "${STUB_BIN}/ansible-lint" <<EOF
#!/usr/bin/env bash
printf '%s' '${body}'
exit ${exit_code}
EOF
  chmod +x "${STUB_BIN}/ansible-lint"
}

@test "runs from non-repo cwd and writes reports under script root" {
  #R001
  make_semgrep_stub
  make_shellcheck_stub
  make_gitleaks_stub
  make_detect_secrets_stub
  make_ansible_playbook_stub 0 0
  mkdir -p "${TEST_TMPDIR}/elsewhere"
  cd "${TEST_TMPDIR}/elsewhere"
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" RUN_DAST=false bash "${FIXTURE_ROOT}/05_run_security_checks.sh"
  [ "$status" -eq 0 ]
  [ -f "${FIXTURE_ROOT}/.security-reports/sast-summary.json" ]
}

@test "fails fast with installer guidance when semgrep is missing" {
  #R005
  run env PATH="/usr/bin:/bin:/usr/sbin:/sbin" RUN_DAST=false bash "${FIXTURE_ROOT}/05_run_security_checks.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing required command: semgrep"* ]]
  [[ "$output" == *"./01_install_prerequisites.sh"* ]]
}

@test "writes all expected SAST and ansible artifacts" {
  #R010
  make_semgrep_stub
  make_shellcheck_stub
  make_gitleaks_stub
  make_detect_secrets_stub
  make_ansible_playbook_stub 0 0
  make_ansible_lint_stub '[]' 0
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" RUN_DAST=false bash "${FIXTURE_ROOT}/05_run_security_checks.sh"
  [ "$status" -eq 0 ]
  [ -f "${FIXTURE_ROOT}/.security-reports/semgrep.json" ]
  [ -f "${FIXTURE_ROOT}/.security-reports/shellcheck.json" ]
  [ -f "${FIXTURE_ROOT}/.security-reports/gitleaks.json" ]
  [ -f "${FIXTURE_ROOT}/.security-reports/detect-secrets.json" ]
  [ -f "${FIXTURE_ROOT}/.security-reports/ansible-lint.json" ]
  [ -f "${FIXTURE_ROOT}/.security-reports/ansible-setup-syntax.log" ]
  [ -f "${FIXTURE_ROOT}/.security-reports/ansible-teardown-syntax.log" ]
}

@test "fails gate when findings exist and fail-on-high is enabled" {
  #R020
  make_semgrep_stub
  make_shellcheck_stub
  make_gitleaks_stub '[{"RuleID":"secret"}]'
  make_detect_secrets_stub
  make_ansible_playbook_stub 0 0
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" RUN_DAST=false SECURITY_FAIL_ON_HIGH_CRITICAL=true bash "${FIXTURE_ROOT}/05_run_security_checks.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SAST) gate failed"* ]]
}

@test "excludes detect-secrets findings under configured excluded paths" {
  #R025
  make_semgrep_stub
  make_shellcheck_stub
  make_gitleaks_stub
  make_detect_secrets_stub '{"results":{"requirements/05_run_security_checks-requirements.md":[{"type":"Secret Keyword","line_number":1}],"pg_install-venv/lib/python3.12/site-packages/pkg/file.py":[{"type":"Secret Keyword","line_number":2}],".security-reports/old-report.json":[{"type":"Secret Keyword","line_number":3}]}}'
  make_ansible_playbook_stub 0 0
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" RUN_DAST=false SECURITY_FAIL_ON_HIGH_CRITICAL=true bash "${FIXTURE_ROOT}/05_run_security_checks.sh"
  [ "$status" -eq 0 ]
  run python3 -c 'import json,sys;print(json.load(open(sys.argv[1], encoding="utf-8"))["detect_secrets_findings"])' "${FIXTURE_ROOT}/.security-reports/sast-summary.json"
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}

@test "keeps shellcheck exit code 1 non-gating for info-level findings" {
  #R020
  make_semgrep_stub
  make_shellcheck_stub '[{"level":"info","code":2086}]' 1
  make_gitleaks_stub
  make_detect_secrets_stub
  make_ansible_playbook_stub 0 0
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" RUN_DAST=false SECURITY_FAIL_ON_HIGH_CRITICAL=true bash "${FIXTURE_ROOT}/05_run_security_checks.sh"
  [ "$status" -eq 0 ]
  run python3 -c 'import json,sys;s=json.load(open(sys.argv[1], encoding="utf-8"));print(s["shellcheck_exit_code"],s["shellcheck_high_critical"],s["shellcheck_findings_total"],s["shellcheck_non_gating_findings"],int(s["shellcheck_tool_error"]))' "${FIXTURE_ROOT}/.security-reports/sast-summary.json"
  [ "$status" -eq 0 ]
  [ "$output" = "1 0 1 1 0" ]
}

@test "fails when DAST is explicitly enabled for this repo" {
  #R015
  make_semgrep_stub
  make_shellcheck_stub
  make_gitleaks_stub
  make_detect_secrets_stub
  make_ansible_playbook_stub 0 0
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" RUN_DAST=true bash "${FIXTURE_ROOT}/05_run_security_checks.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"DAST is not configured for this repo yet."* ]]
}

@test "prints deterministic final completion output with report path" {
  #R030
  make_semgrep_stub
  make_shellcheck_stub
  make_gitleaks_stub
  make_detect_secrets_stub
  make_ansible_playbook_stub 0 0
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" RUN_DAST=false bash "${FIXTURE_ROOT}/05_run_security_checks.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Security checks completed. Reports:"* ]]
}
