# Ansible Requirements

## Overview
Requirements for all Ansible playbooks and tasks in this project.

R001  Set umask 007 for all Ansible operations (PostgreSQL data directory exception: umask 027)
Statement: All Ansible playbooks must execute with umask 007, ensuring files and directories created have secure permissions. PostgreSQL data directory operations use umask 027 due to hardcoded permission requirements.
Design: Tasks that create files/directories via shell commands (e.g., initdb) must include `umask 007 &&` prefix and set `UMASK: "007"` in environment. PostgreSQL initialization uses `umask 027 &&` for data directory creation. File/directory modules must explicitly set mode '0660' (files) or '0770' (directories) for general operations. PostgreSQL data directory uses '0640' (files) or '0750' (directories). Add post-operation file tasks to ensure permissions on files modified by lineinfile/blockinfile.
Rationale: Files created by Ansible operations require secure permissions. PostgreSQL hardcodes a permission check in miscinit.c that rejects data directories with group write access (0770), requiring 0700 or 0750. For multi-user Homebrew setups where multiple users (cursor/phil) share Homebrew (requiring 0770), the hybrid approach uses 0750 for PostgreSQL data directory (group read/execute, no write) while maintaining 0770 for Homebrew management. This allows both users to run brew commands, start/stop services, and connect to PostgreSQL as clients while PostgreSQL accepts the permissions.
Alternatives: 
- Use 0700 for all: Breaks multi-user Homebrew access
- Use 0770 everywhere: PostgreSQL refuses to start
- Dedicated postgres user: More complex, requires sudo
Tests: 
- Verify shell tasks that create files include `umask 007 &&` prefix (or `umask 027 &&` for PostgreSQL)
- Execute playbook → verify PostgreSQL data directory has 750 after initdb
- Execute playbook → verify PostgreSQL config files have 640 permissions (pg_hba.conf, postgresql.conf)
- Execute playbook → verify all created directories have 750 permissions (PostgreSQL data, log, backup)
- Verify PostgreSQL starts without permission errors
Refs: shell-script-requirements.md R001

