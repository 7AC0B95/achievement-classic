--[[
  LaucobsAchievements - Tracker
  Central event frame + criteria routing for Classic Era / Hardcore.
]]

local addonName, LA = ...

local Tracker = {}
LA.Tracker = Tracker

local frame = CreateFrame("Frame")
Tracker.frame = frame

-- Pending low-HP flag: set when we dip below threshold while in combat;
-- cleared / completed when we leave combat still alive.
local lowHpArmed = {} -- [achievementId] = true

local function PlayerAlive()
  return not UnitIsDeadOrGhost("player")
end

local function CheckLevelCriteria(def, crit, critIndex, levelOverride)
  -- On PLAYER_LEVEL_UP, UnitLevel("player") is still the old level in Classic.
  -- Prefer the level passed from the event payload when present.
  local level = levelOverride or UnitLevel("player") or 1
  local target = crit.value or 1
  LA:SetProgress(def.id, critIndex, math.min(level, target))
  if level >= target then
    LA:CompleteAchievement(def.id)
  end
end

local function CheckMoneyCriteria(def, crit, critIndex)
  local money = GetMoney() or 0
  local target = crit.value or 0
  LA:SetProgress(def.id, critIndex, math.min(money, target))
  if money >= target then
    LA:CompleteAchievement(def.id)
  end
end

local function ArmHealthCriteria(def, crit)
  if LA:IsComplete(def.id) then
    return
  end
  if not UnitAffectingCombat("player") then
    return
  end
  local hp = UnitHealth("player") or 0
  local max = UnitHealthMax("player") or 1
  if max <= 0 then
    return
  end
  local pct = (hp / max) * 100
  local threshold = crit.threshold or crit.value or 5
  if pct > 0 and pct <= threshold then
    lowHpArmed[def.id] = true
  end
end

local function ResolveHealthCriteria(def)
  if not lowHpArmed[def.id] then
    return
  end
  lowHpArmed[def.id] = nil
  if PlayerAlive() then
    LA:SetProgress(def.id, 1, 1)
    LA:CompleteAchievement(def.id)
  end
end

local function CheckKillCriteria(def, crit, critIndex, destName)
  if LA:IsComplete(def.id) then
    return
  end
  if not destName then
    return
  end

  local match = crit.match
  if match then
    local lower = destName:lower()
    if not lower:find(match:lower(), 1, true) then
      return
    end
  end

  local current = LA:GetProgress(def.id, critIndex)
  local target = crit.value or 1
  current = current + 1
  LA:SetProgress(def.id, critIndex, current)
  if current >= target then
    LA:CompleteAchievement(def.id)
  elseif LA.UI and LA.UI.Refresh then
    -- Lightweight refresh for progress bars
    LA.UI:Refresh()
  end
end

local function CheckQuestCriteria(def, crit, critIndex)
  if LA:IsComplete(def.id) then
    return
  end
  local current = LA:GetProgress(def.id, critIndex) + 1
  local target = crit.value or 1
  LA:SetProgress(def.id, critIndex, current)
  if current >= target then
    LA:CompleteAchievement(def.id)
  elseif LA.UI and LA.UI.Refresh then
    LA.UI:Refresh()
  end
end

--- Route a logical event to all matching achievement criteria.
-- @param kind string  "LEVEL" | "MONEY" | "HEALTH_UPDATE" | "HEALTH_LEAVE_COMBAT" | "KILL" | "QUEST"
-- @param payload table optional context (e.g. { name = destName })
function Tracker:Route(kind, payload)
  if not LA.loaded or not LA.Achievements then
    return
  end

  for id, def in pairs(LA.Achievements) do
    if not LA:IsComplete(id) and def.criteria then
      for i, crit in ipairs(def.criteria) do
        local ctype = crit.type
        if kind == "LEVEL" and ctype == "LEVEL" then
          CheckLevelCriteria(def, crit, i, payload and payload.level)
        elseif kind == "MONEY" and ctype == "MONEY" then
          CheckMoneyCriteria(def, crit, i)
        elseif kind == "HEALTH_UPDATE" and ctype == "HEALTH" then
          ArmHealthCriteria(def, crit)
        elseif kind == "HEALTH_LEAVE_COMBAT" and ctype == "HEALTH" then
          ResolveHealthCriteria(def)
        elseif kind == "KILL" and ctype == "KILLS" then
          CheckKillCriteria(def, crit, i, payload and payload.name)
        elseif kind == "QUEST" and ctype == "QUESTS" then
          CheckQuestCriteria(def, crit, i)
        end
      end
    end
  end
end

local function OnCombatLogEvent()
  local _, subevent, _, _, _, _, _, _, destName = CombatLogGetCurrentEventInfo()
  if subevent ~= "PARTY_KILL" and subevent ~= "UNIT_DIED" then
    -- Prefer party/self kills: UNIT_DIED fires for everything; filter to player-attributed kills via PARTY_KILL
    return
  end
  -- PARTY_KILL is the Classic-friendly "you (or your party) got credit" signal
  if subevent == "PARTY_KILL" then
    Tracker:Route("KILL", { name = destName })
  end
end

local function OnEvent(_, event, ...)
  if event == "PLAYER_LEVEL_UP" then
    local newLevel = ...
    Tracker:Route("LEVEL", { level = newLevel })
    Tracker:Route("MONEY")
  elseif event == "PLAYER_ENTERING_WORLD" then
    Tracker:Route("LEVEL")
    Tracker:Route("MONEY")
  elseif event == "PLAYER_MONEY" then
    Tracker:Route("MONEY")
  elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
    local unit = ...
    if unit == "player" then
      Tracker:Route("HEALTH_UPDATE")
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    -- Left combat
    Tracker:Route("HEALTH_LEAVE_COMBAT")
  elseif event == "PLAYER_DEAD" then
    -- Death cancels any pending near-death arms
    wipe(lowHpArmed)
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    OnCombatLogEvent()
  elseif event == "QUEST_TURNED_IN" then
    Tracker:Route("QUEST")
  elseif event == "BAG_UPDATE" then
    -- Money can also shift via loot; PLAYER_MONEY covers it, but re-check wealth
    Tracker:Route("MONEY")
  end
end

function Tracker:Start()
  frame:UnregisterAllEvents()
  frame:RegisterEvent("PLAYER_LEVEL_UP")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("PLAYER_MONEY")
  frame:RegisterEvent("UNIT_HEALTH")
  frame:RegisterEvent("UNIT_MAXHEALTH")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("PLAYER_DEAD")
  frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  frame:RegisterEvent("QUEST_TURNED_IN")
  frame:RegisterEvent("BAG_UPDATE")
  frame:SetScript("OnEvent", OnEvent)

  -- Initial evaluation for already-met criteria (e.g. mid-level login)
  self:Route("LEVEL")
  self:Route("MONEY")
end
