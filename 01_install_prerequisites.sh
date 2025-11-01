#!/bin/bash
umask 007

set -e

# Configuration
PYTHON_VERSION="3.12"

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
