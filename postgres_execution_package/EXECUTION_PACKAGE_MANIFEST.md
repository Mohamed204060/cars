# postgres_execution_package — الحزمة الكاملة المكتفية ذاتيًا

## تحديث (بعد أول تشغيل فعلي — 4 إخفاقات في Repository Tests)

تم رصد وإصلاح 4 مشكلات بعد أول تشغيل حقيقي على GitHub Actions:

| # | المشكلة | السبب الجذري | الإصلاح |
|---|---|---|---|
| 1 | `pricing_mode="contact_for_price"` يتجاوز `VARCHAR(16)` رغم Migration 022 | **خطئي أنا**: `scripts/setup_test_database.sh` يحتوي قائمة `REQUIRED_FILES` مُكوَّدة يدويًا كانت لا تزال تتوقف عند 021 — لم تكن تُطبِّق 022 أو 023 إطلاقًا رغم وجودهما في مجلد migrations/. النسخة السابقة من هذا الملف نُسخَت من الحزمة الأصلية الأولى، قبل أي CR، دون تحديثها. | إضافة `022_postgresql_validation_runtime_fixes.sql` وَ`023_iam_sessions.sql` إلى `REQUIRED_FILES` |
| 2 | `TestPostgresTrmRepository`: لم يُرفع `DuplicateRatingError` | خطأ في الاختبار: المحاولة الثانية استخدمت `target_ref_id` **مختلفًا** عشوائيًا، بينما قيد التفرّد الفعلي `uq_ratings_rater_target_source` يشمل `target_ref_id` ضمن المفتاح المركَّب — فلم يقع أي تعارض تفرّد أصلاً | إعادة استخدام نفس `target_ref_id` في كلا الاستدعاءين |
| 3 | `TestPostgresPctRepository`: FK على `categories` | الاختبار مرَّر `category_id` عشوائيًا لا يقابله صف حقيقي في `pct.categories` (لا توجد دالة `insert_category` في المستودع لإدارتها) | إدراج صف فئة حقيقي مباشرة (`INSERT INTO pct.categories DEFAULT VALUES`) قبل استخدام مُعرِّفه |
| 4 | `TestPostgresVctRepository`: `InvalidTextRepresentation` | الاختبار مرَّر `"nonexistent-trim-id"` — سلسلة نصية ليست بصيغة UUID، بينما العمود مُعرَّف `UUID` فعليًا؛ "عدم الوجود" غير "صيغة غير صالحة" | استبدالها بـ`str(uuid.uuid4())` — UUID صحيح الصيغة لكن غير موجود فعليًا |

**لا تعديل على أي منطق Repository أو Migration بسبب الجولة الأولى** — الإصلاحات الثلاثة اختبارية بحتة؛ إصلاح الـWorkflow/Script سكربتي بحت.

## تحديث ثانٍ (بعد ثاني تشغيل — 1 إخفاق متبقٍ)

| # | المشكلة | السبب | الإصلاح |
|---|---|---|---|
| 5 | `TestPostgresInventoryItemRepository`: `ForeignKeyViolation` على `store_id` | `str.inventory_items.store_id` يحمل `REFERENCES str.stores(id)` فعليًا (خلافًا لـ`catalog_part_ref_id`/`condition_ref_id`، إشارتان وصفيتان فقط بلا FK حقيقي في هذا الجدول تحديدًا) — الاختبار كان يمرِّر UUID عشوائيًا لا يقابله صف متجر حقيقي | إدراج صف `str.stores` حقيقي مباشرة (`owner_user_ref_id` لا يحمل FK فعليًا، فقيمة عشوائية تكفي) قبل استخدام `store_id` الناتج |

## تحديث ثالث (بعد ثالث تشغيل — 5 إخفاقات في test_auth_api.py، كلها بسبب واحد)

| # | المشكلة | السبب | الإصلاح |
|---|---|---|---|
| 6 | كل المسارات المحمية تُعيد 401 رغم نجاح تسجيل الدخول | `TestClient(app)` الافتراضي يعمل على `http://testserver`؛ الجلسة تُصدَر بخاصية `Secure=True` (لم تُعطَّل، ولن تُعطَّل)، وCookies من نوع Secure لا تُرسَل إلا فوق HTTPS — فلا يُعيد العميل إرسالها في أي طلب لاحق | `TestClient(app, base_url="https://testserver")` — تشخيص وحل من مالك المشروع، طُبِّق حرفيًا |

اختباري بحت (Fixture فقط)؛ `Secure=True` بقي كما هو في `auth_api.py` دون أي تعديل.

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
