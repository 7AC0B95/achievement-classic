# Laucob's Achievements

Retail-style achievement tracking for **World of Warcraft Classic Era / Hardcore**.

**190+ achievements** across 10 categories: General, Quests, Combat, Exploration, Wealth, Professions, Dungeons, PvP, Hardcore, and Feats of Strength.

## Install (play)

Copy the `LaucobsAchievements` folder into:

`World of Warcraft\_classic_era_\Interface\AddOns\`

Then `/reload` in-game.

## Develop

This repo is the **source of truth**. The live AddOns copy under Program Files is for in-game testing only.

Sync to the game folder (PowerShell):

```powershell
.\sync-to-wow.ps1
```

## Commands

| Command | Action |
|---------|--------|
| `/la` | Open the achievements panel |
| `/la debug` | Toggle debug mode |
| `/la debug on\|off` | Enable/disable debug mode |
| `/la reset` | Reset this character's progress |
| `/la reset <id>` | Reset one achievement (requires debug) |
| `/la share` | Show sharing status |
| `/la share on\|off` | Enable/disable peer sharing |
| `/la inspect` | Request achievements from your current target |
| `/la inspect Name` | Request achievements from a named player |

## Sharing

Completed achievements can be browsed for other players who use the addon (guild, party, raid, or `/la inspect`). Sharing is on by default; turn off with `/la share off`.

Open the **Players** sidebar to browse peers. The list is:

- **Searchable** by name
- **Filterable** by addon status (All / Addon / Pending / No addon)
- **Grouped** into Group/Raid, Guild, and Inspected (manual `/la inspect`)
