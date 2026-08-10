--[[
  LaucobsAchievements - Core
  Initializes the addon namespace, SavedVariables, and slash commands.
]]

local addonName, LA = ...

LA.name = addonName
LA.version = "0.2.0"

-- Defaults applied on first load / when keys are missing
local defaults = {
  version = 1,
  characters = {},
  shareEnabled = true, -- social-graph achievement sharing (opt-out)
}

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
    }
  end
  return db.characters[key]
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

  return true
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

  if cmd == "reset" then
    local char = LA:GetCharDB()
    if char then
      wipe(char.completed)
      wipe(char.progress)
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Laucob's Achievements|r: progress reset for this character.")
      if LA.UI and LA.UI.Refresh then
        LA.UI:Refresh()
      end
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
