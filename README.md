# Laucob's Achievements

Retail-style achievement tracking for **World of Warcraft Classic Era / Hardcore**, plus a web platform to share progress on public leaderboards.

**190+ achievements** across 10 categories: General, Quests, Combat, Exploration, Wealth, Professions, Dungeons, PvP, Hardcore, and Feats of Strength.

## Architecture

| Piece | Path | Role |
| --- | --- | --- |
| WoW Addon | [`LaucobsAchievements/`](LaucobsAchievements/) | Tracks events, unlocks achievements, peer share, writes account-wide SavedVariables |
| Web App | [`web/`](web/) | Leaderboards, dashboard, Lua upload / multi-character sync |
| Database | [`supabase/migrations/`](supabase/migrations/) | Profiles, characters, achievements, RLS, catalog seed |

Data flow: **Addon → `LaucobsAchievements.lua` → Browser file picker → Lua parser → Supabase upsert**.

---

## 1. Install the addon (play)

Copy the `LaucobsAchievements` folder into:

`World of Warcraft\_classic_era_\Interface\AddOns\`

Then `/reload` in-game.

### Develop

This repo is the **source of truth**. Sync to the game folder (PowerShell):

```powershell
.\sync-to-wow.ps1
```

### Commands

| Command | Action |
|---------|--------|
| `/la` | Open the achievements panel |
| `/la web` | Show where to find the upload file for the website |
| `/la debug` | Toggle debug mode |
| `/la debug on\|off` | Enable/disable debug mode |
| `/la reset` | Reset this character's progress |
| `/la reset <id>` | Reset one achievement (requires debug) |
| `/la share` | Show sharing status |
| `/la share on\|off` | Enable/disable peer sharing |
| `/la inspect` | Request achievements from your current target |
| `/la inspect Name` | Request achievements from a named player |

### In-game sharing

Completed achievements can be browsed for other players who use the addon (guild, party, raid, or `/la inspect`). Sharing is on by default; turn off with `/la share off`.

---

## 2. Website sync (upload file)

After playing, **log out** so WoW flushes SavedVariables. Upload this **account-wide** file on the dashboard:

```
World of Warcraft\_classic_era_\WTF\Account\<Account>\SavedVariables\LaucobsAchievements.lua
```

One file contains every character on the account. The dashboard lists them so you can sync selected characters (or all).

In-game tip: `/la web`.

---

## 3. Supabase setup

1. Create a project at [supabase.com](https://supabase.com).
2. Open **SQL Editor** and run:

[`supabase/migrations/20260812100000_laucobs_initial_schema.sql`](supabase/migrations/20260812100000_laucobs_initial_schema.sql)

This creates profiles, characters, achievements, character_achievements, character_stats, RLS, and the 190-achievement catalog seed.

3. Enable **Email** auth (magic link) under Authentication → Providers.
4. Add redirect URL: `http://localhost:3000/auth/callback` (and your production URL).

---

## 4. Run the web app

```bash
cd web
cp .env.example .env.local
# fill NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

Without env vars the UI still loads; leaderboard and live activity stay empty until Supabase is configured and characters are synced.

### Pages

- `/` — Landing, live activity feed, overall leaderboard
- `/dashboard` — Auth, file upload, character picker, your characters
- `/leaderboard` — Filters: realm, class, status, sort
- `/achievements` — Full catalog (10 categories)
- `/characters/[id]` — Public character profile

### Regenerating the catalog from the addon

When `LaucobsAchievements/Data.lua` changes:

```bash
node scripts/extract-achievements.mjs
```

This refreshes `web/src/lib/achievements.ts` and prints a SQL seed fragment (re-run / update the migration seed as needed for fresh projects).

---

## Friend updater

See [`friend-sync/`](friend-sync/) for an optional Windows script that pulls the addon from GitHub into the AddOns folder.
