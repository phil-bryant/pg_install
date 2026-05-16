#!/usr/bin/env bash
umask 007
#R001: Run in strict mode and anchor execution to repository root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

print_suite_header() {
  local suite="$1"
  echo ""
  echo "------------------------------------------------------------"
  echo "[unit-tests] ${suite}"
  echo "------------------------------------------------------------"
}

record_pass() {
  local suite="$1"
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "✅ [unit-tests] ${suite}: PASS"
}

record_fail() {
  local suite="$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "❌ [unit-tests] ${suite}: FAIL"
}

record_skip() {
  local suite="$1"
  SKIP_COUNT=$((SKIP_COUNT + 1))
  echo "⏭️  [unit-tests] ${suite}: SKIP"
}

run_suite() {
  local suite="$1"
  shift
  print_suite_header "$suite"
  set +e
  "$@"
  local code=$?
  set -e
  if [[ "$code" -eq 0 ]]; then
    record_pass "$suite"
  else
    record_fail "$suite"
  fi
}

#R005: Discover and run Bats tests from tests/sh/*.bats.
BATS_TEST_FILES=()
while IFS= read -r test_file; do
  BATS_TEST_FILES+=("$test_file")
done < <(find ./tests/sh -type f -name "*.bats" 2>/dev/null | sort)
if [[ "${#BATS_TEST_FILES[@]}" -gt 0 ]]; then
  if command -v bats >/dev/null 2>&1; then
    run_suite "Bats (${#BATS_TEST_FILES[@]} files)" bats "${BATS_TEST_FILES[@]}"
  else
    echo "❌ [unit-tests] Bats tests discovered but 'bats' is not available."
    record_fail "Bats (${#BATS_TEST_FILES[@]} files)"
  fi
else
  record_skip "Bats"
fi

#R010: Python suites are intentionally not discovered in this repository step.
run_ansible_syntax_suite() {
  local -a playbooks=("$@")
  local code=0
  for playbook in "${playbooks[@]}"; do ansible-playbook --syntax-check "$playbook" || code=1; done
  return "$code"
}

#R020: Run ansible syntax checks when playbooks are present.
ANSIBLE_PLAYBOOKS=()
[[ -f "./setup.yml" ]] && ANSIBLE_PLAYBOOKS+=("setup.yml")
[[ -f "./teardown.yml" ]] && ANSIBLE_PLAYBOOKS+=("teardown.yml")
if [[ "${#ANSIBLE_PLAYBOOKS[@]}" -gt 0 ]]; then
  if command -v ansible-playbook >/dev/null 2>&1; then
    print_suite_header "Ansible syntax checks"
    set +e
    run_ansible_syntax_suite "${ANSIBLE_PLAYBOOKS[@]}"
    code=$?
    set -e
    if [[ "$code" -eq 0 ]]; then record_pass "Ansible syntax checks"; else record_fail "Ansible syntax checks"; fi
  else
    echo "❌ [unit-tests] Ansible playbooks discovered but 'ansible-playbook' is not available."
    record_fail "Ansible syntax checks"
  fi
else
  record_skip "Ansible syntax checks"
fi

#R025: Run ansible-lint when available and playbooks are present.
if [[ "${#ANSIBLE_PLAYBOOKS[@]}" -gt 0 ]]; then
  if command -v ansible-lint >/dev/null 2>&1; then
    run_suite "Ansible lint" ansible-lint "${ANSIBLE_PLAYBOOKS[@]}"
  else
    echo "❌ [unit-tests] Ansible playbooks discovered but 'ansible-lint' is not available."
    echo "[unit-tests] Fix: run ./01_install_prerequisites.sh, then ./02_create_venv.sh, then activate, then ./03_load_requirements.sh."
    record_fail "Ansible lint"
  fi
else
  record_skip "Ansible lint"
fi

#R030: Always continue through suite failures and report full outcomes.
TOTAL_DISCOVERED=$((PASS_COUNT + FAIL_COUNT))

echo ""
echo "==================== Unit Test Summary ===================="
echo "Suites discovered: ${TOTAL_DISCOVERED}"
echo "Suites passed:     ${PASS_COUNT}"
echo "Suites failed:     ${FAIL_COUNT}"
echo "Suites skipped:    ${SKIP_COUNT}"

#R035: Emit final checkmark/cross summary and return pass/fail exit code.
if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo "✅ All discovered unit test suites passed."
  exit 0
fi

echo "❌ One or more discovered unit test suites failed."
exit 1
