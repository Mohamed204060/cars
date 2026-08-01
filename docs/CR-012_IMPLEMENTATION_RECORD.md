# CR-012 — PostgreSQL Live-Validation Corrective Changes

## Status
Approved by the project owner for implementation in this package. Final phase closure remains conditional on real GitHub Actions evidence and programming-platform review.

## Scope
1. Preserve migrations 000–021 byte-for-byte.
2. Add migration `022_postgresql_validation_runtime_fixes.sql` to:
   - widen `str.inventory_items.pricing_mode` for `contact_for_price`;
   - enforce append-only behavior on `ntf.template_versions`.
3. Correct mandatory `business_code` values in affected Inventory and Order repository inserts.
4. Update only the tests needed to prove these corrections.

## Acceptance criteria
- Clean execution of migrations 000–022.
- Repository tests: 14 passed, 0 skipped.
- Integration tests: 10 passed, 0 skipped.
- Schema Drift: 52 tables checked with every difference classified.
- Full Regression: 361 passed.

## Baseline protection
No migration from 000 through 021 may be edited. Their SHA-256 values are recorded in `IMMUTABLE_MIGRATIONS_000_021.sha256`.
