#!/bin/bash
umask 007

set -e

# Get the expected virtual environment directory name
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DIRECTORY_NAME=$(basename "$SCRIPT_DIR")
VENV_DIR="${SCRIPT_DIR}/${CURRENT_DIRECTORY_NAME}-venv"
POSTGRES_FORMULA=$(awk -F': *' '/^postgres_formula:/{gsub(/"/,"",$2); print $2; exit}' "$SCRIPT_DIR/vars/postgres.yml")
POSTGRES_PORT=$(awk -F': *' '/^postgres_port:/{gsub(/"/,"",$2); print $2; exit}' "$SCRIPT_DIR/vars/postgres.yml")
APP_DATABASE=$(awk -F': *' '/^app_database:/{gsub(/"/,"",$2); print $2; exit}' "$SCRIPT_DIR/vars/postgres.yml")
[ -n "$POSTGRES_FORMULA" ] || POSTGRES_FORMULA="postgresql@17"
[ -n "$POSTGRES_PORT" ] || POSTGRES_PORT="5432"
[ -n "$APP_DATABASE" ] || APP_DATABASE="myapp_db"

# R300: TLS knobs surfaced as CLI flags.
#R320: Variable defaults for TLS knobs live in vars/postgres.yml; this script
# only forwards values when the operator overrides them via flags.
SSL_REGENERATE="false"
SSL_BACKEND=""
SSL_DISK_DIR=""
SSL_1PSA_ITEM=""

usage() {
    cat <<EOF
Usage: $0 [options]

TLS / SSL options:
  --regenerate-cert           Force regeneration of the server cert and key.
  --ssl-backend=disk|1psa     Where TLS material is stored (default: disk).
  --ssl-dir=PATH              For disk backend: directory holding cert/key (gitignored).
                              Default: \$REPO/.secrets/tls
  --ssl-1psa-item=NAME        For 1psa backend: 1Password item name.
  -h, --help                  Show this help.

Environment variables (still honored):
  APP_OWNER_PASSWORD, APP_USER_PASSWORD, APP_READONLY_PASSWORD
EOF
}

EXTRA_VARS=()
#R300: Recognize TLS-related CLI flags; reject unknown options with usage.
for arg in "$@"; do
    case "$arg" in
        --regenerate-cert) SSL_REGENERATE="true" ;;
        --ssl-backend=disk|--ssl-backend=1psa) SSL_BACKEND="${arg#*=}" ;;
        --ssl-dir=*) SSL_DISK_DIR="${arg#*=}" ;;
        --ssl-1psa-item=*) SSL_1PSA_ITEM="${arg#*=}" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $arg"; usage; exit 2 ;;
    esac
done

#R310: Pass parsed TLS knobs to ansible-playbook as extra-vars.
#R330: Cert generation is delegated to tasks/tls_material.yml when ssl=on.
#R340: Renewal-window/force-flag decision lives in tasks/tls_material.yml.
#R350: Disk-backend layout (0700 dir, 0600 files, gitignored) is enforced there.
#R360: Installation of cert/key/ca into postgres_data_dir is performed there.
#R370: postgresql.conf ssl_*/ssl_min_protocol_version lines are written by setup.yml when ssl=on.
#R380: pg_hba.conf is rendered with hostssl/hostnossl-reject rules by setup.yml when ssl=on.
#R390: Default postgres_ssl is "on" in vars/postgres.yml; this script honors that default.
#R400: 1psa backend reads existing material via ../1psa/bin/1psa -f <item> <field> in tasks/tls_material.yml.
#R410: 1psa backend writes regenerated material via op item create|edit in tasks/tls_material.yml.
#R420: 1psa backend fails with brew/op-signin guidance when op CLI is unavailable.
EXTRA_VARS+=("postgres_ssl_regenerate=${SSL_REGENERATE}")
[ -n "$SSL_BACKEND" ]   && EXTRA_VARS+=("postgres_ssl_backend=${SSL_BACKEND}")
[ -n "$SSL_DISK_DIR" ]  && EXTRA_VARS+=("postgres_ssl_disk_dir=${SSL_DISK_DIR}")
[ -n "$SSL_1PSA_ITEM" ] && EXTRA_VARS+=("postgres_ssl_1psa_item=${SSL_1PSA_ITEM}")

echo "============================================================"
echo "PostgreSQL Standup Script"
echo "============================================================"
echo ""

ANSIBLE_PLAYBOOK="${VENV_DIR}/bin/ansible-playbook"

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ ERROR: Virtual environment not found!"
    echo ""
    echo "Please run the setup scripts first:"
    echo "  ./01_install_prerequisites.sh"
    echo "  ./02_create_venv.sh"
    echo "  activate"
    echo "  ./03_load_requirements.sh"
    exit 1
fi

# Check if virtual environment is active
if [ -z "${VIRTUAL_ENV:-}" ]; then
    #R200: Bail with activation guidance when no virtual environment is active.
    echo "❌ ERROR: No virtual environment is currently active!"
    echo ""
    echo "Please activate the virtual environment first:"
    echo "  source ${VENV_DIR}/bin/activate"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Verify the active venv is the expected one
EXPECTED_VENV_PATH=$(cd "$VENV_DIR" && pwd -P)
CURRENT_VENV_PATH=$(cd "$VIRTUAL_ENV" && pwd -P 2>/dev/null || echo "$VIRTUAL_ENV")
if [ "$CURRENT_VENV_PATH" != "$EXPECTED_VENV_PATH" ]; then
    #R210: Bail with deactivate/reactivate guidance when a different venv is active.
    echo "❌ ERROR: A different virtual environment is active!"
    echo "Expected: $EXPECTED_VENV_PATH"
    echo "Current:  $CURRENT_VENV_PATH"
    echo ""
    echo "Please deactivate and reactivate the correct virtual environment:"
    echo "  deactivate"
    echo "  source ${VENV_DIR}/bin/activate"
    exit 1
fi

if [ ! -x "$ANSIBLE_PLAYBOOK" ]; then
    echo "❌ ERROR: ${ANSIBLE_PLAYBOOK} not found or not executable."
    echo ""
    echo "Run the dependency setup for this virtual environment:"
    echo "  ./01_install_prerequisites.sh"
    echo "  ./02_create_venv.sh"
    echo "  activate"
    echo "  ./03_load_requirements.sh"
    exit 1
fi

# Display credential sourcing reminder
echo "============================================================"
echo "Credential Sources"
echo "============================================================"
echo "Postgres admin credentials are read from 1psa item: postgres_admin"
echo ""
echo "Application user passwords can still be overridden with env vars:"
echo "  export APP_OWNER_PASSWORD=\"your_secure_owner_password\""
echo "  export APP_USER_PASSWORD=\"your_secure_user_password\""
echo "  export APP_READONLY_PASSWORD=\"your_secure_readonly_password\""
echo ""
echo "If app env vars are not set, defaults from vars/postgres.yml are used."
echo "============================================================"
echo ""

# Run the Ansible playbook
echo "Running PostgreSQL setup playbook..."
echo ""

#R001: Invoke setup.yml playbook to orchestrate install/config/verify.
if "$ANSIBLE_PLAYBOOK" setup.yml -e "${EXTRA_VARS[*]}"; then
    echo ""
    echo "============================================================"
    echo "✅ PostgreSQL Setup Complete!"
    echo "============================================================"
    echo ""
    echo "You can now connect to PostgreSQL with:"
    echo "  PAGER='' PGPASSWORD=changeme_owner /opt/homebrew/opt/${POSTGRES_FORMULA}/bin/psql -h localhost -p ${POSTGRES_PORT} -U app_owner -d ${APP_DATABASE}"
    echo ""
    echo "Or use the psql alias if PostgreSQL bin is in your PATH:"
    echo "  PAGER='' PGPASSWORD=changeme_owner psql -h localhost -p ${POSTGRES_PORT} -U app_owner -d ${APP_DATABASE}"
    echo ""
else
    echo ""
    echo "❌ PostgreSQL setup failed. Please check the error messages above."
    exit 1
fi

