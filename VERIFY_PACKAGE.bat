@echo off
setlocal enabledelayedexpansion
set missing=0
for %%F in (
 ".github\workflows\postgresql-validation.yml"
 "postgres_execution_package\README.md"
 "postgres_execution_package\requirements.txt"
 "postgres_execution_package\scripts\setup_test_database.sh"
 "postgres_execution_package\scripts\teardown_test_database.sh"
 "postgres_execution_package\tools\schema_drift_check.py"
 "postgres_execution_package\tests\conftest.py"
 "postgres_execution_package\tests\test_postgres_repositories.py"
 "postgres_execution_package\tests\test_postgres_integration.py"
) do (
  if exist %%F (echo FOUND: %%~F) else (echo MISSING: %%~F & set /a missing+=1)
)
set count=0
for %%F in (postgres_execution_package\migrations\*.sql) do set /a count+=1
echo migration_count=!count!
if not !count!==23 set /a missing+=1
if not !missing!==0 (
  echo PACKAGE FAILED
  exit /b 1
)
echo PACKAGE OK
exit /b 0
