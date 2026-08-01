# PostgreSQL Validation Execution Package — Ready v2.1

هذه حزمة إعادة بدء نظيفة ومتكاملة لمرحلة PostgreSQL Validation.

## مبادئ الحزمة
- Migrations 000-021 محفوظة دون تغيير عن الحزمة المعتمدة.
- جميع الإصلاحات اللاحقة موجودة في Migration جديدة: `022_postgresql_validation_runtime_fixes.sql`.
- CR-011 مطبق: فحص 52 جدولًا، ويشمل PK/FK وUnique/Check/Indexes/Partial Indexes.
- CR-012 موثق ومعتمد من مالك المشروع للتنفيذ، والإغلاق النهائي يبقى مشروطًا بالأدلة الخام.
- اختبار Auth حقيقي، ولا يحتوي على `pytest.skip`.
- Full Regression (361 اختبارًا) مضمّن في Workflow.

## الرفع إلى GitHub
ارفع **محتويات المجلد الخارجي** إلى جذر المستودع، ليظهر:

```
.github/workflows/postgresql-validation.yml
postgres_execution_package/
full_regression/
docs/
CHECKSUMS.sha256
```

إذا تعذر رفع `.github` من المتصفح، أنشئ الملف يدويًا عبر:
`Add file → Create new file` ثم اكتب المسار:
`.github/workflows/postgresql-validation.yml`
وانسخ محتوى الملف الموجود في الحزمة.

## التشغيل
من GitHub: `Actions → PostgreSQL Validation → Run workflow`.

## الأدلة المتوقعة
- migrations.log
- schema-drift.json
- repository-tests.log / XML
- integration-tests.log / XML
- full-regression.log / XML
- schema.sql / table-list.txt / schema-list.txt
- SUMMARY.md

## معايير النجاح
- 23 Migration مطبقة (000-022)
- Repository: 14 passed, 0 skipped
- Integration: 10 passed, 0 skipped
- Schema Drift: 52 tables checked، بلا Drift غير معتمد
- Full Regression: 361 passed

لا يُدَّعى نجاح PostgreSQL قبل ظهور هذه النتائج فعليًا في GitHub Actions.
