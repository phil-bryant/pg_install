# Shell Script Requirements

## Overview
Requirements for all shell scripts and automation in this project.

R001  Set umask 007 in all scripts (PostgreSQL exception: use 0750 permissions manually)
Statement: All executable scripts must set umask 007 at startup. PostgreSQL-related operations should manually set permissions to 0750/0640 due to hardcoded restrictions.
Design: Place `umask 007` immediately after shebang, before any other commands. For PostgreSQL data directories, manually chmod to 0750 after creation since PostgreSQL rejects group write permissions (0770).
Rationale: Files created by scripts have secure permissions (660 rw-rw----, directories 770 rwxrwx---). Prevents accidental exposure of sensitive data. PostgreSQL hardcodes permission checks rejecting 0770; use 0750 for data directories while maintaining 0770 for general Homebrew operations. Consistent security model across automation.
Tests: 
- Verify `umask 007` present after shebang in all `.sh` scripts
- Execute script creating file → verify file permissions are 660
- Execute script creating directory → verify directory permissions are 770
- PostgreSQL data directories: verify 0750 (not 0770) if PostgreSQL is involved

