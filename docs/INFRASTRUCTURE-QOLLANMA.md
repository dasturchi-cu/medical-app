# Medical App — infratuzilma, egress va ko‘chirish qo‘llanmasi

> Loyiha: `jcwvunjccbrmqtodsodm` (Supabase)  
> Sana: 2026-06  
> Maqsad: nima bo‘ldi, limitlar, qaysi xizmatga kirish, nima qilish tartibi.

---

## 1. Nima bo‘ldi? (19 GB va yopilish)

### Belgilar
- Ilova: reyting bo‘sh, kurslar yuklanmaydi
- Admin panel: server xatosi
- API: `402 Payment Required`
- Xato: `exceed_cached_egress_quota`, `exceed_egress_quota`

### Limit vs foydalanish (Supabase Free)

| Ko‘rsatkich | Limit | Sizda bo‘lgan |
|-------------|-------|---------------|
| Egress (oylik trafik) | 5 GB | ~7 GB |
| Cached egress | 5 GB | ~19 GB |
| Baza (storage) | 500 MB | ~50–150 MB (taxmin) |
| Fayl storage | 1 GB | ~352 MB slayd + boshqa |

**Muhim:** ma’lumotlar **o‘chmagan** — faqat xizmat **qulflangan**.

### 19 GB nimadan? (taxminiy)

| Manba | Taxmin | Izoh |
|-------|--------|------|
| APK yuklash | ~1.6 GB | 50 user × 32 MB |
| Storage listing + bot | ~5–15 GB | Butun bucket (352 MB) ko‘p marta yuklanishi mumkin |
| Slayd rasmlari | ~0.2 GB | Faqat 2–3 user ko‘rgan |
| Banner / API | ~0.5–1 GB | Kichik |
| Admin test | noma’lum | Qayta yuklash, tekshirish |

**Xulosa:** asosiy muammo **APK + Storage (listing)**; slayd/PDF o‘zi kam.

---

## 2. Hozirgi arxitektura

```
┌─────────────────┐
│  Flutter ilova  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Railway — FastAPI backend          │  ✅ ishlaydi
│  neuroscience-appbackend-...        │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Supabase (PostgreSQL + Storage)    │  ❌ YOPILGAN (402)
│  jcwvunjccbrmqtodsodm               │
└─────────────────────────────────────┘

Alohida:
  YouTube     — videolar (egress hisobiga kirmaydi)
  Firebase    — push bildirishnomalar
  Railway     — admin panel (veb)
```

### URL lar

| Xizmat | Manzil |
|--------|--------|
| Backend | https://neuroscience-appbackend-production.up.railway.app |
| Admin | https://neuroscienceadminpanel-production.up.railway.app |
| Supabase | https://jcwvunjccbrmqtodsodm.supabase.co |

---

## 3. Kontent qayerda turadi

| Kontent | Joy | Hajm (taxmin) |
|---------|-----|---------------|
| Slayd rasmlari (157 ta) | Supabase `content-assets` | 352 MB |
| Bannerlar (8 ta) | Supabase Storage | kichik |
| PDF kitob (1 ta) | Supabase Storage | ochilmagan |
| PPT | Supabase Storage | kam |
| APK (~32 MB) | Supabase Storage (ehtimol) | har yuklash = 32 MB |
| Videolar | **YouTube** | 0 (sizda) |
| Foydalanuvchilar, progress | Supabase **baza** | ~50–150 MB |

---

## 4. Limitlar — barcha xizmatlar

### Supabase Free (hozir — yopilgan)

| Limit | Qiymat | Yangilanadi? |
|-------|--------|--------------|
| Egress | 5 GB/oy | Ha (oy boshida) |
| Baza | 500 MB | Doimiy cap |
| Storage | 1 GB | Doimiy cap |
| Narx | $0 | — |

**Cheklov ochilishi:** Pro upgrade **yoki** yangi billing davr (egress uchun) + 24–48 soat.

**Support:** vaqtinchalik backup uchun ochish **bermaydi** (avtomatik javob tasdiqlangan).

---

### Cloudflare R2 (kelajak — fayllar)

| Limit | Bepul | Nima yeydi |
|-------|-------|------------|
| Storage | 10 GB | Saqlangan fayl hajmi (admin yuklaganda) |
| Egress | 10 GB/oy | User fayl yuklaganda |
| Narx ortiqcha | ~$0.015/GB | Yopilmaydi, pul yoziladi |

**Ro‘yxat:** https://dash.cloudflare.com → R2

---

### Neon (kelajak — baza)

| Limit | Bepul | Nima yeydi |
|-------|-------|------------|
| Baza hajmi | 0.5 GB | Jadval ma’lumotlari |
| Egress | 5 GB/oy | API/matn so‘rovlari |
| Compute | 100 soat/oy | DB ish vaqti |
| Narx | $0 | — |

**Ro‘yxat:** https://neon.tech

---

### GitHub Releases (APK)

| Limit | | |
|-------|---|---|
| Fayl hajmi | Katta repo limitlari | APK ~32 MB |
| Egress | GitHub o‘zi | Neon/R2 limitiga **kirmaydi** |

---

### Railway

| | |
|---|---|
| Hobby | ~$5 kredit/oy |
| Backend + Admin | allaqachon ulangan |
| Egress | Railway o‘z limiti |

---

### Firebase

| | |
|---|---|
| FCM push | bepul tier katta |
| Videolar/storage | ishlatilmaydi |

---

## 5. User soni bo‘yicha egress (R2 + Neon + kesh)

| User | R2 egress/oy | Neon egress/oy | Bepul yetadimi? |
|------|--------------|----------------|-----------------|
| 50 | ~0.3 GB | ~0.5 GB | ✅ |
| 200 | ~1.5 GB | ~1 GB | ✅ |
| 500 | ~3–5 GB | ~1–2 GB | ✅ |
| 1000 | ~8 GB | ~2 GB | ⚠️ R2 chegarada |

*Shart: yangi APK (kesh), APK GitHub da, rasmlar siqilgan.*

---

## 6. Loyihada qilingan ishlar

### Backup
- `scripts/backup-supabase.ps1` — backup skripti
- `scripts/tools/` — `pg_dump` (Docker kerak emas)
- `scripts/backup.env` — ulanish (Git ga kirmaydi)
- **Hali backup olinmadi** — Supabase yopiq

Backup ishga tushirish (ochilgandan keyin):
```powershell
cd c:\Users\User\medical_app
.\scripts\backup-supabase.ps1
```
Natija: `backups\supabase-YYYY-MM-DD_HHMM.sql`

`backup.env` da **Session pooler** URI bo‘lishi kerak (Dashboard → Connect → Session pooler).

---

### Xavfsizlik (Supabase SQL)
- `supabase/migrations/019_security_advisor_hardening.sql`
- `supabase/migrations/020_security_advisor_remaining.sql`

Qilgan ishlar:
- Storage **public listing** yopildi
- RLS policylar qo‘yildi
- Ranking funksiyalari faqat `service_role`
- `get_pomodoro_ranking` himoyalandi

---

### Ilova — kesh (egress kamaytirish)
- `lib/widgets/cached_remote_image.dart` — banner, muqova, bildirishnoma
- `lib/core/services/lesson_slides_bytes_cache.dart` — slayd, PDF (disk kesh)
- Kitob PDF: `SfPdfViewer.network` olib tashlandi
- API polling sekinlashtirildi (8–10 sek → 90–120 sek)

**Yangi APK chiqarish shart:**
```powershell
flutter build apk --release
```

---

## 7. Qaysi saytlarga kirish / ro‘yxatdan o‘tish

| # | Xizmat | URL | Nima uchun | Narx |
|---|--------|-----|------------|------|
| 1 | **Supabase** | supabase.com | Hozirgi baza (yopiq) | $0 |
| 2 | **Neon** | neon.tech | Kelajak baza | $0 |
| 3 | **Cloudflare** | dash.cloudflare.com | R2 fayllar | $0 |
| 4 | **GitHub** | github.com | APK releases | $0 |
| 5 | **Railway** | railway.app | Backend (bor) | ~$5/oy kredit |
| 6 | **Firebase** | console.firebase.google.com | Push (bor) | $0 |

**Hozir ochish mumkin (tayyorgarlik):** Neon, Cloudflare R2, GitHub.  
**Kutish kerak:** Supabase backup uchun ochilishi.

---

## 8. Nima qilish tartibi (to‘liq reja)

### Bosqich 0 — Hozir (Supabase yopiq)
- [ ] Hech narsa sotib olmang (Pro shart emas, agar pul yo‘q bo‘lsa)
- [ ] Supabase Dashboard → **Usage** → billing tugash sanasini yozib qo‘ying
- [ ] Supportga sana so‘rash (ixtiyoriy)
- [ ] Neon + Cloudflare account oching (tayyor)

### Bosqich 1 — Supabase ochilganda (BIRINCHI ISH)
- [ ] `.\scripts\backup-supabase.ps1` — to‘liq SQL backup
- [ ] Dashboard → Storage → muhim fayllarni qo‘lda yuklab oling (ixtiyoriy)
- [ ] Supabase parolini **almashtiring** (`backup.env` ochiq bo‘lgan)

### Bosqich 2 — Yangi infratuzilma
- [ ] **Neon:** loyiha → PostgreSQL → `DATABASE_URL` nusxalang
- [ ] Backup SQL ni Neon SQL Editor ga import qiling (yoki `psql`)
- [ ] **R2:** bucket yarating → slayd, PDF, banner yuklang
- [ ] **GitHub:** APK ni Releases ga qo‘ying
- [ ] Railway backend Variables: `DATABASE_URL` = Neon URL

### Bosqich 3 — Kod o‘zgarishlari (backend)
- [ ] Backend: Supabase client o‘rniga to‘g‘ridan-to‘g‘ri PostgreSQL (`asyncpg` / SQLAlchemy)
- [ ] Admin: fayl yuklash R2 ga
- [ ] `APK_SOURCE_URL` = GitHub release URL
- [ ] Deploy + test

### Bosqich 4 — Ilova
- [ ] Yangi APK (kesh bilan) tarqating
- [ ] Eski Supabase URL larni R2 URL ga yangilang (bazada)

### Bosqich 5 — Egress qayta bo‘lmasin
- [ ] APK — faqat GitHub
- [ ] Fayllar — R2 (listing yopiq)
- [ ] Rasmlar — WebP, siqilgan
- [ ] Kesh — yangi APK
- [ ] Polling — sekin (kodda qilingan)

---

## 9. Alternativa yo‘llar

### A) Kutish + backup + ko‘chirish (tavsiya)
- Ma’lumotlar saqlanadi
- Narx: $0 (bepul tierlar)
- Vaqt: oy boshini kutish + 2–3 kun ish

### B) 1 oy Supabase Pro ($25)
- Tez ochiladi → backup → keyin Neon ga ko‘chirish
- Pro ni keyin bekor qilish mumkin

### C) Noldan boshlash (backup yo‘q)
- Neon + R2 + admin paneldan qayta yuklash
- Foydalanuvchilar, progress **yo‘qoladi**

---

## 10. Tez-tez savollar

**Reytinglar o‘chib ketdimi?**  
Yo‘q — ko‘rinmayapti, bazada turibdi.

**Videolar yo‘qoladimi?**  
Yo‘q — YouTube da.

**Drive link ishlatilsa?**  
PPT uchun ba’zan; PDF/rasm uchun yomon. R2 yaxshiroq.

**Qayta ochganda yana yuklanadimi?**  
Yangi APK bilan — yo‘q (kesh). Eski APK — bannerlar qayta yuklanishi mumkin.

**PostgreSQL alohida o‘rnatish kerakmi?**  
Yo‘q — Neon bulutda, faqat URL qo‘yasiz.

**Railway PostgreSQL kerakmi?**  
Yo‘q — Neon bepul va yetarli.

---

## 11. Xavfsizlik eslatmalari

- `scripts/backup.env` — Git ga **kirmaydi**
- `backend/fastapi/.env` — hech qachon Git ga qo‘ymang
- Service role kalitni rotate qiling (ochiq bo‘lgan bo‘lsa)
- R2 da public faqat kerakli fayllar, listing yopiq

---

## 12. Foydali fayllar (repo ichida)

| Fayl | Vazifa |
|------|--------|
| `scripts/backup-supabase.ps1` | DB backup |
| `scripts/backup.env.example` | Ulanish namunasi |
| `supabase/migrations/019_*.sql` | Xavfsizlik |
| `supabase/migrations/020_*.sql` | Qolgan xavfsizlik |
| `lib/widgets/cached_remote_image.dart` | Rasm keshi |
| `lib/core/services/lesson_slides_bytes_cache.dart` | Slayd/PDF keshi |
| `admin_panel/RAILWAY-INTEGRATION.md` | Railway sozlama |

---

## 13. Qisqa xulosa (bir jumla)

**Supabase egress 19 GB / 5 GB limit oshib yopildi; ma’lumotlar saqlangan; oy boshida backup oling, keyin Neon (baza) + R2 (fayllar) + GitHub (APK) ga ko‘chiring — 500 user gacha bepul tier yetadi.**

---

*Yordam kerak bo‘lsa: Supabase ochilganda backup, Neon/R2 sozlash, backend migratsiya — ketma-ket qadamlar bo‘yicha davom ettiring.*
