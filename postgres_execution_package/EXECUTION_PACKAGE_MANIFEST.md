# postgres_execution_package — الحزمة الكاملة المكتفية ذاتيًا

**اعتذار وتصحيح:** الحزمة السابقة (`CR-013_v2_execution_package.zip`) كانت
Delta فقط (الملفات الجديدة/المعدَّلة حصرًا)، لا حزمة مكتفية ذاتيًا — وهذا
تسبَّب في فشل التشغيل لديكم (`scripts/teardown_test_database.sh: No such
file or directory`). هذه النسخة كاملة: **استبدلوا مجلد `postgres_execution_package/`
في المستودع بمحتوى هذا الأرشيف بالكامل، حرفيًا، دون دمج انتقائي.**

## تحقَّقتُ محليًا من كل شرط يفحصه الـWorkflow نفسه قبل الإرسال
```
FOUND: README.md
FOUND: requirements.txt
FOUND: scripts/setup_test_database.sh
FOUND: scripts/teardown_test_database.sh
FOUND: tools/schema_drift_check.py
FOUND: tests/conftest.py
FOUND: tests/test_postgres_repositories.py
FOUND: tests/test_postgres_integration.py
migration_count = 24  ✓ (يطابق الـPatch المعتمَد على الـWorkflow)
```
كما تحقَّقت من أن كل ملف Python الـ42 في الحزمة (لا الجديد فقط) صحيح النحو
(`ast.parse` على كل ملف، بلا استثناء).

## مصدر كل ملف (لا شيء افتراضي أو مخمَّن)

### أصلي دون أي تعديل (من الحزمة المعتمَدة أول مرة، Release Verification Report)
- `README.md`
- `scripts/setup_test_database.sh`, `scripts/teardown_test_database.sh`
- `migrations/000` حتى `021` (22 ملفًا)
- `tests/conftest.py`
- كل الخدمات الـ13 **عدا** `auth`، `order`، `inventory_item` (كما هي، دون مساس)

### CR-011 (تغطية Schema Drift الكاملة + اختبار Auth حقيقي)
- `tests/test_postgres_repositories.py`

### CR-012 (حزمة إصلاحات التنفيذ الحي)
- `migrations/022_postgresql_validation_runtime_fixes.sql`
- `services/order/src/order_repository.py`
- `services/inventory_item/src/inventory_item_repository.py`
- `tests/test_postgres_integration.py`

### CR-013 v1+v2 (جلسات + بيانات اعتماد كلمة المرور + REST API) — أحدث نسخة تراكمية
- `migrations/023_iam_sessions.sql`
- `tools/schema_drift_check.py` (53 جدولًا، شامل PK/FK)
- `services/auth/src/auth_repository.py` (يشمل إصلاح CR-012 + إضافات CR-013 معًا)
- `services/auth/src/auth_service.py`
- `services/auth/src/credential_service.py` **(جديد)**
- `services/auth/src/session_service.py` **(جديد)**
- `services/auth/src/session_repository.py` **(جديد)**
- `services/auth/src/auth_api.py` **(جديد)**
- `tests/test_session_service.py` **(جديد)**
- `tests/test_credential_service.py` **(جديد)**
- `tests/test_auth_api.py` **(جديد)**
- `tests/test_postgres_auth_sessions_integration.py` **(جديد)**
- `tests/test_postgres_auth_credentials_integration.py` **(جديد)**
- `requirements.txt` (+fastapi, +httpx)

## ملف الـWorkflow
يُرفَع بشكل منفصل تمامًا (`postgresql-validation.yml`، أرسلته في الرسالة
السابقة) إلى `.github/workflows/postgresql-validation.yml`. لا علاقة له
بمحتوى هذا الأرشيف؛ الأرشيف الحالي يخص مجلد `postgres_execution_package/`
فقط.

## ما لم يتغيَّر ولا يجوز افتراض تغييره
`services/{cmp,message,message_extended,ntf,pct,scheduler,search,store,trm,vct}/src/*`
كما هي منذ الاعتماد الأول. `full_regression/` (خارج نطاق هذا الأرشيف
تمامًا؛ ملاحظة سابقة: كودها لِـauth منفصل ولن يتأثر بهذه الحزمة).
