# Package Manifest — cars_postgresql_validation_complete_v3.0

## Purpose
A direct-root, complete GitHub repository package for PostgreSQL Validation, rebuilt and verified to address the programming platform's documented objections.

## Governance and change history
- CR-011: complete Schema Drift scope across 52 tables.
- CR-012: corrective live-validation changes, implemented without rewriting migration history.
- Migrations 000–021 remain byte-for-byte identical to the authoritative Project Baseline.
- Migration 022 contains the post-validation database corrections.

## Required runtime evidence
- 23 migrations applied from a clean database.
- Repository tests: 14 passed, 0 skipped.
- Integration tests: 10 passed, 0 skipped.
- Schema Drift: 52 tables checked; all differences classified.
- Full Regression: 361 passed.

## Build-time verification performed
- ZIP direct-root layout verified.
- Required files verified after two independent clean extractions.
- ZIP CRC verified.
- 23 migrations found.
- Migrations 000–021 verified against the Project Baseline.
- All Python files parsed successfully.
- Workflow YAML parsed successfully.
- Full Regression executed successfully on the build tree and on both extracted copies.
- Cache and compiled Python artifacts removed.
