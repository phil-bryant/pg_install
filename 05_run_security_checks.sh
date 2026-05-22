#!/usr/bin/env bash
umask 007
#R001: Run in strict fail-fast mode from repository root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
#R001: Security checks execute from repository root with strict mode.
#R005: Required security tooling must exist or the script exits with install guidance.
#R010: SAST lane runs semgrep, shellcheck, gitleaks, detect-secrets, and ansible checks.
#R015: DAST lane is intentionally out-of-scope for this repository security script.
#R020: Security findings are aggregated into machine-readable summary and gate on any finding.
#R025: detect-secrets exclusions are applied during counting and gate evaluation.
#R030: Script emits deterministic final completion output with report location.

REPORT_DIR="${SECURITY_REPORT_DIR:-./.security-reports}"
RUN_SAST="${RUN_SAST:-true}"
RUN_ANSIBLE_CHECKS="${RUN_ANSIBLE_CHECKS:-true}"
DETECT_SECRETS_EXCLUDE_FILES_REGEX="${DETECT_SECRETS_EXCLUDE_FILES_REGEX:-(^|/)requirements/.*-requirements\\.md$|(^|/)\\.git/|(^|/)pg_install-venv/|(^|/)\\.venv/|(^|/)venv/|(^|/)\\.security-reports/|(^|/)\\.secrets/}"

#R010: Emit deterministic multiline startup header for security lane configuration.
echo "============================================================"
echo "Security Checks Script"
echo "============================================================"
echo "Run SAST: ${RUN_SAST}"
echo "Run Ansible Checks: ${RUN_ANSIBLE_CHECKS}"
echo "Fail on Any Findings: true"
echo "Reports Directory: ${REPORT_DIR}"
echo "============================================================"
echo ""

mkdir -p "$REPORT_DIR"

require_command() {
  local command_name="$1"
  #R005: Fail fast with installer guidance when required commands are missing.
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}"
    echo "Install prerequisites with: ./01_install_prerequisites.sh"
    exit 1
  fi
}

print_tool_header() {
  local tool_name="$1" line_1="$2" line_2="$3" tool_url="$4"
  local border="+==============================================================================+"
  printf '%s\n' "$border"
  printf '| %-76s |\n' "Security Tool: ${tool_name}"
  printf '| %-76s |\n' "$line_1"
  printf '| %-76s |\n' "$line_2"
  printf '| %-76s |\n' "URL: ${tool_url}"
  printf '%s\n' "$border"
}

run_sast_lane() {
  #R010: Keep step-05 security checks scoped to SAST plus optional ansible validations.
  if [[ "$RUN_SAST" != "true" ]]; then
    echo "SAST lane skipped."
    return 0
  fi
  require_command semgrep
  require_command shellcheck
  require_command gitleaks
  require_command detect-secrets
  require_command python3
  echo "Running SAST lane"

  print_tool_header "Semgrep" "Static pattern-based scanning for security and correctness issues." "Uses curated shell/python/secrets rules against repository source." "https://semgrep.dev/docs/"
  semgrep scan --config "p/security-audit" --config "p/python" --config "p/secrets" --json --output "${REPORT_DIR}/semgrep.json" .
  print_tool_header "ShellCheck" "Static linting for shell scripts with security and reliability checks." "Flags risky shell patterns, quoting bugs, and execution pitfalls." "https://www.shellcheck.net/"
  set +e
  shellcheck --format json --external-sources --source-path SCRIPTDIR ./*.sh > "${REPORT_DIR}/shellcheck.json"
  SHELLCHECK_EXIT=$?
  set -e
  if [[ "$SHELLCHECK_EXIT" -gt 1 ]]; then echo "shellcheck failed to execute."; exit 1; fi

  print_tool_header "Gitleaks" "Scans repository content for hard-coded secrets and credentials." "Detects leaked tokens, keys, and other sensitive data patterns." "https://github.com/gitleaks/gitleaks"
  set +e
  gitleaks detect --no-banner --report-format json --report-path "${REPORT_DIR}/gitleaks.json"
  GITLEAKS_EXIT=$?
  set -e
  if [[ "$GITLEAKS_EXIT" -gt 1 ]]; then echo "gitleaks failed to execute."; exit 1; fi

  #R025: Apply detect-secrets path exclusion policy during scan collection.
  print_tool_header "detect-secrets" "Scans repository files for high-entropy and known secret formats." "Helps catch accidentally committed credentials before release." "https://github.com/Yelp/detect-secrets"
  detect-secrets scan --all-files --exclude-files "${DETECT_SECRETS_EXCLUDE_FILES_REGEX}" > "${REPORT_DIR}/detect-secrets.json"

  ANSIBLE_LINT_EXIT=0
  if [[ "$RUN_ANSIBLE_CHECKS" == "true" ]]; then
    if command -v ansible-lint >/dev/null 2>&1; then
      print_tool_header "ansible-lint" "Static linting for Ansible playbooks and task structure." "Validates style, correctness, and common misconfiguration patterns." "https://ansible.readthedocs.io/projects/lint/"
      set +e
      ansible-lint setup.yml teardown.yml --format json > "${REPORT_DIR}/ansible-lint.json"
      ANSIBLE_LINT_EXIT=$?
      set -e
      if [[ "$ANSIBLE_LINT_EXIT" -gt 2 ]]; then echo "ansible-lint failed to execute."; exit 1; fi
    else
      printf '%s\n' '{"skipped": true, "reason": "ansible-lint not installed"}' > "${REPORT_DIR}/ansible-lint.json"
    fi
    require_command ansible-playbook
    print_tool_header "ansible-playbook --syntax-check" "Syntax validation for setup and teardown playbooks before execution." "Confirms Ansible parseability without applying infrastructure changes." "https://docs.ansible.com/ansible/latest/cli/ansible-playbook.html"
    set +e
    ansible-playbook --syntax-check setup.yml > "${REPORT_DIR}/ansible-setup-syntax.log" 2>&1
    ANSIBLE_SETUP_EXIT=$?
    ansible-playbook --syntax-check teardown.yml > "${REPORT_DIR}/ansible-teardown-syntax.log" 2>&1
    ANSIBLE_TEARDOWN_EXIT=$?
    set -e
  else
    printf '%s\n' '{"skipped": true, "reason": "RUN_ANSIBLE_CHECKS=false"}' > "${REPORT_DIR}/ansible-lint.json"
    ANSIBLE_SETUP_EXIT=0
    ANSIBLE_TEARDOWN_EXIT=0
  fi

  #R020: Aggregate SAST/ansible findings and fail gate when any finding exists.
  python3 - <<'PY' "${REPORT_DIR}" "${SHELLCHECK_EXIT}" "${GITLEAKS_EXIT}" "${ANSIBLE_LINT_EXIT}" "${ANSIBLE_SETUP_EXIT}" "${ANSIBLE_TEARDOWN_EXIT}" "${DETECT_SECRETS_EXCLUDE_FILES_REGEX}"
import json
import re
import sys
from pathlib import Path

report_dir = Path(sys.argv[1])
shellcheck_exit = int(sys.argv[2])
gitleaks_exit = int(sys.argv[3])
ansible_lint_exit = int(sys.argv[4])
ansible_setup_exit = int(sys.argv[5])
ansible_teardown_exit = int(sys.argv[6])
exclude_pattern = sys.argv[7]

def load_json(path, fallback):
    text = Path(path).read_text(encoding="utf-8", errors="replace").strip()
    if not text:
        return fallback
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return fallback

semgrep = load_json(report_dir / "semgrep.json", {"results": []})
semgrep_results = semgrep.get("results", []) if isinstance(semgrep, dict) else []
semgrep_high = sum(1 for item in semgrep_results if str(item.get("extra", {}).get("severity", "")).upper() in {"CRITICAL", "ERROR", "HIGH"})
semgrep_findings_total = len(semgrep_results)

shellcheck = load_json(report_dir / "shellcheck.json", [])
if isinstance(shellcheck, list):
    shellcheck_issue_count = len(shellcheck)
    shellcheck_high = sum(1 for issue in shellcheck if str(issue.get("level", "")).lower() in {"error", "warning"})
else:
    shellcheck_issue_count = 0
    shellcheck_high = 0
shellcheck_tool_error = shellcheck_exit > 1

gitleaks = load_json(report_dir / "gitleaks.json", [])
if isinstance(gitleaks, list):
    gitleaks_findings = len(gitleaks)
elif isinstance(gitleaks, dict) and isinstance(gitleaks.get("findings"), list):
    gitleaks_findings = len(gitleaks.get("findings", []))
else:
    gitleaks_findings = 0

detect = load_json(report_dir / "detect-secrets.json", {})
detect_results = detect.get("results", {}) if isinstance(detect, dict) else {}
exclude_regex = re.compile(exclude_pattern) if exclude_pattern else None
detect_findings = 0
if isinstance(detect_results, dict):
    for filename, findings in detect_results.items():
        if exclude_regex and exclude_regex.search(str(filename)):
            continue
        if isinstance(findings, list):
            detect_findings += len(findings)

ansible_lint = load_json(report_dir / "ansible-lint.json", [])
if isinstance(ansible_lint, list):
    ansible_lint_findings = len(ansible_lint)
else:
    ansible_lint_findings = 0
syntax_failures = int(ansible_setup_exit != 0) + int(ansible_teardown_exit != 0)
findings_total = semgrep_findings_total + shellcheck_issue_count + gitleaks_findings + detect_findings + ansible_lint_findings + syntax_failures
summary = {
    "findings_total": findings_total,
    "semgrep_findings_total": semgrep_findings_total,
    "semgrep_high_critical": semgrep_high,
    "shellcheck_high_critical": shellcheck_high,
    "shellcheck_findings_total": shellcheck_issue_count,
    "shellcheck_non_gating_findings": max(shellcheck_issue_count - shellcheck_high, 0),
    "shellcheck_tool_error": shellcheck_tool_error,
    "gitleaks_findings": gitleaks_findings,
    "detect_secrets_findings": detect_findings,
    "ansible_lint_findings": ansible_lint_findings,
    "ansible_syntax_failures": syntax_failures,
    "shellcheck_exit_code": shellcheck_exit,
    "gitleaks_exit_code": gitleaks_exit,
    "ansible_lint_exit_code": ansible_lint_exit,
    "ansible_setup_syntax_exit_code": ansible_setup_exit,
    "ansible_teardown_syntax_exit_code": ansible_teardown_exit,
    "high_critical_total": semgrep_high + shellcheck_high + gitleaks_findings + detect_findings + ansible_lint_findings + syntax_failures,
    "gate_failed": findings_total > 0,
}
(report_dir / "sast-summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print("Static Application Security Testing (SAST) summary")
print(json.dumps(summary, indent=2))
if summary["gate_failed"]:
    print("Static Application Security Testing (SAST) gate failed: findings detected.")
    raise SystemExit(1)
PY
  echo "Static Application Security Testing (SAST) checks completed."
}

run_sast_lane
#R015: DAST is intentionally not executed; step-05 remains SAST-only by design.
#R030: Emit deterministic final completion output including report location.
echo "Security checks completed. Reports: ${REPORT_DIR}"
