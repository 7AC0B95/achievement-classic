# Classic Glory

Retail-style achievement tracking for **World of Warcraft Classic Era / Hardcore** (addon **v0.10.1**), plus a web platform to share progress on public leaderboards.

**190+ achievements** across 10 categories: General, Quests, Combat, Exploration, Wealth, Professions, Dungeons, PvP, Hardcore, and Feats of Strength.

## Architecture

| Piece | Path | Role |
| --- | --- | --- |
| WoW Addon | [`ClassicGlory/`](ClassicGlory/) | Tracks events, unlocks achievements, peer share, writes account-wide SavedVariables |
| Web App | [`web/`](web/) | Leaderboards, dashboard, Lua upload / multi-character sync |
| Database | [`supabase/migrations/`](supabase/migrations/) | Profiles, characters, achievements, RLS, catalog seed |

Data flow: **Addon → `ClassicGlory.lua` → Browser file picker → Lua parser → Supabase upsert**.

---

## 1. Install the addon (play)

Copy the `ClassicGlory` folder into:

`World of Warcraft\_classic_era_\Interface\AddOns\`

Then `/reload` in-game. Remove the old `LaucobsAchievements` folder if it is still there.

If you already had progress, copy:

`WTF\Account\<Account>\SavedVariables\LaucobsAchievements.lua`

to:

`WTF\Account\<Account>\SavedVariables\ClassicGlory.lua`

The addon also adopts `LaucobsAchievementsDB` if that global is still in the copied file.

### Develop

This repo is the **source of truth**. Sync to the game folder (PowerShell):

```powershell
.\sync-to-wow.ps1
```

### Commands

| Command | Action |
|---------|--------|
| `/cg` | Open the achievements panel |
| `/cg web` | Show where to find the upload file for the website |
| `/cg debug` | Toggle debug mode |
| `/cg debug on\|off` | Enable/disable debug mode |
| `/cg reset` | Reset this character's progress |
| `/cg reset <id>` | Reset one achievement (requires debug) |
| `/cg share` | Show sharing status |
| `/cg share on\|off` | Enable/disable peer sharing |
| `/cg inspect` | Request achievements from your current target |
| `/cg inspect Name` | Request achievements from a named player |

`/la`, `/classicglory`, `/laach`, and `/lachievements` still work as aliases.

### In-game panel

`/cg` opens on **Summary**: overall points and earned count, per-category progress, the last three earns, and up to three almost-finished achievements. The panel remembers its size and position; the minimap button remembers where you dragged it.

Category lists are searchable (title and description; a query searches every category). Filter with All / Earned / Incomplete / Almost, and sort with Default / Recent / Points / A-Z. Hover a card for criteria progress.

### In-game sharing

Completed achievements can be browsed for other players who use the addon (guild, party, raid, or `/cg inspect`). Sharing is on by default; turn off with `/cg share off`.

Open the **Players** sidebar to browse peers. The list defaults to players with the addon, is searchable by name, and can be filtered with All / Addon / No addon. Use **Inspect current target** (or `/cg inspect`) to request a targeted player. Peers are grouped into Group/Raid, Guild, and Inspected.

---

## 2. Website sync (upload file)

After playing, **log out** so WoW flushes SavedVariables. Upload this **account-wide** file on the dashboard:

```
World of Warcraft\_classic_era_\WTF\Account\<Account>\SavedVariables\ClassicGlory.lua
```

One file contains every character on the account. The dashboard lists them so you can sync selected characters (or all).

Uploads must be written by addon **v0.6.0+** (tamper-evident seal). After updating, log in once and log out so every character on the account is sealed — unsigned or hand-edited files are rejected.

In-game tip: `/cg web`.

A sample file for parser testing lives at [`web/sample-ClassicGlory.lua`](web/sample-ClassicGlory.lua).

---

## 3. Supabase setup

1. Create a project at [supabase.com](https://supabase.com) (or reuse an existing one).
2. Open **SQL Editor** and run, in order:

   - [`supabase/migrations/20260812100000_laucobs_initial_schema.sql`](supabase/migrations/20260812100000_laucobs_initial_schema.sql) — tables, RLS, and the original achievement catalog (fresh projects)
   - [`supabase/migrations/20260812220000_laucobs_catalog_and_stats.sql`](supabase/migrations/20260812220000_laucobs_catalog_and_stats.sql) — only if the database already had the older Achieve-mint schema
   - [`supabase/migrations/20260813220000_character_achievements_delete_policy.sql`](supabase/migrations/20260813220000_character_achievements_delete_policy.sql) — owners can delete leftover unlocks on reseal
   - [`supabase/migrations/20260815190000_world_buff_feats.sql`](supabase/migrations/20260815190000_world_buff_feats.sql) — Zandalar / Onyxia / Rend Feats of Strength (existing projects)

3. Enable **Email** auth (magic link) under Authentication → Providers.
4. Add redirect URLs: `http://localhost:3000/auth/callback` and your production callback URL.

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

When [`ClassicGlory/Data.lua`](ClassicGlory/Data.lua) changes:

```bash
node scripts/extract-achievements.mjs
```

This refreshes [`web/src/lib/achievements.ts`](web/src/lib/achievements.ts), [`web/src/lib/achievement-rules.ts`](web/src/lib/achievement-rules.ts), and [`scripts/seed-achievements.sql`](scripts/seed-achievements.sql). Merge the seed into a new Supabase migration if the live catalog needs updating.

---

## Friend updater

See [`friend-sync/`](friend-sync/) for an optional Windows script that pulls the addon from GitHub into the AddOns folder.
