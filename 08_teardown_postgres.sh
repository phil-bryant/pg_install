#!/bin/bash
umask 007

set -e

# Get the expected virtual environment directory name
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DIRECTORY_NAME=$(basename "$SCRIPT_DIR")
VENV_DIR="${SCRIPT_DIR}/${CURRENT_DIRECTORY_NAME}-venv"

echo "============================================================"
echo "PostgreSQL Teardown Script"
echo "============================================================"
echo ""

ANSIBLE_PLAYBOOK="${VENV_DIR}/bin/ansible-playbook"

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ ERROR: Virtual environment not found!"
    echo ""
    echo "The virtual environment is required to run Ansible."
    echo "If PostgreSQL is installed but you need to tear it down,"
    echo "please first run:"
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

# Display warning
echo "============================================================"
echo "⚠️  WARNING: DESTRUCTIVE OPERATION"
echo "============================================================"
echo ""
echo "This script will COMPLETELY REMOVE PostgreSQL including:"
echo "  - PostgreSQL service"
echo "  - ALL databases and data"
echo "  - PostgreSQL installation"
echo "  - Configuration files"
echo "  - Log files"
echo ""
echo "A backup will be created before removal."
echo "Backups are preserved in: /opt/homebrew/var/backups/postgres"
echo ""
echo "============================================================"
echo ""

# Confirmation prompt
#R220: Require explicit 'yes' confirmation before invoking destructive teardown.
read -r -p "Type 'yes' to confirm teardown (or anything else to cancel): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo ""
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo "Running PostgreSQL teardown playbook..."
echo ""

# Run the Ansible playbook with confirmation
#R001: Invoke teardown.yml playbook to orchestrate destructive cleanup.
if "$ANSIBLE_PLAYBOOK" teardown.yml -e confirm_teardown=yes; then
    echo ""
    echo "============================================================"
    echo "✅ PostgreSQL Teardown Complete!"
    echo "============================================================"
    echo ""
    echo "PostgreSQL has been completely removed from your system."
    echo "Backups are preserved in: /opt/homebrew/var/backups/postgres"
    echo ""
else
    echo ""
    echo "❌ PostgreSQL teardown encountered errors. Please check the messages above."
    exit 1
fi

