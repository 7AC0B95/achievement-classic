--[[
  Classic Glory - Tracker
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

-- Skip zone spam while zoning repeatedly into the same place
local lastZoneKey

local function PlayerAlive()
  return not UnitIsDeadOrGhost("player")
end

local function RefreshUI()
  if LA.UI and LA.UI.Refresh then
    LA.UI:Refresh()
  end
end

local function IsHardcoreActive()
  if C_GameRules and C_GameRules.IsHardcoreActive then
    local ok, result = pcall(C_GameRules.IsHardcoreActive)
    if ok then
      return result and true or false
    end
  end
  return false
end

--- Achievements marked hcOnly / factionOnly are ignored when they do not apply.
local function AchievementAllowed(def)
  if def.hcOnly and not IsHardcoreActive() then
    return false
  end
  if def.factionOnly then
    local faction = UnitFactionGroup("player")
    if not faction or faction:lower() ~= def.factionOnly:lower() then
      return false
    end
  end
  return true
end

local function NameMatches(haystack, needle)
  if not needle or needle == "" then
    return true
  end
  if not haystack or haystack == "" then
    return false
  end
  return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

local function BumpProgress(def, critIndex, amount)
  amount = amount or 1
  local current = LA:GetProgress(def.id, critIndex) + amount
  local target = (def.criteria[critIndex] and def.criteria[critIndex].value) or 1
  LA:SetProgress(def.id, critIndex, current)
  if current >= target then
    LA:TryComplete(def.id)
  else
    RefreshUI()
  end
  return current
end

local function SetProgressToward(def, critIndex, value)
  local target = (def.criteria[critIndex] and def.criteria[critIndex].value) or 1
  local capped = math.min(value, target)
  local changed = LA:SetProgress(def.id, critIndex, capped)
  if capped >= target then
    LA:TryComplete(def.id)
  elseif changed then
    RefreshUI()
  end
end

------------------------------------------------------------------------
-- Criteria checkers
------------------------------------------------------------------------

local function CheckLevelCriteria(def, crit, critIndex, levelOverride)
  local level = levelOverride or UnitLevel("player") or 1
  local target = crit.value or 1
  SetProgressToward(def, critIndex, level)
  if level >= target then
    LA:TryComplete(def.id)
  end
end

local function CheckDeathlessCriteria(def, crit, critIndex, levelOverride)
  local char = LA:GetCharDB()
  if not char then
    return
  end
  if (char.deaths or 0) > 0 then
    return
  end
  local level = levelOverride or UnitLevel("player") or 1
  local target = crit.value or 1
  SetProgressToward(def, critIndex, level)
  if level >= target then
    LA:TryComplete(def.id)
  end
end

-- Locale-safe copper parse from CHAT_MSG_MONEY text (GOLD/SILVER/COPPER_AMOUNT).
local goldPat, silverPat, copperPat

local function MoneyAmountPattern(fmt)
  local marked = fmt:gsub("%%d", "\001")
  marked = marked:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
  return marked:gsub("\001", "(%d+)")
end

local function EnsureMoneyPatterns()
  if goldPat then
    return
  end
  goldPat = MoneyAmountPattern(GOLD_AMOUNT)
  silverPat = MoneyAmountPattern(SILVER_AMOUNT)
  copperPat = MoneyAmountPattern(COPPER_AMOUNT)
end

local function ParseLootedCopper(msg)
  if not msg or msg == "" then
    return 0
  end
  EnsureMoneyPatterns()
  local g = tonumber(msg:match(goldPat)) or 0
  local s = tonumber(msg:match(silverPat)) or 0
  local c = tonumber(msg:match(copperPat)) or 0
  return g * 10000 + s * 100 + c
end

local function CheckMoneyCriteria(def, crit, critIndex, copperGained)
  if copperGained <= 0 then
    return
  end
  local current = LA:GetProgress(def.id, critIndex) + copperGained
  local target = crit.value or 0
  LA:SetProgress(def.id, critIndex, current)
  if current >= target then
    LA:TryComplete(def.id)
  else
    RefreshUI()
  end
end

local function ArmHealthCriteria(def, crit)
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

local function ResolveHealthCriteria(def, crit, critIndex)
  if not lowHpArmed[def.id] then
    return
  end
  lowHpArmed[def.id] = nil
  if PlayerAlive() then
    BumpProgress(def, critIndex, 1)
  end
end

local function CheckKillCriteria(def, crit, critIndex, destName)
  if not destName then
    return
  end
  if crit.match and not NameMatches(destName, crit.match) then
    return
  end
  BumpProgress(def, critIndex, 1)
end

local function CheckQuestCriteria(def, crit, critIndex)
  BumpProgress(def, critIndex, 1)
end

local function CheckZoneCriteria(def, crit, critIndex, zoneName)
  if not zoneName then
    return
  end
  if crit.match and not NameMatches(zoneName, crit.match) then
    return
  end
  SetProgressToward(def, critIndex, 1)
end

local function CheckZonesCriteria(def, crit, critIndex)
  local char = LA:GetCharDB()
  if not char then
    return
  end
  local count = 0
  for _ in pairs(char.visitedZones or {}) do
    count = count + 1
  end
  SetProgressToward(def, critIndex, count)
end

local function CheckDeathsCriteria(def, crit, critIndex)
  local char = LA:GetCharDB()
  if not char then
    return
  end
  SetProgressToward(def, critIndex, char.deaths or 0)
end

local function CheckClassCriteria(def, crit, critIndex)
  local className, classFile = UnitClass("player")
  local char = LA:GetCharDB()
  if char and classFile then
    char.class = classFile
  end
  local match = crit.match
  if not match then
    return
  end
  local needle = match:lower()
  if (classFile and classFile:lower() == needle) or NameMatches(className, match) then
    SetProgressToward(def, critIndex, 1)
  end
end

local function CheckRaceCriteria(def, crit, critIndex)
  local raceName, raceFile = UnitRace("player")
  local match = crit.match
  if not match then
    return
  end
  local needle = match:lower():gsub("%s+", "")
  local file = raceFile and raceFile:lower():gsub("%s+", "") or ""
  local name = raceName and raceName:lower():gsub("%s+", "") or ""
  if file == needle or name == needle or NameMatches(raceName, match) then
    SetProgressToward(def, critIndex, 1)
  end
end

local function CheckFactionCriteria(def, crit, critIndex)
  local faction = UnitFactionGroup("player")
  if not faction or not crit.match then
    return
  end
  if faction:lower() == crit.match:lower() then
    SetProgressToward(def, critIndex, 1)
  end
end

local function CheckDuelCriteria(def, crit, critIndex)
  BumpProgress(def, critIndex, 1)
end

local function CheckLootCriteria(def, crit, critIndex, itemName)
  if not itemName then
    return
  end
  if crit.match and not NameMatches(itemName, crit.match) then
    return
  end
  BumpProgress(def, critIndex, 1)
end

local function CheckCritHitCriteria(def, crit, critIndex)
  BumpProgress(def, critIndex, 1)
end

local function CheckEmoteCriteria(def, crit, critIndex, msg)
  if crit.match and msg and not NameMatches(msg, crit.match) then
    return
  end
  BumpProgress(def, critIndex, 1)
end

local function CheckInstanceCriteria(def, crit, critIndex, instanceName)
  if not instanceName then
    return
  end
  if crit.match and not NameMatches(instanceName, crit.match) then
    return
  end
  -- value > 1 with no match = unique instances visited
  if not crit.match and (crit.value or 1) > 1 then
    local char = LA:GetCharDB()
    if not char then
      return
    end
    local count = 0
    for _ in pairs(char.visitedInstances or {}) do
      count = count + 1
    end
    SetProgressToward(def, critIndex, count)
  else
    SetProgressToward(def, critIndex, 1)
  end
end

local function StandingIdFromName(name)
  if not name then
    return nil
  end
  local n = name:lower()
  local map = {
    hated = 1,
    hostile = 2,
    unfriendly = 3,
    neutral = 4,
    friendly = 5,
    honored = 6,
    revered = 7,
    exalted = 8,
  }
  return map[n]
end

local function CheckRepCriteria(def, crit, critIndex)
  local factionMatch = crit.match
  local needStanding = StandingIdFromName(crit.standing) or crit.value or 5
  if not factionMatch then
    return
  end

  local num = GetNumFactions and GetNumFactions() or 0
  for i = 1, num do
    local name, _, standingId = GetFactionInfo(i)
    if name and NameMatches(name, factionMatch) then
      if (standingId or 0) >= needStanding then
        SetProgressToward(def, critIndex, 1)
      end
      return
    end
  end
end

local function CheckSkillCriteria(def, crit, critIndex)
  local skillMatch = crit.match
  local needRank = crit.value or 1
  if not skillMatch then
    return
  end

  local num = GetNumSkillLines and GetNumSkillLines() or 0
  for i = 1, num do
    local name, isHeader, _, rank = GetSkillLineInfo(i)
    if not isHeader and name and NameMatches(name, skillMatch) then
      SetProgressToward(def, critIndex, rank or 0)
      if (rank or 0) >= needRank then
        LA:TryComplete(def.id)
      end
      return
    end
  end
end

local function CheckMetaCriteria(def, crit, critIndex)
  local need = crit.value or 1
  local count = 0
  for id in pairs(LA.Achievements or {}) do
    if id ~= def.id and LA:IsComplete(id) then
      count = count + 1
    end
  end
  SetProgressToward(def, critIndex, count)
end

local function CheckLoginCriteria(def, crit, critIndex)
  -- LOGIN type: award on any successful session (value usually 1)
  SetProgressToward(def, critIndex, 1)
end

local function PlayerBuffAt(index)
  -- Classic Era: UnitBuff is the stable helpful-aura API. spellId is the 10th return.
  if UnitBuff then
    local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", index)
    if type(name) == "table" then
      return name.name, name.spellId
    end
    return name, spellId
  end
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local data = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
    if not data then
      return nil
    end
    return data.name, data.spellId
  end
  local name, _, _, _, _, _, _, _, _, spellId = UnitAura("player", index, "HELPFUL")
  if type(name) == "table" then
    return name.name, name.spellId
  end
  return name, spellId
end

local function PlayerHasBuff(spellId, nameNeedle)
  if not spellId and (not nameNeedle or nameNeedle == "") then
    return false
  end
  for i = 1, 80 do
    local name, id = PlayerBuffAt(i)
    if not name then
      break
    end
    if spellId and id == spellId then
      return true
    end
    if nameNeedle and NameMatches(name, nameNeedle) then
      return true
    end
  end
  return false
end

-- BUFF progress is only "on" while the aura is present so multi-criteria
-- world-buff feats require the listed buffs at the same time.
local function CheckBuffCriteria(def, crit, critIndex)
  if PlayerHasBuff(crit.spellId, crit.match) then
    SetProgressToward(def, critIndex, 1)
    return
  end
  local current = LA:GetProgress(def.id, critIndex)
  if current > 0 then
    LA:SetProgress(def.id, critIndex, 0)
    RefreshUI()
  end
end

------------------------------------------------------------------------
-- Routing
------------------------------------------------------------------------

--- Route a logical event to all matching achievement criteria.
function Tracker:Route(kind, payload)
  if not LA.loaded or not LA.Achievements then
    return
  end

  for id, def in pairs(LA.Achievements) do
    if not LA:IsComplete(id) and def.criteria and AchievementAllowed(def) then
      for i, crit in ipairs(def.criteria) do
        local ctype = crit.type
        if kind == "LEVEL" and ctype == "LEVEL" then
          CheckLevelCriteria(def, crit, i, payload and payload.level)
        elseif kind == "LEVEL" and ctype == "DEATHLESS" then
          CheckDeathlessCriteria(def, crit, i, payload and payload.level)
        elseif kind == "MONEY" and ctype == "MONEY" then
          CheckMoneyCriteria(def, crit, i, payload and payload.copper or 0)
        elseif kind == "HEALTH_UPDATE" and ctype == "HEALTH" then
          ArmHealthCriteria(def, crit)
        elseif kind == "HEALTH_LEAVE_COMBAT" and ctype == "HEALTH" then
          ResolveHealthCriteria(def, crit, i)
        elseif kind == "KILL" and ctype == "KILLS" then
          CheckKillCriteria(def, crit, i, payload and payload.name)
        elseif kind == "QUEST" and ctype == "QUESTS" then
          CheckQuestCriteria(def, crit, i)
        elseif kind == "ZONE" and ctype == "ZONE" then
          CheckZoneCriteria(def, crit, i, payload and payload.zone)
        elseif kind == "ZONE" and ctype == "ZONES" then
          CheckZonesCriteria(def, crit, i)
        elseif kind == "DEATH" and ctype == "DEATHS" then
          CheckDeathsCriteria(def, crit, i)
        elseif kind == "IDENTITY" and ctype == "CLASS" then
          CheckClassCriteria(def, crit, i)
        elseif kind == "IDENTITY" and ctype == "RACE" then
          CheckRaceCriteria(def, crit, i)
        elseif kind == "IDENTITY" and ctype == "FACTION" then
          CheckFactionCriteria(def, crit, i)
        elseif kind == "DUEL_WIN" and ctype == "DUELS" then
          CheckDuelCriteria(def, crit, i)
        elseif kind == "LOOT" and ctype == "LOOT" then
          CheckLootCriteria(def, crit, i, payload and payload.item)
        elseif kind == "CRIT" and ctype == "CRITS" then
          CheckCritHitCriteria(def, crit, i)
        elseif kind == "EMOTE" and ctype == "EMOTES" then
          CheckEmoteCriteria(def, crit, i, payload and payload.msg)
        elseif kind == "INSTANCE" and ctype == "INSTANCE" then
          CheckInstanceCriteria(def, crit, i, payload and payload.name)
        elseif kind == "REP" and ctype == "REP" then
          CheckRepCriteria(def, crit, i)
        elseif kind == "SKILL" and ctype == "SKILL" then
          CheckSkillCriteria(def, crit, i)
        elseif kind == "META" and ctype == "META" then
          CheckMetaCriteria(def, crit, i)
        elseif kind == "LOGIN" and ctype == "LOGIN" then
          CheckLoginCriteria(def, crit, i)
        elseif kind == "BUFF" and ctype == "BUFF" then
          CheckBuffCriteria(def, crit, i)
        end
      end
    end
  end
end

------------------------------------------------------------------------
-- Event helpers
------------------------------------------------------------------------

local function RecordZoneVisit()
  local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
  if not zone or zone == "" then
    return
  end
  local key = zone:lower()
  if key == lastZoneKey then
    return
  end
  lastZoneKey = key

  local char = LA:GetCharDB()
  if char then
    local added = not char.visitedZones[key]
    char.visitedZones[key] = true
    if added and LA.Seal and LA.Seal.Write then
      LA.Seal.Write(char)
    end
  end

  Tracker:Route("ZONE", { zone = zone })
end

local function RecordInstanceVisit()
  local inInstance, instanceType = IsInInstance()
  if not inInstance then
    return
  end
  if instanceType ~= "party" and instanceType ~= "raid" then
    return
  end

  local name = GetRealZoneText and GetRealZoneText() or GetZoneText()
  if not name or name == "" then
    return
  end

  local instKey = name:lower()
  local char = LA:GetCharDB()
  if char then
    local added = not char.visitedInstances[instKey]
    char.visitedInstances[instKey] = true
    if added and LA.Seal and LA.Seal.Write then
      LA.Seal.Write(char)
    end
  end

  Tracker:Route("INSTANCE", { name = name })
end

local function OnCombatLogEvent()
  local info = { CombatLogGetCurrentEventInfo() }
  local subevent = info[2]
  local sourceGUID = info[4]
  local destName = info[9]

  if subevent == "PARTY_KILL" then
    Tracker:Route("KILL", { name = destName })
    return
  end

  -- Critical strikes dealt by the player
  if sourceGUID ~= UnitGUID("player") then
    return
  end

  -- CLEU prefix (11 fields) + payload. Swing critical is field 18; spell/range critical is 21.
  local critical
  if subevent == "SWING_DAMAGE" then
    critical = info[18]
  elseif subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" then
    critical = info[21]
  end

  if critical == true then
    Tracker:Route("CRIT")
  end
end

local function ParseLootItemName(msg)
  if not msg then
    return nil
  end
  -- |Hitem:...|h[Item Name]|h
  local name = msg:match("%|h%[(.-)%]%|h")
  return name
end

local function ClearDeathlessProgress()
  if not LA.Achievements then
    return
  end
  for id, def in pairs(LA.Achievements) do
    if not LA:IsComplete(id) and def.criteria then
      for i, crit in ipairs(def.criteria) do
        if crit.type == "DEATHLESS" then
          LA:SetProgress(id, i, 0)
        end
      end
    end
  end
end

local function RecordDeath()
  local char = LA:GetCharDB()
  if not char then
    return
  end
  char.deaths = (char.deaths or 0) + 1
  if IsHardcoreActive() then
    char.status = "Dead"
  end
  if LA.RefreshCharacterMeta then
    LA:RefreshCharacterMeta(char)
  end
  ClearDeathlessProgress()
  Tracker:Route("DEATH")
end

-- Hardcore ghosts who died while the addon was not loaded (or missed PLAYER_DEAD)
-- still appear as a ghost on login/logout. Count that death once.
local function DetectMissedHardcoreDeath()
  if not IsHardcoreActive() then
    return
  end
  if not UnitIsGhost("player") then
    return
  end
  local char = LA:GetCharDB()
  if not char or (char.deaths or 0) > 0 then
    return
  end
  LA:Debug("hardcore ghost on login/logout; recording missed death")
  RecordDeath()
end

-- CHAT_MSG_TEXT_EMOTE / CHAT_MSG_EMOTE fire for every nearby player.
-- Count only emotes this character performed.
local function EmoteIsFromPlayer(sender, guid)
  local playerGuid = UnitGUID("player")
  if type(guid) == "string" and guid:find("^Player%-") and playerGuid then
    return guid == playerGuid
  end
  local player = UnitName("player")
  if type(sender) ~= "string" or sender == "" or not player then
    return false
  end
  if sender == player then
    return true
  end
  return sender:match("^([^-]+)") == player
end

local function OnEvent(_, event, ...)
  if event == "PLAYER_LEVEL_UP" then
    local newLevel = ...
    local char = LA:GetCharDB()
    if char and type(newLevel) == "number" then
      if LA.RefreshCharacterMeta then
        LA:RefreshCharacterMeta(char, { level = newLevel })
      else
        char.level = newLevel
      end
    end
    Tracker:Route("LEVEL", { level = newLevel })
    Tracker:Route("META")
  elseif event == "PLAYER_ENTERING_WORLD" then
    if LA.RefreshCharacterMeta then
      LA:RefreshCharacterMeta()
    end
    DetectMissedHardcoreDeath()
    Tracker:Route("LEVEL")
    Tracker:Route("IDENTITY")
    Tracker:Route("LOGIN")
    Tracker:Route("REP")
    Tracker:Route("SKILL")
    Tracker:Route("META")
    Tracker:Route("BUFF")
    RecordZoneVisit()
    RecordInstanceVisit()
  elseif event == "CHAT_MSG_MONEY" then
    local msg = ...
    local copper = ParseLootedCopper(msg)
    if copper > 0 then
      LA:Debug(string.format("looted %d copper", copper))
      Tracker:Route("MONEY", { copper = copper })
    end
  elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
    local unit = ...
    if unit == "player" then
      Tracker:Route("HEALTH_UPDATE")
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    Tracker:Route("HEALTH_LEAVE_COMBAT")
  elseif event == "PLAYER_DEAD" then
    wipe(lowHpArmed)
    RecordDeath()
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    OnCombatLogEvent()
  elseif event == "QUEST_TURNED_IN" then
    Tracker:Route("QUEST")
    Tracker:Route("META")
  elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
    RecordZoneVisit()
    RecordInstanceVisit()
  elseif event == "CHAT_MSG_SYSTEM" then
    local msg = ...
    local player = UnitName("player")
    if msg and player then
      -- DUEL_WINNER_KNOCKOUT: "%1$s has defeated %2$s in a duel"
      -- DUEL_WINNER_RETREAT:  "%2$s has fled from %1$s in a duel" (winner is %1$s)
      local winner
      if DUEL_WINNER_KNOCKOUT then
        local pat = DUEL_WINNER_KNOCKOUT:gsub("%%1%$s", "(.-)"):gsub("%%2%$s", ".-")
        winner = msg:match(pat)
      end
      if not winner and DUEL_WINNER_RETREAT then
        local pat = DUEL_WINNER_RETREAT:gsub("%%2%$s", ".-"):gsub("%%1%$s", "(.-)")
        winner = msg:match(pat)
      end
      if winner == player then
        Tracker:Route("DUEL_WIN")
      end
    end
  elseif event == "CHAT_MSG_LOOT" then
    local msg = ...
    local item = ParseLootItemName(msg)
    if item then
      Tracker:Route("LOOT", { item = item })
    end
  elseif event == "CHAT_MSG_TEXT_EMOTE" or event == "CHAT_MSG_EMOTE" then
    local msg, sender, _, _, _, _, _, _, _, _, _, guid = ...
    if not EmoteIsFromPlayer(sender, guid) then
      return
    end
    Tracker:Route("EMOTE", { msg = msg })
  elseif event == "UPDATE_FACTION" or event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
    Tracker:Route("REP")
  elseif event == "CHAT_MSG_SKILL" or event == "SKILL_LINES_CHANGED" then
    Tracker:Route("SKILL")
  elseif event == "PLAYER_LOGOUT" then
    DetectMissedHardcoreDeath()
  elseif event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE" then
    -- no-op; deaths already counted (or caught as a hardcore ghost on login/logout)
  elseif event == "UNIT_AURA" then
    local unit = ...
    if unit == "player" then
      Tracker:Route("BUFF")
    end
  end
end

function Tracker:ClearAchievementState(achievementId)
  if achievementId then
    lowHpArmed[achievementId] = nil
  else
    wipe(lowHpArmed)
  end
end

function Tracker:IsHardcore()
  return IsHardcoreActive()
end

function Tracker:Start()
  frame:UnregisterAllEvents()
  frame:RegisterEvent("PLAYER_LEVEL_UP")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("CHAT_MSG_MONEY")
  frame:RegisterEvent("UNIT_HEALTH")
  frame:RegisterEvent("UNIT_MAXHEALTH")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("PLAYER_DEAD")
  frame:RegisterEvent("PLAYER_LOGOUT")
  frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  frame:RegisterEvent("QUEST_TURNED_IN")
  frame:RegisterEvent("ZONE_CHANGED")
  frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  frame:RegisterEvent("ZONE_CHANGED_INDOORS")
  frame:RegisterEvent("CHAT_MSG_LOOT")
  frame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
  frame:RegisterEvent("CHAT_MSG_EMOTE")
  frame:RegisterEvent("UPDATE_FACTION")
  frame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
  frame:RegisterEvent("CHAT_MSG_SKILL")
  frame:RegisterEvent("SKILL_LINES_CHANGED")
  frame:RegisterEvent("CHAT_MSG_SYSTEM")
  if frame.RegisterUnitEvent then
    frame:RegisterUnitEvent("UNIT_AURA", "player")
  else
    frame:RegisterEvent("UNIT_AURA")
  end
  frame:SetScript("OnEvent", OnEvent)

  -- Initial evaluation for already-met criteria (e.g. mid-level login)
  DetectMissedHardcoreDeath()
  self:Route("LEVEL")
  self:Route("IDENTITY")
  self:Route("LOGIN")
  self:Route("REP")
  self:Route("SKILL")
  self:Route("META")
  self:Route("DEATH")
  self:Route("BUFF")
  RecordZoneVisit()
  RecordInstanceVisit()
end
