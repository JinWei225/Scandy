#!/bin/bash
#
# Run every test in this directory against the local Supabase stack.
#
#   ./supabase/tests/run.sh
#
# Uses `docker exec` into the stack's own database container rather than psql,
# because the Supabase CLI does not install a psql client and there is no
# reason to make you install Postgres locally just to run these.
#
# Each test file rolls back at the end, so this is safe to run repeatedly and
# leaves no rows behind. Exit code is 0 only if every file passes, so this
# works unchanged as a CI gate.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

DB="$(docker ps --format '{{.Names}}' | grep '^supabase_db_' | head -n 1)"
if [ -z "$DB" ]; then
    echo "The local Supabase stack is not running." >&2
    echo "  Start it with: supabase start" >&2
    exit 1
fi

FAILED=0
for test_file in supabase/tests/*.sql; do
    name="$(basename "$test_file")"
    output="$(docker exec -i "$DB" psql -U postgres -d postgres \
                  -v ON_ERROR_STOP=1 < "$test_file" 2>&1)"
    status=$?

    passed="$(printf '%s' "$output" | grep -c 'NOTICE:  PASS')"

    if [ $status -eq 0 ]; then
        printf '  \033[32m✓\033[0m %-30s %s checks\n' "$name" "$passed"
    else
        FAILED=1
        printf '  \033[31m✗\033[0m %-30s FAILED after %s checks\n' "$name" "$passed"
        printf '%s\n' "$output" | grep -E '^(ERROR|DETAIL|CONTEXT)' | sed 's/^/      /'
    fi
done

echo ""
if [ $FAILED -eq 0 ]; then
    printf '\033[32mAll suites passed.\033[0m\n'
else
    printf '\033[31mAt least one suite failed.\033[0m\n'
fi
exit $FAILED
