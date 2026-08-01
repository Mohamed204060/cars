# Package Manifest — cars_postgresql_validation_ready_v2.1

## Purpose
Clean restart package addressing the programming platform's objections without rewriting migration history.

## Included governance
- CR-011: full schema drift scope (52 tables).
- CR-012: live-validation corrective fixes, owner-approved for execution.

## Database history
- Immutable migrations: 000-021 (22 files, byte-for-byte verified).
- Corrective migration: 022 (new file, no retroactive edits).

## Verification performed here
- Python syntax: 91 files, 0 errors.
- Workflow YAML: valid.
- Schema expected baseline: 52 tables, 336 columns, 52 PKs, 33 FKs.
- Local full regression: 361 passed.

## Verification still required externally
- Apply 23 migrations on PostgreSQL 16.
- Repository tests: 14 passed, 0 skipped.
- Integration tests: 10 passed.
- Schema drift check: 52 tables and no unapproved drift.
- Review GitHub Actions Artifact before phase closure.
