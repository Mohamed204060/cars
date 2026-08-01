#!/usr/bin/env bash
set -euo pipefail
required=(
  ".github/workflows/postgresql-validation.yml"
  "postgres_execution_package/README.md"
  "postgres_execution_package/requirements.txt"
  "postgres_execution_package/scripts/setup_test_database.sh"
  "postgres_execution_package/scripts/teardown_test_database.sh"
  "postgres_execution_package/tools/schema_drift_check.py"
  "postgres_execution_package/tests/conftest.py"
  "postgres_execution_package/tests/test_postgres_repositories.py"
  "postgres_execution_package/tests/test_postgres_integration.py"
)
missing=0
for f in "${required[@]}"; do
  if [[ -f "$f" ]]; then echo "FOUND: $f"; else echo "MISSING: $f" >&2; missing=$((missing+1)); fi
done
count=$(find postgres_execution_package/migrations -maxdepth 1 -type f -name '*.sql' | wc -l | tr -d ' ')
echo "migration_count=$count"
[[ "$count" == "23" ]] || { echo "Expected 23 migrations" >&2; exit 1; }
[[ "$missing" == "0" ]] || exit 1
echo "PACKAGE OK"
