# HeyCutu - The Fun Side of Love 💬❤️

Couples ke liye game web app. React + Vite se bana hai. Free mein GitHub aur Vercel par host hota hai.

---

## Step 1: Computer par Node.js install karein (ek baar)

1. https://nodejs.org par jaayein.
2. **LTS** version download karke install karein.
3. Check karein terminal mein:
   ```bash
   node -v
   npm -v
   ```
   Dono version number dikhane chahiye.

---

## Step 2: Project local par chalayein

Project folder (heycutu-app) ke andar terminal kholein:

```bash
npm install
npm run dev
```

Browser mein `http://localhost:5173` kholein. Game chal rahi hogi.

Band karne ke liye terminal mein `Ctrl + C` dabayein.

---

## Step 3: GitHub account aur repository banayein

1. https://github.com par free account banayein.
2. Upar **+** → **New repository** par click karein.
3. Naam dein: `heycutu`
4. **Public** select karein (Vercel free plan ke liye sahi hai).
5. **Create repository** dabayein.

---

## Step 4: Code GitHub par upload karein

### Option A: Bina coding ke (browser se)
1. Apni repository kholein.
2. **uploading an existing file** link par click karein.
3. Poora `heycutu-app` folder ke andar ki files (node_modules ko chhod kar) drag karke daal dein.
4. **Commit changes** dabayein.

### Option B: Git commands se (recommended)
Computer par Git install karein (https://git-scm.com), phir project folder mein:

```bash
git init
git add .
git commit -m "HeyCutu first version"
git branch -M main
git remote add origin https://github.com/APNA-USERNAME/heycutu.git
git push -u origin main
```

`APNA-USERNAME` ki jagah apna GitHub username likhein. Pehli baar push karte waqt GitHub login maangega.

---

## Step 5: Vercel par free hosting (live link)

1. https://vercel.com par jaayein aur **Continue with GitHub** se login karein.
2. **Add New → Project** click karein.
3. Apni `heycutu` repository ke saamne **Import** dabayein.
4. Settings mein kuch change na karein. Vercel Vite project ko khud pehchan leta hai.
5. **Deploy** dabayein.
6. 1-2 minute mein aapko link milega, jaise `heycutu.vercel.app`.

**Ab se:** GitHub par jo bhi change push karoge, Vercel apne aap naya version live kar dega.

---

## Free hosting ke aur options

| Platform | Kaise deploy karein | Free limit |
|---|---|---|
| **Vercel** (recommended) | GitHub se import | Personal use ke liye kaafi |
| **Netlify** | `npm run build` karke `dist` folder drag & drop | Bahut acha, simple |
| **Cloudflare Pages** | GitHub se connect | Unlimited bandwidth |
| **GitHub Pages** | Repo Settings → Pages | Static sites ke liye |

Netlify par drag & drop ke liye:
```bash
npm run build
```
Phir https://app.netlify.com/drop par `dist` folder drag kar dein.

---

## Custom domain (optional, paid)

Agar `heycutu.com` chahiye, to domain kharidna padega (lagbhag ₹800-1000/saal). Phir Vercel dashboard → Project → Settings → Domains mein add karein aur DNS instructions follow karein.

---

## Important: Leaderboard kaise kaam karta hai

Abhi leaderboard browser ki **localStorage** mein save hota hai. Matlab:
- Wo sirf usi device/browser par dikhega jahan score khela gaya.
- Sabke liye shared leaderboard nahi hai.

### Next step: Shared leaderboard (free)
Sabke scores ek jagah dikhane ke liye free backend chahiye. Sabse aasaan option:
- **Supabase** (free tier): database + API. Ye project mein add kiya ja sakta hai.
- Ya Google Sheets + Apps Script (bina database ke).

Ye chahiye to bataiye, main woh code add kar dunga.

---

## Next steps: Aur games kaise jodein

`src/App.jsx` mein `QUESTIONS` array ke saath naye sawal jodein. Naya game chahiye to alag component banakar `screen` state mein add karein.

---

## Folder structure

```
heycutu-app/
├── index.html
├── package.json
├── vite.config.js
├── .gitignore
├── README.md
└── src/
    ├── main.jsx
    ├── App.jsx      ← game aur leaderboard logic
    └── App.css      ← styling
```

---

## Common problems

- **`npm` command nahi chal raha:** Node.js dobara install karke terminal band karke kholein.
- **Vercel build fail:** Check karein `package.json` project root mein hai, aur `npm run build` local par chalta hai.
- **GitHub push mein error:** Repository ka naam aur username sahi hai ya nahi, ye check karein.
