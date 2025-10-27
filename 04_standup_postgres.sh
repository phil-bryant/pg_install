#!/bin/bash

set -e

# Get the expected virtual environment directory name
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DIRECTORY_NAME=$(basename "$SCRIPT_DIR")
VENV_DIR="${SCRIPT_DIR}/${CURRENT_DIRECTORY_NAME}-venv"

echo "============================================================"
echo "PostgreSQL Standup Script"
echo "============================================================"
echo ""

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "❌ ERROR: Virtual environment not found!"
    echo ""
    echo "Please run the setup scripts first:"
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

# Display environment variables reminder
echo "============================================================"
echo "Optional: Set Password Environment Variables"
echo "============================================================"
echo "You can set custom passwords (recommended for production):"
echo ""
echo "  export POSTGRES_ADMIN_PASSWORD=\"your_secure_admin_password\""
echo "  export APP_OWNER_PASSWORD=\"your_secure_owner_password\""
echo "  export APP_USER_PASSWORD=\"your_secure_user_password\""
echo "  export APP_READONLY_PASSWORD=\"your_secure_readonly_password\""
echo ""
echo "If not set, default passwords will be used."
echo "============================================================"
echo ""

# Run the Ansible playbook
echo "Running PostgreSQL setup playbook..."
echo ""

if ansible-playbook setup.yml; then
    echo ""
    echo "============================================================"
    echo "✅ PostgreSQL Setup Complete!"
    echo "============================================================"
    echo ""
    echo "You can now connect to PostgreSQL with:"
    echo "  PAGER='' PGPASSWORD=changeme_owner /opt/homebrew/opt/postgresql@15/bin/psql -h localhost -p 5432 -U app_owner -d myapp_db"
    echo ""
    echo "Or use the psql alias if PostgreSQL bin is in your PATH:"
    echo "  PAGER='' PGPASSWORD=changeme_owner psql -h localhost -p 5432 -U app_owner -d myapp_db"
    echo ""
else
    echo ""
    echo "❌ PostgreSQL setup failed. Please check the error messages above."
    exit 1
fi

