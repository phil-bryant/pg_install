#!/usr/bin/env bats

load "helpers/common.bash"

setup_fixture() {
  create_repo_fixture
  copy_script_to_fixture "01_install_prerequisites.sh"
}

setup() { setup_shell_test; setup_fixture; }
teardown() { teardown_shell_test; }

add_cmd_stub() {
  local name="$1"
  cat > "${STUB_BIN}/${name}" <<EOF
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${STUB_BIN}/${name}"
}

seed_installed_prereqs() {
  add_cmd_stub "brew"
  add_cmd_stub "git"
  add_cmd_stub "python3.12"
  add_cmd_stub "semgrep"
  add_cmd_stub "shellcheck"
  add_cmd_stub "gitleaks"
  add_cmd_stub "detect-secrets"
  add_cmd_stub "clamscan"
  add_cmd_stub "freshclam"
}

make_git_stub() {
  cat > "${STUB_BIN}/git" <<'EOF'
#!/usr/bin/env bash
echo "git $*" >> "${CALLS_LOG}"
if [ "$1" = "clone" ]; then mkdir -p "$3/.git"; fi
exit 0
EOF
  chmod +x "${STUB_BIN}/git"
}

make_brew_stub_installs_tools() {
  cat > "${STUB_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
echo "brew $*" >> "${CALLS_LOG}"
mkcmd() {
  cat > "${STUB_BIN}/$1" <<INNER
#!/usr/bin/env bash
exit 0
INNER
  chmod +x "${STUB_BIN}/$1"
}
if [ "$1" = "install" ]; then
  case "$2" in
    python@3.12) mkcmd "python3.12" ;;
    semgrep) mkcmd "semgrep" ;;
    shellcheck) mkcmd "shellcheck" ;;
    gitleaks) mkcmd "gitleaks" ;;
    detect-secrets) mkcmd "detect-secrets" ;;
    clamav) mkcmd "clamscan"; mkcmd "freshclam" ;;
  esac
fi
exit 0
EOF
  chmod +x "${STUB_BIN}/brew"
}

make_brew_stub_no_install_effect() {
  cat > "${STUB_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
echo "brew $*" >> "${CALLS_LOG}"
exit 0
EOF
  chmod +x "${STUB_BIN}/brew"
}

@test "runs from non-repo cwd and resolves paths from script root" {
  #R001 #R025
  seed_installed_prereqs
  make_git_stub
  mkdir -p "${TEST_TMPDIR}/1psa/.git" "${TEST_TMPDIR}/elsewhere"
  cd "${TEST_TMPDIR}/elsewhere"
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" bash "${FIXTURE_ROOT}/01_install_prerequisites.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All prerequisites are satisfied."* ]]
}

@test "fails clearly when Homebrew is missing" {
  #R005
  run env PATH="/usr/bin:/bin:/usr/sbin:/sbin" bash "${FIXTURE_ROOT}/01_install_prerequisites.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Homebrew is not installed"* ]]
}

@test "clones 1psa when missing and pulls when repository exists" {
  #R010
  seed_installed_prereqs
  make_git_stub
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" bash "${FIXTURE_ROOT}/01_install_prerequisites.sh"
  [ "$status" -eq 0 ]
  run python3 - "${CALLS_LOG}" "git clone" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
raise SystemExit(0 if sys.argv[2] in text else 1)
PY
  [ "$status" -eq 0 ]
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" bash "${FIXTURE_ROOT}/01_install_prerequisites.sh"
  [ "$status" -eq 0 ]
  run python3 - "${CALLS_LOG}" "git -C" "pull --ff-only" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
ok = sys.argv[2] in text and sys.argv[3] in text
raise SystemExit(0 if ok else 1)
PY
  [ "$status" -eq 0 ]
}

@test "installs python 3.12 when missing and fails if still unavailable" {
  #R015
  seed_installed_prereqs
  rm_stub="${STUB_BIN}/python3.12"
  mv "${rm_stub}" "${rm_stub}.off"
  make_git_stub
  make_brew_stub_installs_tools
  mkdir -p "${TEST_TMPDIR}/1psa/.git"
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" bash "${FIXTURE_ROOT}/01_install_prerequisites.sh"
  [ "$status" -eq 0 ]
  run python3 - "${CALLS_LOG}" "brew install python@3.12" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
raise SystemExit(0 if sys.argv[2] in text else 1)
PY
  [ "$status" -eq 0 ]

  mv "${STUB_BIN}/python3.12" "${STUB_BIN}/python3.12.installed"
  make_brew_stub_no_install_effect
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" bash "${FIXTURE_ROOT}/01_install_prerequisites.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Failed to install Python 3.12"* ]]
}

@test "installs missing security and AV tools and fails if one remains unavailable" {
  #R020
  seed_installed_prereqs
  make_git_stub
  make_brew_stub_installs_tools
  mkdir -p "${TEST_TMPDIR}/1psa/.git"
  mv "${STUB_BIN}/semgrep" "${STUB_BIN}/semgrep.off"
  mv "${STUB_BIN}/clamscan" "${STUB_BIN}/clamscan.off"
  mv "${STUB_BIN}/freshclam" "${STUB_BIN}/freshclam.off"
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" bash "${FIXTURE_ROOT}/01_install_prerequisites.sh"
  [ "$status" -eq 0 ]
  run python3 - "${CALLS_LOG}" "brew install semgrep" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
raise SystemExit(0 if sys.argv[2] in text else 1)
PY
  [ "$status" -eq 0 ]
  run python3 - "${CALLS_LOG}" "brew install clamav" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
raise SystemExit(0 if sys.argv[2] in text else 1)
PY
  [ "$status" -eq 0 ]

  mv "${STUB_BIN}/detect-secrets" "${STUB_BIN}/detect-secrets.off"
  make_brew_stub_no_install_effect
  run env PATH="${STUB_BIN}:/usr/bin:/bin:/usr/sbin:/sbin" bash "${FIXTURE_ROOT}/01_install_prerequisites.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Failed to install required command: detect-secrets"* ]]
}
