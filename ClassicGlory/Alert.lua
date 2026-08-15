--[[
  Classic Glory - Alert
  Toast popup + sound when an achievement is earned.
  Unlocks that arrive within a short window are coalesced into one toast.
]]

local addonName, LA = ...

local Alert = {}
LA.Alert = Alert

local TOAST_WIDTH = 320
local TOAST_HEIGHT = 72
local DISPLAY_SECONDS = 5
local SOUND_ID = 8499 -- Achievement-like fanfare (Classic-safe numeric id)
local BURST_WINDOW = 0.3
local MAX_NAMED = 3
local TITLE_LINE = 16
local MORE_LINE = 14

local toast
local scheduler
local hideAt = 0
local pending = {}
local flushAt = 0
local flushGen = 0

local function EnsureScheduler()
  if scheduler then
    return scheduler
  end
  scheduler = CreateFrame("Frame")
  scheduler:Hide()
  scheduler:SetScript("OnUpdate", function(self)
    if flushAt == 0 or GetTime() < flushAt then
      return
    end
    flushAt = 0
    self:Hide()
    Alert:_FlushPending()
  end)
  return scheduler
end

local function ArmFlush()
  if flushAt ~= 0 then
    return
  end
  flushAt = GetTime() + BURST_WINDOW
  flushGen = flushGen + 1
  local gen = flushGen
  if C_Timer and C_Timer.After then
    C_Timer.After(BURST_WINDOW, function()
      if gen ~= flushGen then
        return
      end
      flushAt = 0
      Alert:_FlushPending()
    end)
  else
    EnsureScheduler():Show()
  end
end

local function CancelFlush()
  flushAt = 0
  flushGen = flushGen + 1
  if scheduler then
    scheduler:Hide()
  end
end

local function EnsureToast()
  if toast then
    return toast
  end

  toast = CreateFrame("Frame", "ClassicGloryToast", UIParent, "BackdropTemplate")
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
  title:SetWordWrap(false)
  toast.title = title

  local title2 = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title2:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  title2:SetPoint("RIGHT", toast, "RIGHT", -16, 0)
  title2:SetJustifyH("LEFT")
  title2:SetWordWrap(false)
  title2:Hide()
  toast.title2 = title2

  local title3 = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title3:SetPoint("TOPLEFT", title2, "BOTTOMLEFT", 0, -2)
  title3:SetPoint("RIGHT", toast, "RIGHT", -16, 0)
  title3:SetJustifyH("LEFT")
  title3:SetWordWrap(false)
  title3:Hide()
  toast.title3 = title3

  local more = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  more:SetJustifyH("LEFT")
  more:SetTextColor(0.75, 0.75, 0.75)
  more:SetWordWrap(false)
  more:Hide()
  toast.more = more

  local points = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  points:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  points:SetJustifyH("LEFT")
  points:SetTextColor(0.9, 0.9, 0.6)
  toast.points = points

  return toast
end

local function LayoutContent(f, defs)
  local n = #defs
  local first = defs[1]
  f.icon:SetTexture(first.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  f.icon:SetDesaturated(false)

  local named = math.min(MAX_NAMED, n)
  local titles = { f.title, f.title2, f.title3 }
  local leftover = n - named

  if n == 1 then
    f:SetHeight(TOAST_HEIGHT)
    f.banner:SetText("Achievement Earned!")
    f.title:SetText(first.title or "Achievement")
    f.title:Show()
    f.title2:Hide()
    f.title3:Hide()
    f.more:Hide()
    f.points:ClearAllPoints()
    f.points:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
  else
    f.banner:SetText("Achievements Earned!")
    local last = f.title
    for i = 1, MAX_NAMED do
      local fs = titles[i]
      if i <= named then
        fs:SetText(defs[i].title or "Achievement")
        fs:Show()
        last = fs
      else
        fs:Hide()
      end
    end
    if leftover > 0 then
      f.more:ClearAllPoints()
      f.more:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2)
      f.more:SetPoint("RIGHT", f, "RIGHT", -16, 0)
      f.more:SetText("... and " .. leftover .. " more")
      f.more:Show()
      last = f.more
    else
      f.more:Hide()
    end
    f.points:ClearAllPoints()
    f.points:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2)
    f:SetHeight(TOAST_HEIGHT + (named - 1) * TITLE_LINE + (leftover > 0 and MORE_LINE or 0))
  end

  local pts = 0
  for i = 1, n do
    pts = pts + (defs[i].points or 0)
  end
  if pts > 0 then
    f.points:SetText(pts .. " points")
  else
    f.points:SetText("Feat of Strength")
  end
end

local function OnToastHidden()
  CancelFlush()
  if #pending > 0 then
    Alert:_FlushPending()
  end
end

function Alert:_Present(defs)
  if not defs or #defs == 0 then
    return
  end
  local f = EnsureToast()
  LayoutContent(f, defs)

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
          OnToastHidden()
        end
      end)
    end
  end)
end

function Alert:_FlushPending()
  flushAt = 0
  if scheduler then
    scheduler:Hide()
  end
  if #pending == 0 then
    return
  end
  local f = EnsureToast()
  if f:IsShown() then
    return
  end
  local defs = pending
  pending = {}
  self:_Present(defs)
end

--- Public entry: show a toast for the given achievement definition.
function Alert:Show(def)
  if not def then
    return
  end
  pending[#pending + 1] = def
  local f = EnsureToast()
  if f:IsShown() then
    return
  end
  ArmFlush()
end
