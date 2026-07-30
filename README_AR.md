# حزمة تصحيح PostgreSQL Validation v1.1

تحتوي هذه الحزمة على تصحيحات حالات الفشل الخمس التي ظهرت في GitHub Actions:

1. توسيع `pricing_mode` من `VARCHAR(16)` إلى `VARCHAR(32)`.
2. توليد `business_code` تلقائيًا لطلبات الشراء والعروض.
3. استخدام الهدف نفسه عند اختبار منع التقييم المكرر.
4. إنشاء فئة PCT قبل إدخال قطعة الكتالوج.
5. استخدام UUID صالح لاختبار trim غير موجود.

## طريقة الاستخدام

فك الضغط، ثم ارفع مجلد `postgres_execution_package` الموجود داخل الحزمة إلى جذر مستودع GitHub، ووافق على استبدال الملفات الثلاثة الحالية.

الملفات المعدلة:

- `postgres_execution_package/migrations/009_str.sql`
- `postgres_execution_package/services/order/src/order_repository.py`
- `postgres_execution_package/tests/test_postgres_repositories.py`

بعد Commit، شغّل Workflow جديدًا من Actions عبر `Run workflow`. لا تستخدم إعادة تشغيل التشغيل القديم لأن التشغيل القديم مرتبط بالـCommit السابق.
