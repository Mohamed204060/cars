# Corrected PostgreSQL Execution Package v2.0

This package is rebuilt from the clean validated baseline and does not reuse the rejected consolidated v1.5 package.

## Immutable migration policy
Migrations 000–021 remain byte-for-byte unchanged. Their SHA-256 values are recorded in `docs/IMMUTABLE_MIGRATIONS_000_021.sha256`.
All database corrections are introduced only through migration 022.

## Included changes
- CR-011: 52-table schema drift baseline, with PK/FK definition checks and reproducible golden snapshot.
- Real Auth repository test; no `SKIPPED` placeholder.
- Runtime test fixture corrections discovered by live PostgreSQL.
- Repository inserts supply mandatory `business_code` values.
- New immutable migration 022 expands `pricing_mode` and enforces NTF template-version append-only behavior.
- Complete 361-test regression snapshot and CI step.
- Improved CI diagnostics and 23-migration package verification.

## Governance warning
CR-011 is already recorded. The database/repository fixes are documented in `CR-012_POSTGRESQL_VALIDATION_FIXES_APPROVAL_REQUIRED.md`; obtain explicit project-owner/platform approval before declaring this package a new formal baseline.

## Static checks performed during build
- Original migrations preserved: 22/22.
- New migration count: 23 total.
- Python syntax verification: performed for every `.py` file.
- Full regression executed locally: 361 passed.
- PostgreSQL-specific tests require GitHub Actions/PostgreSQL 16 and are not claimed as passed by this build step.

Generated schema metadata: 52 primary keys and 33 foreign keys.
