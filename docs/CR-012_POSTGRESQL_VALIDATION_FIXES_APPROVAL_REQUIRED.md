# CR-012 — PostgreSQL live-validation corrective changes (approval record)

## Status
Implementation candidate included for review/approval before the new package is treated as a formal baseline.

## Why this change exists
Live PostgreSQL execution exposed three mismatches that cannot be corrected by rewriting immutable migrations 000–021:

1. `str.inventory_items.pricing_mode` was `VARCHAR(16)`, while the approved value `contact_for_price` requires more capacity.
2. `ntf.template_versions` was described as append-only, but the database did not enforce UPDATE/DELETE prevention.
3. Inventory/PUR repository INSERT statements omitted mandatory `business_code` columns.

## Approved implementation shape requested
- Preserve migrations 000–021 byte-for-byte.
- Add migration `022_postgresql_validation_runtime_fixes.sql`.
- Update only the affected repository INSERT statements.
- Update the live PostgreSQL tests that prove the fixes.
- No new business feature or architecture change.

## Acceptance criteria
- Clean database applies migrations 000–022 in order.
- Repository suite: 14 passed, 0 skipped.
- Integration suite: 10 passed, 0 skipped.
- Schema drift: 52 tables checked, including PK/FK checks, with no unapproved drift.
- Full regression: 361 passed, 0 failed.
