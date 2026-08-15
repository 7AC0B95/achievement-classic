--[[
  Classic Glory - Core
  Initializes the addon namespace, SavedVariables, and slash commands.
]]

local addonName, LA = ...

LA.name = addonName
LA.displayName = "Classic Glory"
LA.version = "0.9.0"

-- Defaults applied on first load / when keys are missing.
-- `version` is owned by MigrateDB so a fresh default does not skip older steps.
local defaults = {
  version = 7,
  characters = {},
  shareEnabled = true, -- social-graph achievement sharing (opt-out)
  debugEnabled = false,
  ui = { achFilter = "all", achSort = "default" },
}

local function IsHardcoreActive()
  if C_GameRules and C_GameRules.IsHardcoreActive then
    local ok, result = pcall(C_GameRules.IsHardcoreActive)
    if ok then
      return result and true or false
    end
  end
  return false
end

function LA:IsHardcoreActive()
  return IsHardcoreActive()
end

-- Live Unit* snapshot for website sync. Never infer these from achievements.
local function ReadPlayerIdentity(levelOverride)
  local name = UnitName("player")
  local realm = GetRealmName()
  local guid = UnitGUID("player")
  local _, classToken = UnitClass("player")
  local _, raceToken = UnitRace("player")
  local faction = UnitFactionGroup("player")
  local level = levelOverride
  if type(level) ~= "number" or level < 1 then
    level = UnitLevel("player")
  end
  if type(level) == "number" then
    if level < 1 then
      level = nil
    elseif level > 60 then
      level = 60
    end
  else
    level = nil
  end
  return {
    name = name,
    realm = realm,
    guid = guid,
    class = classToken,
    race = raceToken,
    level = level,
    faction = faction,
  }
end

local function ApplyPlayerIdentity(char, info)
  if type(char) ~= "table" then
    return char
  end
  info = info or {}
  local ident = ReadPlayerIdentity(info.level)

  if ident.name then
    char.name = ident.name
  end
  if ident.realm then
    char.realm = ident.realm
  end
  if ident.class then
    char.class = ident.class
  end
  if ident.race then
    char.race = ident.race
  end
  if ident.level then
    char.level = ident.level
  end
  if ident.faction then
    char.faction = ident.faction
  end
  if ident.guid then
    char.guid = ident.guid
  elseif not char.guid and char.name and char.realm then
    char.guid = char.name .. "-" .. char.realm
  end

  char.deaths = char.deaths or 0
  if char.status ~= "Dead" then
    char.status = "Alive"
  end
  if (char.deaths or 0) > 0 and IsHardcoreActive() then
    char.status = "Dead"
  end

  char.lastUpdated = time()
  return char
end

-- Clear MONEY progress that was stored as current wealth (v1), not looted total.
-- v3: wipe progress for removed starter achievements so old IDs don't linger.
-- v4: ensure web-sync character metadata fields exist on every row.
-- v6: drop achievement-inferred identity; only live Unit* data is stored.
-- v7: tamper-evident seals (adopted on login; see Seal.lua).
local function MigrateDB(db)
  local ver = db.version or 1
  if ver < 2 then
    for _, char in pairs(db.characters or {}) do
      if type(char.progress) == "table" and type(char.completed) == "table" then
        for achievementId, prog in pairs(char.progress) do
          if not char.completed[achievementId] then
            local def = LA.Achievements and LA.Achievements[achievementId]
            if def and def.criteria then
              for i, crit in ipairs(def.criteria) do
                if crit.type == "MONEY" then
                  prog[i] = nil
                end
              end
            end
          end
        end
      end
    end
    db.version = 2
  end
  if ver < 3 then
    -- Achievement catalog was fully replaced in 0.3.0; drop orphaned progress/completion.
    for _, char in pairs(db.characters or {}) do
      if type(char.completed) == "table" then
        for achievementId in pairs(char.completed) do
          if not (LA.Achievements and LA.Achievements[achievementId]) then
            char.completed[achievementId] = nil
          end
        end
      end
      if type(char.progress) == "table" then
        for achievementId in pairs(char.progress) do
          if not (LA.Achievements and LA.Achievements[achievementId]) then
            char.progress[achievementId] = nil
          end
        end
      end
      char.visitedZones = char.visitedZones or {}
      char.visitedInstances = char.visitedInstances or {}
      char.deaths = char.deaths or 0
    end
    db.version = 3
  end
  if ver < 4 then
    for key, char in pairs(db.characters or {}) do
      if type(char) == "table" then
        char.visitedZones = char.visitedZones or {}
        char.visitedInstances = char.visitedInstances or {}
        char.deaths = char.deaths or 0
        char.status = char.status or "Alive"
        -- Parse "Realm-Name" key when live Unit* data is not available yet
        if not char.name or not char.realm then
          local realm, name = tostring(key):match("^(.+)%-(.+)$")
          char.realm = char.realm or realm or "Unknown"
          char.name = char.name or name or "Unknown"
        end
        if (char.deaths or 0) > 0 and IsHardcoreActive() then
          char.status = "Dead"
        end
      end
    end
    db.version = 4
  end
  if ver < 5 then
    -- v5 used to infer class/level from achievements; that produced wrong levels.
    db.version = 5
  end
  if ver < 6 then
    for _, char in pairs(db.characters or {}) do
      if type(char) == "table" then
        char.level = nil
        char.class = nil
        char.race = nil
        char.faction = nil
        char.guid = nil
        char.lastUpdated = nil
      end
    end
    db.version = 6
  end
  if ver < 7 then
    -- Unsigned rows are sealed in Seal.AdoptUnsigned on PLAYER_LOGIN.
    db.version = 7
  end
end

-- First GetCharDB per character this session verifies SavedVariables ink
-- before live Unit* identity is applied (so a level-up cannot false-wipe).
local inkChecked = {}

local function CharKey()
  local name, realm = UnitName("player"), GetRealmName()
  if not name then
    return nil
  end
  return (realm or "Unknown") .. "-" .. name
end

--- Persist identity fields used by the website upload/sync from live Unit* APIs.
function LA:RefreshCharacterMeta(char, info)
  if not char then
    char = self:GetCharDB()
    if not char then
      return nil
    end
  end
  ApplyPlayerIdentity(char, info)
  if self.Seal and self.Seal.Write then
    self.Seal.Write(char)
  end
  return char
end

--- Return (and lazily create) the per-character progress table.
function LA:GetCharDB()
  local key = CharKey()
  if not key then
    return nil
  end
  local db = self.db or ClassicGloryDB
  if not db or type(db.characters) ~= "table" then
    return nil
  end
  if not db.characters[key] then
    local ident = ReadPlayerIdentity()
    db.characters[key] = {
      completed = {}, -- [achievementId] = { earnedOn, lvl, ticket }
      progress = {},  -- [achievementId] = { [criteriaIndex] = number }
      visitedZones = {}, -- [zoneNameLower] = true
      visitedInstances = {}, -- [instanceNameLower] = true
      deaths = 0,
      status = "Alive",
      name = ident.name,
      realm = ident.realm,
      guid = ident.guid,
      class = ident.class,
      race = ident.race,
      level = ident.level,
      faction = ident.faction,
    }
  else
    local char = db.characters[key]
    char.visitedZones = char.visitedZones or {}
    char.visitedInstances = char.visitedInstances or {}
    char.deaths = char.deaths or 0
    char.status = char.status or "Alive"
  end

  local char = db.characters[key]
  if not inkChecked[key] then
    inkChecked[key] = true
    if self.Seal and self.Seal.VerifyOrAdopt then
      local status = self.Seal.VerifyOrAdopt(char)
      if status == "wiped" then
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cffff5555Classic Glory|r: SavedVariables were modified outside the game. Progress for this character was reset."
        )
      end
    end
    ApplyPlayerIdentity(char)
    if self.Seal and self.Seal.Write then
      self.Seal.Write(char)
    end
    return char
  end

  ApplyPlayerIdentity(char)
  return char
end

--- True when every criteria has reached its target value.
function LA:AreCriteriaMet(achievementId)
  local def = self.Achievements and self.Achievements[achievementId]
  if not def or not def.criteria or #def.criteria == 0 then
    return false
  end
  for i, crit in ipairs(def.criteria) do
    local target = crit.value or 1
    if (self:GetProgress(achievementId, i) or 0) < target then
      return false
    end
  end
  return true
end

--- Complete only if all criteria are satisfied.
function LA:TryComplete(achievementId)
  if self:IsComplete(achievementId) then
    return false
  end
  if not self:AreCriteriaMet(achievementId) then
    return false
  end
  return self:CompleteAchievement(achievementId)
end

--- Whether an achievement is completed for the current character.
function LA:IsComplete(achievementId)
  local char = self:GetCharDB()
  return char and char.completed[achievementId] ~= nil
end

--- Unix time when the achievement was earned, or nil.
function LA:GetEarnedDate(achievementId)
  local char = self:GetCharDB()
  local entry = char and char.completed[achievementId]
  return entry and entry.earnedOn or nil
end

--- Current numeric progress for a criteria index (1-based).
function LA:GetProgress(achievementId, criteriaIndex)
  local char = self:GetCharDB()
  if not char then
    return 0
  end
  local prog = char.progress[achievementId]
  return (prog and prog[criteriaIndex]) or 0
end

--- Set progress for a criteria index. Returns true if the value changed.
function LA:SetProgress(achievementId, criteriaIndex, value)
  local char = self:GetCharDB()
  if not char then
    return false
  end
  char.progress[achievementId] = char.progress[achievementId] or {}
  local old = char.progress[achievementId][criteriaIndex] or 0
  if old == value then
    return false
  end
  char.progress[achievementId][criteriaIndex] = value
  if self.Seal and self.Seal.Write then
    self.Seal.Write(char)
  end
  return true
end

--- Mark an achievement complete and fire the alert. Idempotent.
function LA:CompleteAchievement(achievementId)
  if self:IsComplete(achievementId) then
    return false
  end
  local char = self:GetCharDB()
  if not char then
    return false
  end

  local def = self.Achievements and self.Achievements[achievementId]
  if not def then
    return false
  end

  local earnedOn = time()
  local lvl = tonumber(char.level) or 0
  local guid = tostring(char.guid or "")
  local ticket = ""
  if self.Seal and self.Seal.Ticket then
    ticket = self.Seal.Ticket(guid, achievementId, earnedOn, lvl)
  end
  char.completed[achievementId] = {
    earnedOn = earnedOn,
    lvl = lvl,
    ticket = ticket,
  }

  -- Ensure progress bars read as full once completed
  if def.criteria then
    char.progress[achievementId] = char.progress[achievementId] or {}
    for i, crit in ipairs(def.criteria) do
      local target = crit.value or 1
      if (char.progress[achievementId][i] or 0) < target then
        char.progress[achievementId][i] = target
      end
    end
  end

  if self.Seal and self.Seal.Write then
    self.Seal.Write(char)
  end

  if self.Alert and self.Alert.Show then
    self.Alert:Show(def)
  end

  if self.Share and self.Share.BroadcastEarned then
    self.Share:BroadcastEarned(achievementId)
  end

  if self.UI and self.UI.Refresh then
    self.UI:Refresh()
  end

  -- Meta achievements ("earn N achievements") need a recount next frame
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      if LA.Tracker and LA.Tracker.Route then
        LA.Tracker:Route("META")
      end
    end)
  elseif self.Tracker and self.Tracker.Route then
    self.Tracker:Route("META")
  end

  return true
end

--- Clear completion and progress for one achievement (debug). Returns ok, detail.
function LA:ResetAchievement(achievementId)
  achievementId = tonumber(achievementId)
  if not achievementId then
    return false, "invalid id"
  end
  local def = self.Achievements and self.Achievements[achievementId]
  if not def then
    return false, "unknown achievement " .. tostring(achievementId)
  end
  local char = self:GetCharDB()
  if not char then
    return false, "no character data"
  end

  char.completed[achievementId] = nil
  char.progress[achievementId] = nil

  if self.Seal and self.Seal.Write then
    self.Seal.Write(char)
  end

  if self.Tracker and self.Tracker.ClearAchievementState then
    self.Tracker:ClearAchievementState(achievementId)
  end

  if self.UI and self.UI.Refresh then
    self.UI:Refresh()
  end

  return true, def
end

function LA:IsDebug()
  return self.db and self.db.debugEnabled == true
end

function LA:SetDebug(enabled)
  if not self.db then
    return false
  end
  self.db.debugEnabled = enabled and true or false
  if self.UI and self.UI.Refresh then
    self.UI:Refresh()
  end
  return self.db.debugEnabled
end

--- Chat print only when debug mode is on.
function LA:Debug(msg)
  if not self:IsDebug() then
    return
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cff888888[CG debug]|r " .. tostring(msg))
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addonName then
    -- Adopt leftover LaucobsAchievementsDB if the SavedVariables file was copied in place.
    if type(ClassicGloryDB) ~= "table" then
      if type(LaucobsAchievementsDB) == "table" then
        ClassicGloryDB = LaucobsAchievementsDB
      else
        ClassicGloryDB = {}
      end
    end
    for k, v in pairs(defaults) do
      if k ~= "version" and ClassicGloryDB[k] == nil then
        if type(v) == "table" then
          ClassicGloryDB[k] = {}
        else
          ClassicGloryDB[k] = v
        end
      end
    end
    if type(ClassicGloryDB.characters) ~= "table" then
      ClassicGloryDB.characters = {}
    end
    if ClassicGloryDB.shareEnabled == nil then
      ClassicGloryDB.shareEnabled = true
    end
    if ClassicGloryDB.debugEnabled == nil then
      ClassicGloryDB.debugEnabled = false
    end
    if type(ClassicGloryDB.ui) ~= "table" then
      ClassicGloryDB.ui = {}
    end
    if ClassicGloryDB.ui.achFilter == nil then
      ClassicGloryDB.ui.achFilter = "all"
    end
    if ClassicGloryDB.ui.achSort == nil then
      ClassicGloryDB.ui.achSort = "default"
    end

    MigrateDB(ClassicGloryDB)

    LA.db = ClassicGloryDB
    LA.loaded = true
  elseif event == "PLAYER_LOGIN" then
    -- Ensure char row exists once the player unit is available
    LA:GetCharDB()
    if LA.Seal and LA.Seal.AdoptUnsigned then
      LA.Seal.AdoptUnsigned(LA.db)
    end

    if LA.Tracker and LA.Tracker.Start then
      LA.Tracker:Start()
    end

    if LA.Share and LA.Share.Start then
      LA.Share:Start()
    end

    if LA.UI and LA.UI.Init then
      LA.UI:Init()
    end

    DEFAULT_CHAT_FRAME:AddMessage(
      "|cffffd100Classic Glory|r loaded. Type |cff00ff00/cg|r to open the in-game panel. |cff00ff00/cg web|r shows how to publish progress on the website leaderboard."
    )
  elseif event == "PLAYER_LEVEL_UP" then
    LA:RefreshCharacterMeta(nil, { level = arg1 })
  elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGOUT" then
    LA:RefreshCharacterMeta()
    if event == "PLAYER_LOGOUT" and LA.UI and LA.UI.PersistLayout then
      LA.UI:PersistLayout()
    end
  end
end)

SLASH_CLASSICGLORY1 = "/cg"
SLASH_CLASSICGLORY2 = "/classicglory"
SLASH_CLASSICGLORY3 = "/la"
SLASH_CLASSICGLORY4 = "/laach"
SLASH_CLASSICGLORY5 = "/lachievements"
SlashCmdList["CLASSICGLORY"] = function(msg)
  msg = (msg or ""):match("^%s*(.-)%s*$") or ""
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = (cmd or ""):lower()
  rest = rest or ""

  if cmd == "debug" then
    local arg = rest:lower():match("^%s*(.-)%s*$") or ""
    if arg == "on" or arg == "1" or arg == "enable" then
      LA:SetDebug(true)
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffd100Classic Glory|r: debug |cff00ff00on|r. "
          .. "IDs shown in the panel. |cff00ff00/cg reset <id>|r resets one achievement."
      )
    elseif arg == "off" or arg == "0" or arg == "disable" then
      LA:SetDebug(false)
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Classic Glory|r: debug |cffff5555off|r.")
    elseif arg == "" then
      local on = LA:IsDebug()
      LA:SetDebug(not on)
      on = LA:IsDebug()
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffd100Classic Glory|r: debug "
          .. (on and "|cff00ff00on|r" or "|cffff5555off|r")
          .. (on and ". |cff00ff00/cg reset <id>|r resets one achievement." or ".")
      )
    else
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffd100Classic Glory|r: usage |cff00ff00/cg debug|r, |cff00ff00/cg debug on|r, or |cff00ff00/cg debug off|r"
      )
    end
    return
  end

  if cmd == "reset" then
    local char = LA:GetCharDB()
    if not char then
      return
    end

    local arg = rest:match("^%s*(.-)%s*$") or ""
    if arg ~= "" then
      if not LA:IsDebug() then
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cffffd100Classic Glory|r: enable debug first with |cff00ff00/cg debug on|r"
        )
        return
      end
      local id = tonumber(arg)
      if not id then
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cffffd100Classic Glory|r: usage |cff00ff00/cg reset|r or |cff00ff00/cg reset <id>|r"
        )
        return
      end
      local ok, detail = LA:ResetAchievement(id)
      if ok then
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cffffd100Classic Glory|r: reset |cff00ff00"
            .. detail.title
            .. "|r ("
            .. id
            .. ")."
        )
      else
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cffffd100Classic Glory|r: " .. tostring(detail)
        )
      end
      return
    end

    wipe(char.completed)
    wipe(char.progress)
    if LA.Seal and LA.Seal.Write then
      LA.Seal.Write(char)
    end
    if LA.Tracker and LA.Tracker.ClearAchievementState then
      LA.Tracker:ClearAchievementState()
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Classic Glory|r: progress reset for this character.")
    if LA.UI and LA.UI.Refresh then
      LA.UI:Refresh()
    end
    return
  end

  if cmd == "share" then
    local arg = rest:lower():match("^%s*(.-)%s*$")
    if not LA.Share then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Classic Glory|r: sharing unavailable.")
      return
    end
    if arg == "on" or arg == "1" or arg == "enable" then
      LA.Share:SetEnabled(true)
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Classic Glory|r: sharing |cff00ff00enabled|r.")
    elseif arg == "off" or arg == "0" or arg == "disable" then
      LA.Share:SetEnabled(false)
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Classic Glory|r: sharing |cffff5555disabled|r.")
    else
      local on = LA.Share:IsEnabled()
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffd100Classic Glory|r: sharing is "
          .. (on and "|cff00ff00on|r" or "|cffff5555off|r")
          .. ". Use |cff00ff00/cg share on|r or |cff00ff00/cg share off|r."
      )
    end
    return
  end

  if cmd == "inspect" then
    if not LA.Share then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Classic Glory|r: sharing unavailable.")
      return
    end
    local ok, result = LA.Share:InspectTargetOrName(rest ~= "" and rest or nil)
    if ok then
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffd100Classic Glory|r: requesting achievements from |cff00ff00"
          .. tostring(result)
          .. "|r..."
      )
      local shown, err = pcall(function()
        if LA.UI and LA.UI.ShowPeer then
          LA.UI:ShowPeer(result)
        elseif LA.UI and LA.UI.Show then
          LA.UI:Show()
        end
      end)
      if not shown then
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cffff5555Classic Glory|r: UI error while inspecting: " .. tostring(err)
        )
      end
    else
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffd100Classic Glory|r: " .. (result or "inspect failed.")
      )
    end
    return
  end

  if cmd == "web" then
    LA:RefreshCharacterMeta()
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cffffd100Classic Glory|r pairs with the website: track in-game, then publish characters to public leaderboards."
    )
    DEFAULT_CHAT_FRAME:AddMessage(
      "  Log out, then upload |cff00ff00ClassicGlory.lua|r from:"
    )
    DEFAULT_CHAT_FRAME:AddMessage(
      "  |cffaaaaaaWTF\\Account\\<Account>\\SavedVariables\\|r"
    )
    DEFAULT_CHAT_FRAME:AddMessage(
      "  Open the website |cff00ff00Connect|r / dashboard page and sync selected characters."
    )
    return
  end

  if LA.UI and LA.UI.Toggle then
    LA.UI:Toggle()
  end
end
