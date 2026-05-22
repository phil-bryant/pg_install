# PostgreSQL Automation for macOS

Complete automation solution for installing, configuring, securing, and managing PostgreSQL on macOS using **Homebrew + Ansible**.

## Features

✅ **Automated Setup Scripts** - Helper scripts for prerequisites, venv creation, and dependency installation  
✅ **Automated Installation** - Downloads and installs PostgreSQL 17 (current supported target)  
✅ **Idempotent** - Safe to run multiple times, only changes what's needed  
✅ **Secure by Default** - SCRAM-SHA-256 authentication, localhost-only, secure pg_hba.conf  
✅ **Complete Configuration** - Database, users, roles, tables, triggers, and sample data  
✅ **Full Teardown** - Complete cleanup with optional backup  
✅ **Production-Ready** - Logging, auditing, and proper permissions  

## Quick Start

```bash
# Step 0: Verify requirement/source/test traceability
./00_verify_requirements_traceability.sh

# Step 1-3: Initial setup (one time)
./01_install_prerequisites.sh
./02_create_venv.sh
activate
./03_load_requirements.sh

# Step 4: Run AV checks
./04_run_av_checks.sh

# Step 5: Run security checks
./05_run_security_checks.sh

# Step 6: Run unit tests
./06_run_unit_tests.sh

# Step 7: Stand up PostgreSQL
./07_standup_postgres.sh

# Step 8: When done, tear down PostgreSQL
./08_teardown_postgres.sh
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
# Step 0: Verify requirement/source/test traceability
./00_verify_requirements_traceability.sh

# Step 1: Check Homebrew is installed and install Python 3.12
./01_install_prerequisites.sh

# Step 2: Create virtual environment
./02_create_venv.sh

# Step 3: Activate the virtual environment
activate

# Step 3: Install Python dependencies (Ansible, psycopg2-binary)
./03_load_requirements.sh
```

### Configure Variables (Optional)

Edit `vars/postgres.yml` to customize:
- PostgreSQL version
- Database names
- User passwords (via environment variables)
- Port and connection settings

### Version Policy and Major Upgrades

- Default runtime target is `postgresql@17`.
- Keep `postgres_version`, `postgres_formula`, `postgres_service_name`, and `postgres_*_dir` values aligned in `vars/postgres.yml`.
- If an existing data directory contains a different major version than `postgres_version`, `setup.yml` now fails fast.
- Before changing majors (example: `15 -> 17`), run a migration path (`pg_upgrade` or dump/restore), then rerun setup.

### Set Password Environment Variables (Recommended)

```bash
export POSTGRES_ADMIN_PASSWORD="your_secure_admin_password" # pragma: allowlist secret
export APP_OWNER_PASSWORD="your_secure_owner_password" # pragma: allowlist secret
export APP_USER_PASSWORD="your_secure_user_password" # pragma: allowlist secret
export APP_READONLY_PASSWORD="your_secure_readonly_password" # pragma: allowlist secret
```

If not set, default passwords will be used (change them in production!).

### Run Validation Checks

```bash
# Step 0: Requirement traceability verification
./00_verify_requirements_traceability.sh

# Step 4: AV checks (ClamAV lane)
./04_run_av_checks.sh

# Step 5: Security checks (SAST + ansible validations)
./05_run_security_checks.sh

# Step 6: Unit tests (bats/python/ansible)
./06_run_unit_tests.sh
```

### Run PostgreSQL Setup

**Option 1: Using the wrapper script (easiest)**

```bash
# Run the setup script (it will auto-activate the venv)
./07_standup_postgres.sh
```

**Option 2: Using Ansible directly**

```bash
# Ensure virtual environment is activated
activate

# Run the Ansible playbook
ansible-playbook setup.yml
```

This will:
- ✅ Check if PostgreSQL is already installed
- ✅ Install PostgreSQL 17 via Homebrew (if needed)
- ✅ Configure PostgreSQL with secure settings
- ✅ Start the PostgreSQL service
- ✅ Create database, users, and roles
- ✅ Initialize schema (tables, indexes, triggers, functions)
- ✅ Populate with sample data
- ✅ Verify everything is working

### Verify Runtime Version After Setup

```bash
brew services list | rg postgresql@
PAGER='' /opt/homebrew/opt/postgresql@17/bin/psql -h localhost -p 5432 -U app_owner -d postgres -t -A -c "SELECT version();"
```

Expected: service is `started` for `postgresql@17` and `SELECT version()` reports PostgreSQL 17.x.

### Connect to Database

PostgreSQL is now stood up with TLS required by default. Cert and key material is auto-generated on first run and renewed automatically when within 30 days of expiry. See "TLS / SSL" below for the knobs.

```bash
# Connect as app_owner (full access to myapp_db) — TLS verify-ca path
psql 'host=localhost port=5432 user=app_owner dbname=myapp_db sslmode=verify-ca sslrootcert=./.secrets/tls/root.crt'

# Or with sslmode=require (no CA verification, simpler)
psql 'host=localhost port=5432 user=app_owner dbname=myapp_db sslmode=require'

# app_user (read-write access)
psql 'host=localhost port=5432 user=app_user dbname=myapp_db sslmode=require'

# app_readonly (read-only access)
psql 'host=localhost port=5432 user=app_readonly dbname=myapp_db sslmode=require'
```

To verify TLS is enforced after setup:
```bash
# Should be rejected by pg_hba.conf:
psql 'host=localhost port=5432 user=app_owner dbname=myapp_db sslmode=disable'
```

### TLS / SSL

| Flag                          | Effect                                                                           |
|-------------------------------|----------------------------------------------------------------------------------|
| `--regenerate-cert`           | Force a fresh CA + server cert/key on this run.                                  |
| `--ssl-backend=disk`          | Store TLS material under `./.secrets/tls/` (gitignored). **Default.**            |
| `--ssl-backend=1psa`          | Store TLS material in 1Password (reads via `1psa`, writes via `op` CLI).         |
| `--ssl-dir=PATH`              | Override the disk-backend directory.                                             |
| `--ssl-1psa-item=NAME`        | Override the 1Password item name (default `localhost_postgres_tls`).             |

To disable TLS for a specific run (not recommended), use the playbook directly:
```bash
ansible-playbook setup.yml -e postgres_ssl=off
```

### Teardown (Complete Cleanup)

**Option 1: Using the wrapper script (easiest)**

```bash
# Run the teardown script (it will auto-activate the venv)
./08_teardown_postgres.sh
```

**Option 2: Using Ansible directly**

```bash
# Ensure virtual environment is activated
activate

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