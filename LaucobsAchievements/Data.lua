--[[
  LaucobsAchievements - Data
  Static achievement definitions and categories.
  Player completion/progress lives in SavedVariables (see Core.lua).
]]

local addonName, LA = ...

-- Category metadata (order controls sidebar sorting)
LA.Categories = {
  { id = "General",          name = "General",          order = 1 },
  { id = "Hardcore",         name = "Hardcore",         order = 2 },
  { id = "Exploration",      name = "Exploration",      order = 3 },
  { id = "Feats of Strength", name = "Feats of Strength", order = 4 },
}

--[[
  criteria types used by Tracker.lua:
    LEVEL   - player reaches criteria.value
    MONEY   - accumulate looted copper to criteria.value (10000 = 1g)
    HEALTH  - survive with healthPct <= criteria.threshold (percent)
    KILLS   - accumulate kills matching criteria.match (optional substring)
    QUESTS  - accumulate quest turn-ins to criteria.value
    CUSTOM  - manual / future hooks
]]

LA.Achievements = {
  -- General -----------------------------------------------------------------
  [1000] = {
    id = 1000,
    title = "First Steps",
    description = "Reach level 2.",
    icon = "Interface\\Icons\\Spell_Nature_Regeneration",
    points = 5,
    category = "General",
    criteria = {
      { type = "LEVEL", value = 2 },
    },
  },
  [1001] = {
    id = 1001,
    title = "Welcome to the World",
    description = "Reach level 10.",
    icon = "Interface\\Icons\\Spell_Nature_Strength",
    points = 10,
    category = "General",
    criteria = {
      { type = "LEVEL", value = 10 },
    },
  },
  [1002] = {
    id = 1002,
    title = "Pocket Change",
    description = "Loot a total of 100 gold (cumulative wealth).",
    icon = "Interface\\Icons\\INV_Misc_Coin_02",
    points = 10,
    category = "General",
    criteria = {
      -- 100 gold in copper
      { type = "MONEY", value = 100 * 10000 },
    },
  },
  [1003] = {
    id = 1003,
    title = "Murloc Massacre",
    description = "Slay 100 murlocs.",
    icon = "Interface\\Icons\\INV_Misc_MonsterHead_02",
    points = 10,
    category = "General",
    criteria = {
      { type = "KILLS", value = 100, match = "murloc" },
    },
  },
  [1004] = {
    id = 1004,
    title = "Of Quests and Heroes",
    description = "Complete a quest for the first time.",
    icon = "Interface\\Icons\\INV_Misc_Note_02",
    points = 5,
    category = "General",
    criteria = {
      { type = "QUESTS", value = 1 },
    },
  },

  -- Hardcore ----------------------------------------------------------------
  [2001] = {
    id = 2001,
    title = "Near Death Experience",
    description = "Survive combat after dropping below 5% health.",
    icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    points = 10,
    category = "Hardcore",
    criteria = {
      -- value = steps to complete; threshold = max HP% that arms the criteria
      { type = "HEALTH", value = 1, threshold = 5 },
    },
  },
  [2002] = {
    id = 2002,
    title = "Seasoned Survivor",
    description = "Reach level 20 on a Hardcore character.",
    icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    points = 25,
    category = "Hardcore",
    criteria = {
      { type = "LEVEL", value = 20 },
    },
  },

  -- Exploration -------------------------------------------------------------
  [3001] = {
    id = 3001,
    title = "Getting Your Bearings",
    description = "Reach level 5 — your first steps into Azeroth.",
    icon = "Interface\\Icons\\Ability_TownWatch",
    points = 5,
    category = "Exploration",
    criteria = {
      { type = "LEVEL", value = 5 },
    },
  },

  -- Feats of Strength -------------------------------------------------------
  [9001] = {
    id = 9001,
    title = "Did Somebody Say...?",
    description = "A feat reserved for those who defy the odds. Reach level 60.",
    icon = "Interface\\Icons\\Spell_Holy_SummonChampion",
    points = 0, -- Feats of Strength traditionally award no points
    category = "Feats of Strength",
    criteria = {
      { type = "LEVEL", value = 60 },
    },
  },
}

--- Achievements belonging to a category, sorted by id.
function LA:GetAchievementsByCategory(categoryId)
  local list = {}
  for id, def in pairs(self.Achievements) do
    if def.category == categoryId then
      list[#list + 1] = def
    end
  end
  table.sort(list, function(a, b)
    return a.id < b.id
  end)
  return list
end

--- Sum of points earned by the current character.
function LA:GetEarnedPoints()
  local total = 0
  for id, def in pairs(self.Achievements) do
    if self:IsComplete(id) then
      total = total + (def.points or 0)
    end
  end
  return total
end

--- Overall progress for display: current, required (uses first criteria or sum).
function LA:GetAchievementProgress(achievementId)
  local def = self.Achievements[achievementId]
  if not def or not def.criteria or #def.criteria == 0 then
    return 0, 1
  end

  -- Multi-criteria: require all; show aggregate for the progress bar
  local current, required = 0, 0
  for i, crit in ipairs(def.criteria) do
    local target = crit.value or 1
    required = required + target
    local prog = self:GetProgress(achievementId, i)
    if prog > target then
      prog = target
    end
    current = current + prog
  end
  return current, required
end
