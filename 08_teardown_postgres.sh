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

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ ERROR: Virtual environment not found!"
    echo ""
    echo "The virtual environment is required to run Ansible."
    echo "If PostgreSQL is installed but you need to tear it down,"
    echo "please first run:"
    echo "  ./01_install_prerequisites.sh"
    echo "  ./02_create_venv.sh"
    echo "  source ${CURRENT_DIRECTORY_NAME}-venv/bin/activate"
    echo "  ./03_load_requirements.sh"
    exit 1
fi

# Check if virtual environment is active
if [ -z "$VIRTUAL_ENV" ]; then
    echo "Virtual environment not active. Activating..."
    source "$VENV_DIR/bin/activate"
    if [ -z "$VIRTUAL_ENV" ]; then
        echo "❌ ERROR: Failed to activate virtual environment"
        exit 1
    fi
    echo "✅ Virtual environment activated"
    echo ""
fi

# Verify we're in the correct virtual environment
EXPECTED_VENV_PATH=$(cd "$VENV_DIR" && pwd -P)
CURRENT_VENV_PATH=$(cd "$VIRTUAL_ENV" && pwd -P 2>/dev/null || echo "$VIRTUAL_ENV")

if [ "$CURRENT_VENV_PATH" != "$EXPECTED_VENV_PATH" ]; then
    echo "⚠️  WARNING: You are using a different virtual environment!"
    echo "Expected: $EXPECTED_VENV_PATH"
    echo "Current:  $CURRENT_VENV_PATH"
    echo ""
    echo "Activating the correct virtual environment..."
    deactivate 2>/dev/null || true
    source "$VENV_DIR/bin/activate"
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
read -p "Type 'yes' to confirm teardown (or anything else to cancel): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo ""
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo "Running PostgreSQL teardown playbook..."
echo ""

# Run the Ansible playbook with confirmation
if ansible-playbook teardown.yml -e confirm_teardown=yes; then
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

