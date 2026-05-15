#!/usr/bin/env bash
umask 007
#R001: Run with strict mode from script directory for deterministic relative paths.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON_VERSION="3.12"
PYTHON_COMMAND="python${PYTHON_VERSION}"
ONE_PSA_REPO_URL="https://github.com/phil-bryant/1psa"
ONE_PSA_DIR="../1psa"

require_homebrew() {
  #R005: Fail fast when Homebrew is unavailable with explicit install guidance.
  if command -v brew >/dev/null 2>&1; then return 0; fi
  echo "Homebrew is not installed."
  echo "Please install Homebrew first by running:"
  echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  echo "After installation, add Homebrew to your PATH and run this script again."
  echo "For more information, visit: https://brew.sh/"
  exit 1
}

ensure_1psa_repo() {
  #R010: Ensure 1psa dependency is cloned when missing and updated when present.
  if [ ! -d "${ONE_PSA_DIR}/.git" ]; then
    if [ -d "${ONE_PSA_DIR}" ]; then
      echo "${ONE_PSA_DIR} exists but is not a git repository."
      exit 1
    fi
    git clone "${ONE_PSA_REPO_URL}" "${ONE_PSA_DIR}"
    return 0
  fi
  git -C "${ONE_PSA_DIR}" pull --ff-only
}

ensure_python() {
  #R015: Install python3.12 via brew when missing, then fail if still unavailable.
  if command -v "${PYTHON_COMMAND}" >/dev/null 2>&1; then return 0; fi
  brew install "python@${PYTHON_VERSION}"
  if command -v "${PYTHON_COMMAND}" >/dev/null 2>&1; then return 0; fi
  echo "Failed to install Python ${PYTHON_VERSION}"
  exit 1
}

ensure_command() {
  local command_name="$1" formula_name="$2"
  #R020: Install required security/AV tools and verify command availability.
  if command -v "${command_name}" >/dev/null 2>&1; then return 0; fi
  brew install "${formula_name}"
  if command -v "${command_name}" >/dev/null 2>&1; then return 0; fi
  echo "Failed to install required command: ${command_name}"
  exit 1
}

require_homebrew
ensure_1psa_repo
ensure_python
ensure_command "semgrep" "semgrep"
ensure_command "shellcheck" "shellcheck"
ensure_command "gitleaks" "gitleaks"
ensure_command "detect-secrets" "detect-secrets"
ensure_command "clamscan" "clamav"
ensure_command "freshclam" "clamav"

#R025: Emit deterministic completion summary once all prerequisite checks pass.
echo "All prerequisites are satisfied."
