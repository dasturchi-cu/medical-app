# APK chiqarish — doimiy qoida

> **Qadab qo‘yilgan.** Har safar yangi APK chiqarishda faqat shu tartib.
> Oxirgi yangilanish: 2026-07-10

---

## 1. Qisqa qoida (3 ta)

| # | Qoida | Nima demak |
|---|--------|------------|
| 1 | **Bitta APK** | Faqat `app-arm64-v8a-release.apk` — 3 ta split (arm32/x64) kerak emas |
| 2 | **Telefon uchun Cloudflare** | IP (`84.46.243.149`) emas — Cloudflare HTTPS link beriladi |
| 3 | **Ilova backend** | APK ichida `API_BASE_URL` = VPS (`http://84.46.243.149`) |

---

## 2. Telefonlarga beriladigan havolalar

**Asosiy domen (Cloudflare tunnel):**
```
https://protest-examining-assure-ventures.trycloudflare.com
```

| Nima | Havola |
|------|--------|
| Yuklash sahifasi | `https://protest-examining-assure-ventures.trycloudflare.com/download` |
| To‘g‘ridan-to‘g‘ri APK | `https://protest-examining-assure-ventures.trycloudflare.com/api/android-apk` |
| Admin panel | `https://protest-examining-assure-ventures.trycloudflare.com` |

> Agar tunnel qayta ishga tushsa, URL o‘zgarishi mumkin. Tekshirish: VPS da  
> `grep FRONTEND_ORIGIN /app/neuroscience/.env.production`  
> yoki `curl -s https://…trycloudflare.com/health`

**IP ni telefonlarga bermang** (`http://84.46.243.149/...`) — faqat Cloudflare.

---

## 3. Build (Windows, lokal)

```powershell
cd D:\proyektlar\medical_app

flutter build apk --release --split-per-abi `
  --dart-define=API_BASE_URL=http://84.46.243.149
```

Natija (faqat shuni ishlatamiz):
```
build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

- `app-armeabi-v7a-release.apk` va `app-x86_64-release.apk` — **yuklamang / tarqatmang**
- Universal (`flutter build apk` without split) ham shart emas — arm64 yetadi

Tekshiruv (APK ichida Railway bo‘lmasin):
```powershell
# APK da VPS IP bor, railway.app yo‘q bo‘lishi kerak
Select-String -Path (strings ...) # yoki unzip + grep
```

---

## 4. R2 ga yuklash

Faqat arm64:

```
https://pub-f2e4edcbc94e4154bf7991b8b9ada00d.r2.dev/app-arm64-v8a-release.apk
```

Skript: `scratch/upload_apks.py` (yoki qo‘lda R2).

---

## 5. Server `.env.production` yangilash

VPS: `/app/neuroscience/.env.production`

```env
APK_SOURCE_URL=https://pub-f2e4edcbc94e4154bf7991b8b9ada00d.r2.dev/app-arm64-v8a-release.apk
APK_FILE_NAME=app-arm64-v8a-release.apk
APK_CONTENT_LENGTH=<yangi fayl bayt hajmi>

APK_SOURCE_URL_ARM64=... (xuddi shu URL)
APK_CONTENT_LENGTH_ARM64=<xuddi shu hajm>
```

Keyin:
```bash
cd /app/neuroscience && docker compose up -d admin_panel
```

Tekshiruv:
```bash
curl -sI https://protest-examining-assure-ventures.trycloudflare.com/api/android-apk | grep -i content-length
```

---

## 6. Foydalanuvchiga nima aytish

1. Eski ilovani o‘chirish  
2. Brauzerda ochish: **Cloudflare `/download`**  
3. Yuklab olib o‘rnatish  

IP yoki 3 ta APK havolasini bermang.

---

## 7. Infra eslatma

| Joy | Rol |
|-----|-----|
| VPS `84.46.243.149` | Backend + nginx + admin (Docker) |
| Cloudflare tunnel | Telefon/HTTPS kirish |
| Neon | Postgres |
| R2 | Media + APK fayl |
| Railway | **O‘lik** — APK da Railway URL bo‘lmasin |

Batafsil: `docs/INFRASTRUCTURE-QOLLANMA.md`, `docs/NEON-R2-HOZIR-NIMA-QILISH.md`, `docs/MONOREPO-DEPLOY-QOLLANMA.md`
