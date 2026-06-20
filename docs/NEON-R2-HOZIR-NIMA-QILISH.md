# Neon + R2 — hozir nima bo‘ldi, nima qilish kerak

> Sana: 2026-06  
> Maqsad: chalkashlikni yo‘qotish — NOTICE xatosi emas, R2 bo‘shligi normal, keyingi qadamlar.

---

## 1. Qisqa xulosa (3 ta joy)

| Joy | Holat | Normalmi? |
|-----|-------|-----------|
| **Neon SQL** | Migrationlar **muvaffaqiyatli** (`Barcha migrationlar muvaffaqiyatli`) | ✅ Ha |
| **Neon jadvallar** | Ko‘p jadval bor (`courses`, `lessons`, …) | ✅ Ha — **lekin ichida ma’lumot yo‘q** |
| **Cloudflare R2** | Bucket `content-assets` **bo‘sh** | ✅ Ha — hali **fayl yuklamagansiz** |
| **Railway backend** | Hali **eski kod** (`build_id: ranking-your-place-v7`) | ❌ Yangi deploy kerak |
| **Admin / ilova** | Server error / 0 ko‘rsatkich | ❌ Deploy + ma’lumot import kerak |

---

## 2. Neon SQL Editor — sariq NOTICE xato EMAS

Quyidagilarni ko‘rsangiz — **xavotir olmang**:

```
NOTICE: extension "pgcrypto" already exists, skipping
NOTICE: relation "users" already exists, skipping
NOTICE: schema "storage" already exists, skipping
NOTICE: relation "buckets" already exists, skipping
```

**Ma’nosi:** jadval/rol allaqachon yaratilgan, skript qayta ishlaganda o‘tkazib yuborildi.

**Haqiqiy xato** faqat qizil `ERROR:` bilan chiqadi.

### To‘g‘ri tartib (qo‘lda yoki skript)

**Variant A — PowerShell (tavsiya):**
```powershell
cd c:\Users\User\medical_app
.\scripts\apply-neon-migrations.ps1
```

**Variant B — Neon SQL Editor qo‘lda:**
1. `scripts/neon-preflight.sql` — birinchi
2. Keyin `000_neon_platform.sql`
3. Keyin `001` … `020` ketma-ket
4. **`012` ni birinchi qilib ishga tushirmang**

Oxirida: `Barcha migrationlar muvaffaqiyatli` yoki faqat NOTICE.

---

## 3. Neon da jadval bor, lekin ma’lumot yo‘q — NORMAL

Migrationlar faqat **bo‘sh skelet** yaratadi:

- `courses` jadvali bor ✅
- Ichida kurs qatorlari yo‘q ❌ (hali import qilinmagan)

**Shuning uchun:**
- Admin: **0 kurs, 0 dars**
- Ilova: bo‘sh ro‘yxat

### Ma’lumot qayerdan keladi?

| Nima | Qayerdan |
|------|----------|
| Kurslar, userlar, darslar | Eski Supabase **backup SQL** → Neon import |
| Slayd rasmlari, PDF | **Cloudflare R2** ga qo‘lda yuklash |
| APK | **GitHub Releases** (allaqachon qo‘yilgan) |

Supabase yopiq bo‘lsa — backup ochilguncha kutish yoki qo‘lda qayta kiritish.

---

## 4. Cloudflare R2 — nega bo‘sh?

**R2 o‘zi hech narsani ko‘chirmaydi.** Bucket yaratdingiz — bu faqat **quti**. Ichiga siz yuklaysiz.

### R2 da ko‘rinishi kerak bo‘lgan joy

1. [dash.cloudflare.com](https://dash.cloudflare.com) → **R2**
2. Bucket: **`content-assets`**
3. **Objects** tab
4. Hozir: **0 objects** — normal (hali upload qilmagansiz)

### Birinchi test fayl

1. **Upload** → bitta kichik `.jpg` yoki `.webp`
2. Papka: `test/` (ixtiyoriy)
3. Fayl URL:
   ```
   https://pub-f2e4edcbc94e4154bf7991b8b9ada00d.r2.dev/test/fayl.jpg
   ```
4. Brauzerda oching — rasm ko‘rinsa R2 ishlayapti ✅

### Haqiqiy kontent (keyinroq)

| Tur | R2 papka (masalan) | Hajm |
|-----|-------------------|------|
| Slayd rasmlari | `lessons/`, `slides/` | ~352 MB |
| PDF kitoblar | `books/` | ~50–100 MB |
| Bannerlar | `banners/`, `ads/` | ~20–50 MB |

**Admin panel** yangi kod deploy bo‘lgach — rasm yuklash avtomatik R2 ga ketadi (backend orqali).

Hozircha: Supabase Storage dan fayllarni qo‘lda yuklab, R2 ga upload qilish mumkin.

---

## 5. Nega hali "Server ichki xatoligi"?

Tekshiruv (2026-06):

```
GET /health → build_id: "2026-06-05-ranking-your-place-v7"  ← ESKI KOD
GET /api/v1/courses → 500
```

Siz Railway da `SUPABASE_*` ni olib tashladingiz, lekin serverda **hali eski Supabase kodi** ishlayapti.

### Yangi kod GitHub da (push qilindi)

- `Neuroscience-app_backend` — Neon + R2 backend
- `Neuroscience_admin_panel` — R2 upload

### Siz qilishingiz kerak

1. **Railway to‘lov** — "subscription past due" bo‘lsa deploy to‘xtashi mumkin
2. **Redeploy** ikkala servis:
   - `Neuroscience-app_backend`
   - `Neuroscience_admin_panel`
3. `/health` tekshiring — yangi kod:
   ```json
   "build_id": "2026-06-05-neon-r2-v1"
   "database": "neon"
   ```
4. **Admin Variables** tuzatish:
   - `APK_SOURCE_URL` — `USER` emas, `dasturchi-cu`:
     ```
     https://github.com/dasturchi-cu/Neuroscience-app/releases/download/v1.0.0/app-arm64-v8a-release.apk
     ```
   - `FIREBASE_CREDENTIALS_JSON` — buzilgan `{"` bo‘lsa **o‘chiring**

---

## 6. Railway Variables — yakuniy ro‘yxat

### Backend (`Neuroscience-app_backend`)

**Qo‘yilgan bo‘lishi kerak:**
```
APP_NAME=medical-backend
ENVIRONMENT=production
API_PREFIX=/api/v1
FRONTEND_ORIGIN=https://neuroscienceadminpanel-production.up.railway.app
DATABASE_URL=postgresql://...neon.tech/neondb?sslmode=require
R2_ACCOUNT_ID=...
R2_BUCKET_NAME=content-assets
R2_ENDPOINT=https://....r2.cloudflarestorage.com
R2_PUBLIC_BASE_URL=https://pub-....r2.dev
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
ADMIN_API_KEY=...
```

**Olib tashlangan:**
- `SUPABASE_URL` ❌
- `SUPABASE_SERVICE_ROLE_KEY` ❌

### Admin (`Neuroscience_admin_panel`)

**Qo‘yilgan:**
```
NEXT_PUBLIC_API_BASE_URL=https://neuroscience-appbackend-production.up.railway.app
BACKEND_PROXY_URL=https://neuroscience-appbackend-production.up.railway.app
NEXT_PUBLIC_ADMIN_API_KEY=... (backend bilan bir xil)
APK_SOURCE_URL=https://github.com/dasturchi-cu/Neuroscience-app/releases/download/v1.0.0/app-arm64-v8a-release.apk
APK_FILE_NAME=app-arm64-v8a-release.apk
APK_CONTENT_LENGTH=32598324
ADMIN_PANEL_SECRET=...
ADMIN_PANEL_PASSWORD=...
ADMIN_PANEL_PHONE_DIGITS=998777777777
```

**Olib tashlangan:**
- `NEXT_PUBLIC_SUPABASE_URL` ❌
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` ❌

---

## 7. To‘liq tartib (ketma-ket)

### ✅ Allaqachon qilingan
- [x] Neon loyiha + `DATABASE_URL`
- [x] Migrationlar (`apply-neon-migrations.ps1` muvaffaqiyatli)
- [x] R2 bucket `content-assets` + API token
- [x] GitHub APK release
- [x] Railway Variables (qisman)
- [x] Yangi kod GitHub ga push

### 🔲 Hozir qilish
- [ ] Railway to‘lov + **Redeploy** backend va admin
- [ ] `/health` → `neon-r2-v1` ko‘rinishi
- [ ] Admin `APK_SOURCE_URL` tuzatish
- [ ] R2 ga test rasm yuklash

### 🔲 Keyinroq
- [ ] Supabase ochilganda → `backup-supabase.ps1` → Neon import
- [ ] Yoki admin orqali kurs/dars/slayd qayta kiritish
- [ ] Eski Supabase URL larni R2 URL ga yangilash (bazada)
- [ ] Yangi APK tarqatish (`flutter build apk --release --split-per-abi`)

---

## 8. Tez-tez savollar

**NOTICE "already exists" — xato?**  
Yo‘q. Skript qayta ishlaganda chiqadi. Muhim: oxirida `ERROR` bo‘lmasin.

**Neon da jadval ko‘rinadi, lekin 0 ma’lumot?**  
Normal. Migration = struktura. Ma’lumot = backup import yoki qo‘lda kiritish.

**R2 da hech narsa yo‘q?**  
Normal. Bucket bo‘sh quti. Upload qilishingiz kerak.

**Cloudflare ga Neon ma’lumoti o‘tadimi?**  
Yo‘q. Neon = matn (baza). R2 = fayllar. Alohida.

**Ilova yana ishlaydimi?**  
Deploy + ma’lumot import bo‘lgach — ha. Hozir backend 500 berishi mumkin (eski kod).

---

## 9. Foydali fayllar

| Fayl | Vazifa |
|------|--------|
| `scripts/neon.env` | Neon ulanish |
| `scripts/neon-preflight.sql` | Rollar, storage stub |
| `scripts/apply-neon-migrations.ps1` | Barcha migrationlar |
| `scripts/r2.env` | R2 kalitlar |
| `scripts/railway-backend.env` | Railway backend nusxa |
| `scripts/railway-admin.env` | Railway admin nusxa |
| `docs/INFRASTRUCTURE-QOLLANMA.md` | Umumiy infratuzilma |

---

## 10. Bir jumlada

**Neon migrationlar tayyor (jadval bor, qator yo‘q). R2 tayyor (bucket bor, fayl yo‘q). Server error — Railway hali eski kodni ishga tushiryapti; redeploy qiling, keyin ma’lumot va fayllarni to‘ldirasiz.**
