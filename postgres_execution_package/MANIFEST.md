# CR-013 (v2) — حزمة تنفيذية كاملة جاهزة للاستبدال

المرجع الحوكمي: CR-013 (v1: جلسات iam.sessions، v2: بيانات اعتماد كلمة المرور
+ توثيق FastAPI/LoginResponse). راجع CR-013_جلسات_iam_sessions.docx للتفاصيل
الكاملة والمبررات.

## افتراض بنية المستودع
هذه الحزمة مبنية على نفس بنية postgres_execution_package.zip المُتحقَّق منها
فعليًا عبر GitHub Actions طوال مرحلة PostgreSQL Validation (migrations/،
services/<name>/src/، tools/، tests/ على مستوى الجذر). إن كانت بنية مستودع
`cars` الفعلية مختلفة عن هذا الافتراض في أي جزء، عدِّلوا المسارات أدناه فقط
دون تغيير محتوى الملفات نفسها.

## ملفات جديدة كليًا (5)
| المسار | الغرض |
|---|---|
| `migrations/023_iam_sessions.sql` | جدول iam.sessions (CR-013 v1) |
| `services/auth/src/credential_service.py` | تجزئة/تحقق كلمات المرور PBKDF2-HMAC-SHA256 (CR-013 v2) |
| `services/auth/src/session_service.py` | منطق دورة حياة الجلسة (CR-013 v1) |
| `services/auth/src/session_repository.py` | Repository لجدول iam.sessions (CR-013 v1) |
| `services/auth/src/auth_api.py` | طبقة REST (FastAPI) — 6 عمليات Auth كاملة (CR-013 v1+v2) |

## ملفات معدَّلة (استبدال كامل، لا Patch جزئي) (4)
| المسار | التعديل |
|---|---|
| `services/auth/src/auth_repository.py` | `insert_identity()`: معامل اختياري `raw_password` جديد (توافق رجعي كامل). دالة جديدة `find_identity_and_verify_password()`. لا تعديل آخر. |
| `services/auth/src/auth_service.py` | إضافة `login_with_password_via_repository()` و`InvalidPasswordCredentialsError`. لا حذف أو تعديل على أي دالة قائمة. |
| `tools/schema_drift_check.py` | `EXPECTED_TABLES` أصبح 53 جدولًا (إضافة `iam.sessions`) بدلًا من 52. لا تغيير آخر على منطق الأداة. |
| `api_spec/openapi.yaml` | +4 مسارات جديدة (logout، إدارة الهوية، عرض المزوّدين)، تعديل `LoginResponse` (إزالة `session_id`)، توضيح رسالة 401 لتسجيل الدخول. الإصدار الآن 1.1.0. |

## ملفات اختبار جديدة (5)
| المسار | النوع | يحتاج قاعدة بيانات حية؟ |
|---|---|---|
| `tests/test_session_service.py` | وحدة خالصة | لا — نُفِّذ يدويًا هنا فعليًا (19/19 PASSED) |
| `tests/test_credential_service.py` | وحدة + مستودع وهمي | لا — نُفِّذ يدويًا هنا فعليًا (11/11 PASSED) |
| `tests/test_auth_api.py` | وحدة REST (FastAPI TestClient) | لا، لكن يحتاج `fastapi`/`httpx` (لم يُشغَّل هنا؛ أول تشغيل فعلي على GitHub Actions) |
| `tests/test_postgres_auth_sessions_integration.py` | تكامل حقيقي | نعم — PostgreSQL حي بعد تطبيق Migration 023 |
| `tests/test_postgres_auth_credentials_integration.py` | تكامل حقيقي | نعم — PostgreSQL حي بعد تطبيق Migration 023 |

## ملف مُحدَّث في الجذر
`requirements.txt`: أُضيف `fastapi>=0.110` و`httpx>=0.27` (لا حاجة لأي مكتبة
تجزئة خارجية؛ `credential_service.py` يعتمد حصرًا على `hashlib` القياسية).

## خطوات التشغيل المتوقَّعة (بنفس منهجية PostgreSQL Validation)
```bash
pip install -r requirements.txt --break-system-packages
export TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5432/carparts_test
./scripts/setup_test_database.sh          # يطبِّق حتى 023 ضمنًا الآن
python3 tools/schema_drift_check.py       # يُتوقَّع tables_checked=53, diffs_found=0
pytest tests/test_session_service.py tests/test_credential_service.py tests/test_auth_api.py -v
pytest tests/test_postgres_auth_sessions_integration.py tests/test_postgres_auth_credentials_integration.py -v
pytest tests/test_postgres_repositories.py tests/test_postgres_integration.py -v   # يجب أن تبقى 14/14 و10/10 كما كانت (لا تراجع)
# ثم Full Regression الكامل كالمعتاد
./scripts/teardown_test_database.sh
```

## لا تعديل خارج ما ورد أعلاه
لم تُعدَّل أي Migration من 000 إلى 022. لم تُعدَّل أي خدمة غير `services/auth`.
لم يُعدَّل `tests/test_postgres_repositories.py` أو `tests/test_postgres_integration.py`
(النسختان المعتمَدتان سابقًا ضمن CR-011/CR-012 تبقيان كما هما دون مساس).
