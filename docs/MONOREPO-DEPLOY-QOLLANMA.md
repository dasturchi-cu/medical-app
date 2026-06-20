# Monorepo va Deploy Qo'llanma

Bu faylning maqsadi: keyingi safar `backend`, `admin_panel` va Flutter ilova yana 2 martadan ko'payib ketmasligi uchun aniq tartib berish.

---

## 1. Hozirgi to'g'ri tuzilma

Loyihada endi bitta asosiy Flutter repo va uning ichida bitta backend repo bor:

```text
medical_app/                  ← Flutter ilova
├── lib/
├── android/
├── assets/
├── supabase/
└── backend/                  ← alohida git repo: Neuroscience-app_backend
    ├── fastapi/              ← Backend API
    └── admin_panel/          ← Admin panel
```

Muhim qoida:

- `medical_app/` ichida faqat Flutter ilova yashaydi
- `medical_app/backend/fastapi/` ichida faqat backend yashaydi
- `medical_app/backend/admin_panel/` ichida faqat admin panel yashaydi
- `medical_app/admin_panel/` degan alohida papka endi bo'lmasligi kerak
- `medical_app/backend/lib/`, `medical_app/backend/android/` kabi Flutter papkalari `backend` ichida bo'lmasligi kerak

---

## 2. Deploylar qanday ishlaydi

Ha, deploylar alohida-alohida project bo'ladi, lekin kod bitta repo ichidan olinadi.

Sizda to'g'ri variant shu:

### 1) Backend deploy

- Railway project nomi: `Neuroscience-app_backend`
- Source repo: `dasturchi-cu/Neuroscience-app_backend`
- Branch: `main`
- Root Directory: `/fastapi`

Bu project faqat FastAPI backendni deploy qiladi.

### 2) Admin deploy

- Railway project nomi: `Neuroscience_admin_panel`
- Source repo: `dasturchi-cu/Neuroscience-app_backend`
- Branch: `main`
- Root Directory: `/admin_panel`

Bu project faqat admin panelni deploy qiladi.

### Xulosa

Bir repo ichida 2 ta alohida deploy bo'lishi mumkin:

- biri `fastapi/` ni ishga tushiradi
- biri `admin_panel/` ni ishga tushiradi

Demak:

- repo bitta
- deploy service/project 2 ta
- har birining Root Directory si boshqa

---

## 3. Nega oldin dublikat chiqib ketdi

Oldin quyidagi holat aralashib ketgan edi:

- Flutter ilova rootda bor edi
- shu Flutter kodi yana `backend/` repo ichiga ham kirib qolgan edi
- admin panel alohida repo sifatida ham bor edi
- admin panel yana `backend/admin_panel/` ichida ham bor edi

Shuning uchun:

- qaysi repo haqiqiy ekanini adashtirish oson bo'ldi
- Railway noto'g'ri joydan build qilishi mumkin edi
- bir joydagi o'zgarish boshqa joyga tushmay qolardi

---

## 4. Keyingi safar dublikat chiqmasligi uchun qoida

Har safar ish boshlashdan oldin shu qoidaga qarang:

### Flutter bilan ishlasangiz

Faqat shu papkada ishlang:

```text
medical_app/
```

Flutterga oid fayllar:

- `lib/`
- `android/`
- `assets/`
- `pubspec.yaml`

Bu fayllarni `medical_app/backend/` ichida yaratmang.

### Backend bilan ishlasangiz

Faqat shu papkada ishlang:

```text
medical_app/backend/fastapi/
```

Backendga oid narsalar:

- `app/`
- `requirements.txt`
- `.env`

### Admin panel bilan ishlasangiz

Faqat shu papkada ishlang:

```text
medical_app/backend/admin_panel/
```

Adminga oid narsalar:

- `app/`
- `components/`
- `package.json`
- `next.config.*`

`medical_app/admin_panel/` degan yangi alohida loyiha ochmang.

---

## 5. Railwayda yangi deploy qo'shish tartibi

Agar keyin yana qaytadan sozlash kerak bo'lsa:

### Backend uchun

1. Railwayda yangi project oching yoki mavjud backend projectga kiring
2. GitHub repo sifatida `dasturchi-cu/Neuroscience-app_backend` ni tanlang
3. Branch: `main`
4. Root Directory: `/fastapi`
5. Env variable larni kiriting
6. Deploy qiling

### Admin uchun

1. Railwayda alohida project oching yoki mavjud admin projectga kiring
2. GitHub repo sifatida yana o'sha `dasturchi-cu/Neuroscience-app_backend` ni tanlang
3. Branch: `main`
4. Root Directory: `/admin_panel`
5. Kerakli env variable larni kiriting
6. Deploy qiling

Muhim:

- backend va admin bitta repo ichidan deploy bo'ladi
- lekin Railwayda ular 2 ta alohida project bo'lib turadi
- har biri mustaqil deploy history, logs va variables ga ega bo'ladi

---

## 6. Qaysi o'zgarishni qaysi repo ga push qilish kerak

### Agar Flutter o'zgarsa

`medical_app/` root repoga push qilinadi.

Masalan:

- UI
- APK
- `lib/`
- `android/`

### Agar backend yoki admin o'zgarsa

`medical_app/backend/` ichidagi repoga push qilinadi.

Masalan:

- `fastapi/`
- `admin_panel/`

Muhim:

- Flutter repo boshqa
- monorepo backend repo boshqa

---

## 7. Eng oddiy ish tartibi

Quyidagi tartib bilan ishlasangiz chalkashmaysiz:

### Flutter uchun

```powershell
cd c:\Users\User\medical_app
git status
```

### Backend/admin uchun

```powershell
cd c:\Users\User\medical_app\backend
git status
```

Qaysi papkada turganingizni doim tekshiring.

---

## 8. Tekshiruv ro'yxati

Deploydan oldin shuni tekshiring:

- `medical_app/admin_panel/` yo'qmi?
- `medical_app/backend/lib/` yo'qmi?
- `medical_app/backend/android/` yo'qmi?
- `medical_app/backend/backend/` yo'qmi?
- Railway backend Root Directory `/fastapi` mi?
- Railway admin Root Directory `/admin_panel` mi?
- To'g'ri repo ga push qildingizmi?

Agar shu savollarga javob to'g'ri bo'lsa, yana dublikat chiqishi juda qiyin bo'ladi.

---

## 9. Bir jumlalik eslab qolish

**Flutter rootda yashaydi, backend va admin `backend/` repo ichida yashaydi, Railwayda esa ular 2 ta alohida project bo'lib, Root Directory orqali ajraladi.**
