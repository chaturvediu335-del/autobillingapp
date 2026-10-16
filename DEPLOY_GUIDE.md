# Om Logistics — Netlify + Supabase Deploy Guide

Is folder me:

| File | Kaam |
|---|---|
| `public/index.html` | Poora app |
| `public/config.js` | Yahan Supabase URL + anon key daalni hai |
| `netlify/functions/staff-admin.js` | Admin ke liye staff banana / password reset / delete |
| `netlify.toml` | Netlify settings |
| `supabase-schema.sql` | Database tables + security rules |

> Config khali chhodo to app purane "local mode" me chalta hai (sirf ek browser me). Supabase daalte hi shared (multi-device) ban jaata hai.

---

## Step 1 — Supabase project banao
1. https://supabase.com par sign up / login karein → **New project**.
2. Name: `om-logistics`, ek strong **Database Password** rakhein (save kar lein), Region: **Mumbai (ap-south-1)**.
3. Project ready hone tak 1–2 minute wait karein.

## Step 2 — Database tables banao
1. Supabase me left menu → **SQL Editor** → **New query**.
2. `supabase-schema.sql` ka poora content paste karein → **Run**. "Success" aana chahiye.

## Step 3 — Signup band karo (bahut zaroori)
1. **Authentication → Sign In / Providers → Email**.
2. **"Allow new users to sign up"** ko **OFF** karein → Save.
   (Warna koi bhi bahar wala anon key se khud account bana ke data dekh sakta hai.)
3. Agar **"Confirm email"** ON ho to bhi chalega — hum users ko already-confirmed banate hain.

## Step 4 — Admin account banao
1. **Authentication → Users → Add user → Create new user**.
2. Email: `admin@omlogistics.app` , Password: apna strong password (min 6), **Auto Confirm User** ✅ → Create.
3. **SQL Editor** me ye chalayein (admin ko admin role dene ke liye):
```sql
insert into public.profiles (id, username, name, role)
select id, 'admin', 'Admin', 'admin' from auth.users where email = 'admin@omlogistics.app'
on conflict (id) do update set role = 'admin', username = 'admin', name = 'Admin';
```
4. App me login hamesha **username** se hota hai (`admin`), email nahi.

## Step 5 — Keys copy karo
**Project Settings → API** se:
- **Project URL** (https://xxxx.supabase.co)
- **anon / publishable key** (public key)
- **service_role key** (SECRET — sirf Step 8 me Netlify me jaayegi)

`public/config.js` kholkar URL aur **anon** key paste karein:
```js
window.OM_CONFIG = {
  SUPABASE_URL: "https://xxxx.supabase.co",
  SUPABASE_ANON_KEY: "eyJ...."
};
```
⚠️ `service_role` key kabhi `config.js` ya index.html me na daalein.

## Step 6 — GitHub par upload karo
(Functions ke liye Netlify ka drag-and-drop bharosemand nahi hai, isliye GitHub se deploy karein.)
1. https://github.com → **New repository** → name `om-logistics` → **Private** → Create.
2. **uploading an existing file** link par click karein → is folder ki saari files/folders (`public`, `netlify`, `netlify.toml`, SQL, guide) drag karein → **Commit changes**.
   - `public/index.html` ~3 MB hai, GitHub upload me chal jaata hai.

## Step 7 — Netlify par site banao
1. https://app.netlify.com → **Add new project → Import an existing project → GitHub** → `om-logistics` chunein.
2. Build settings: **Build command** khali, **Publish directory** `public` (netlify.toml se apne-aap aa jaayega) → **Deploy**.

## Step 8 — Netlify me secret keys daalo
1. Site → **Project configuration → Environment variables → Add a variable**:
   - `SUPABASE_URL` = Project URL
   - `SUPABASE_SERVICE_ROLE_KEY` = service_role key
2. **Deploys → Trigger deploy → Deploy site** (naya deploy, taaki function ko keys mil jaayein).

## Step 9 — Pehli baar chalao (ORDER ZAROORI)
1. Site URL kholein → pehle **admin** se login karein. Ye pehli login built-in billing data server par upload karti hai.
2. **Staff Users** tab → naya staff banayein (username a-z/0-9, password min 6).
3. Ab staff apne phone/computer se login karke data entry kare → **Submit**.
4. Admin ke **Auto Billing**, **Employee Report** aur **Work Dashboard** me data aa jaata hai. Admin ka tab khula ho to ~30 second me khud update; turant ke liye **🔄 Sync** dabayein.

> Staff ko login admin ke pehli baar login karne **se pehle** na dein — warna staff ka auto-add tab tak ruka rahega jab tak admin ek baar login na kare.

## Step 10 — Purana data (agar pehle local me kaam kiya ho)
Admin us purane browser me, jahan data hai, naye URL par login kare — server khali hone par local billing data, reports aur submissions automatically upload ho jaate hain.

---

## Ye jaanna zaroori hai
- **Auto-add ON (default):** staff Submit → data turant Auto Billing + Employee Report me. Work Dashboard me toggle OFF karne se Verify wala flow wapas aa jaata hai.
- **Security ka level:** staff apni submissions hi dekh sakte hain, par billing data padh/likh sakte hain (auto-add ke liye zaroori). Billing rows delete sirf admin kar sakta hai.
- **Employees directory** tab ka data (naam/code list) abhi bhi file ke andar hai, server me save nahi hota. Employee Code is list se apne-aap bharta hai.
- **Update karna:** GitHub me file badlo → Netlify apne-aap deploy kar deta hai.
- **Free plan:** Supabase free project ~1 hafta inactive rahe to pause ho sakta hai — dashboard se "Restore" karein. Regular use me dikkat nahi.

## Dikkat aaye to
| Dikkat | Wajah / hal |
|---|---|
| Login par "Supabase library load nahi hui" | Internet / CDN block; refresh karein |
| "Is user ka profile nahi mila" | Step 4 ka SQL chalayein |
| "Username ya password galat" | Username lowercase me; password sahi ho |
| Staff add par "Netlify me ... set nahi hain" | Step 8 + naya deploy |
| Staff submit par data dashboard me nahi aaya | Admin ne pehli login nahi ki (Step 9.1) |
| Data kisi device par nahi dikh raha | 🔄 Sync dabayein |
