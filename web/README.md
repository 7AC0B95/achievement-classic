# Classic Glory — web

Next.js app for public leaderboards, character profiles, and uploading the addon SavedVariables file.

Full setup (addon install, file path, Supabase, catalog regen) is in the [root README](../README.md).

## Run locally

```bash
cp .env.example .env.local
# fill NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

| Variable | Purpose |
| --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Publishable / anon key |

Without env vars the UI still loads; live activity and the leaderboard stay empty until you configure Supabase and sync a `.lua` file.

## Upload file

After logging out of WoW, upload:

```
World of Warcraft\_classic_era_\WTF\Account\<Account>\SavedVariables\ClassicGlory.lua
```

Older `LaucobsAchievements.lua` files still parse. Sample parser input: [`sample-ClassicGlory.lua`](sample-ClassicGlory.lua).

## Scripts

```bash
npm run dev    # next dev
npm run build  # production build
npm run start  # serve the production build
npm run lint   # eslint
```
