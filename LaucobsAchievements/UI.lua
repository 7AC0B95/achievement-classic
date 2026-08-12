--[[
  LaucobsAchievements - UI
  Retail-inspired achievement panel for Classic Era / Hardcore.
  Uses only Classic-safe APIs and textures.
]]

local addonName, LA = ...

local UI = {}
LA.UI = UI

-- Layout constants
local PANEL_W, PANEL_H = 900, 640
local SIDEBAR_W = 190
local HEADER_H = 58
local CARD_H = 108
local CARD_GAP = 12
local ICON_SIZE = 62
local CARD_PAD = 18
local CAT_BTN_H = 36
local CAT_BTN_GAP = 8

local FONT = "Fonts\\FRIZQT__.TTF"

local selectedCategory
local categoryButtons = {}
local cardPool = {}
local peerCardPool = {}
local peerHeaderPool = {}
local viewingPeer -- fullName when inspecting another player; nil = self
local playersMode = false -- true when sidebar "Players" list is shown
local playersBtn
local youBtn
local playerSearchText = ""
local playerStatusFilter = "all" -- all | addon | pending | noaddon
local PLAYERS_TOOLBAR_H = 58
local SCROLL_TOP_DEFAULT = -50
local SCROLL_TOP_PLAYERS = -(50 + PLAYERS_TOOLBAR_H)

local PLAYER_SECTIONS = {
  { id = "group",   title = "Group / Raid" },
  { id = "guild",   title = "Guild" },
  { id = "inspect", title = "Inspected" },
  { id = "other",   title = "Other" },
}

local function IsShownComplete(achievementId)
  if viewingPeer and LA.Share then
    return LA.Share:IsPeerComplete(viewingPeer, achievementId)
  end
  return LA:IsComplete(achievementId)
end

local function GetShownEarnedDate(achievementId)
  if viewingPeer then
    return nil -- peers sync completion only, not earn timestamps
  end
  return LA:GetEarnedDate(achievementId)
end

local function GetShownProgress(achievementId)
  if viewingPeer then
    if IsShownComplete(achievementId) then
      local _, required = LA:GetAchievementProgress(achievementId)
      return required, required
    end
    local _, required = LA:GetAchievementProgress(achievementId)
    return 0, required
  end
  return LA:GetAchievementProgress(achievementId)
end

local function GetShownPoints()
  if viewingPeer and LA.Share then
    local peer = LA.Share:GetPeer(viewingPeer)
    return peer and peer.points or 0
  end
  return LA:GetEarnedPoints() or 0
end

local function GetCompareCounts(categoryId)
  local list = LA:GetAchievementsByCategory(categoryId)
  local them, you, both, total = 0, 0, 0, #list
  for _, def in ipairs(list) do
    local peerDone = LA.Share and LA.Share:IsPeerComplete(viewingPeer, def.id)
    local selfDone = LA:IsComplete(def.id)
    if peerDone then
      them = them + 1
    end
    if selfDone then
      you = you + 1
    end
    if peerDone and selfDone then
      both = both + 1
    end
  end
  return them, you, both, total
end

local function UpdateHeaderContext()
  local f = UI.frame
  if not f then
    return
  end
  if f.pointsLabel then
    if viewingPeer then
      local themPts = GetShownPoints()
      local youPts = LA:GetEarnedPoints() or 0
      f.pointsLabel:SetText(
        "|cff8cd463Them " .. themPts .. "|r  ·  |cff73c8faYou " .. youPts .. "|r"
      )
    else
      f.pointsLabel:SetText(GetShownPoints() .. " points")
    end
  end
  if youBtn then
    if viewingPeer then
      youBtn:Show()
      local short = viewingPeer:match("^(.+)%-") or viewingPeer
      if f.viewLabel then
        f.viewLabel:SetText("vs  " .. short)
        f.viewLabel:Show()
      end
    else
      youBtn:Hide()
      if f.viewLabel then
        f.viewLabel:Hide()
      end
    end
  end
end

-- Colors
local C = {
  gold       = { 1.00, 0.82, 0.00 },
  goldDim    = { 0.90, 0.75, 0.20 },
  cream      = { 0.95, 0.90, 0.75 },
  ink        = { 0.22, 0.16, 0.08 },
  inkMuted   = { 0.40, 0.32, 0.18 },
  grey       = { 0.55, 0.55, 0.55 },
  greyTitle  = { 0.62, 0.62, 0.58 },
  green      = { 0.25, 0.75, 0.25 },
  red        = { 0.90, 0.28, 0.22 },
  woodDark   = { 0.10, 0.07, 0.04 },
  parchment  = { 0.78, 0.68, 0.48 },
  cardDone   = { 0.16, 0.13, 0.06, 0.95 },
  cardTodo   = { 0.09, 0.08, 0.06, 0.92 },
  borderGold = { 0.72, 0.58, 0.22, 1 },
  borderDim  = { 0.40, 0.34, 0.22, 1 },
  -- Compare palette (them = leaf gold-green, you = cool steel)
  cmpThem    = { 0.55, 0.82, 0.38 },
  cmpYou     = { 0.45, 0.78, 0.98 },
  cmpShared  = { 0.92, 0.78, 0.32 },
}

local function SetFS(fs, size, flags)
  fs:SetFont(FONT, size, flags or "")
end

local function Color(fs, key, a)
  local c = C[key]
  fs:SetTextColor(c[1], c[2], c[3], a or 1)
end

local function TexColor(tex, key)
  local c = C[key]
  if tex.SetColorTexture then
    tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
  else
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  end
end

local function FormatDate(unix)
  if not unix then
    return ""
  end
  return date("%d %b %Y", unix)
end

local function FormatProgress(current, required)
  if required >= 10000 and required % 10000 == 0 then
    local function g(copper)
      return math.floor(copper / 10000) .. "g"
    end
    return g(current) .. " / " .. g(required)
  end
  return current .. " / " .. required
end

local function Solid(parent, layer, r, g, b, a)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  if t.SetColorTexture then
    t:SetColorTexture(r, g, b, a or 1)
  else
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetVertexColor(r, g, b, a or 1)
  end
  return t
end

local function SetSolidColor(tex, r, g, b, a)
  if not tex then
    return
  end
  if tex.SetColorTexture then
    tex:SetColorTexture(r, g, b, a or 1)
  else
    tex:SetVertexColor(r, g, b, a or 1)
  end
end

---------------------------------------------------------------------------
-- Achievement cards
---------------------------------------------------------------------------

local function CreateComparePill(parent, caption)
  local pill = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  pill:SetSize(78, 24)
  pill:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  pill:SetBackdropColor(0.06, 0.05, 0.04, 0.92)
  pill:SetBackdropBorderColor(0.32, 0.28, 0.20, 0.85)

  local glow = Solid(pill, "BACKGROUND", 1, 1, 1, 0)
  glow:SetPoint("TOPLEFT", 1, -1)
  glow:SetPoint("BOTTOMRIGHT", -1, 1)
  pill.glow = glow

  local dot = Solid(pill, "OVERLAY", 0.35, 0.32, 0.26, 1)
  dot:SetSize(7, 7)
  dot:SetPoint("LEFT", 8, 0)
  pill.dot = dot

  local label = pill:CreateFontString(nil, "OVERLAY")
  SetFS(label, 11)
  label:SetJustifyH("LEFT")
  label:SetPoint("LEFT", dot, "RIGHT", 6, 0)
  label:SetPoint("RIGHT", -8, 0)
  label:SetText(caption)
  label:SetTextColor(0.50, 0.46, 0.38, 1)
  pill.label = label

  return pill
end

local function StyleComparePill(pill, done, tone)
  if not pill then
    return
  end
  local active = done and true or false
  if active and tone == "them" then
    pill:SetBackdropColor(0.14, 0.20, 0.09, 0.96)
    pill:SetBackdropBorderColor(0.55, 0.82, 0.38, 1)
    SetSolidColor(pill.glow, 0.45, 0.75, 0.28, 0.14)
    SetSolidColor(pill.dot, 0.55, 0.88, 0.40, 1)
    pill.label:SetTextColor(0.86, 0.96, 0.72, 1)
  elseif active and tone == "you" then
    pill:SetBackdropColor(0.08, 0.14, 0.22, 0.96)
    pill:SetBackdropBorderColor(0.45, 0.78, 0.98, 1)
    SetSolidColor(pill.glow, 0.35, 0.65, 0.90, 0.14)
    SetSolidColor(pill.dot, 0.50, 0.84, 1.00, 1)
    pill.label:SetTextColor(0.78, 0.92, 1.00, 1)
  else
    pill:SetBackdropColor(0.05, 0.04, 0.03, 0.88)
    pill:SetBackdropBorderColor(0.28, 0.24, 0.16, 0.75)
    SetSolidColor(pill.glow, 1, 1, 1, 0)
    SetSolidColor(pill.dot, 0.32, 0.29, 0.22, 1)
    pill.label:SetTextColor(0.48, 0.44, 0.36, 1)
  end
end

--- Build / refresh modern compare chrome on a card (pills + outcome tag).
local function EnsureCompareChrome(card)
  if card.youCheck then
    card.youCheck:Hide()
    card.youCheck = nil
  end
  if card.compareLabel then
    card.compareLabel:Hide()
  end
  if card.compare then
    card.compare:Hide()
  end

  if not card.compareRow then
    local row = CreateFrame("Frame", nil, card)
    row:SetSize(164, 24)
    row:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -CARD_PAD, 12)
    row:Hide()

    local themPill = CreateComparePill(row, "Them")
    local youPill = CreateComparePill(row, "You")
    youPill:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    themPill:SetPoint("RIGHT", youPill, "LEFT", -6, 0)

    card.compareRow = row
    card.themPill = themPill
    card.youPill = youPill
  end

  if not card.compareTag then
    local tag = card:CreateFontString(nil, "OVERLAY")
    SetFS(tag, 11)
    tag:SetJustifyH("LEFT")
    tag:SetPoint("BOTTOMLEFT", card.iconSlot, "BOTTOMRIGHT", 14, 14)
    tag:Hide()
    card.compareTag = tag
  elseif card.compareTag and card.iconSlot then
    card.compareTag:ClearAllPoints()
    card.compareTag:SetJustifyH("LEFT")
    card.compareTag:SetPoint("BOTTOMLEFT", card.iconSlot, "BOTTOMRIGHT", 14, 14)
  end

  return card.compareRow
end

local function AcquireCard(parent, index)
  if cardPool[index] then
    local existing = cardPool[index]
    EnsureCompareChrome(existing)
    return existing
  end

  local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
  card:SetHeight(CARD_H)
  card:EnableMouse(true)
  card:RegisterForClicks("LeftButtonUp")

  card:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })

  -- Soft inner wash (parchment tint)
  local wash = Solid(card, "BACKGROUND", 0.55, 0.45, 0.28, 0.18)
  wash:SetPoint("TOPLEFT", 4, -4)
  wash:SetPoint("BOTTOMRIGHT", -4, 4)
  card.wash = wash

  -- Left accent strip
  local accent = Solid(card, "ARTWORK", 0.72, 0.58, 0.22, 0.85)
  accent:SetWidth(3)
  accent:SetPoint("TOPLEFT", 5, -5)
  accent:SetPoint("BOTTOMLEFT", 5, 5)
  card.accent = accent

  -- Icon plate
  local iconSlot = card:CreateTexture(nil, "ARTWORK")
  iconSlot:SetSize(ICON_SIZE + 12, ICON_SIZE + 12)
  iconSlot:SetPoint("LEFT", CARD_PAD, 0)
  iconSlot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  iconSlot:SetVertexColor(0.9, 0.8, 0.5)
  card.iconSlot = iconSlot

  local icon = card:CreateTexture(nil, "OVERLAY")
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:SetPoint("CENTER", iconSlot, "CENTER", 0, 0)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  card.icon = icon

  -- Completed check overlay (hidden unless earned) — self view / peer complete
  local check = card:CreateTexture(nil, "OVERLAY", nil, 7)
  check:SetSize(22, 22)
  check:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 4, -4)
  check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  check:Hide()
  card.check = check

  EnsureCompareChrome(card)

  -- Title
  local title = card:CreateFontString(nil, "OVERLAY")
  SetFS(title, 15)
  title:SetJustifyH("LEFT")
  title:SetJustifyV("TOP")
  title:SetWordWrap(false)
  title:SetPoint("TOPLEFT", iconSlot, "TOPRIGHT", 14, -8)
  card.title = title

  -- Description
  local desc = card:CreateFontString(nil, "OVERLAY")
  SetFS(desc, 12)
  desc:SetJustifyH("LEFT")
  desc:SetJustifyV("TOP")
  desc:SetWordWrap(true)
  desc:SetNonSpaceWrap(false)
  desc:SetSpacing(3)
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  card.desc = desc

  -- Points shield-style label (right side)
  local points = card:CreateFontString(nil, "OVERLAY")
  SetFS(points, 13)
  points:SetJustifyH("RIGHT")
  points:SetPoint("TOPRIGHT", card, "TOPRIGHT", -CARD_PAD, -14)
  Color(points, "gold")
  card.points = points

  -- Date earned (self view); hidden while comparing
  local status = card:CreateFontString(nil, "OVERLAY")
  SetFS(status, 12)
  status:SetJustifyH("RIGHT")
  status:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -CARD_PAD, 14)
  Color(status, "green")
  card.status = status

  -- Progress track
  local barBg = CreateFrame("Frame", nil, card, "BackdropTemplate")
  barBg:SetHeight(16)
  barBg:SetPoint("BOTTOMLEFT", iconSlot, "BOTTOMRIGHT", 14, 12)
  barBg:SetPoint("RIGHT", card, "RIGHT", -CARD_PAD, 0)
  barBg:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  barBg:SetBackdropColor(0.05, 0.05, 0.04, 0.95)
  barBg:SetBackdropBorderColor(0.45, 0.38, 0.22, 1)
  card.barBg = barBg

  local bar = CreateFrame("StatusBar", nil, barBg)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("BOTTOMRIGHT", -1, 1)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(0.20, 0.70, 0.20)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  card.bar = bar

  -- Subtle bar sheen
  local sheen = bar:CreateTexture(nil, "OVERLAY")
  sheen:SetTexture("Interface\\Buttons\\WHITE8X8")
  sheen:SetVertexColor(1, 1, 1, 0.12)
  sheen:SetPoint("TOPLEFT", 0, 0)
  sheen:SetPoint("BOTTOMRIGHT", bar, "RIGHT", 0, 0)

  local barText = bar:CreateFontString(nil, "OVERLAY")
  SetFS(barText, 10, "OUTLINE")
  barText:SetPoint("CENTER", 0, 0)
  barText:SetTextColor(1, 1, 1, 1)
  card.barText = barText

  -- Hover highlight
  local hl = Solid(card, "HIGHLIGHT", 1, 0.90, 0.50, 0.08)
  hl:SetAllPoints()
  card:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.95, 0.80, 0.30, 1)
  end)
  card:SetScript("OnLeave", function(self)
    if self._borderR then
      self:SetBackdropBorderColor(self._borderR, self._borderG, self._borderB, self._borderA or 1)
    else
      local complete = self.def and IsShownComplete(self.def.id)
      if complete then
        self:SetBackdropBorderColor(unpack(C.borderGold))
      else
        self:SetBackdropBorderColor(unpack(C.borderDim))
      end
    end
  end)

  cardPool[index] = card
  return card
end

--- Apply peer-vs-you compare chrome to a card. Returns peerDone, selfDone.
local function ApplyCompareChrome(card, achievementId)
  local peerDone = IsShownComplete(achievementId) and true or false
  local selfDone = LA:IsComplete(achievementId) and true or false

  EnsureCompareChrome(card)

  StyleComparePill(card.themPill, peerDone, "them")
  StyleComparePill(card.youPill, selfDone, "you")
  if card.compareRow then
    card.compareRow:Show()
  end

  if card.compareTag then
    if peerDone and selfDone then
      card.compareTag:SetText("Shared")
      card.compareTag:SetTextColor(C.cmpShared[1], C.cmpShared[2], C.cmpShared[3], 1)
      card.compareTag:Show()
    elseif peerDone then
      card.compareTag:SetText("They have it")
      card.compareTag:SetTextColor(C.cmpThem[1], C.cmpThem[2], C.cmpThem[3], 0.95)
      card.compareTag:Show()
    elseif selfDone then
      card.compareTag:SetText("Only you")
      card.compareTag:SetTextColor(C.cmpYou[1], C.cmpYou[2], C.cmpYou[3], 0.95)
      card.compareTag:Show()
    else
      card.compareTag:Hide()
    end
  end

  if card.status then
    card.status:Hide()
  end
  if card.check then
    card.check:Hide()
  end

  -- Card surface: shared / them / you / neither
  local br, bg, bb, ba = 0.36, 0.30, 0.18, 1
  if peerDone and selfDone then
    br, bg, bb, ba = 0.78, 0.64, 0.24, 1
    card:SetBackdropColor(0.17, 0.14, 0.07, 0.96)
    if card.accent and card.accent.SetColorTexture then
      card.accent:SetColorTexture(0.92, 0.78, 0.28, 1)
    end
    if card.wash then
      card.wash:SetAlpha(0.30)
    end
    if card.iconSlot then
      card.iconSlot:SetVertexColor(1.0, 0.90, 0.40)
    end
    Color(card.title, "gold")
    Color(card.desc, "cream")
  elseif peerDone then
    br, bg, bb, ba = 0.48, 0.68, 0.32, 1
    card:SetBackdropColor(0.12, 0.14, 0.08, 0.95)
    if card.accent and card.accent.SetColorTexture then
      card.accent:SetColorTexture(0.50, 0.78, 0.35, 0.95)
    end
    if card.wash then
      card.wash:SetAlpha(0.22)
    end
    if card.iconSlot then
      card.iconSlot:SetVertexColor(0.70, 0.90, 0.50)
    end
    Color(card.title, "cream")
    card.desc:SetTextColor(0.78, 0.86, 0.68, 1)
  elseif selfDone then
    br, bg, bb, ba = 0.35, 0.58, 0.78, 1
    card:SetBackdropColor(0.07, 0.10, 0.15, 0.96)
    if card.accent and card.accent.SetColorTexture then
      card.accent:SetColorTexture(0.40, 0.68, 0.90, 0.95)
    end
    if card.wash then
      card.wash:SetAlpha(0.20)
    end
    if card.iconSlot then
      card.iconSlot:SetVertexColor(0.55, 0.78, 0.95)
    end
    Color(card.title, "cream")
    card.desc:SetTextColor(0.70, 0.80, 0.90, 1)
  else
    card:SetBackdropColor(0.08, 0.07, 0.05, 0.92)
    if card.accent and card.accent.SetColorTexture then
      card.accent:SetColorTexture(0.32, 0.28, 0.18, 0.65)
    end
    if card.wash then
      card.wash:SetAlpha(0.08)
    end
    if card.iconSlot then
      card.iconSlot:SetVertexColor(0.50, 0.48, 0.42)
    end
    Color(card.title, "greyTitle")
    card.desc:SetTextColor(0.58, 0.54, 0.44, 1)
  end

  card._borderR, card._borderG, card._borderB, card._borderA = br, bg, bb, ba
  card:SetBackdropBorderColor(br, bg, bb, ba)

  return peerDone, selfDone
end

local function ClearCompareChrome(card)
  if card.compareRow then
    card.compareRow:Hide()
  end
  if card.compareTag then
    card.compareTag:Hide()
  end
  if card.compareLabel then
    card.compareLabel:Hide()
  end
  if card.compare then
    card.compare:Hide()
  end
  card._borderR, card._borderG, card._borderB, card._borderA = nil, nil, nil, nil
end

local function ReleaseCardsFrom(startIndex)
  for i = startIndex, #cardPool do
    cardPool[i]:Hide()
    cardPool[i].def = nil
  end
end

local function ReleasePeerCardsFrom(startIndex)
  for i = startIndex, #peerCardPool do
    peerCardPool[i]:Hide()
    peerCardPool[i].peerKey = nil
  end
end

local function ReleasePeerHeadersFrom(startIndex)
  for i = startIndex, #peerHeaderPool do
    peerHeaderPool[i]:Hide()
  end
end

local function HideAchievementCards()
  ReleaseCardsFrom(1)
end

local function HidePeerCards()
  ReleasePeerCardsFrom(1)
  ReleasePeerHeadersFrom(1)
end

local function SetPlayersToolbarVisible(visible)
  local bar = UI.playersToolbar
  local scrollFrame = UI.scrollFrame
  if bar then
    if visible then
      bar:Show()
    else
      bar:Hide()
    end
  end
  if scrollFrame then
    scrollFrame:ClearAllPoints()
    local top = visible and SCROLL_TOP_PLAYERS or SCROLL_TOP_DEFAULT
    scrollFrame:SetPoint("TOPLEFT", 10, top)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 10)
  end
end

local function GetViewWidth()
  local sf = UI.scrollFrame
  if not sf then
    return 480
  end
  local w = sf:GetWidth()
  if not w or w < 50 then
    -- Frame may not be laid out yet; estimate from panel
    local f = UI.frame
    if f then
      w = (f:GetWidth() or PANEL_W) - SIDEBAR_W - 70
    else
      w = 480
    end
  end
  return w
end

local function PopulateAchievements(categoryId)
  local scrollChild = UI.scrollChild
  local scrollFrame = UI.scrollFrame
  if not scrollChild or not scrollFrame or not categoryId then
    return
  end

  HidePeerCards()
  playersMode = false
  SetPlayersToolbarVisible(false)

  local viewW = GetViewWidth()
  scrollChild:SetWidth(viewW)

  local list = LA:GetAchievementsByCategory(categoryId)
  local y = -4
  local textW

  for i, def in ipairs(list) do
    local card = AcquireCard(scrollChild, i)
    card.def = def
    card:ClearAllPoints()
    card:SetWidth(viewW - 10)
    card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)

    -- Explicit text widths (fixes collapsed/invisible fontstrings)
    textW = (viewW - 10) - (ICON_SIZE + 12 + CARD_PAD + 14 + 80)
    if textW < 140 then
      textW = 140
    end
    card.title:SetWidth(textW)
    card.desc:SetWidth(textW)
    card.desc:ClearAllPoints()
    card.desc:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -6)

    local complete = IsShownComplete(def.id)
    local selfDone = LA:IsComplete(def.id)

    card.icon:SetTexture(def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    -- In compare mode, saturate if either player earned it so "you only" still reads clearly
    if viewingPeer then
      card.icon:SetDesaturated(not (complete or selfDone))
    else
      card.icon:SetDesaturated(not complete)
    end

    card.title:SetText(
      (LA:IsDebug() and ("[" .. def.id .. "] ") or "") .. (def.title or "")
    )
    card.desc:SetText(def.description or "")

    local pts = def.points or 0
    if pts > 0 then
      card.points:SetText(pts .. " pts")
      card.points:Show()
    else
      card.points:SetText("FoS")
      Color(card.points, "goldDim")
      card.points:Show()
    end

    local current, required = GetShownProgress(def.id)
    if viewingPeer then
      ApplyCompareChrome(card, def.id)
      if complete or selfDone then
        Color(card.points, "gold")
      else
        card.points:SetTextColor(0.55, 0.50, 0.35, 1)
      end
      card.barBg:Hide()
      card.desc:SetHeight(36)
    elseif complete then
      ClearCompareChrome(card)
      Color(card.title, "gold")
      Color(card.desc, "cream")
      card:SetBackdropColor(unpack(C.cardDone))
      card:SetBackdropBorderColor(unpack(C.borderGold))
      card.accent:SetVertexColor(1, 0.85, 0.2, 1)
      if card.accent.SetColorTexture then
        card.accent:SetColorTexture(0.95, 0.78, 0.15, 1)
      end
      card.iconSlot:SetVertexColor(1.0, 0.88, 0.35)
      card.check:Show()
      card.wash:SetAlpha(0.28)
      Color(card.points, "gold")
      card.barBg:Hide()
      local earned = GetShownEarnedDate(def.id)
      if earned then
        card.status:SetText(FormatDate(earned))
      else
        card.status:SetText("")
      end
      card.status:Show()
      card.desc:SetHeight(42)
      card:SetBackdropBorderColor(0.72, 0.58, 0.22, 1)
      card._borderR, card._borderG, card._borderB, card._borderA = 0.72, 0.58, 0.22, 1
    else
      ClearCompareChrome(card)
      Color(card.title, "greyTitle")
      card.desc:SetTextColor(0.62, 0.58, 0.48, 1)
      card:SetBackdropColor(unpack(C.cardTodo))
      card:SetBackdropBorderColor(unpack(C.borderDim))
      if card.accent.SetColorTexture then
        card.accent:SetColorTexture(0.35, 0.30, 0.20, 0.7)
      end
      card.iconSlot:SetVertexColor(0.55, 0.55, 0.50)
      card.check:Hide()
      card.wash:SetAlpha(0.10)
      card.points:SetTextColor(0.55, 0.50, 0.35, 1)
      card.status:SetText("")
      card.status:Hide()
      card.desc:SetHeight(34)
      card:SetBackdropBorderColor(0.40, 0.34, 0.22, 1)
      card._borderR, card._borderG, card._borderB, card._borderA = 0.40, 0.34, 0.22, 1
      if required > 1 then
        card.barBg:Show()
        card.bar:SetMinMaxValues(0, required)
        card.bar:SetValue(math.min(current, required))
        card.barText:SetText(FormatProgress(current, required))
        local pct = required > 0 and (current / required) or 0
        if pct >= 1 then
          card.bar:SetStatusBarColor(0.25, 0.80, 0.25)
        elseif pct >= 0.5 then
          card.bar:SetStatusBarColor(0.85, 0.70, 0.15)
        else
          card.bar:SetStatusBarColor(0.55, 0.45, 0.15)
        end
      else
        card.barBg:Hide()
      end
    end

    card:Show()
    y = y - (CARD_H + CARD_GAP)
  end

  ReleaseCardsFrom(#list + 1)

  local contentH = math.max(scrollFrame:GetHeight() or 400, (-y) + 12)
  scrollChild:SetHeight(contentH)

  -- Header summary
  if UI.frame and UI.frame.catLabel then
    local catName = categoryId
    for _, cat in ipairs(LA.Categories) do
      if cat.id == categoryId then
        catName = cat.name
        break
      end
    end
    UI.frame.catLabel:SetText(catName)
    if viewingPeer then
      local them, you, both, total = GetCompareCounts(categoryId)
      UI.frame.catCount:SetText(
        "|cff8cd463Them " .. them .. "/" .. total .. "|r"
          .. "   ·   "
          .. "|cff73c8faYou " .. you .. "/" .. total .. "|r"
          .. "   ·   "
          .. "|cffe8c652Shared " .. both .. "|r"
      )
    else
      local earned, total = 0, #list
      for _, def in ipairs(list) do
        if IsShownComplete(def.id) then
          earned = earned + 1
        end
      end
      UI.frame.catCount:SetText(earned .. " / " .. total .. " earned")
    end
  end

  UpdateHeaderContext()
end

---------------------------------------------------------------------------
-- Category sidebar
---------------------------------------------------------------------------

local function SelectCategory(categoryId)
  selectedCategory = categoryId
  playersMode = false
  SetPlayersToolbarVisible(false)
  for id, btn in pairs(categoryButtons) do
    local active = (id == categoryId)
    btn.selected = active
    if active then
      btn.bg:SetAlpha(1)
      Color(btn.label, "gold")
      if btn.arrow then
        btn.arrow:Show()
      end
    else
      btn.bg:SetAlpha(0)
      btn.label:SetTextColor(0.82, 0.76, 0.60, 1)
      if btn.arrow then
        btn.arrow:Hide()
      end
    end
  end
  if playersBtn then
    playersBtn.selected = false
    playersBtn.bg:SetAlpha(0)
    playersBtn.label:SetTextColor(0.82, 0.76, 0.60, 1)
    if playersBtn.arrow then
      playersBtn.arrow:Hide()
    end
  end
  PopulateAchievements(categoryId)
end

local function SetPlayersSidebarSelected(active)
  if not playersBtn then
    return
  end
  playersBtn.selected = active
  if active then
    playersBtn.bg:SetAlpha(1)
    Color(playersBtn.label, "gold")
    if playersBtn.arrow then
      playersBtn.arrow:Show()
    end
    for _, btn in pairs(categoryButtons) do
      btn.selected = false
      btn.bg:SetAlpha(0)
      btn.label:SetTextColor(0.82, 0.76, 0.60, 1)
      if btn.arrow then
        btn.arrow:Hide()
      end
    end
  else
    playersBtn.bg:SetAlpha(0)
    playersBtn.label:SetTextColor(0.82, 0.76, 0.60, 1)
    if playersBtn.arrow then
      playersBtn.arrow:Hide()
    end
  end
end

local function AcquirePeerCard(parent, index)
  if peerCardPool[index] then
    return peerCardPool[index]
  end

  local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
  card:SetHeight(64)
  card:EnableMouse(true)
  card:RegisterForClicks("LeftButtonUp")
  card:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  card:SetBackdropColor(unpack(C.cardTodo))
  card:SetBackdropBorderColor(unpack(C.borderDim))

  local name = card:CreateFontString(nil, "OVERLAY")
  SetFS(name, 14)
  name:SetPoint("TOPLEFT", 14, -12)
  name:SetPoint("RIGHT", -14, 0)
  name:SetJustifyH("LEFT")
  Color(name, "gold")
  card.name = name

  local detail = card:CreateFontString(nil, "OVERLAY")
  SetFS(detail, 12)
  detail:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
  detail:SetPoint("RIGHT", -14, 0)
  detail:SetJustifyH("LEFT")
  detail:SetTextColor(0.75, 0.70, 0.55, 1)
  card.detail = detail

  card:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.95, 0.80, 0.30, 1)
  end)
  card:SetScript("OnLeave", function(self)
    if self.noAddon then
      self:SetBackdropBorderColor(0.75, 0.25, 0.20, 1)
    else
      self:SetBackdropBorderColor(unpack(C.borderDim))
    end
  end)

  peerCardPool[index] = card
  return card
end

local function AcquirePeerHeader(parent, index)
  if peerHeaderPool[index] then
    return peerHeaderPool[index]
  end

  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(22)

  local label = row:CreateFontString(nil, "OVERLAY")
  SetFS(label, 13)
  label:SetPoint("LEFT", 4, 0)
  label:SetPoint("RIGHT", -4, 0)
  label:SetJustifyH("LEFT")
  Color(label, "goldDim")
  row.label = label

  peerHeaderPool[index] = row
  return row
end

local function PeerMatchesStatus(peer, filter)
  if filter == "all" then
    return true
  elseif filter == "addon" then
    return peer.hasAddon and true or false
  elseif filter == "pending" then
    return (not peer.hasAddon) and peer.pending
  elseif filter == "noaddon" then
    return (not peer.hasAddon) and (not peer.pending)
  end
  return true
end

local function PeerMatchesSearch(peer, query)
  if not query or query == "" then
    return true
  end
  local q = strlower(query)
  local name = strlower(peer.name or "")
  local key = strlower(peer.key or "")
  local realm = strlower(peer.realm or "")
  return name:find(q, 1, true) or key:find(q, 1, true) or realm:find(q, 1, true)
end

local function UpdatePlayerFilterButtons()
  local bar = UI.playersToolbar
  if not bar or not bar.filterButtons then
    return
  end
  for id, btn in pairs(bar.filterButtons) do
    local active = (id == playerStatusFilter)
    btn.active = active
    if active then
      btn:SetBackdropBorderColor(0.95, 0.80, 0.30, 1)
      btn:SetBackdropColor(0.35, 0.26, 0.08, 0.95)
      Color(btn.label, "gold")
    else
      btn:SetBackdropBorderColor(unpack(C.borderDim))
      btn:SetBackdropColor(0.12, 0.10, 0.06, 0.9)
      btn.label:SetTextColor(0.75, 0.70, 0.55, 1)
    end
  end
end

local function ViewPeer(peerKey)
  if not peerKey or not LA.Share then
    return
  end
  viewingPeer = peerKey
  if LA.Share.viewing ~= peerKey then
    LA.Share.viewing = peerKey
  end
  LA.Share:RequestPeer(peerKey)
  playersMode = false
  SetPlayersToolbarVisible(false)
  SetPlayersSidebarSelected(false)
  -- Show General category through peer lens by default
  local catId = selectedCategory or (LA.Categories[1] and LA.Categories[1].id)
  if catId then
    selectedCategory = catId
    for id, btn in pairs(categoryButtons) do
      local active = (id == catId)
      btn.selected = active
      if active then
        btn.bg:SetAlpha(1)
        Color(btn.label, "gold")
        if btn.arrow then
          btn.arrow:Show()
        end
      else
        btn.bg:SetAlpha(0)
        btn.label:SetTextColor(0.82, 0.76, 0.60, 1)
        if btn.arrow then
          btn.arrow:Hide()
        end
      end
    end
    PopulateAchievements(catId)
  end
  UpdateHeaderContext()
end

local function PopulatePlayers()
  local scrollChild = UI.scrollChild
  local scrollFrame = UI.scrollFrame
  if not scrollChild or not scrollFrame then
    return
  end

  HideAchievementCards()
  playersMode = true
  SetPlayersSidebarSelected(true)
  SetPlayersToolbarVisible(true)
  UpdatePlayerFilterButtons()

  if LA.Share and LA.Share.Announce then
    LA.Share:Announce()
  end

  local viewW = GetViewWidth()
  scrollChild:SetWidth(viewW)

  local peers = (LA.Share and LA.Share.GetPeerList and LA.Share:GetPeerList()) or {}
  local filtered = {}
  local onlineWithAddon = 0
  for _, peer in ipairs(peers) do
    if peer.hasAddon then
      onlineWithAddon = onlineWithAddon + 1
    end
    if PeerMatchesSearch(peer, playerSearchText) and PeerMatchesStatus(peer, playerStatusFilter) then
      filtered[#filtered + 1] = peer
    end
  end

  local bySource = {
    group = {},
    guild = {},
    inspect = {},
    other = {},
  }
  for _, peer in ipairs(filtered) do
    local src = peer.source or "other"
    if not bySource[src] then
      src = "other"
    end
    bySource[src][#bySource[src] + 1] = peer
  end

  local y = -4
  local cardIndex = 0
  local headerIndex = 0

  local function placeCard(peer)
    cardIndex = cardIndex + 1
    local card = AcquirePeerCard(scrollChild, cardIndex)
    card.peerKey = peer.key
    card:ClearAllPoints()
    card:SetWidth(viewW - 10)
    card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)
    card.name:SetText(peer.name or peer.key)

    if peer.hasAddon then
      card.noAddon = false
      Color(card.name, "gold")
      card.detail:SetTextColor(0.75, 0.70, 0.55, 1)
      local syncNote = peer.syncing and " (syncing…)" or ""
      card.detail:SetText(
        (peer.points or 0) .. " points  ·  " .. (peer.count or 0) .. " earned" .. syncNote
      )
      card:SetBackdropBorderColor(unpack(C.borderDim))
    elseif peer.pending then
      card.noAddon = false
      Color(card.name, "greyTitle")
      card.detail:SetTextColor(0.62, 0.62, 0.58, 1)
      card.detail:SetText("Awaiting addon response…")
      card:SetBackdropBorderColor(unpack(C.borderDim))
    else
      card.noAddon = true
      Color(card.name, "red")
      card.detail:SetTextColor(0.90, 0.40, 0.32, 1)
      card.detail:SetText("No addon (no response)")
      card:SetBackdropBorderColor(0.75, 0.25, 0.20, 1)
    end

    card:SetScript("OnClick", function(self)
      if self.peerKey then
        ViewPeer(self.peerKey)
      end
    end)
    card:Show()
    y = y - 76
  end

  if #peers == 0 then
    cardIndex = 1
    local card = AcquirePeerCard(scrollChild, 1)
    card.peerKey = nil
    card.noAddon = false
    card:ClearAllPoints()
    card:SetWidth(viewW - 10)
    card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)
    Color(card.name, "gold")
    card.name:SetText("No players found yet")
    card.detail:SetTextColor(0.75, 0.70, 0.55, 1)
    card.detail:SetText("Guild, party, and raid members with the addon appear here. Target a player and type /la inspect.")
    card:SetBackdropBorderColor(unpack(C.borderDim))
    card:SetScript("OnClick", nil)
    card:Show()
    y = y - 76
  elseif #filtered == 0 then
    cardIndex = 1
    local card = AcquirePeerCard(scrollChild, 1)
    card.peerKey = nil
    card.noAddon = false
    card:ClearAllPoints()
    card:SetWidth(viewW - 10)
    card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)
    Color(card.name, "gold")
    card.name:SetText("No matching players")
    card.detail:SetTextColor(0.75, 0.70, 0.55, 1)
    card.detail:SetText("Try a different search or status filter.")
    card:SetBackdropBorderColor(unpack(C.borderDim))
    card:SetScript("OnClick", nil)
    card:Show()
    y = y - 76
  else
    for _, section in ipairs(PLAYER_SECTIONS) do
      local list = bySource[section.id]
      if list and #list > 0 then
        headerIndex = headerIndex + 1
        local header = AcquirePeerHeader(scrollChild, headerIndex)
        header:ClearAllPoints()
        header:SetWidth(viewW - 10)
        header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)
        header.label:SetText(section.title .. "  (" .. #list .. ")")
        header:Show()
        y = y - 26
        for _, peer in ipairs(list) do
          placeCard(peer)
        end
        y = y - 6
      end
    end
  end

  ReleasePeerCardsFrom(cardIndex + 1)
  ReleasePeerHeadersFrom(headerIndex + 1)

  local contentH = math.max(scrollFrame:GetHeight() or 400, (-y) + 12)
  scrollChild:SetHeight(contentH)

  if UI.frame then
    UI.frame.catLabel:SetText("Players")
    local shown = #filtered
    if #peers == 0 then
      UI.frame.catCount:SetText("0 online with addon")
    elseif shown == #peers then
      UI.frame.catCount:SetText(onlineWithAddon .. " online with addon")
    else
      UI.frame.catCount:SetText(shown .. " shown · " .. onlineWithAddon .. " with addon")
    end
  end
  UpdateHeaderContext()
end

local function ClearPeerView()
  viewingPeer = nil
  if LA.Share then
    LA.Share.viewing = nil
  end
  UpdateHeaderContext()
  if playersMode then
    PopulatePlayers()
  elseif selectedCategory then
    PopulateAchievements(selectedCategory)
  end
end

local function BuildCategorySidebar(parent)
  local sorted = {}
  for _, cat in ipairs(LA.Categories) do
    sorted[#sorted + 1] = cat
  end
  table.sort(sorted, function(a, b)
    return a.order < b.order
  end)

  local btnW = math.max(120, (parent:GetWidth() or (SIDEBAR_W - 28)) - 4)
  local y = -8
  for _, cat in ipairs(sorted) do
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(btnW, CAT_BTN_H)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)

    local bg = Solid(btn, "BACKGROUND", 0.55, 0.42, 0.12, 0.55)
    bg:SetAllPoints()
    bg:SetAlpha(0)
    btn.bg = bg

    local edge = Solid(btn, "BORDER", 0.85, 0.70, 0.25, 0.0)
    edge:SetWidth(3)
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("BOTTOMLEFT")
    btn.edge = edge

    local arrow = btn:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(10, 10)
    arrow:SetPoint("LEFT", 6, 0)
    arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    arrow:SetVertexColor(1, 0.85, 0.3)
    arrow:Hide()
    btn.arrow = arrow

    local label = btn:CreateFontString(nil, "OVERLAY")
    SetFS(label, 14)
    label:SetPoint("LEFT", 22, 0)
    label:SetPoint("RIGHT", -8, 0)
    label:SetJustifyH("LEFT")
    label:SetText(cat.name)
    label:SetTextColor(0.82, 0.76, 0.60, 1)
    btn.label = label

    btn:SetScript("OnEnter", function(self)
      if not self.selected then
        self.bg:SetAlpha(0.45)
        self.label:SetTextColor(1, 0.92, 0.65, 1)
      end
    end)
    btn:SetScript("OnLeave", function(self)
      if not self.selected then
        self.bg:SetAlpha(0)
        self.label:SetTextColor(0.82, 0.76, 0.60, 1)
      end
    end)
    btn:SetScript("OnClick", function()
      SelectCategory(cat.id)
    end)

    categoryButtons[cat.id] = btn
    y = y - (CAT_BTN_H + CAT_BTN_GAP)
  end

  -- Spacer + Players browser (social graph)
  y = y - 8
  local rule = Solid(parent, "ARTWORK", 0.55, 0.42, 0.18, 0.55)
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", 10, y + 4)
  rule:SetPoint("TOPRIGHT", -6, y + 4)

  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(btnW, CAT_BTN_H)
  btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y - 8)

  local bg = Solid(btn, "BACKGROUND", 0.55, 0.42, 0.12, 0.55)
  bg:SetAllPoints()
  bg:SetAlpha(0)
  btn.bg = bg

  local arrow = btn:CreateTexture(nil, "ARTWORK")
  arrow:SetSize(10, 10)
  arrow:SetPoint("LEFT", 6, 0)
  arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  arrow:SetVertexColor(1, 0.85, 0.3)
  arrow:Hide()
  btn.arrow = arrow

  local label = btn:CreateFontString(nil, "OVERLAY")
  SetFS(label, 14)
  label:SetPoint("LEFT", 22, 0)
  label:SetPoint("RIGHT", -8, 0)
  label:SetJustifyH("LEFT")
  label:SetText("Players")
  label:SetTextColor(0.82, 0.76, 0.60, 1)
  btn.label = label

  btn:SetScript("OnEnter", function(self)
    if not self.selected then
      self.bg:SetAlpha(0.45)
      self.label:SetTextColor(1, 0.92, 0.65, 1)
    end
  end)
  btn:SetScript("OnLeave", function(self)
    if not self.selected then
      self.bg:SetAlpha(0)
      self.label:SetTextColor(0.82, 0.76, 0.60, 1)
    end
  end)
  btn:SetScript("OnClick", function()
    PopulatePlayers()
  end)

  playersBtn = btn

  -- Content height for the scroll child (Players button bottom + padding)
  return (-(y - 8 - CAT_BTN_H)) + 16
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------

local function CreateMinimapButton()
  local btn = CreateFrame("Button", "LaucobsAchievementsMinimapButton", Minimap)
  btn:SetSize(32, 32)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local overlay = btn:CreateTexture(nil, "OVERLAY")
  overlay:SetSize(53, 53)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetPoint("TOPLEFT")

  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetTexture("Interface\\Icons\\INV_Crown_01")
  icon:SetPoint("CENTER", 1, 0)
  btn.icon = icon

  local angle = 220
  local function UpdatePosition()
    local radius = (Minimap:GetWidth() / 2) + 5
    local rad = math.rad(angle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
  end
  UpdatePosition()

  btn:RegisterForDrag("LeftButton")
  btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      cx, cy = cx / scale, cy / scale
      angle = math.deg(math.atan2(cy - my, cx - mx))
      UpdatePosition()
    end)
  end)
  btn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)

  btn:SetScript("OnClick", function()
    UI:Toggle()
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Laucob's Achievements", 1, 0.82, 0)
    GameTooltip:AddLine("Click to open. Drag to move.", 0.75, 0.75, 0.75, true)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", GameTooltip_Hide)

  UI.minimapButton = btn
end

---------------------------------------------------------------------------
-- Main frame
---------------------------------------------------------------------------

function UI:Init()
  if self.frame then
    return
  end

  local f = CreateFrame("Frame", "LaucobsAchievementsFrame", UIParent, "BackdropTemplate")
  f:SetSize(PANEL_W, PANEL_H)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:SetResizable(true)
  if f.SetResizeBounds then
    f:SetResizeBounds(720, 500, 1100, 860)
  else
    f:SetMinResize(720, 500)
    f:SetMaxResize(1100, 860)
  end
  f:SetClampedToScreen(true)
  f:SetFrameStrata("HIGH")
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:Hide()

  -- Outer wood dialog (Classic-safe border textures only)
  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetBackdropColor(0.08, 0.06, 0.04, 1)
  f:SetBackdropBorderColor(0.85, 0.70, 0.30, 1)

  -- Inner content inset
  local inset = CreateFrame("Frame", nil, f, "BackdropTemplate")
  inset:SetPoint("TOPLEFT", 14, -14)
  inset:SetPoint("BOTTOMRIGHT", -14, 14)
  inset:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  inset:SetBackdropColor(0.12, 0.09, 0.05, 0.95)
  inset:SetBackdropBorderColor(0.55, 0.45, 0.22, 1)
  f.inset = inset

  -- Top header bar
  local header = CreateFrame("Frame", nil, inset, "BackdropTemplate")
  header:SetPoint("TOPLEFT", 6, -6)
  header:SetPoint("TOPRIGHT", -6, -6)
  header:SetHeight(HEADER_H)
  header:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  header:SetBackdropColor(0.18, 0.12, 0.04, 0.95)
  header:SetBackdropBorderColor(0.70, 0.55, 0.20, 1)
  f.header = header

  -- Header gold gradient wash
  local headerGlow = Solid(header, "ARTWORK", 0.85, 0.65, 0.15, 0.12)
  headerGlow:SetPoint("TOPLEFT", 3, -3)
  headerGlow:SetPoint("BOTTOMRIGHT", -3, 3)

  local titleIcon = header:CreateTexture(nil, "OVERLAY")
  titleIcon:SetSize(32, 32)
  titleIcon:SetPoint("LEFT", 14, 0)
  titleIcon:SetTexture("Interface\\Icons\\INV_Crown_01")
  titleIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  local title = header:CreateFontString(nil, "OVERLAY")
  SetFS(title, 20)
  title:SetPoint("LEFT", titleIcon, "RIGHT", 12, 1)
  title:SetText("Laucob's Achievements")
  Color(title, "gold")
  f.title = title

  local pointsLabel = header:CreateFontString(nil, "OVERLAY")
  SetFS(pointsLabel, 14)
  pointsLabel:SetPoint("RIGHT", header, "RIGHT", -44, 0)
  Color(pointsLabel, "cream")
  f.pointsLabel = pointsLabel

  local viewLabel = header:CreateFontString(nil, "OVERLAY")
  SetFS(viewLabel, 13)
  viewLabel:SetPoint("LEFT", title, "RIGHT", 18, 0)
  viewLabel:SetTextColor(0.70, 0.86, 0.98, 1)
  viewLabel:Hide()
  f.viewLabel = viewLabel

  youBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
  youBtn:SetSize(64, 24)
  youBtn:SetPoint("RIGHT", pointsLabel, "LEFT", -12, 0)
  youBtn:SetText("Back")
  youBtn:Hide()
  youBtn:SetScript("OnClick", function()
    ClearPeerView()
  end)

  local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
  close:SetPoint("RIGHT", 2, 0)
  close:SetScript("OnClick", function()
    f:Hide()
  end)

  -- Sidebar
  local sidebar = CreateFrame("Frame", nil, inset, "BackdropTemplate")
  sidebar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -10)
  sidebar:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 8, 8)
  sidebar:SetWidth(SIDEBAR_W)
  sidebar:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  sidebar:SetBackdropColor(0.07, 0.05, 0.03, 0.95)
  sidebar:SetBackdropBorderColor(0.50, 0.40, 0.22, 1)
  f.sidebar = sidebar

  local sideHead = sidebar:CreateFontString(nil, "OVERLAY")
  SetFS(sideHead, 12)
  sideHead:SetPoint("TOPLEFT", 14, -12)
  sideHead:SetText("CATEGORIES")
  Color(sideHead, "goldDim")

  local sideRule = Solid(sidebar, "ARTWORK", 0.55, 0.42, 0.18, 0.7)
  sideRule:SetHeight(1)
  sideRule:SetPoint("TOPLEFT", 12, -30)
  sideRule:SetPoint("TOPRIGHT", -12, -30)

  -- Scrollable category list (fits the longer catalog + Players)
  local sideScroll = CreateFrame("ScrollFrame", "LaucobsAchievementsCatScroll", sidebar, "UIPanelScrollFrameTemplate")
  sideScroll:SetPoint("TOPLEFT", 2, -36)
  sideScroll:SetPoint("BOTTOMRIGHT", -22, 6)
  f.sideScroll = sideScroll
  UI.sideScroll = sideScroll

  local sideChild = CreateFrame("Frame", nil, sideScroll)
  sideChild:SetWidth(SIDEBAR_W - 28)
  sideScroll:SetScrollChild(sideChild)
  f.sideChild = sideChild
  UI.sideChild = sideChild

  local contentH = BuildCategorySidebar(sideChild) or 400
  sideChild:SetHeight(math.max(contentH, 1))

  sideScroll:EnableMouseWheel(true)
  sideScroll:SetScript("OnMouseWheel", function(self, delta)
    local step = CAT_BTN_H + CAT_BTN_GAP
    local cur = self:GetVerticalScroll() or 0
    local maxScroll = self:GetVerticalScrollRange() or 0
    self:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - delta * step)))
  end)

  sideScroll:SetScript("OnSizeChanged", function(self)
    local child = self:GetScrollChild()
    if not child then
      return
    end
    local maxScroll = math.max(0, (child:GetHeight() or 0) - (self:GetHeight() or 0))
    if (self:GetVerticalScroll() or 0) > maxScroll then
      self:SetVerticalScroll(maxScroll)
    end
  end)

  -- Main pane
  local main = CreateFrame("Frame", nil, inset, "BackdropTemplate")
  main:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 10, 0)
  main:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -8, 8)
  main:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  main:SetBackdropColor(0.14, 0.11, 0.06, 0.95)
  main:SetBackdropBorderColor(0.50, 0.40, 0.22, 1)
  f.main = main

  -- Parchment field
  local parchment = Solid(main, "BACKGROUND", 0.62, 0.52, 0.34, 0.22)
  parchment:SetPoint("TOPLEFT", 4, -4)
  parchment:SetPoint("BOTTOMRIGHT", -4, 4)

  -- Category strip inside main
  local catBar = CreateFrame("Frame", nil, main)
  catBar:SetPoint("TOPLEFT", 12, -10)
  catBar:SetPoint("TOPRIGHT", -32, -10)
  catBar:SetHeight(26)

  local catLabel = catBar:CreateFontString(nil, "OVERLAY")
  SetFS(catLabel, 15)
  catLabel:SetPoint("LEFT", 2, 0)
  Color(catLabel, "gold")
  f.catLabel = catLabel

  local catCount = catBar:CreateFontString(nil, "OVERLAY")
  SetFS(catCount, 12)
  catCount:SetPoint("RIGHT", -2, 0)
  catCount:SetTextColor(0.75, 0.70, 0.55, 1)
  f.catCount = catCount

  local catRule = Solid(main, "ARTWORK", 0.55, 0.42, 0.18, 0.55)
  catRule:SetHeight(1)
  catRule:SetPoint("TOPLEFT", 12, -40)
  catRule:SetPoint("TOPRIGHT", -32, -40)
  f.catRule = catRule
  f.main = main

  -- Players-only search + status filter strip (shown under catBar)
  local playersToolbar = CreateFrame("Frame", nil, main)
  playersToolbar:SetPoint("TOPLEFT", 12, -46)
  playersToolbar:SetPoint("TOPRIGHT", -32, -46)
  playersToolbar:SetHeight(PLAYERS_TOOLBAR_H)
  playersToolbar:Hide()
  UI.playersToolbar = playersToolbar

  local searchBox = CreateFrame("EditBox", "LaucobsAchievementsPlayerSearch", playersToolbar, "InputBoxTemplate")
  searchBox:SetAutoFocus(false)
  searchBox:SetHeight(22)
  searchBox:SetPoint("TOPLEFT", 4, -2)
  searchBox:SetPoint("TOPRIGHT", -4, -2)
  searchBox:SetFont(FONT, 13, "")
  searchBox:SetTextColor(0.95, 0.90, 0.75, 1)
  searchBox:SetMaxLetters(40)
  playersToolbar.searchBox = searchBox

  local searchHint = playersToolbar:CreateFontString(nil, "OVERLAY")
  SetFS(searchHint, 12)
  searchHint:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
  searchHint:SetText("Search players…")
  searchHint:SetTextColor(0.55, 0.50, 0.40, 1)
  playersToolbar.searchHint = searchHint

  searchBox:SetScript("OnTextChanged", function(self, userInput)
    local text = self:GetText() or ""
    if text == "" and not self:HasFocus() then
      searchHint:Show()
    else
      searchHint:Hide()
    end
    if text == playerSearchText then
      return
    end
    playerSearchText = text
    if playersMode then
      PopulatePlayers()
    end
  end)
  searchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    if (self:GetText() or "") ~= "" then
      self:SetText("")
      playerSearchText = ""
      if playersMode then
        PopulatePlayers()
      end
    end
  end)
  searchBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  searchBox:SetScript("OnEditFocusGained", function()
    searchHint:Hide()
  end)
  searchBox:SetScript("OnEditFocusLost", function(self)
    if (self:GetText() or "") == "" then
      searchHint:Show()
    end
  end)

  local filterDefs = {
    { id = "all",     label = "All",      width = 48 },
    { id = "addon",   label = "Addon",    width = 58 },
    { id = "pending", label = "Pending",  width = 68 },
    { id = "noaddon", label = "No addon", width = 78 },
  }
  playersToolbar.filterButtons = {}
  local filterX = 4
  for _, def in ipairs(filterDefs) do
    local btn = CreateFrame("Button", nil, playersToolbar, "BackdropTemplate")
    btn:SetSize(def.width, 22)
    btn:SetPoint("TOPLEFT", filterX, -30)
    btn:SetBackdrop({
      bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0.12, 0.10, 0.06, 0.9)
    btn:SetBackdropBorderColor(unpack(C.borderDim))

    local flabel = btn:CreateFontString(nil, "OVERLAY")
    SetFS(flabel, 11)
    flabel:SetPoint("CENTER")
    flabel:SetText(def.label)
    flabel:SetTextColor(0.75, 0.70, 0.55, 1)
    btn.label = flabel
    btn.filterId = def.id

    btn:SetScript("OnClick", function(self)
      if playerStatusFilter == self.filterId then
        return
      end
      playerStatusFilter = self.filterId
      UpdatePlayerFilterButtons()
      if playersMode then
        PopulatePlayers()
      end
    end)

    playersToolbar.filterButtons[def.id] = btn
    filterX = filterX + def.width + 4
  end
  UpdatePlayerFilterButtons()

  -- Scroll area
  local scrollFrame = CreateFrame("ScrollFrame", "LaucobsAchievementsScrollFrame", main, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", 10, SCROLL_TOP_DEFAULT)
  scrollFrame:SetPoint("BOTTOMRIGHT", -32, 10)
  f.scrollFrame = scrollFrame
  UI.scrollFrame = scrollFrame

  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetSize(math.max(100, GetViewWidth()), 1)
  scrollFrame:SetScrollChild(scrollChild)
  UI.scrollChild = scrollChild

  -- Relayout when size changes (also fixes first-show zero-width)
  scrollFrame:SetScript("OnSizeChanged", function()
    if playersMode then
      PopulatePlayers()
    elseif selectedCategory then
      PopulateAchievements(selectedCategory)
    end
  end)

  f:SetScript("OnShow", function()
    if LA.Share and LA.Share.Announce then
      LA.Share:Announce()
    end
    UpdateHeaderContext()
    if playersMode then
      PopulatePlayers()
    elseif selectedCategory then
      -- Defer one frame so widths are valid after Show()
      f._pending = true
      f:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        self._pending = nil
        if playersMode then
          PopulatePlayers()
        elseif selectedCategory then
          PopulateAchievements(selectedCategory)
        end
      end)
    end
  end)

  -- Resize grip
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -8, 8)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function()
    f:StartSizing("BOTTOMRIGHT")
  end)
  grip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    if playersMode then
      PopulatePlayers()
    elseif selectedCategory then
      PopulateAchievements(selectedCategory)
    end
  end)

  self.frame = f
  CreateMinimapButton()

  if LA.Categories[1] then
    SelectCategory(LA.Categories[1].id)
  end

  tinsert(UISpecialFrames, "LaucobsAchievementsFrame")
end

function UI:Refresh()
  if not self.frame then
    return
  end
  UpdateHeaderContext()
  if not self.frame:IsShown() then
    return
  end
  if playersMode then
    PopulatePlayers()
  elseif selectedCategory then
    PopulateAchievements(selectedCategory)
  end
end

function UI:OnShareUpdate()
  if not self.frame or not self.frame:IsShown() then
    return
  end
  if playersMode then
    PopulatePlayers()
  elseif viewingPeer and selectedCategory then
    PopulateAchievements(selectedCategory)
  end
  UpdateHeaderContext()
end

function UI:ShowPeer(fullName)
  if not self.frame then
    self:Init()
  end
  -- Set compare target before Show() so OnShow / deferred layout use the right mode.
  if fullName then
    viewingPeer = fullName
    if LA.Share then
      LA.Share.viewing = fullName
    end
    playersMode = false
  end
  self.frame:Show()
  if fullName then
    ViewPeer(fullName)
  end
end

function UI:Toggle()
  if not self.frame then
    self:Init()
  end
  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self.frame:Show()
  end
end

function UI:Show()
  if not self.frame then
    self:Init()
  end
  self.frame:Show()
end

function UI:Hide()
  if self.frame then
    self.frame:Hide()
  end
end
