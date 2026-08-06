"""
idempotency_repository.py — طبقة الوصول للبيانات لمخزن مفاتيح عدم التكرار
المرجع: Migration 025 (sys.idempotency_keys)؛ DD الحزمة 2، القسم 2.2
"""

import json
from abc import ABC, abstractmethod
from typing import Any, Dict, Optional


class IdempotencyRepository(ABC):

    @abstractmethod
    def get_cached_response(self, idempotency_key: str, user_id: str, endpoint: str) -> Optional[Dict[str, Any]]:
        """يُعيد {'response_status': int, 'response_body': dict} أو None."""
        raise NotImplementedError

    @abstractmethod
    def store_response(self, idempotency_key: str, user_id: str, endpoint: str,
                        response_status: int, response_body: Dict[str, Any]) -> None:
        raise NotImplementedError


class PostgresIdempotencyRepository(IdempotencyRepository):

    def __init__(self, connection):
        self._connection = connection

    def get_cached_response(self, idempotency_key: str, user_id: str, endpoint: str) -> Optional[Dict[str, Any]]:
        with self._connection.cursor() as cur:
            cur.execute(
                "SELECT response_status, response_body FROM sys.idempotency_keys "
                "WHERE idempotency_key = %(key)s AND user_ref_id = %(user_id)s AND endpoint = %(endpoint)s",
                {"key": idempotency_key, "user_id": user_id, "endpoint": endpoint},
            )
            row = cur.fetchone()
        if row is None:
            return None
        body = row["response_body"]
        if isinstance(body, str):
            body = json.loads(body)
        return {"response_status": row["response_status"], "response_body": body}

    def store_response(self, idempotency_key: str, user_id: str, endpoint: str,
                        response_status: int, response_body: Dict[str, Any]) -> None:
        # يعتمد على uq_idempotency_key_user_endpoint؛ محاولة تخزين مزدوجة
        # متزامنة لنفس المفتاح تفشل بانتهاك تفرّد بدلاً من تكرار صامت — وهذا
        # سلوك آمن ومقبول هنا (الطلب الثاني سيقرأ النتيجة المخزَّنة أصلاً).
        try:
            with self._connection:
                with self._connection.cursor() as cur:
                    cur.execute(
                        "INSERT INTO sys.idempotency_keys "
                        "(idempotency_key, user_ref_id, endpoint, response_status, response_body) "
                        "VALUES (%(key)s, %(user_id)s, %(endpoint)s, %(status)s, %(body)s)",
                        {"key": idempotency_key, "user_id": user_id, "endpoint": endpoint,
                         "status": response_status, "body": json.dumps(response_body)},
                    )
        except Exception as exc:
            if "UniqueViolation" in type(exc).__name__ or "unique" in str(exc).lower():
                return  # نتيجة مخزَّنة بالفعل من طلب متزامن آخر؛ لا خطأ فعلي
            raise


class InMemoryIdempotencyRepository(IdempotencyRepository):
    """تنفيذ وهمي للاختبار فقط."""

    def __init__(self):
        self._store: Dict[tuple, Dict[str, Any]] = {}

    def get_cached_response(self, idempotency_key: str, user_id: str, endpoint: str) -> Optional[Dict[str, Any]]:
        return self._store.get((idempotency_key, user_id, endpoint))

    def store_response(self, idempotency_key: str, user_id: str, endpoint: str,
                        response_status: int, response_body: Dict[str, Any]) -> None:
        key = (idempotency_key, user_id, endpoint)
        if key not in self._store:
            self._store[key] = {"response_status": response_status, "response_body": response_body}
