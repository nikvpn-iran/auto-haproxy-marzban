# Marzban Custom HAProxy & Node-Ready Setup

این اسکریپت بر اساس یک ساختار متمرکز و یکپارچه طراحی شده است تا فایل `.env` در پنل مرکزی و نودها کاملاً یکسان باشد. 
در این روش، نیازی به وارد کردن مکرر دامنه‌ها و SNIها در حین نصب نیست؛ اسکریپت تنها پورت‌های بک‌اند را از شما دریافت کرده و پیکربندی را انجام می‌دهد.

## ویژگی‌های اصلی استخراج شده از آموزش
* **آپدیت خودکار:** سیستم‌عامل به صورت خودکار با `apt-get update -y && apt-get upgrade -y` بروزرسانی می‌شود[cite: 2].
* **مسیریابی چندگانه روی پورت ۴۴۳:** ترافیک ورودی روی پورت `443` بر اساس SNIهای ثابت (`yourpaneldomain.com`، `FirstSNI` و `SecondSNI`) به سمت پنل، REALITY، REALITY GRPC و در نهایت فالبک هدایت می‌شود[cite: 2].
* **بخش sfront:** یک لیسنر مجزا روی پورت فعلی سرور (`YourCurrentPort`) ایجاد می‌شود که ترافیک سابسکریپشن را مستقیماً به پنل ارجاع می‌دهد[cite: 2].
* **یکپارچگی .env:** تنها با افزودن تگ `XRAY_FALLBACKS_INBOUND_TAG = "TROJAN_FALLBACK_INBOUND"` به فایل `.env`، می‌توان این فایل را روی پنل و نودها به صورت کپی یکسان استفاده کرد[cite: 2].

## نحوه اجرا

```bash
bash <(curl -Ls [https://raw.githubusercontent.com/nikvpn-iran/auto-haproxy-marzban/main/setup.sh](https://raw.githubusercontent.com/nikvpn-iran/auto-haproxy-marzban/main/setup.sh))
