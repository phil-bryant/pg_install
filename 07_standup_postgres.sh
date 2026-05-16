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

if "$ANSIBLE_PLAYBOOK" setup.yml; then
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

