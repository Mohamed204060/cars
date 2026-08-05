"""
idempotency_service.py — منطق إعادة إرسال العمليات الحساسة (DD الحزمة 2، القسم 2.2)
المرجع: Store + Inventory Contract Extension؛ Migration 025

مبدأ: يُخزَّن ناتج أول تنفيذ ناجح فقط (2xx) لكل (Idempotency-Key، مستخدم،
عملية)؛ أي إعادة إرسال بنفس المفتاح تُعيد هذا الناتج حرفيًا دون أي تنفيذ
فعلي جديد. لا تخزين لاستجابات الأخطاء عمدًا — طلب فاشل بمفتاح معيّن يجب أن
يُسمَح بإعادة محاولته بنفس المفتاح لاحقًا بعد تصحيح السبب.
"""

from dataclasses import dataclass
from typing import Any, Dict, Optional


@dataclass
class IdempotentReplay:
    response_status: int
    response_body: Dict[str, Any]


def is_cacheable_status(status_code: int) -> bool:
    """لا تُخزَّن إلا الاستجابات الناجحة (2xx)."""
    return 200 <= status_code < 300


def get_cached_response_via_repository(
    repository, idempotency_key: Optional[str], user_id: str, endpoint: str
) -> Optional[IdempotentReplay]:
    """يُستدعى في بداية معالج الطلب؛ يُعيد نتيجة سابقة إن وُجدت، أو None للمتابعة بتنفيذ عادي."""
    if not idempotency_key:
        return None
    cached = repository.get_cached_response(idempotency_key, user_id, endpoint)
    if cached is None:
        return None
    return IdempotentReplay(response_status=cached["response_status"], response_body=cached["response_body"])


def store_response_via_repository(
    repository, idempotency_key: Optional[str], user_id: str, endpoint: str,
    response_status: int, response_body: Dict[str, Any],
) -> None:
    """يُستدعى بعد تنفيذ ناجح فقط؛ لا يُخزِّن شيئًا إن لم يُرسَل مفتاح، أو
    كانت الاستجابة غير ناجحة (2xx)."""
    if not idempotency_key or not is_cacheable_status(response_status):
        return
    repository.store_response(idempotency_key, user_id, endpoint, response_status, response_body)
