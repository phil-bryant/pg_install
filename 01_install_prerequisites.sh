#!/bin/bash
umask 007

set -e

# Configuration
PYTHON_VERSION="3.12"
ONE_PSA_REPO_URL="https://github.com/phil-bryant/1psa"
ONE_PSA_DIR="../1psa"

echo "============================================================"
echo "Prerequisites Installer"
echo "============================================================"
echo ""

# Check for Homebrew
echo "Checking for Homebrew..."
if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Homebrew is not installed."
    echo ""
    echo "Please install Homebrew first by running:"
    echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo ""
    echo "After installation, add Homebrew to your PATH and run this script again."
    echo "For more information, visit: https://brew.sh/"
    exit 1
else
    echo "✅ Homebrew is installed"
fi

# Install or update 1psa
echo ""
echo "Checking for 1psa source at ${ONE_PSA_DIR}..."
if [ ! -d "${ONE_PSA_DIR}/.git" ]; then
    if [ -d "${ONE_PSA_DIR}" ]; then
        echo "❌ ${ONE_PSA_DIR} exists but is not a git repository."
        exit 1
    fi
    echo "Cloning 1psa into ${ONE_PSA_DIR}..."
    git clone "${ONE_PSA_REPO_URL}" "${ONE_PSA_DIR}"
    echo "✅ 1psa cloned"
else
    echo "✅ 1psa repository already exists, pulling latest..."
    git -C "${ONE_PSA_DIR}" pull --ff-only
fi

# Check for $PYTHON_VERSION
echo ""
echo "Checking for Python ${PYTHON_VERSION}..."
if ! command -v python${PYTHON_VERSION} >/dev/null 2>&1; then
    echo "❌ Python ${PYTHON_VERSION} is not installed."
    echo ""
    echo "Installing Python ${PYTHON_VERSION} via Homebrew..."
    brew install python@${PYTHON_VERSION}
    
    # Verify installation
    if ! command -v python${PYTHON_VERSION} >/dev/null 2>&1; then
        echo "❌ Failed to install Python ${PYTHON_VERSION}"
        exit 1
    else
        echo "✅ Python ${PYTHON_VERSION} installed successfully"
    fi
else
    echo "✅ Python ${PYTHON_VERSION} is already installed"
fi

echo ""
echo "✅ All prerequisites are satisfied!"
