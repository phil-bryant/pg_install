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

