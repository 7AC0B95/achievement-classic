# Friend sync (Windows)

Keeps **Laucob's Achievements** in your Classic Era AddOns folder up to date with GitHub. No Git install.

## Quick start

1. Put this `friend-sync` folder somewhere permanent (e.g. `Documents\LaucobsAchievements-sync\`).
2. Double-click **`Update-Addon.bat`**.
   - Finds `_classic_era_\Interface\AddOns` (or asks once).
   - Syncs immediately, then **keeps watching** GitHub and updates whenever you push.
3. Leave the window open while playing. Press **Ctrl+C** to stop.

In-game after an update: `/reload`.

## Options

| What | How |
|------|-----|
| Continuous (default) | `Update-Addon.bat` — polls every 10s |
| Faster polling | `Update-Addon.bat -IntervalSeconds 5` |
| One-shot update | `Update-Addon.bat -Once` |
| Background hourly | Double-click `Install-AutoUpdate.bat` (Task Scheduler) |

## Uninstall scheduled auto-update

```powershell
powershell -ExecutionPolicy Bypass -File ".\Install-AutoUpdate.ps1" -Uninstall
```

## Notes

- Needs internet access to GitHub.
- Each poll is a tiny conditional API request; when you push, only files under `LaucobsAchievements/` are fetched and replaced in AddOns (not `friend-sync` or other repo files).
- If WoW is under Program Files and Windows blocks writes, run as Administrator once, or install WoW somewhere writable.
- Saved path / last sync: `%LOCALAPPDATA%\LaucobsAchievements\`
