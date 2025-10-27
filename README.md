# PostgreSQL Automation for macOS

Complete automation solution for installing, configuring, securing, and managing PostgreSQL on macOS using **Homebrew + Ansible**.

## Features

✅ **Automated Setup Scripts** - Helper scripts for prerequisites, venv creation, and dependency installation  
✅ **Automated Installation** - Downloads and installs PostgreSQL 15 (stable LTS version)  
✅ **Idempotent** - Safe to run multiple times, only changes what's needed  
✅ **Secure by Default** - SCRAM-SHA-256 authentication, localhost-only, secure pg_hba.conf  
✅ **Complete Configuration** - Database, users, roles, tables, triggers, and sample data  
✅ **Full Teardown** - Complete cleanup with optional backup  
✅ **Production-Ready** - Logging, auditing, and proper permissions  

## Quick Start

```bash
# Step 1-4: Initial setup (one time)
./01_install_prerequisites.sh
./02_create_venv.sh
source pg_install-venv/bin/activate
./03_load_requirements.sh

# Step 5: Stand up PostgreSQL
./04_standup_postgres.sh

# Step 6: When done, tear down PostgreSQL
./05_teardown_postgres.sh
```

## Setup

### Prerequisites

Before running the setup scripts, you must have:

1. **macOS** (tested on macOS 10.15+)
2. **Homebrew** - Install from [https://brew.sh](https://brew.sh)
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

### Installation Steps

Run these scripts in order:

```bash
# Step 1: Check Homebrew is installed and install Python 3.12
./01_install_prerequisites.sh

# Step 2: Create virtual environment
./02_create_venv.sh

# Step 3: Activate the virtual environment
source pg_install-venv/bin/activate

# Step 4: Install Python dependencies (Ansible, psycopg2-binary)
./03_load_requirements.sh
```

### Configure Variables (Optional)

Edit `vars/postgres.yml` to customize:
- PostgreSQL version
- Database names
- User passwords (via environment variables)
- Port and connection settings

### Set Password Environment Variables (Recommended)

```bash
export POSTGRES_ADMIN_PASSWORD="your_secure_admin_password"
export APP_OWNER_PASSWORD="your_secure_owner_password"
export APP_USER_PASSWORD="your_secure_user_password"
export APP_READONLY_PASSWORD="your_secure_readonly_password"
```

If not set, default passwords will be used (change them in production!).

### Run PostgreSQL Setup

**Option 1: Using the wrapper script (easiest)**

```bash
# Run the setup script (it will auto-activate the venv)
./04_standup_postgres.sh
```

**Option 2: Using Ansible directly**

```bash
# Ensure virtual environment is activated
source pg_install-venv/bin/activate

# Run the Ansible playbook
ansible-playbook setup.yml
```

This will:
- ✅ Check if PostgreSQL is already installed
- ✅ Install PostgreSQL 15 via Homebrew (if needed)
- ✅ Configure PostgreSQL with secure settings
- ✅ Start the PostgreSQL service
- ✅ Create database, users, and roles
- ✅ Initialize schema (tables, indexes, triggers, functions)
- ✅ Populate with sample data
- ✅ Verify everything is working

### Connect to Database

```bash
# Connect as app_owner (full access to myapp_db)
psql -h localhost -p 5432 -U app_owner -d myapp_db

# Connect as app_user (read-write access)
psql -h localhost -p 5432 -U app_user -d myapp_db

# Connect as app_readonly (read-only access)
psql -h localhost -p 5432 -U app_readonly -d myapp_db
```

### Teardown (Complete Cleanup)

**Option 1: Using the wrapper script (easiest)**

```bash
# Run the teardown script (it will auto-activate the venv)
./05_teardown_postgres.sh
```

**Option 2: Using Ansible directly**

```bash
# Ensure virtual environment is activated
source pg_install-venv/bin/activate

# Run the teardown playbook
ansible-playbook teardown.yml
```

You'll be prompted to confirm. This will:
- ✅ Create final backup of all databases
- ✅ Stop PostgreSQL service
- ✅ Remove all data and configuration
- ✅ Uninstall PostgreSQL
- ✅ Clean up Homebrew cache
- ⚠️ Preserve backups (by default)