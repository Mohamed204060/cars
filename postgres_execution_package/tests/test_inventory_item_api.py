"""
test_inventory_item_api.py — اختبارات وحدة لطبقة REST API لعنصر مخزون البائع
مطابقة حرفيًا للعقد المعتمَد أصلًا (openapi.yaml): store_id يُشتَق من الجلسة،
Idempotency-Key مطلوب لإنشاء العنصر، الاستجابة {id, business_code, status}.
"""

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from auth_api import router as auth_router
from auth_repository import InMemoryAuthRepository
from auth_service import IdentityProvider, UserIdentity
from session_repository import InMemorySessionRepository
from store_api import router as store_router
from store_repository import InMemoryStoreRepository
from pct_api import router as pct_router
from pct_repository import InMemoryPctRepository
from inventory_item_api import router as inventory_router
from inventory_item_repository import InMemoryInventoryItemRepository
from idempotency_repository import InMemoryIdempotencyRepository


@pytest.fixture
def app_and_client():
    app = FastAPI()
    app.include_router(auth_router)
    app.include_router(store_router)
    app.include_router(pct_router)
    app.include_router(inventory_router)

    providers = [IdentityProvider(code="email_password", display_name="كلمة المرور", category="password", is_enabled=True)]
    app.state.auth_repository = InMemoryAuthRepository(providers=providers, identities=[])
    app.state.session_repository = InMemorySessionRepository()
    app.state.store_repository = InMemoryStoreRepository()
    app.state.pct_repository = InMemoryPctRepository()
    app.state.inventory_repository = InMemoryInventoryItemRepository()
    app.state.idempotency_repository = InMemoryIdempotencyRepository()

    client = TestClient(app, base_url="https://testserver")
    return app, client


def _login_as(app, client, email: str, role: str = "individual_seller") -> str:
    repo = app.state.auth_repository
    user_id = repo.create_user()
    repo.set_user_role(user_id, role)
    identity = UserIdentity(id="", user_id=user_id, provider_code="email_password",
                             external_identifier=email, is_verified=True, is_primary=True)
    repo.insert_identity(identity, raw_password="Str0ngPass1!")
    resp = client.post("/api/v1/auth/login", json={"login_identifier": email, "password": "Str0ngPass1!"})
    assert resp.status_code == 200
    return user_id


def _make_own_store(client) -> str:
    return client.post("/api/v1/store/stores", json={}).json()["id"]


def _make_approved_part(client) -> str:
    part_id = client.post("/api/v1/pct/parts", json={"category_id": "cat-1"}).json()["id"]
    client.post(f"/api/v1/pct/parts/{part_id}/approve")
    return part_id


def _create_item_request_body(part_id: str) -> dict:
    return {
        "catalog_part_ref_id": part_id, "condition_ref_id": "cond-1",
        "pricing_mode": "contact_for_price", "quantity": 3,
    }


class TestCreateItemMatchesApprovedContract:

    def test_create_item_requires_idempotency_key_header(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "seller@example.com")
        _make_own_store(client)
        part_id = _make_approved_part(client)

        resp = client.post("/api/v1/inventory-items", json=_create_item_request_body(part_id))
        assert resp.status_code == 422  # Header مطلوب (required) مفقود

    def test_create_item_response_matches_minimal_contract_shape(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "seller2@example.com")
        _make_own_store(client)
        part_id = _make_approved_part(client)

        resp = client.post(
            "/api/v1/inventory-items", json=_create_item_request_body(part_id),
            headers={"Idempotency-Key": "key-abc-1"},
        )
        assert resp.status_code == 201
        body = resp.json()
        assert set(body.keys()) == {"id", "business_code", "status"}
        assert body["status"] == "active"
        assert body["business_code"].startswith("IT-")


class TestIdempotencyReplay:
    """DD الحزمة 2، القسم 2.2: نفس المفتاح يُعيد نفس النتيجة دون تنفيذ ثانٍ."""

    def test_same_key_returns_same_result_without_duplicate_creation(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "seller4@example.com")
        _make_own_store(client)
        part_id = _make_approved_part(client)

        first = client.post(
            "/api/v1/inventory-items", json=_create_item_request_body(part_id),
            headers={"Idempotency-Key": "same-key-1"},
        )
        second = client.post(
            "/api/v1/inventory-items", json=_create_item_request_body(part_id),
            headers={"Idempotency-Key": "same-key-1"},
        )
        assert first.status_code == 201
        assert second.status_code == 201
        assert first.json() == second.json()  # نفس id، لا عنصر جديد

    def test_different_key_creates_a_new_item(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "seller5@example.com")
        _make_own_store(client)
        part_id = _make_approved_part(client)

        first = client.post(
            "/api/v1/inventory-items", json=_create_item_request_body(part_id),
            headers={"Idempotency-Key": "key-A"},
        )
        second = client.post(
            "/api/v1/inventory-items", json=_create_item_request_body(part_id),
            headers={"Idempotency-Key": "key-B"},
        )
        assert first.json()["id"] != second.json()["id"]

    def test_failed_request_not_cached_can_retry_same_key(self, app_and_client):
        """طلب فاشل (قطعة غير معتمَدة) لا يُخزَّن؛ إعادة المحاولة بنفس المفتاح
        بعد إصلاح السبب يجب أن تنجح، لا أن تُعيد فشلًا مخزَّنًا."""
        app, client = app_and_client
        _login_as(app, client, "seller6@example.com")
        _make_own_store(client)
        unapproved_part_id = client.post("/api/v1/pct/parts", json={"category_id": "cat-1"}).json()["id"]

        first = client.post(
            "/api/v1/inventory-items", json=_create_item_request_body(unapproved_part_id),
            headers={"Idempotency-Key": "retry-key"},
        )
        assert first.status_code == 409

        client.post(f"/api/v1/pct/parts/{unapproved_part_id}/approve")
        second = client.post(
            "/api/v1/inventory-items", json=_create_item_request_body(unapproved_part_id),
            headers={"Idempotency-Key": "retry-key"},
        )
        assert second.status_code == 201  # نجحت هذه المرة؛ الفشل الأول لم يُخزَّن


class TestStoreDerivedFromSession:

    def test_no_store_returns_403(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "nostoreuser@example.com")  # لم يُنشئ متجرًا
        part_id = "some-part"

        resp = client.post(
            "/api/v1/inventory-items", json=_create_item_request_body(part_id),
            headers={"Idempotency-Key": "no-store-key"},
        )
        assert resp.status_code == 403
        assert resp.json()["detail"]["error_code"] == "STORE_NOT_ACTIVE_OR_NOT_OWNED"

    def test_item_created_under_correct_owned_store(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "seller7@example.com")
        store_id = _make_own_store(client)
        part_id = _make_approved_part(client)

        item_id = client.post(
            "/api/v1/inventory-items", json=_create_item_request_body(part_id),
            headers={"Idempotency-Key": "own-store-key"},
        ).json()["id"]

        full_item = client.get(f"/api/v1/inventory/items/{item_id}").json()
        assert full_item["store_id"] == store_id


class TestUnapprovedPartRejected:

    def test_unapproved_part_rejected(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "seller8@example.com")
        _make_own_store(client)
        unapproved_part_id = client.post("/api/v1/pct/parts", json={"category_id": "cat-1"}).json()["id"]

        resp = client.post(
            "/api/v1/inventory-items", json=_create_item_request_body(unapproved_part_id),
            headers={"Idempotency-Key": "unapproved-key"},
        )
        assert resp.status_code == 409
        assert resp.json()["detail"]["error_code"] == "PART_NOT_APPROVED"


class TestOwnershipEnforcedOnMutations:
    """REQ-STR-019: التعديل مقصور على البائع المالك فقط."""

    def _create_item(self, app, client, key: str = "setup-key"):
        _make_own_store(client)
        part_id = _make_approved_part(client)
        resp = client.post(
            "/api/v1/inventory-items", json=_create_item_request_body(part_id),
            headers={"Idempotency-Key": key},
        )
        return resp.json()["id"]

    def test_non_owner_cannot_update_quantity(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "owner1@example.com")
        item_id = self._create_item(app, client, "k1")

        client.post("/api/v1/auth/logout")
        _login_as(app, client, "stranger1@example.com")
        resp = client.patch(f"/api/v1/inventory/items/{item_id}/quantity", json={"new_quantity": 10})
        assert resp.status_code == 403

    def test_owner_can_update_quantity(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "owner2@example.com")
        item_id = self._create_item(app, client, "k2")

        resp = client.patch(f"/api/v1/inventory/items/{item_id}/quantity", json={"new_quantity": 0})
        assert resp.status_code == 200
        assert resp.json()["status"] == "out_of_stock"

    def test_owner_can_archive_then_no_further_modification(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "owner3@example.com")
        item_id = self._create_item(app, client, "k3")

        archive_resp = client.post(f"/api/v1/inventory/items/{item_id}/archive")
        assert archive_resp.status_code == 200
        assert archive_resp.json()["status"] == "archived"

        resp = client.patch(f"/api/v1/inventory/items/{item_id}/quantity", json={"new_quantity": 5})
        assert resp.status_code == 409
        assert resp.json()["detail"]["error_code"] == "ITEM_ARCHIVED"

    def test_owner_can_hide_then_unhide(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "owner4@example.com")
        item_id = self._create_item(app, client, "k4")

        hide_resp = client.post(f"/api/v1/inventory/items/{item_id}/hide")
        assert hide_resp.status_code == 200
        assert hide_resp.json()["status"] == "hidden"

        unhide_resp = client.post(f"/api/v1/inventory/items/{item_id}/unhide")
        assert unhide_resp.status_code == 200
        assert unhide_resp.json()["status"] in ("active", "out_of_stock")

    def test_owner_can_update_pricing(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "owner5@example.com")
        item_id = self._create_item(app, client, "k5")

        resp = client.patch(f"/api/v1/inventory/items/{item_id}/pricing",
                             json={"pricing_mode": "fixed_price", "price_amount": 250.0, "price_currency": "SAR"})
        assert resp.status_code == 200
        assert resp.json()["price_amount"] == 250.0


class TestGetItem:

    def test_get_item_no_ownership_required(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "owner6@example.com")
        _make_own_store(client)
        part_id = _make_approved_part(client)
        item_id = client.post(
            "/api/v1/inventory-items", json=_create_item_request_body(part_id),
            headers={"Idempotency-Key": "get-test-key"},
        ).json()["id"]

        client.post("/api/v1/auth/logout")
        _login_as(app, client, "anyone@example.com")
        resp = client.get(f"/api/v1/inventory/items/{item_id}")
        assert resp.status_code == 200

    def test_get_nonexistent_item_404(self, app_and_client):
        app, client = app_and_client
        _login_as(app, client, "getter@example.com")
        resp = client.get("/api/v1/inventory/items/ghost")
        assert resp.status_code == 404
