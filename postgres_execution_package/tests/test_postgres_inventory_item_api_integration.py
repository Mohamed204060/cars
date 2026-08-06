"""
test_postgres_inventory_item_api_integration.py — اختبارات تكامل حقيقية
لطبقة REST API لعنصر مخزون البائع على PostgreSQL حي، شاملة تخزين
Idempotency-Key الفعلي في sys.idempotency_keys (Migration 025)
=====================================================================
الحالة: Ready for PostgreSQL Execution — لم يُشغَّل أي اختبار هنا فعليًا بعد.
"""

import os
import uuid

import pytest
import psycopg2
import psycopg2.extras
from fastapi import FastAPI
from fastapi.testclient import TestClient

from auth_api import router as auth_router
from auth_repository import PostgresAuthRepository
from session_repository import PostgresSessionRepository
from store_api import router as store_router
from store_repository import PostgresStoreRepository
from pct_api import router as pct_router
from pct_repository import PostgresPctRepository
from inventory_item_api import router as inventory_router
from inventory_item_repository import PostgresInventoryItemRepository
from idempotency_repository import PostgresIdempotencyRepository
from credential_service import hash_password


DATABASE_URL = os.environ.get("TEST_DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/carparts_test")


@pytest.fixture
def conn():
    connection = psycopg2.connect(DATABASE_URL, cursor_factory=psycopg2.extras.RealDictCursor)
    yield connection
    connection.rollback()
    connection.close()


@pytest.fixture
def app_and_client(conn):
    app = FastAPI()
    app.include_router(auth_router)
    app.include_router(store_router)
    app.include_router(pct_router)
    app.include_router(inventory_router)
    app.state.auth_repository = PostgresAuthRepository(conn)
    app.state.session_repository = PostgresSessionRepository(conn)
    app.state.store_repository = PostgresStoreRepository(conn)
    app.state.pct_repository = PostgresPctRepository(conn)
    app.state.inventory_repository = PostgresInventoryItemRepository(conn)
    app.state.idempotency_repository = PostgresIdempotencyRepository(conn)
    client = TestClient(app, base_url="https://testserver")
    return app, client, conn


def _register_and_login(client, conn, email: str, role: str = "individual_seller") -> str:
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO iam.users (business_code, primary_role, account_type, status) "
        "VALUES (%s, %s, 'individual', 'active') RETURNING id",
        (f"USR-{uuid.uuid4().hex[:12]}", role),
    )
    user_id = cur.fetchone()["id"]
    cur.execute(
        "INSERT INTO iam.user_identities (user_id, provider_type_id, external_identifier, credential_secret_hash, verified_at, is_primary) "
        "SELECT %s, ip.id, %s, %s, now(), true FROM iam.identity_providers ip WHERE ip.code = 'email_password'",
        (user_id, email, hash_password("Str0ngPass1!")),
    )
    resp = client.post("/api/v1/auth/login", json={"login_identifier": email, "password": "Str0ngPass1!"})
    assert resp.status_code == 200, resp.text
    return user_id


def _make_approved_part(client, conn) -> str:
    cur = conn.cursor()
    cur.execute("INSERT INTO pct.categories DEFAULT VALUES RETURNING id")
    category_id = cur.fetchone()["id"]
    part_id = client.post("/api/v1/pct/parts", json={"category_id": category_id}).json()["id"]
    client.post(f"/api/v1/pct/parts/{part_id}/approve")
    return part_id


def _request_body(part_id: str) -> dict:
    return {"catalog_part_ref_id": part_id, "condition_ref_id": str(uuid.uuid4()),
            "pricing_mode": "contact_for_price", "quantity": 2}


class TestCreateItemOnLivePostgres:

    def test_owner_creates_item_via_session_derived_store(self, app_and_client):
        app, client, conn = app_and_client
        _register_and_login(client, conn, f"seller{uuid.uuid4().hex[:6]}@example.com")
        client.post("/api/v1/store/stores", json={})
        part_id = _make_approved_part(client, conn)

        resp = client.post("/api/v1/inventory-items", json=_request_body(part_id),
                            headers={"Idempotency-Key": str(uuid.uuid4())})
        assert resp.status_code == 201
        assert set(resp.json().keys()) == {"id", "business_code", "status"}

    def test_no_store_returns_403(self, app_and_client):
        app, client, conn = app_and_client
        _register_and_login(client, conn, f"nostore{uuid.uuid4().hex[:6]}@example.com")
        part_id = _make_approved_part(client, conn)

        resp = client.post("/api/v1/inventory-items", json=_request_body(part_id),
                            headers={"Idempotency-Key": str(uuid.uuid4())})
        assert resp.status_code == 403


class TestIdempotencyPersistedOnLivePostgres:
    """يثبت أن sys.idempotency_keys (Migration 025) يخزِّن ويُعيد النتيجة فعليًا."""

    def test_same_key_returns_identical_result_and_single_db_row(self, app_and_client):
        app, client, conn = app_and_client
        _register_and_login(client, conn, f"seller{uuid.uuid4().hex[:6]}@example.com")
        client.post("/api/v1/store/stores", json={})
        part_id = _make_approved_part(client, conn)

        key = str(uuid.uuid4())
        first = client.post("/api/v1/inventory-items", json=_request_body(part_id), headers={"Idempotency-Key": key})
        second = client.post("/api/v1/inventory-items", json=_request_body(part_id), headers={"Idempotency-Key": key})
        assert first.status_code == 201 and second.status_code == 201
        assert first.json() == second.json()

        cur = conn.cursor()
        cur.execute("SELECT count(*) AS c FROM sys.idempotency_keys WHERE idempotency_key = %s", (key,))
        assert cur.fetchone()["c"] == 1  # سجل واحد فقط رغم طلبين

        cur.execute("SELECT count(*) AS c FROM str.inventory_items WHERE id = %s", (first.json()["id"],))
        assert cur.fetchone()["c"] == 1  # لم يُنشأ عنصر مكرَّر


class TestOwnershipOnLivePostgres:

    def test_non_owner_cannot_archive(self, app_and_client):
        app, client, conn = app_and_client
        _register_and_login(client, conn, f"owner{uuid.uuid4().hex[:6]}@example.com")
        client.post("/api/v1/store/stores", json={})
        part_id = _make_approved_part(client, conn)
        item_id = client.post("/api/v1/inventory-items", json=_request_body(part_id),
                               headers={"Idempotency-Key": str(uuid.uuid4())}).json()["id"]

        client.post("/api/v1/auth/logout")
        _register_and_login(client, conn, f"stranger{uuid.uuid4().hex[:6]}@example.com")
        resp = client.post(f"/api/v1/inventory/items/{item_id}/archive")
        assert resp.status_code == 403
