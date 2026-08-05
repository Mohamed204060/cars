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

## تحديث رابع (بعد ملاحظتكم: schema-drift.json ما زال 52 جدولًا)

**ليس مقصودًا وليس خارج نطاق CR-013** — خطأ تعبئة مني: عند بناء هذه الحزمة، نُسخ `tools/schema_drift_check.py` من نسخة عمل محلية كانت قد فقدت إدخال `iam.sessions` سهوًا. النسخة الصحيحة (53 جدولًا، شاملة `iam.sessions`) كانت موجودة وسُلِّمت فعليًا كملف مستقل ضمن تسليم CR-013 v1، لكنها لم تُدرَج في نسخة الحزمة الكاملة هذه. الدليل نفسه يؤكد المشكلة: `table-list.txt` من تشغيلكم الأخير يُظهر 53 صفًا فعليًا في قاعدة البيانات الحية (شاملة `iam.sessions`)، بينما الأداة فحصت 52 فقط.

**الإصلاح:** استبدال `tools/schema_drift_check.py` بالنسخة الصحيحة (53 جدولًا، 53 PK، 34 FK، شاملة `iam.sessions`). لا تعديل آخر على أي ملف.

## تحديث خامس — إضافة PCT REST API (بعد اعتماد PCT Contract Extension)

### ملفات جديدة
- `services/pct/src/pct_api.py` — طبقة REST (5 عمليات): propose, get, approve (فحص صلاحية admin/super_admin)، إضافة اسم، تسجيل OEM.
- `tests/test_pct_api.py` — اختبارات وحدة (InMemory)، 15 اختبارًا، شاملة اختبارات صلاحية approve الستة (buyer مرفوض، seller مرفوض، admin مقبول، super_admin مقبول، قطعة غير موجودة 404، اعتماد مزدوج 409).
- `tests/test_postgres_pct_api_integration.py` — تكامل حي: FK حقيقي على category_id، صلاحية admin حقيقية عبر iam.users.primary_role، وتفرّد OEM حقيقي عبر القيد.

### ملفات معدَّلة (إضافة فقط، لا حذف)
- `services/pct/src/pct_service.py`: إضافة `add_localized_name_via_repository()` (كان الغلاف مفقودًا رغم وجود الدالة النقية).
- `services/auth/src/auth_repository.py`: إضافة `get_user_role()` للتحقُّق من `primary_role` (فحص موضعي REQ-PCT-002؛ لا RBAC عام).
- `api_spec/openapi.yaml`: v1.2.0 — +5 عمليات PCT (14 مسارًا، 15 عملية إجمالًا).
- `.github/workflows/postgresql-validation.yml` (يُرفَع منفصلًا): +2 خطوة (`pct-api-tests`، `pct-integration-tests`).

### REQ-PCT-006 (Aftermarket)
مؤجَّل صراحةً كما تقرَّر — لا Repository ولا Service ولا API له في هذه الدفعة.

## تحديث سادس — إضافة VCT REST API (بعد اعتماد VCT Contract Extension)

### ملفات جديدة
- `services/vct/src/vct_api.py` — 7 عمليات: propose/get/approve manufacturer (فحص صلاحية admin/super_admin نفسه)، propose model (يتحقق REQ-VCT-003: الشركة معتمَدة)، create generation، create trim، get trim.
- `tests/test_vct_api.py` — 12 اختبار وحدة، شاملة تسلسل manufacturer→model→generation→trim الكامل الذي تحتاجه CMP لاحقًا.
- `tests/test_postgres_vct_api_integration.py` — 5 اختبارات تكامل حي.

### ملفات معدَّلة (إضافة فقط)
- `services/vct/src/vct_repository.py`: إضافة `get_model_by_id()` وَ`get_generation_by_id()` (كانتا مفقودتين رغم وجود `insert_model`/`insert_generation`).
- `services/vct/src/vct_service.py`: إضافة `propose_model_via_repository()` (يتحقق REQ-VCT-003 فعليًا — لم يكن مُتحقَّقًا من قبل)، `create_generation_via_repository()`، `create_trim_via_repository()`.
- `api_spec/openapi.yaml`: v1.3.0 — +7 عمليات VCT (21 مسارًا، 22 عملية إجمالًا).
- `.github/workflows/postgresql-validation.yml`: +2 خطوة (`vct-api-tests`، `vct-integration-tests`).

### مؤجَّل عمدًا (كما تقرَّر)
- REQ-VCT-006 (الاسم متعدد اللغات) — جدول موجود، لا Repository/Service.
- REQ-VCT-007 (أرشفة تتالية تؤثر على CMP) — يُبنى مع/بعد CMP مباشرة.

## تحديث سابع — إضافة CMP REST API (بعد اعتماد CMP Contract Extension)

### اكتشاف مهم أثناء الجرد
حقول `fitment_type`/`compatibility_notes`/`source` في `CompatibilityRecord` (Python) **لا تقابلها أعمدة في قاعدة البيانات إطلاقًا** (007_cmp.sql يحتوي فقط: catalog_part_ref_id, trim_ref_id, status). هذا موثَّق أصلاً في تعليق الكود نفسه كـ"Backlog" (مقترح مالك سابق لم يُستكمَل). **لم يُضَف أي عمود جديد** — العقد يقتصر على الحقول الثلاثة المخزَّنة فعليًا فقط، تفاديًا لعقد يَعِد بحفظ بيانات لا تُخزَّن فعليًا.

### ملفات جديدة
- `services/cmp/src/cmp_api.py` — 4 عمليات: إنشاء سجل توافق (يتحقق فعليًا من PCT+VCT عبر الحقن، لا استعلام مباشر)، عرض سجل، عرض سجلات قطعة، أرشفة (REQ-CMP-003).
- `tests/test_cmp_api.py` — 12 اختبارًا، يستخدم PCT/VCT الحقيقيتين (لا Fixtures منفصلة) لبناء قطعة معتمَدة وفئة صالحة فعليًا قبل اختبار CMP، إثباتًا لعمل SSOT عبر الخدمات الثلاث معًا.
- `tests/test_postgres_cmp_api_integration.py` — 4 اختبارات تكامل حي، تشمل تفرّد `uq_compatibility_part_trim` الفعلي.

### ملفات معدَّلة (إضافة فقط)
- `services/cmp/src/cmp_service.py`: إضافة `archive_compatibility_record_via_repository()` وَ`CompatibilityRecordNotFoundError` (كان الغلاف مفقودًا).
- `services/cmp/src/cmp_repository.py`: إضافة `get_record_by_id()` (Postgres + InMemory).
- `api_spec/openapi.yaml`: v1.4.0 — +4 عمليات CMP (25 مسارًا، 26 عملية إجمالًا).
- `.github/workflows/postgresql-validation.yml`: +2 خطوة (`cmp-api-tests`، `cmp-integration-tests`).

### صلاحيات
REQ-CMP-001 وREQ-CMP-003 كلاهما "مدير النظام حصريًا" — نفس فحص `SYSTEM_ADMIN_ROLES` من PCT/VCT حرفيًا، بلا تكرار منطق (استيراد مباشر من `pct_api.py`).

## تحديث ثامن — إضافة Search REST API (الدفعة 1: CMP + Search)

### لا امتداد عقد جديد
`GET /search/parts` كان موثَّقًا بالكامل أصلًا ضمن الشريحة الأولى المعتمَدة في `openapi.yaml` (5 عمليات أصلية) — لم يكن مُنفَّذًا فقط. لا تغيير على `openapi.yaml` في هذا التحديث.

### ملفات جديدة
- `services/search/src/search_api.py` — ينفِّذ `GET /search/parts` عبر `execute_search_via_repository()` الموجودة فعليًا وجاهزة للاستدعاء المباشر.
- `tests/test_search_api.py` — 10 اختبارات وحدة (InMemory)، شغَّلت المنطق الأساسي (فلترة، تقسيم صفحات، الدولة الفعّالة) **فعليًا يدويًا هنا (5/5 PASSED)** قبل التسليم.
- `tests/test_postgres_search_api_integration.py` — 3 اختبارات تكامل حي، **الأهم بينها**: يثبت أن البحث يستخدم `cmp.compatibility_records` الحقيقية (لا محاكاة) لتصفية النتائج حسب `trim_ref_id`، مستخدمًا سلسلة PCT→VCT→CMP الكاملة المبنية في هذه الدفعة والدفعة السابقة.

### فجوات نطاق موثَّقة صراحة (لا تُخفى)
- معاملا `q` (نص حر) وَ`sort` (ترتيب مخصَّص) موجودان في العقد لكن **غير مُنفَّذين** في `search_service.py`؛ يُقبَلان بالطلب دون أي أثر.
- `account_country_code`/`geolocation_country_code`/`ip_country_code` (REQ-SRC-006-C) تتطلب مصادر بيانات غير موجودة بعد؛ يُستخدَم `country_ref_id` المُرسَل من العميل كـ`manual` فقط.
- `image_url` يُعاد `null` دائمًا — لا نظام تخزين صور مبني في المشروع بعد.

### بنية اختبار مؤقَّتة
`str.stores`/`str.inventory_items` لا REST API لهما بعد (الدفعة التالية: Store + Inventory)؛ اختبارات تكامل البحث تُنشئ بيانات هذين الجدولين مباشرة عبر SQL خام، بنفس أسلوب `pct.categories` قبل اكتمال عقد PCT.
