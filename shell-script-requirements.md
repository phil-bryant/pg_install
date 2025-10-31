# Shell Script Requirements

## Overview
Requirements for all shell scripts and automation in this project.

R001  Set umask 007 in all scripts
Statement: All executable scripts must set umask 007 at startup.
Design: Place `umask 007` immediately after shebang, before any other commands.
Rationale: Files created by scripts have secure permissions (660 rw-rw----, directories 770 rwxrwx---). Prevents accidental exposure of sensitive data (backups, configs, temp files). Consistent security model across automation.
Tests: 
- Verify `umask 007` present after shebang in all `.sh` scripts
- Execute script creating file → verify file permissions are 660
- Execute script creating directory → verify directory permissions are 770

