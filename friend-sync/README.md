# Friend sync (Windows)

Keeps **Classic Glory** in your Classic Era AddOns folder up to date with GitHub. No Git install. Website sync still uses the SavedVariables file the addon writes on logout — this script only updates the addon itself.

## Quick start

1. Put this `friend-sync` folder somewhere permanent (e.g. `Documents\ClassicGlory-sync\`).
2. Double-click **`Update-Addon.bat`**.
   - Finds `_classic_era_\Interface\AddOns` (or asks once).
   - On open, always pulls a fresh copy of the tip from GitHub, then **keeps watching** and updates whenever you push.
   - Removes the old `LaucobsAchievements` folder if it is still present.
3. Leave the window open while playing. Press **Ctrl+C** to stop.

In-game after an update: `/reload`.

## Options

| What | How |
|------|-----|
| Continuous (default) | `Update-Addon.bat` — polls every 10s |
| Faster polling | `Update-Addon.bat -IntervalSeconds 5` |
| One-shot update | `Update-Addon.bat -Once` |

## Notes

- Needs internet access to GitHub.
- Each poll hits GitHub's public commits feed (not the rate-limited REST API). Addon files are pulled from `raw.githubusercontent.com` only when the tip commit changes.
- If WoW is under Program Files and Windows blocks writes, run as Administrator once, or install WoW somewhere writable.
- Auto-detects Classic Era AddOns on any drive (including nested paths like `W:\Games\World of Warcraft`). Missing lettered drives are skipped safely.
- Saved path / last sync: `%LOCALAPPDATA%\ClassicGlory\`
