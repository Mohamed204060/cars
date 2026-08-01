#!/usr/bin/env python3
"""Audit helper for the committed CR-011 golden schema snapshot.

The runtime drift checker uses a committed EXPECTED_TABLES baseline. This helper
only reports reproducibility counts from the immutable pg_dump snapshot and does
not regenerate expectations from the database under test.
"""
from pathlib import Path
import json, re
schema = Path(__file__).with_name("golden_schema_run_30612887616.sql").read_text(encoding="utf-8")
tables = set(re.findall(r"CREATE TABLE ([\w]+)\.([\w]+) \(", schema))
constraints = re.findall(r"ALTER TABLE ONLY\s+([\w]+)\.([\w]+)\s+ADD CONSTRAINT\s+([\w]+)\s+(.+?);", schema, re.S)
result = {
    "tables": len(tables),
    "primary_keys": sum(1 for *_, d in constraints if " ".join(d.split()).startswith("PRIMARY KEY")),
    "foreign_keys": sum(1 for *_, d in constraints if " ".join(d.split()).startswith("FOREIGN KEY")),
}
print(json.dumps(result, indent=2))
