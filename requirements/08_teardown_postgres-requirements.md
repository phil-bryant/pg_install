# Teardown Postgres Requirements

## Scope

Applies to `08_teardown_postgres.sh`.

R001 Statement: Orchestrate destructive PostgreSQL teardown via the Ansible teardown playbook.
Design: `08_teardown_postgres.sh` invokes `${VENV_DIR}/bin/ansible-playbook teardown.yml -e confirm_teardown=yes` after preflight checks and an interactive confirmation prompt succeed.
Tests:
- `tests/sh/08_teardown_postgres.bats` confirms the script reaches the playbook invocation when preflight and confirmation succeed.

R200 Statement: Abort with guidance when no Python virtual environment is active.
Design: Read `$VIRTUAL_ENV`; when empty, print activation instructions referencing `source ${VENV_DIR}/bin/activate` and exit non-zero before invoking ansible.
Rationale: The script depends on tools provided by the project venv (ansible-playbook). Failing fast with instructions prevents partial runs against the wrong Python.
Tests:
- `tests/sh/08_teardown_postgres.bats` verifies the script exits non-zero and prints activation guidance when `VIRTUAL_ENV` is unset.

R210 Statement: Abort with guidance when the active virtual environment is not the expected project venv.
Design: Resolve both expected (`${SCRIPT_DIR}/${repo}-venv`) and current (`$VIRTUAL_ENV`) to absolute paths and compare; on mismatch, print deactivate/reactivate guidance and exit non-zero before invoking ansible.
Rationale: A different venv may have an incompatible ansible toolchain, leading to partial or incorrect destructive runs.
Tests:
- `tests/sh/08_teardown_postgres.bats` verifies the script exits non-zero and prints deactivate/reactivate guidance when `VIRTUAL_ENV` points at a different directory than the project venv.

R220 Statement: Require explicit 'yes' confirmation before invoking the destructive playbook.
Design: Prompt the operator and only invoke `ansible-playbook teardown.yml` when the input equals exactly `yes`; any other input exits 0 with a "cancelled" message.
Rationale: The teardown playbook is irreversible (drops databases, uninstalls the formula, removes data/config/logs). An explicit confirmation token guards against accidental invocation in a misclick or wrong-window scenario.
Tests:
- `tests/sh/08_teardown_postgres.bats` verifies that input other than `yes` exits 0 and does not invoke the playbook.
- `tests/sh/08_teardown_postgres.bats` verifies that input of `yes` proceeds to the playbook invocation.
