--[[
  LaucobsAchievements - Core
  Initializes the addon namespace, SavedVariables, and slash commands.
]]

local addonName, LA = ...

LA.name = addonName
LA.version = "0.3.0"

-- Defaults applied on first load / when keys are missing
local defaults = {
  version = 3,
  characters = {},
  shareEnabled = true, -- social-graph achievement sharing (opt-out)
  debugEnabled = false,
}

-- Clear MONEY progress that was stored as current wealth (v1), not looted total.
-- v3: wipe progress for removed starter achievements so old IDs don't linger.
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
end

local function CharKey()
  local name, realm = UnitName("player"), GetRealmName()
  if not name then
    return nil
  end
  return (realm or "Unknown") .. "-" .. name
end

--- Return (and lazily create) the per-character progress table.
function LA:GetCharDB()
  local key = CharKey()
  if not key then
    return nil
  end
  local db = LaucobsAchievementsDB
  if not db.characters[key] then
    db.characters[key] = {
      completed = {}, -- [achievementId] = { earnedOn = unixTime }
      progress = {},  -- [achievementId] = { [criteriaIndex] = number }
      visitedZones = {}, -- [zoneNameLower] = true
      visitedInstances = {}, -- [instanceNameLower] = true
      deaths = 0,
    }
  else
    local char = db.characters[key]
    char.visitedZones = char.visitedZones or {}
    char.visitedInstances = char.visitedInstances or {}
    char.deaths = char.deaths or 0
  end
  return db.characters[key]
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

  char.completed[achievementId] = {
    earnedOn = time(),
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
  DEFAULT_CHAT_FRAME:AddMessage("|cff888888[LA debug]|r " .. tostring(msg))
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addonName then
    if type(LaucobsAchievementsDB) ~= "table" then
      LaucobsAchievementsDB = {}
    end
    for k, v in pairs(defaults) do
      if LaucobsAchievementsDB[k] == nil then
        if type(v) == "table" then
          LaucobsAchievementsDB[k] = {}
        else
          LaucobsAchievementsDB[k] = v
        end
      end
    end
    if type(LaucobsAchievementsDB.characters) ~= "table" then
      LaucobsAchievementsDB.characters = {}
    end
    if LaucobsAchievementsDB.shareEnabled == nil then
      LaucobsAchievementsDB.shareEnabled = true
    end
    if LaucobsAchievementsDB.debugEnabled == nil then
      LaucobsAchievementsDB.debugEnabled = false
    end

    MigrateDB(LaucobsAchievementsDB)

    LA.db = LaucobsAchievementsDB
    LA.loaded = true
  elseif event == "PLAYER_LOGIN" then
    -- Ensure char row exists once the player unit is available
    LA:GetCharDB()

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
      "|cffffd100Laucob's Achievements|r loaded. Type |cff00ff00/la|r to open."
    )
  end
end)

SLASH_LAUCOBSACHIEVEMENTS1 = "/la"
SLASH_LAUCOBSACHIEVEMENTS2 = "/laach"
SLASH_LAUCOBSACHIEVEMENTS3 = "/lachievements"
SlashCmdList["LAUCOBSACHIEVEMENTS"] = function(msg)
  msg = (msg or ""):match("^%s*(.-)%s*$") or ""
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = (cmd or ""):lower()
  rest = rest or ""

  if cmd == "debug" then
    local arg = rest:lower():match("^%s*(.-)%s*$") or ""
    if arg == "on" or arg == "1" or arg == "enable" then
      LA:SetDebug(true)
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffd100Laucob's Achievements|r: debug |cff00ff00on|r. "
          .. "IDs shown in the panel. |cff00ff00/la reset <id>|r resets one achievement."
      )
    elseif arg == "off" or arg == "0" or arg == "disable" then
      LA:SetDebug(false)
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Laucob's Achievements|r: debug |cffff5555off|r.")
    elseif arg == "" then
      local on = LA:IsDebug()
      LA:SetDebug(not on)
      on = LA:IsDebug()
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffd100Laucob's Achievements|r: debug "
          .. (on and "|cff00ff00on|r" or "|cffff5555off|r")
          .. (on and ". |cff00ff00/la reset <id>|r resets one achievement." or ".")
      )
    else
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffd100Laucob's Achievements|r: usage |cff00ff00/la debug|r, |cff00ff00/la debug on|r, or |cff00ff00/la debug off|r"
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
          "|cffffd100Laucob's Achievements|r: enable debug first with |cff00ff00/la debug on|r"
        )
        return
      end
      local id = tonumber(arg)
      if not id then
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cffffd100Laucob's Achievements|r: usage |cff00ff00/la reset|r or |cff00ff00/la reset <id>|r"
        )
        return
      end
      local ok, detail = LA:ResetAchievement(id)
      if ok then
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cffffd100Laucob's Achievements|r: reset |cff00ff00"
            .. detail.title
            .. "|r ("
            .. id
            .. ")."
        )
      else
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cffffd100Laucob's Achievements|r: " .. tostring(detail)
        )
      end
      return
    end

    wipe(char.completed)
    wipe(char.progress)
    if LA.Tracker and LA.Tracker.ClearAchievementState then
      LA.Tracker:ClearAchievementState()
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Laucob's Achievements|r: progress reset for this character.")
    if LA.UI and LA.UI.Refresh then
      LA.UI:Refresh()
    end
    return
  end

  if cmd == "share" then
    local arg = rest:lower():match("^%s*(.-)%s*$")
    if not LA.Share then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Laucob's Achievements|r: sharing unavailable.")
      return
    end
    if arg == "on" or arg == "1" or arg == "enable" then
      LA.Share:SetEnabled(true)
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Laucob's Achievements|r: sharing |cff00ff00enabled|r.")
    elseif arg == "off" or arg == "0" or arg == "disable" then
      LA.Share:SetEnabled(false)
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Laucob's Achievements|r: sharing |cffff5555disabled|r.")
    else
      local on = LA.Share:IsEnabled()
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffd100Laucob's Achievements|r: sharing is "
          .. (on and "|cff00ff00on|r" or "|cffff5555off|r")
          .. ". Use |cff00ff00/la share on|r or |cff00ff00/la share off|r."
      )
    end
    return
  end

  if cmd == "inspect" then
    if not LA.Share then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Laucob's Achievements|r: sharing unavailable.")
      return
    end
    local ok, result = LA.Share:InspectTargetOrName(rest ~= "" and rest or nil)
    if ok then
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffd100Laucob's Achievements|r: requesting achievements from |cff00ff00"
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
          "|cffff5555Laucob's Achievements|r: UI error while inspecting: " .. tostring(err)
        )
      end
    else
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffd100Laucob's Achievements|r: " .. (result or "inspect failed.")
      )
    end
    return
  end

  if LA.UI and LA.UI.Toggle then
    LA.UI:Toggle()
  end
end
