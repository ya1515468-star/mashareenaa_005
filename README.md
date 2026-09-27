# MASHAREENA

> Copyright © 2026 MASHAREENA. جميع الحقوق محفوظة.

مشروع Flutter + Supabase لمنصة MASHAREENA.

## Android ARM64

الـCI يبني APK Release منفصلًا لمعمارية `arm64-v8a`. البناء السحابي موجود
في `.github/workflows/build-android.yml` ويُشغّل يدويًا من GitHub Actions أو
عند الدفع إلى الفرع الرئيسي.

## توقيع نسخة الإنتاج

لا تحفظ مفاتيح التوقيع داخل المستودع. لإنتاج APK قابل للنشر، خزّن الأسرار
التالية في GitHub Actions Secrets: `ANDROID_KEYSTORE_BASE64`،
`ANDROID_KEYSTORE_PASSWORD`، `ANDROID_KEY_ALIAS`، `ANDROID_KEY_PASSWORD`.

## الأمان

يحتوي المستودع على فحص أسرار ثابت في `scripts/security_scan.py`، ويجب عدم
رفع أي `.env` أو keystore أو service-account JSON أو مفاتيح خاصة.

## الترخيص

راجع `LICENSE` و `COPYRIGHT.md`. تبقى حزم الطرف الثالث خاضعة لتراخيصها
الخاصة.
