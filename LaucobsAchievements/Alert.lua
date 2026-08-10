--[[
  LaucobsAchievements - Alert
  Toast popup + sound when an achievement is earned.
]]

local addonName, LA = ...

local Alert = {}
LA.Alert = Alert

local TOAST_WIDTH = 320
local TOAST_HEIGHT = 72
local DISPLAY_SECONDS = 5
local SOUND_ID = 8499 -- Achievement-like fanfare (Classic-safe numeric id)

local toast
local animGroup
local hideAt = 0
local queue = {}

local function EnsureToast()
  if toast then
    return toast
  end

  toast = CreateFrame("Frame", "LaucobsAchievementsToast", UIParent, "BackdropTemplate")
  toast:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
  toast:SetPoint("TOP", UIParent, "TOP", 0, -80)
  toast:SetFrameStrata("FULLSCREEN_DIALOG")
  toast:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })
  toast:SetBackdropColor(0, 0, 0, 0.85)
  toast:Hide()

  local glow = toast:CreateTexture(nil, "BACKGROUND")
  glow:SetPoint("TOPLEFT", 10, -10)
  glow:SetPoint("BOTTOMRIGHT", -10, 10)
  glow:SetTexture("Interface\\Spellbook\\UI-GlyphFrame-Glow")
  glow:SetBlendMode("ADD")
  glow:SetAlpha(0.25)

  local iconBg = toast:CreateTexture(nil, "ARTWORK")
  iconBg:SetSize(48, 48)
  iconBg:SetPoint("LEFT", 16, 0)
  iconBg:SetTexture("Interface\\Buttons\\UI-EmptySlot")
  toast.iconBg = iconBg

  local icon = toast:CreateTexture(nil, "OVERLAY")
  icon:SetSize(40, 40)
  icon:SetPoint("CENTER", iconBg, "CENTER", 0, 0)
  toast.icon = icon

  local banner = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  banner:SetPoint("TOPLEFT", iconBg, "TOPRIGHT", 10, -2)
  banner:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -16, -12)
  banner:SetJustifyH("LEFT")
  banner:SetTextColor(1, 0.82, 0)
  banner:SetText("Achievement Earned!")
  toast.banner = banner

  local title = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -4)
  title:SetPoint("RIGHT", toast, "RIGHT", -16, 0)
  title:SetJustifyH("LEFT")
  toast.title = title

  local points = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  points:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  points:SetJustifyH("LEFT")
  points:SetTextColor(0.9, 0.9, 0.6)
  toast.points = points

  toast:SetScript("OnUpdate", function(self, elapsed)
    if hideAt == 0 then
      return
    end
    if GetTime() >= hideAt then
      hideAt = 0
      self:Hide()
      Alert:_Dequeue()
    end
  end)

  return toast
end

function Alert:_Present(def)
  local f = EnsureToast()
  f.icon:SetTexture(def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  f.icon:SetDesaturated(false)
  f.title:SetText(def.title or "Achievement")
  local pts = def.points or 0
  if pts > 0 then
    f.points:SetText(pts .. " points")
  else
    f.points:SetText("Feat of Strength")
  end

  -- Sound — numeric id works on Classic Era without SOUNDKIT tables
  pcall(PlaySound, SOUND_ID)

  f:SetAlpha(0)
  f:Show()

  -- Simple fade-in without relying on AnimationGroup templates that differ by client
  local elapsed = 0
  f:SetScript("OnUpdate", function(self, e)
    elapsed = elapsed + e
    if elapsed < 0.25 then
      self:SetAlpha(elapsed / 0.25)
    else
      self:SetAlpha(1)
      hideAt = GetTime() + DISPLAY_SECONDS
      self:SetScript("OnUpdate", function(frame)
        if hideAt == 0 then
          return
        end
        local remaining = hideAt - GetTime()
        if remaining <= 0.4 then
          frame:SetAlpha(math.max(0, remaining / 0.4))
        end
        if remaining <= 0 then
          hideAt = 0
          frame:Hide()
          frame:SetAlpha(1)
          Alert:_Dequeue()
        end
      end)
    end
  end)
end

function Alert:_Dequeue()
  if #queue == 0 then
    return
  end
  local nextDef = table.remove(queue, 1)
  self:_Present(nextDef)
end

--- Public entry: show a toast for the given achievement definition.
function Alert:Show(def)
  if not def then
    return
  end
  local f = EnsureToast()
  if f:IsShown() then
    queue[#queue + 1] = def
    return
  end
  self:_Present(def)
end
