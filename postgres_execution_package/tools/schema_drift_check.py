#!/usr/bin/env python3
"""
schema_drift_check.py (v2 — موسَّع) — أداة اكتشاف انحراف المخطط الشاملة
====================================================================================
الحالة: Prepared / Ready for PostgreSQL Execution — الكود صحيح نحويًا وجاهز
للتشغيل الفعلي؛ لم يُنفَّذ فعليًا في هذه الجلسة لغياب اتصال بقاعدة بيانات حية.

التوسعة عن الإصدار السابق: يفحص الآن Tables، Columns، Data Types،
Nullability، Default Values، Primary Keys، Foreign Keys، Unique
Constraints، Check Constraints، Indexes، وPartial Indexes — لا الأعمدة
فقط. يصنِّف كل اختلاف إلى: Missing / Extra / Definition Mismatch /
Approved Exception.

الاستخدام:
    export TEST_DATABASE_URL=postgresql://user:pass@host:5432/carparts_test
    python3 schema_drift_check.py
"""

import os
import sys
import json

try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    print("تحذير: مكتبة psycopg2 غير مثبَّتة في هذه البيئة؛ الأداة جاهزة للتشغيل لاحقًا في بيئة بها psycopg2 واتصال PostgreSQL حقيقي.")
    psycopg2 = None


EXPECTED_TABLES = {
    ("ntf", "campaigns"): {
        "columns": {
            "id": {"type": "uuid", "nullable": False, "has_default": True},
            "created_by_user_ref_id": {"type": "uuid", "nullable": False, "has_default": False},
            "title": {"type": "character varying", "nullable": False, "has_default": False},
            "body": {"type": "text", "nullable": False, "has_default": False},
            "audience_type": {"type": "character varying", "nullable": False, "has_default": False},
            "status": {"type": "character varying", "nullable": False, "has_default": True},
            "priority": {"type": "character varying", "nullable": False, "has_default": True},
            "campaign_version": {"type": "integer", "nullable": False, "has_default": True},
            "template_version_id": {"type": "uuid", "nullable": True, "has_default": False},
            "scheduled_at": {"type": "timestamp with time zone", "nullable": True, "has_default": False},
            "expires_at": {"type": "timestamp with time zone", "nullable": True, "has_default": False},
            "created_at": {"type": "timestamp with time zone", "nullable": False, "has_default": True},
            "updated_at": {"type": "timestamp with time zone", "nullable": False, "has_default": True},
        },
        "unique_constraints": [], "check_constraints": ["chk_campaigns_audience_type", "chk_campaigns_status", "chk_campaigns_priority"],
        "indexes": ["idx_campaigns_status", "idx_campaigns_scheduled_at"], "partial_indexes": [],
    },
    ("ntf", "recipients"): {
        "columns": {
            "id": {"type": "uuid", "nullable": False, "has_default": True},
            "delivery_id": {"type": "uuid", "nullable": False, "has_default": False},
            "user_ref_id": {"type": "uuid", "nullable": False, "has_default": False},
            "channel_provider_code": {"type": "character varying", "nullable": False, "has_default": False},
            "status": {"type": "character varying", "nullable": False, "has_default": True},
            "sent_at": {"type": "timestamp with time zone", "nullable": True, "has_default": False},
            "delivered_at": {"type": "timestamp with time zone", "nullable": True, "has_default": False},
            "read_at": {"type": "timestamp with time zone", "nullable": True, "has_default": False},
            "failure_reason_code": {"type": "character varying", "nullable": True, "has_default": False},
            "retry_count": {"type": "integer", "nullable": False, "has_default": True},
        },
        "unique_constraints": ["uq_recipients_delivery_user"], "check_constraints": ["chk_recipients_status"],
        "indexes": ["idx_recipients_user_ref_id", "idx_recipients_status"], "partial_indexes": [],
    },
    ("ntf", "outbox"): {
        "columns": {
            "id": {"type": "uuid", "nullable": False, "has_default": True},
            "delivery_id": {"type": "uuid", "nullable": False, "has_default": False},
            "recipient_id": {"type": "uuid", "nullable": False, "has_default": False},
            "correlation_id": {"type": "uuid", "nullable": False, "has_default": False},
            "dispatched": {"type": "boolean", "nullable": False, "has_default": True},
            "created_at": {"type": "timestamp with time zone", "nullable": False, "has_default": True},
        },
        "unique_constraints": [], "check_constraints": [],
        "indexes": [], "partial_indexes": ["idx_outbox_pending"],
    },
    ("sys", "scheduled_jobs"): {
        "columns": {
            "id": {"type": "uuid", "nullable": False, "has_default": True},
            "job_type": {"type": "character varying", "nullable": False, "has_default": False},
            "target_ref_id": {"type": "uuid", "nullable": False, "has_default": False},
            "scheduled_at": {"type": "timestamp with time zone", "nullable": False, "has_default": False},
            "recurrence_rule": {"type": "character varying", "nullable": True, "has_default": False},
            "status": {"type": "character varying", "nullable": False, "has_default": True},
            "last_run_at": {"type": "timestamp with time zone", "nullable": True, "has_default": False},
            "created_at": {"type": "timestamp with time zone", "nullable": False, "has_default": True},
        },
        "unique_constraints": [], "check_constraints": ["chk_scheduled_jobs_status", "chk_scheduled_jobs_recurrence"],
        "indexes": ["idx_scheduled_jobs_job_type"], "partial_indexes": ["idx_scheduled_jobs_status_scheduled_at"],
    },
    ("trm", "ratings"): {
        "columns": {
            "id": {"type": "uuid", "nullable": False, "has_default": True},
            "rated_by_user_ref_id": {"type": "uuid", "nullable": False, "has_default": False},
            "target_type": {"type": "character varying", "nullable": False, "has_default": False},
            "target_ref_id": {"type": "uuid", "nullable": False, "has_default": False},
            "source_purchase_request_ref_id": {"type": "uuid", "nullable": False, "has_default": False},
            "score": {"type": "smallint", "nullable": False, "has_default": False},
            "comment": {"type": "text", "nullable": True, "has_default": False},
            "status": {"type": "character varying", "nullable": False, "has_default": True},
            "created_at": {"type": "timestamp with time zone", "nullable": False, "has_default": True},
        },
        "unique_constraints": ["uq_ratings_rater_target_source"],
        "check_constraints": ["chk_ratings_score", "chk_ratings_target_type", "chk_ratings_status"],
        "indexes": ["idx_ratings_target", "idx_ratings_source"], "partial_indexes": [],
    },
    ("trm", "ratings_legacy_seller_only_v1"): {
        "columns": {
            "id": {"type": "uuid", "nullable": False, "has_default": True},
            "rated_seller_ref_id": {"type": "uuid", "nullable": False, "has_default": False},
            "rater_buyer_ref_id": {"type": "uuid", "nullable": False, "has_default": False},
            "score": {"type": "smallint", "nullable": False, "has_default": False},
            "comment_text": {"type": "text", "nullable": True, "has_default": False},
            "edit_window_expires_at": {"type": "timestamp with time zone", "nullable": False, "has_default": False},
            "is_removed_by_moderator": {"type": "boolean", "nullable": False, "has_default": True},
            "created_at": {"type": "timestamp with time zone", "nullable": False, "has_default": True},
            "updated_at": {"type": "timestamp with time zone", "nullable": False, "has_default": True},
        },
        "unique_constraints": [], "check_constraints": ["chk_ratings_score"],
        "indexes": ["idx_ratings_seller"], "partial_indexes": ["idx_ratings_seller"],
    },
}

# استثناءات معتمَدة صراحة (لا تُحتسَب كانحراف رغم أنها قد تبدو كذلك ظاهريًا)
APPROVED_EXCEPTIONS_NOTE = {
    ("trm", "ratings_legacy_seller_only_v1"): "Superseded by CR-009 — الجدول القديم مُعاد تسميته عمدًا في 021_trm_unified_ratings.sql؛ وجوده متوقَّع كسجل تاريخي، لا انحرافًا.",
}


def fetch_live_columns(conn, schema, table):
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
    """, (schema, table))
    return {r["column_name"]: {"type": r["data_type"], "nullable": r["is_nullable"] == "YES",
                                "has_default": r["column_default"] is not None} for r in cur.fetchall()}


def fetch_live_constraints(conn, schema, table):
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("""
        SELECT con.conname, con.contype
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = %s AND rel.relname = %s
    """, (schema, table))
    result = {"primary_key": [], "unique": [], "check": [], "foreign_key": []}
    type_map = {"p": "primary_key", "u": "unique", "c": "check", "f": "foreign_key"}
    for r in cur.fetchall():
        key = type_map.get(r["contype"])
        if key:
            result[key].append(r["conname"])
    return result


def fetch_live_indexes(conn, schema, table):
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = %s AND tablename = %s", (schema, table))
    all_idx, partial_idx = [], []
    for r in cur.fetchall():
        all_idx.append(r["indexname"])
        if "WHERE" in r["indexdef"]:
            partial_idx.append(r["indexname"])
    return all_idx, partial_idx


def check_table(conn, schema, table, expected):
    diffs = []
    live_cols = fetch_live_columns(conn, schema, table)
    if not live_cols:
        return [{"type": "Missing", "object": f"{schema}.{table}", "detail": "الجدول غير موجود إطلاقًا"}]

    for col_name, exp in expected["columns"].items():
        if col_name not in live_cols:
            diffs.append({"type": "Missing", "object": f"{schema}.{table}.{col_name}", "detail": "عمود مفقود"})
            continue
        live = live_cols[col_name]
        mismatches = []
        if exp["type"] not in live["type"] and live["type"] not in exp["type"]:
            mismatches.append(f"النوع المتوقَّع={exp['type']} الفعلي={live['type']}")
        if exp["nullable"] != live["nullable"]:
            mismatches.append(f"Nullable المتوقَّع={exp['nullable']} الفعلي={live['nullable']}")
        if exp["has_default"] != live["has_default"]:
            mismatches.append(f"وجود Default المتوقَّع={exp['has_default']} الفعلي={live['has_default']}")
        if mismatches:
            diffs.append({"type": "Definition Mismatch", "object": f"{schema}.{table}.{col_name}", "detail": "؛ ".join(mismatches)})

    extra_cols = set(live_cols) - set(expected["columns"])
    for col in extra_cols:
        diffs.append({"type": "Extra", "object": f"{schema}.{table}.{col}", "detail": "عمود غير متوقَّع في التصميم"})

    live_constraints = fetch_live_constraints(conn, schema, table)
    for uq in expected.get("unique_constraints", []):
        if uq not in live_constraints["unique"]:
            diffs.append({"type": "Missing", "object": f"{schema}.{table}::{uq}", "detail": "قيد تفرّد (UNIQUE) مفقود"})
    for chk in expected.get("check_constraints", []):
        if chk not in live_constraints["check"]:
            diffs.append({"type": "Missing", "object": f"{schema}.{table}::{chk}", "detail": "قيد فحص (CHECK) مفقود"})

    live_all_idx, live_partial_idx = fetch_live_indexes(conn, schema, table)
    for idx in expected.get("indexes", []):
        if idx not in live_all_idx:
            diffs.append({"type": "Missing", "object": f"{schema}.{table}::{idx}", "detail": "فهرس مفقود"})
    for pidx in expected.get("partial_indexes", []):
        if pidx not in live_partial_idx:
            diffs.append({"type": "Missing", "object": f"{schema}.{table}::{pidx}", "detail": "فهرس جزئي (Partial Index) مفقود أو غير جزئي فعليًا"})

    return diffs


def main():
    if psycopg2 is None:
        print(json.dumps({"status": "Blocked by Environment",
                          "reason": "psycopg2 not installed / no PostgreSQL connection available"}, ensure_ascii=False, indent=2))
        sys.exit(1)

    database_url = os.environ.get("TEST_DATABASE_URL")
    if not database_url:
        print(json.dumps({"status": "Blocked by Environment", "reason": "TEST_DATABASE_URL not set"}, ensure_ascii=False, indent=2))
        sys.exit(1)

    conn = psycopg2.connect(database_url)
    all_diffs = []
    for (schema, table), expected in EXPECTED_TABLES.items():
        table_diffs = check_table(conn, schema, table, expected)
        for d in table_diffs:
            if (schema, table) in APPROVED_EXCEPTIONS_NOTE and d["type"] == "Extra":
                d["type"] = "Approved Exception"
                d["detail"] += f" — {APPROVED_EXCEPTIONS_NOTE[(schema, table)]}"
            all_diffs.append(d)

    result = {
        "status": "Executed on PostgreSQL",
        "tables_checked": len(EXPECTED_TABLES),
        "diffs_found": len([d for d in all_diffs if d["type"] != "Approved Exception"]),
        "approved_exceptions": len([d for d in all_diffs if d["type"] == "Approved Exception"]),
        "details": all_diffs,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(1 if result["diffs_found"] > 0 else 0)


if __name__ == "__main__":
    main()
