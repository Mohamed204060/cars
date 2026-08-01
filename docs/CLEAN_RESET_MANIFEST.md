# Clean PostgreSQL Reset Package v1.0

## Purpose
This package is a clean restart point for the GitHub repository after deletion of prior files.

## Source of truth
The `postgres_execution_package/` directory is copied byte-for-byte from the last standalone original package:

- `postgres_execution_package.zip`

No historical migration file (000–021) has been modified.
No previous patch v1.1–v1.4 has been merged.
No CR-011 candidate implementation has been merged.

## Included
- `.github/workflows/postgresql-validation.yml`
- complete `postgres_execution_package/`
- 22 migration files
- service/repository source files
- repository and integration tests
- setup/teardown scripts
- schema drift tool as found in the original package
- checksums

## Explicitly excluded
The following are intentionally NOT merged because they require separate review/governance or are not a clean historical baseline:

- modifications to `009_str.sql`
- modifications to `018_ntf.sql`
- repository patches adding `business_code`
- v1.1–v1.4 patch bundles
- consolidated v1.5 package
- CR-011 candidate implementation files

## Expected behavior
This is a reproducible baseline reset, not a claim that every validation test will pass. Running GitHub Actions may reproduce previously discovered failures. Those failures must be handled through approved changes and new migrations rather than retroactively changing migrations 000–021.
