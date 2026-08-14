--[[
  Classic Glory - UI
  Retail-inspired achievement panel for Classic Era / Hardcore.
  Uses only Classic-safe APIs and textures.
]]

local addonName, LA = ...

local UI = {}
LA.UI = UI

-- Layout constants
local PANEL_W, PANEL_H = 900, 640
local PANEL_MIN_W, PANEL_MIN_H = 720, 500
local PANEL_MAX_W, PANEL_MAX_H = 1100, 860
local MINIMAP_DEFAULT_ANGLE = 220
local SIDEBAR_W = 190
local HEADER_H = 58
local CARD_H = 108
local CARD_GAP = 12
local ICON_SIZE = 62
local CARD_PAD = 18
local CAT_BTN_H = 36
local CAT_BTN_GAP = 8
local SUMMARY_ID = "__summary"
local LIST_TOOLBAR_H = 58
local SUM_CAT_H = 22
local SUM_MINI_H = 36

local FONT = "Fonts\\FRIZQT__.TTF"

local selectedCategory
local categoryButtons = {}
local cardPool = {}
local peerCardPool = {}
local peerHeaderPool = {}
local summaryCatPool = {}
local summaryHeaderPool = {}
local summaryMiniPool = {}
local viewingPeer -- fullName when inspecting another player; nil = self
local playersMode = false -- true when sidebar "Players" list is shown
local summaryMode = false
local playersBtn
local summaryBtn
local youBtn
local playerSearchText = ""
local playerStatusFilter = "addon" -- all | addon | noaddon
local achievementSearchText = ""
local SCROLL_TOP_DEFAULT = -50
local SCROLL_TOP_TOOLBAR = -(50 + LIST_TOOLBAR_H)

local PopulateSummary, RelayoutMain

local SORT_CYCLE = { "default", "recent", "points", "name" }
local SORT_LABELS = {
  default = "Default",
  recent = "Recent",
  points = "Points",
  name = "A-Z",
}
local VALID_FILTER = {
  all = true,
  earned = true,
  incomplete = true,
  almost = true,
  shared = true,
  them = true,
  you = true,
}
local VALID_SORT = {
  default = true,
  recent = true,
  points = true,
  name = true,
}
local ACH_FILTER_DEFS = {
  { id = "all",        label = "All",        width = 48, when = "both" },
  { id = "earned",     label = "Earned",     width = 58, when = "both" },
  { id = "incomplete", label = "Incomplete", width = 82, when = "both" },
  { id = "almost",     label = "Almost",     width = 62, when = "self" },
  { id = "shared",     label = "Shared",     width = 58, when = "peer" },
  { id = "them",       label = "Them",       width = 50, when = "peer" },
  { id = "you",        label = "You",        width = 44, when = "peer" },
}
local CRIT_LABELS = {
  LEVEL = "Level",
  DEATHLESS = "Deathless",
  MONEY = "Gold looted",
  HEALTH = "Survive",
  KILLS = "Kills",
  QUESTS = "Quests",
  ZONE = "Visit",
  ZONES = "Zones",
  DEATHS = "Deaths",
  CLASS = "Class",
  RACE = "Race",
  FACTION = "Faction",
  DUELS = "Duels",
  LOOT = "Loot",
  CRITS = "Crits",
  EMOTES = "Emotes",
  INSTANCE = "Instance",
  REP = "Reputation",
  SKILL = "Skill",
  META = "Achievements",
  LOGIN = "Login",
}

local PLAYER_SECTIONS = {
  { id = "group",   title = "Group / Raid" },
  { id = "guild",   title = "Guild" },
  { id = "inspect", title = "Inspected" },
  { id = "other",   title = "Other" },
}

local CHIP_BACKDROP = {
  bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 8, edgeSize = 10,
  insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local function IsDefVisible(def)
  if not def then
    return false
  end
  if def.hcOnly and not (LA.IsHardcoreActive and LA:IsHardcoreActive()) then
    return false
  end
  return true
end

local function GetUIPrefs()
  local db = LA.db or ClassicGloryDB
  if type(db) ~= "table" then
    return { achFilter = "all", achSort = "default" }
  end
  if type(db.ui) ~= "table" then
    db.ui = {}
  end
  if not VALID_FILTER[db.ui.achFilter] then
    db.ui.achFilter = "all"
  end
  if not VALID_SORT[db.ui.achSort] then
    db.ui.achSort = "default"
  end
  return db.ui
end

local function Clamp(n, lo, hi)
  if n < lo then
    return lo
  end
  if n > hi then
    return hi
  end
  return n
end

local function Round(n)
  if n >= 0 then
    return math.floor(n + 0.5)
  end
  return math.ceil(n - 0.5)
end

local function IsFiniteNumber(n)
  return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function SaveFrameLayout(frame)
  if not frame then
    return
  end
  local db = LA.db or ClassicGloryDB
  if type(db) ~= "table" then
    return
  end
  local ui = GetUIPrefs()
  ui.frameW = Round(Clamp(frame:GetWidth() or PANEL_W, PANEL_MIN_W, PANEL_MAX_W))
  ui.frameH = Round(Clamp(frame:GetHeight() or PANEL_H, PANEL_MIN_H, PANEL_MAX_H))
  local left, top = frame:GetLeft(), frame:GetTop()
  if IsFiniteNumber(left) and IsFiniteNumber(top) then
    ui.frameLeft = Round(left * 10) / 10
    ui.frameTop = Round(top * 10) / 10
  end
end

local function RestoreFrameLayout(frame)
  if not frame then
    return
  end
  local db = LA.db or ClassicGloryDB
  if type(db) ~= "table" then
    return
  end
  local ui = GetUIPrefs()
  local w, h = ui.frameW, ui.frameH
  if IsFiniteNumber(w) and IsFiniteNumber(h) then
    frame:SetSize(Clamp(w, PANEL_MIN_W, PANEL_MAX_W), Clamp(h, PANEL_MIN_H, PANEL_MAX_H))
  end
  local left, top = ui.frameLeft, ui.frameTop
  if IsFiniteNumber(left) and IsFiniteNumber(top) then
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
  end
end

local function NormalizeAchFilter()
  local ui = GetUIPrefs()
  local f = ui.achFilter
  if viewingPeer then
    if f == "almost" then
      ui.achFilter = "all"
    end
  else
    if f == "shared" or f == "them" or f == "you" then
      ui.achFilter = "all"
    end
  end
  return ui.achFilter
end

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

local function CollectVisibleDefs(categoryId)
  local list = {}
  if categoryId then
    for _, def in ipairs(LA:GetAchievementsByCategory(categoryId)) do
      if IsDefVisible(def) then
        list[#list + 1] = def
      end
    end
  else
    for _, def in pairs(LA.Achievements or {}) do
      if IsDefVisible(def) then
        list[#list + 1] = def
      end
    end
    table.sort(list, function(a, b)
      return a.id < b.id
    end)
  end
  return list
end

local function CountCategoryProgress(categoryId)
  local earned, total = 0, 0
  for _, def in ipairs(CollectVisibleDefs(categoryId)) do
    total = total + 1
    if IsShownComplete(def.id) then
      earned = earned + 1
    end
  end
  return earned, total
end

local function GetCompareCounts(categoryId)
  local list = CollectVisibleDefs(categoryId)
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

local function SetBarColor(bar, pct)
  if pct >= 1 then
    bar:SetStatusBarColor(0.25, 0.80, 0.25)
  elseif pct >= 0.5 then
    bar:SetStatusBarColor(0.85, 0.70, 0.15)
  else
    bar:SetStatusBarColor(0.55, 0.45, 0.15)
  end
end

local function AchievementMatchesSearch(def, query)
  if not query or query == "" then
    return true
  end
  local q = strlower(query)
  local title = strlower(def.title or "")
  local desc = strlower(def.description or "")
  return title:find(q, 1, true) or desc:find(q, 1, true)
end

local function AchievementMatchesFilter(def, filter)
  if not filter or filter == "all" then
    return true
  end
  local complete = IsShownComplete(def.id)
  if filter == "earned" then
    return complete
  elseif filter == "incomplete" then
    return not complete
  elseif filter == "almost" then
    if complete then
      return false
    end
    local current = GetShownProgress(def.id)
    return current > 0
  elseif filter == "shared" then
    return viewingPeer and complete and LA:IsComplete(def.id)
  elseif filter == "them" then
    return viewingPeer and complete and not LA:IsComplete(def.id)
  elseif filter == "you" then
    return viewingPeer and (not complete) and LA:IsComplete(def.id)
  end
  return true
end

local function SortAchievements(list, mode)
  local sortMode = mode
  if viewingPeer and sortMode == "recent" then
    sortMode = "default"
  end
  table.sort(list, function(a, b)
    if sortMode == "recent" then
      local ca = IsShownComplete(a.id)
      local cb = IsShownComplete(b.id)
      if ca ~= cb then
        return ca
      end
      local da = GetShownEarnedDate(a.id) or 0
      local db_ = GetShownEarnedDate(b.id) or 0
      if da ~= db_ then
        return da > db_
      end
      return a.id < b.id
    elseif sortMode == "points" then
      local pa = a.points or 0
      local pb = b.points or 0
      if pa ~= pb then
        return pa > pb
      end
      return a.id < b.id
    elseif sortMode == "name" then
      local ta = strlower(a.title or "")
      local tb = strlower(b.title or "")
      if ta ~= tb then
        return ta < tb
      end
      return a.id < b.id
    end
    return a.id < b.id
  end)
end

local function ApplyChipVisual(btn, active)
  if not btn then
    return
  end
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

local function MakeChipButton(parent, def)
  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetSize(def.width, 22)
  btn:SetBackdrop({
    bgFile   = CHIP_BACKDROP.bgFile,
    edgeFile = CHIP_BACKDROP.edgeFile,
    tile = CHIP_BACKDROP.tile,
    tileSize = CHIP_BACKDROP.tileSize,
    edgeSize = CHIP_BACKDROP.edgeSize,
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
  return btn
end

local function CritTooltipLine(def, crit, index)
  local target = crit.value or 1
  local prog
  if viewingPeer then
    prog = IsShownComplete(def.id) and target or 0
  else
    prog = LA:GetProgress(def.id, index) or 0
  end
  if prog > target then
    prog = target
  end
  local label = CRIT_LABELS[crit.type] or crit.type or "Progress"
  if crit.match and crit.match ~= "" then
    label = label .. " (" .. crit.match .. ")"
  elseif crit.standing and crit.standing ~= "" then
    label = label .. " (" .. crit.standing .. ")"
  end
  return label, FormatProgress(prog, target), prog >= target
end

local function ShowAchievementTooltip(card)
  local def = card and card.def
  if not def then
    return
  end
  GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
  GameTooltip:AddLine(def.title or "", 1, 0.82, 0)
  if def.description and def.description ~= "" then
    GameTooltip:AddLine(def.description, 0.90, 0.85, 0.70, true)
  end
  local pts = def.points or 0
  if pts > 0 then
    GameTooltip:AddLine(pts .. " points", 0.90, 0.75, 0.20)
  else
    GameTooltip:AddLine("Feat of Strength", 0.90, 0.75, 0.20)
  end
  local earned = GetShownEarnedDate(def.id)
  if earned then
    GameTooltip:AddLine("Earned " .. FormatDate(earned), 0.25, 0.75, 0.25)
  end
  if def.criteria and #def.criteria > 0 then
    GameTooltip:AddLine(" ")
    for i, crit in ipairs(def.criteria) do
      local label, value, done = CritTooltipLine(def, crit, i)
      if done then
        GameTooltip:AddDoubleLine(label, value, 0.85, 0.80, 0.65, 0.25, 0.80, 0.25)
      else
        GameTooltip:AddDoubleLine(label, value, 0.85, 0.80, 0.65, 0.70, 0.65, 0.50)
      end
    end
  end
  GameTooltip:Show()
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
    ShowAchievementTooltip(self)
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
    GameTooltip:Hide()
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

local function ReleaseSummaryCatFrom(startIndex)
  for i = startIndex, #summaryCatPool do
    summaryCatPool[i]:Hide()
  end
end

local function ReleaseSummaryHeadersFrom(startIndex)
  for i = startIndex, #summaryHeaderPool do
    summaryHeaderPool[i]:Hide()
  end
end

local function ReleaseSummaryMinisFrom(startIndex)
  for i = startIndex, #summaryMiniPool do
    summaryMiniPool[i]:Hide()
    summaryMiniPool[i].def = nil
  end
end

local function HideSummaryWidgets()
  if UI.summaryOverall then
    UI.summaryOverall:Hide()
  end
  ReleaseSummaryCatFrom(1)
  ReleaseSummaryHeadersFrom(1)
  ReleaseSummaryMinisFrom(1)
end

local function HideEmptyState()
  if UI.emptyLabel then
    UI.emptyLabel:Hide()
  end
end

local function ShowEmptyState(parent, text)
  local fs = UI.emptyLabel
  if not fs then
    fs = parent:CreateFontString(nil, "OVERLAY")
    SetFS(fs, 13)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(0.70, 0.64, 0.50, 1)
    UI.emptyLabel = fs
  end
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -12)
  fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -12)
  fs:SetText(text or "No achievements match.")
  fs:Show()
end

local function UpdateAchSortButton()
  local bar = UI.achToolbar
  if not bar or not bar.sortBtn then
    return
  end
  local ui = GetUIPrefs()
  local mode = ui.achSort or "default"
  bar.sortBtn.label:SetText("Sort: " .. (SORT_LABELS[mode] or "Default"))
  ApplyChipVisual(bar.sortBtn, true)
end

local function UpdateAchFilterButtons()
  local bar = UI.achToolbar
  if not bar or not bar.filterButtons then
    return
  end
  local filter = NormalizeAchFilter()
  local x = 4
  for _, def in ipairs(ACH_FILTER_DEFS) do
    local btn = bar.filterButtons[def.id]
    if btn then
      local show = def.when == "both"
        or (def.when == "self" and not viewingPeer)
        or (def.when == "peer" and viewingPeer)
      if show then
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", x, -30)
        btn:Show()
        ApplyChipVisual(btn, def.id == filter)
        x = x + def.width + 4
      else
        btn:Hide()
      end
    end
  end
  UpdateAchSortButton()
end

local function UpdateCategoryCounts()
  for _, cat in ipairs(LA.Categories or {}) do
    local btn = categoryButtons[cat.id]
    if btn and btn.count then
      local earned, total = CountCategoryProgress(cat.id)
      if total > 0 then
        btn.count:SetText(earned .. "/" .. total)
        btn.count:Show()
      else
        btn.count:SetText("")
        btn.count:Hide()
      end
    end
  end
end

local function SetListToolbar(which)
  local playersBar = UI.playersToolbar
  local achBar = UI.achToolbar
  if playersBar then
    if which == "players" then
      playersBar:Show()
    else
      playersBar:Hide()
    end
  end
  if achBar then
    if which == "ach" then
      achBar:Show()
      UpdateAchFilterButtons()
      if achBar.searchHint and achBar.searchBox then
        local text = achBar.searchBox:GetText() or ""
        if text == "" and not achBar.searchBox:HasFocus() then
          achBar.searchHint:Show()
        else
          achBar.searchHint:Hide()
        end
      end
    else
      achBar:Hide()
    end
  end
  local scrollFrame = UI.scrollFrame
  if scrollFrame then
    local top = (which == "players" or which == "ach") and SCROLL_TOP_TOOLBAR or SCROLL_TOP_DEFAULT
    if UI._scrollTop ~= top then
      UI._scrollTop = top
      scrollFrame:ClearAllPoints()
      scrollFrame:SetPoint("TOPLEFT", 10, top)
      scrollFrame:SetPoint("BOTTOMRIGHT", -32, 10)
    end
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
  if categoryId == SUMMARY_ID then
    if PopulateSummary then
      PopulateSummary()
    end
    return
  end

  HidePeerCards()
  HideSummaryWidgets()
  playersMode = false
  summaryMode = false
  SetListToolbar("ach")
  HideEmptyState()

  local viewW = GetViewWidth()
  scrollChild:SetWidth(viewW)

  local query = achievementSearchText or ""
  local searching = query ~= ""
  local ui = GetUIPrefs()
  local filter = NormalizeAchFilter()
  local sortMode = ui.achSort or "default"

  local source = CollectVisibleDefs(searching and nil or categoryId)
  local unfilteredTotal = #source
  local unfilteredEarned = 0
  for _, def in ipairs(source) do
    if IsShownComplete(def.id) then
      unfilteredEarned = unfilteredEarned + 1
    end
  end

  local list = {}
  for _, def in ipairs(source) do
    if AchievementMatchesSearch(def, query) and AchievementMatchesFilter(def, filter) then
      list[#list + 1] = def
    end
  end
  SortAchievements(list, sortMode)

  local y = -4
  local textW
  local filtered = searching or (filter ~= "all")

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
        SetBarColor(card.bar, pct)
      else
        card.barBg:Hide()
      end
    end

    card:Show()
    y = y - (CARD_H + CARD_GAP)
  end

  ReleaseCardsFrom(#list + 1)

  if #list == 0 then
    ShowEmptyState(scrollChild, "No achievements match.")
    y = y - 28
  end

  local contentH = math.max(scrollFrame:GetHeight() or 400, (-y) + 12)
  scrollChild:SetHeight(contentH)
  scrollFrame:SetVerticalScroll(0)

  -- Header summary
  if UI.frame and UI.frame.catLabel then
    if searching then
      UI.frame.catLabel:SetText("Search results")
      UI.frame.catCount:SetText(#list .. " shown")
    else
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
        local compareText = "|cff8cd463Them " .. them .. "/" .. total .. "|r"
          .. "   ·   "
          .. "|cff73c8faYou " .. you .. "/" .. total .. "|r"
          .. "   ·   "
          .. "|cffe8c652Shared " .. both .. "|r"
        if filtered then
          UI.frame.catCount:SetText(#list .. " shown · " .. compareText)
        else
          UI.frame.catCount:SetText(compareText)
        end
      else
        local earnedText = unfilteredEarned .. " / " .. unfilteredTotal .. " earned"
        if filtered then
          UI.frame.catCount:SetText(#list .. " shown · " .. earnedText)
        else
          UI.frame.catCount:SetText(earnedText)
        end
      end
    end
  end

  UpdateHeaderContext()
  UpdateCategoryCounts()
end

---------------------------------------------------------------------------
-- Category sidebar
---------------------------------------------------------------------------

local function SetSidebarButtonSelected(btn, active)
  if not btn then
    return
  end
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

local function SelectCategory(categoryId)
  selectedCategory = categoryId
  playersMode = false
  summaryMode = (categoryId == SUMMARY_ID)
  for id, btn in pairs(categoryButtons) do
    SetSidebarButtonSelected(btn, id == categoryId)
  end
  SetSidebarButtonSelected(playersBtn, false)
  SetSidebarButtonSelected(summaryBtn, categoryId == SUMMARY_ID)
  if RelayoutMain then
    RelayoutMain()
  elseif summaryMode then
    PopulateSummary()
  else
    PopulateAchievements(categoryId)
  end
end

local function SetPlayersSidebarSelected(active)
  SetSidebarButtonSelected(playersBtn, active)
  if active then
    for _, btn in pairs(categoryButtons) do
      SetSidebarButtonSelected(btn, false)
    end
    SetSidebarButtonSelected(summaryBtn, false)
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
    ApplyChipVisual(btn, active)
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
  SetPlayersSidebarSelected(false)
  NormalizeAchFilter()
  -- Keep current sidebar pick (Summary or a category) through the peer lens
  local catId = selectedCategory or SUMMARY_ID
  selectedCategory = catId
  for id, btn in pairs(categoryButtons) do
    SetSidebarButtonSelected(btn, id == catId)
  end
  SetSidebarButtonSelected(summaryBtn, catId == SUMMARY_ID)
  if RelayoutMain then
    RelayoutMain()
  elseif catId == SUMMARY_ID then
    PopulateSummary()
  else
    PopulateAchievements(catId)
  end
  UpdateHeaderContext()
end

local function InspectCurrentTarget()
  if not LA.Share or not LA.Share.InspectTargetOrName then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Classic Glory|r: sharing unavailable.")
    return
  end
  local ok, result = LA.Share:InspectTargetOrName()
  if not ok then
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cffffd100Classic Glory|r: " .. (result or "Target a player first.")
    )
    return
  end
  ViewPeer(result)
end

local function PopulatePlayers()
  local scrollChild = UI.scrollChild
  local scrollFrame = UI.scrollFrame
  if not scrollChild or not scrollFrame then
    return
  end

  HideAchievementCards()
  HideSummaryWidgets()
  HideEmptyState()
  playersMode = true
  summaryMode = false
  SetPlayersSidebarSelected(true)
  SetListToolbar("players")
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
      local verNote = (type(peer.version) == "string" and peer.version ~= "")
        and ("  ·  v" .. peer.version)
        or ""
      card.detail:SetText(
        (peer.points or 0) .. " points  ·  " .. (peer.count or 0) .. " earned" .. verNote .. syncNote
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
    card.detail:SetText("Guild, party, and raid members with the addon appear here. Target a player and use Inspect current target.")
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
    card.detail:SetText("Try All or No addon, or inspect your current target.")
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
  NormalizeAchFilter()
  UpdateHeaderContext()
  if RelayoutMain then
    RelayoutMain()
  elseif playersMode then
    PopulatePlayers()
  elseif selectedCategory == SUMMARY_ID then
    PopulateSummary()
  elseif selectedCategory then
    PopulateAchievements(selectedCategory)
  end
end

local function AcquireSummaryHeader(parent, index)
  if summaryHeaderPool[index] then
    return summaryHeaderPool[index]
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
  summaryHeaderPool[index] = row
  return row
end

local function AcquireSummaryCatRow(parent, index)
  if summaryCatPool[index] then
    return summaryCatPool[index]
  end
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(SUM_CAT_H)
  row:EnableMouse(true)
  row:RegisterForClicks("LeftButtonUp")

  local name = row:CreateFontString(nil, "OVERLAY")
  SetFS(name, 12)
  name:SetPoint("LEFT", 4, 0)
  name:SetJustifyH("LEFT")
  name:SetWordWrap(false)
  name:SetTextColor(0.90, 0.84, 0.68, 1)
  row.name = name

  local count = row:CreateFontString(nil, "OVERLAY")
  SetFS(count, 11)
  count:SetPoint("RIGHT", -4, 0)
  count:SetJustifyH("RIGHT")
  count:SetTextColor(0.75, 0.70, 0.55, 1)
  row.count = count

  local barBg = CreateFrame("Frame", nil, row, "BackdropTemplate")
  barBg:SetHeight(8)
  barBg:SetPoint("LEFT", 150, 0)
  barBg:SetPoint("RIGHT", count, "LEFT", -8, 0)
  barBg:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  barBg:SetBackdropColor(0.05, 0.05, 0.04, 0.95)
  barBg:SetBackdropBorderColor(0.45, 0.38, 0.22, 1)
  row.barBg = barBg

  local bar = CreateFrame("StatusBar", nil, barBg)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("BOTTOMRIGHT", -1, 1)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(0.20, 0.70, 0.20)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  row.bar = bar

  row:SetScript("OnEnter", function(self)
    self.name:SetTextColor(1, 0.92, 0.65, 1)
  end)
  row:SetScript("OnLeave", function(self)
    self.name:SetTextColor(0.90, 0.84, 0.68, 1)
  end)

  summaryCatPool[index] = row
  return row
end

local function AcquireSummaryMini(parent, index)
  if summaryMiniPool[index] then
    return summaryMiniPool[index]
  end
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(SUM_MINI_H)
  row:EnableMouse(true)
  row:RegisterForClicks("LeftButtonUp")

  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(28, 28)
  icon:SetPoint("LEFT", 4, 0)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  row.icon = icon

  local title = row:CreateFontString(nil, "OVERLAY")
  SetFS(title, 13)
  title:SetPoint("LEFT", icon, "RIGHT", 10, 4)
  title:SetPoint("RIGHT", -80, 4)
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  Color(title, "gold")
  row.title = title

  local detail = row:CreateFontString(nil, "OVERLAY")
  SetFS(detail, 11)
  detail:SetPoint("RIGHT", -4, 0)
  detail:SetJustifyH("RIGHT")
  detail:SetTextColor(0.75, 0.70, 0.55, 1)
  row.detail = detail

  row:SetScript("OnEnter", function(self)
    self.title:SetTextColor(1, 0.92, 0.65, 1)
    if self.def then
      ShowAchievementTooltip(self)
    end
  end)
  row:SetScript("OnLeave", function(self)
    Color(self.title, "gold")
    GameTooltip:Hide()
  end)
  row:SetScript("OnClick", function(self)
    if self.def and self.def.category then
      SelectCategory(self.def.category)
    end
  end)

  summaryMiniPool[index] = row
  return row
end

local function EnsureSummaryOverall(parent)
  local frame = UI.summaryOverall
  if frame then
    return frame
  end
  frame = CreateFrame("Frame", nil, parent)
  frame:SetHeight(52)

  local stats = frame:CreateFontString(nil, "OVERLAY")
  SetFS(stats, 14)
  stats:SetPoint("TOPLEFT", 4, -4)
  stats:SetPoint("TOPRIGHT", -4, -4)
  stats:SetJustifyH("LEFT")
  Color(stats, "cream")
  frame.stats = stats

  local barBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  barBg:SetHeight(14)
  barBg:SetPoint("BOTTOMLEFT", 4, 6)
  barBg:SetPoint("BOTTOMRIGHT", -4, 6)
  barBg:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  barBg:SetBackdropColor(0.05, 0.05, 0.04, 0.95)
  barBg:SetBackdropBorderColor(0.45, 0.38, 0.22, 1)
  frame.barBg = barBg

  local bar = CreateFrame("StatusBar", nil, barBg)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetPoint("BOTTOMRIGHT", -1, 1)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(0.20, 0.70, 0.20)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  frame.bar = bar

  local barText = bar:CreateFontString(nil, "OVERLAY")
  SetFS(barText, 10, "OUTLINE")
  barText:SetPoint("CENTER", 0, 0)
  barText:SetTextColor(1, 1, 1, 1)
  frame.barText = barText

  UI.summaryOverall = frame
  return frame
end

PopulateSummary = function()
  local scrollChild = UI.scrollChild
  local scrollFrame = UI.scrollFrame
  if not scrollChild or not scrollFrame then
    return
  end

  HideAchievementCards()
  HidePeerCards()
  HideEmptyState()
  playersMode = false
  summaryMode = true
  SetListToolbar("none")

  local viewW = GetViewWidth()
  scrollChild:SetWidth(viewW)
  local innerW = viewW - 10
  local y = -4
  local headerIndex = 0
  local catIndex = 0
  local miniIndex = 0

  local function placeHeader(text)
    headerIndex = headerIndex + 1
    local header = AcquireSummaryHeader(scrollChild, headerIndex)
    header:ClearAllPoints()
    header:SetWidth(innerW)
    header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)
    header.label:SetText(text)
    header:Show()
    y = y - 24
  end

  local overall = EnsureSummaryOverall(scrollChild)
  overall:ClearAllPoints()
  overall:SetWidth(innerW)
  overall:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)
  if viewingPeer then
    local them, you, both, total = GetCompareCounts(nil)
    overall.stats:SetText(
      "|cff8cd463Them " .. them .. "|r  ·  |cff73c8faYou " .. you .. "|r  ·  |cffe8c652Shared " .. both .. "|r"
    )
    overall.bar:SetMinMaxValues(0, math.max(total, 1))
    overall.bar:SetValue(both)
    overall.barText:SetText(both .. " / " .. total)
    local pct = total > 0 and (both / total) or 0
    SetBarColor(overall.bar, pct)
  else
    local earned, total = CountCategoryProgress(nil)
    local pts = LA:GetEarnedPoints() or 0
    overall.stats:SetText(pts .. " points   ·   " .. earned .. " / " .. total .. " earned")
    overall.bar:SetMinMaxValues(0, math.max(total, 1))
    overall.bar:SetValue(earned)
    overall.barText:SetText(earned .. " / " .. total)
    local pct = total > 0 and (earned / total) or 0
    SetBarColor(overall.bar, pct)
  end
  overall:Show()
  y = y - 60

  placeHeader("Categories")
  local sorted = {}
  for _, cat in ipairs(LA.Categories or {}) do
    sorted[#sorted + 1] = cat
  end
  table.sort(sorted, function(a, b)
    return a.order < b.order
  end)
  for _, cat in ipairs(sorted) do
    local earned, total = CountCategoryProgress(cat.id)
    if total > 0 then
      catIndex = catIndex + 1
      local row = AcquireSummaryCatRow(scrollChild, catIndex)
      row:ClearAllPoints()
      row:SetWidth(innerW)
      row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)
      row.name:SetText(cat.name)
      row.catId = cat.id
      row:SetScript("OnClick", function(self)
        if self.catId then
          SelectCategory(self.catId)
        end
      end)
      if viewingPeer then
        local them, you = GetCompareCounts(cat.id)
        row.barBg:Hide()
        row.count:SetText("|cff8cd463" .. them .. "|r / |cff73c8fa" .. you .. "|r")
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", 4, 0)
        row.name:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
      else
        row.barBg:Show()
        row.bar:SetMinMaxValues(0, math.max(total, 1))
        row.bar:SetValue(earned)
        SetBarColor(row.bar, total > 0 and (earned / total) or 0)
        row.count:SetText(earned .. "/" .. total)
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", 4, 0)
        row.name:SetPoint("RIGHT", row.barBg, "LEFT", -8, 0)
      end
      row:Show()
      y = y - (SUM_CAT_H + 4)
    end
  end
  y = y - 8

  if not viewingPeer then
    local recent = {}
    for _, def in ipairs(CollectVisibleDefs(nil)) do
      if LA:IsComplete(def.id) then
        local earnedOn = LA:GetEarnedDate(def.id)
        if earnedOn then
          recent[#recent + 1] = { def = def, earnedOn = earnedOn }
        end
      end
    end
    table.sort(recent, function(a, b)
      if a.earnedOn ~= b.earnedOn then
        return a.earnedOn > b.earnedOn
      end
      return a.def.id < b.def.id
    end)
    if #recent > 0 then
      placeHeader("Recently earned")
      local n = math.min(3, #recent)
      for i = 1, n do
        miniIndex = miniIndex + 1
        local row = AcquireSummaryMini(scrollChild, miniIndex)
        local def = recent[i].def
        row.def = def
        row:ClearAllPoints()
        row:SetWidth(innerW)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)
        row.icon:SetTexture(def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon:SetDesaturated(false)
        row.title:SetText(def.title or "")
        Color(row.title, "gold")
        row.detail:SetText(FormatDate(recent[i].earnedOn))
        row:Show()
        y = y - (SUM_MINI_H + 4)
      end
      y = y - 8
    end

    local almost = {}
    for _, def in ipairs(CollectVisibleDefs(nil)) do
      if not LA:IsComplete(def.id) then
        local current, required = LA:GetAchievementProgress(def.id)
        if current > 0 and required > 0 then
          almost[#almost + 1] = {
            def = def,
            ratio = current / required,
            current = current,
            required = required,
          }
        end
      end
    end
    table.sort(almost, function(a, b)
      if a.ratio ~= b.ratio then
        return a.ratio > b.ratio
      end
      return a.def.id < b.def.id
    end)
    if #almost > 0 then
      placeHeader("Almost there")
      local n = math.min(3, #almost)
      for i = 1, n do
        miniIndex = miniIndex + 1
        local row = AcquireSummaryMini(scrollChild, miniIndex)
        local item = almost[i]
        row.def = item.def
        row:ClearAllPoints()
        row:SetWidth(innerW)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, y)
        row.icon:SetTexture(item.def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.icon:SetDesaturated(true)
        row.title:SetText(item.def.title or "")
        Color(row.title, "gold")
        row.detail:SetText(FormatProgress(item.current, item.required))
        row:Show()
        y = y - (SUM_MINI_H + 4)
      end
    end
  end

  ReleaseSummaryCatFrom(catIndex + 1)
  ReleaseSummaryHeadersFrom(headerIndex + 1)
  ReleaseSummaryMinisFrom(miniIndex + 1)

  local contentH = math.max(scrollFrame:GetHeight() or 400, (-y) + 12)
  scrollChild:SetHeight(contentH)
  scrollFrame:SetVerticalScroll(0)

  if UI.frame and UI.frame.catLabel then
    UI.frame.catLabel:SetText("Summary")
    if viewingPeer then
      local them, you, both, total = GetCompareCounts(nil)
      UI.frame.catCount:SetText(
        "|cff8cd463Them " .. them .. "/" .. total .. "|r"
          .. "   ·   "
          .. "|cff73c8faYou " .. you .. "/" .. total .. "|r"
          .. "   ·   "
          .. "|cffe8c652Shared " .. both .. "|r"
      )
    else
      local earned, total = CountCategoryProgress(nil)
      UI.frame.catCount:SetText(earned .. " / " .. total .. " earned")
    end
  end
  UpdateHeaderContext()
  UpdateCategoryCounts()
end

RelayoutMain = function()
  if UI._layingOut then
    UI._needsRelayout = true
    return
  end
  UI._layingOut = true
  UI._needsRelayout = true
  while UI._needsRelayout do
    UI._needsRelayout = false
    if playersMode then
      PopulatePlayers()
    elseif selectedCategory == SUMMARY_ID then
      PopulateSummary()
    elseif selectedCategory then
      PopulateAchievements(selectedCategory)
    end
  end
  UI._layingOut = false
end

local function MakeSidebarButton(parent, btnW, y, title, withCount)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(btnW, CAT_BTN_H)
  btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)

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
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  label:SetText(title)
  label:SetTextColor(0.82, 0.76, 0.60, 1)
  btn.label = label

  if withCount then
    local count = btn:CreateFontString(nil, "OVERLAY")
    SetFS(count, 11)
    count:SetPoint("RIGHT", -8, 0)
    count:SetJustifyH("RIGHT")
    count:SetTextColor(0.55, 0.50, 0.38, 1)
    btn.count = count
    label:SetPoint("RIGHT", count, "LEFT", -4, 0)
  else
    label:SetPoint("RIGHT", -8, 0)
  end

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

  return btn
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

  summaryBtn = MakeSidebarButton(parent, btnW, y, "Summary", false)
  summaryBtn:SetScript("OnClick", function()
    SelectCategory(SUMMARY_ID)
  end)
  y = y - (CAT_BTN_H + CAT_BTN_GAP)

  for _, cat in ipairs(sorted) do
    local btn = MakeSidebarButton(parent, btnW, y, cat.name, true)
    btn:SetScript("OnClick", function()
      SelectCategory(cat.id)
    end)
    categoryButtons[cat.id] = btn
    y = y - (CAT_BTN_H + CAT_BTN_GAP)
  end

  y = y - 8
  local rule = Solid(parent, "ARTWORK", 0.55, 0.42, 0.18, 0.55)
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", 10, y + 4)
  rule:SetPoint("TOPRIGHT", -6, y + 4)

  playersBtn = MakeSidebarButton(parent, btnW, y - 8, "Players", false)
  playersBtn:SetScript("OnClick", function()
    PopulatePlayers()
  end)

  return (-(y - 8 - CAT_BTN_H)) + 16
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------

local function CreateMinimapButton()
  local btn = CreateFrame("Button", "ClassicGloryMinimapButton", Minimap)
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

  local savedAngle = GetUIPrefs().minimapAngle
  local angle = IsFiniteNumber(savedAngle) and savedAngle or MINIMAP_DEFAULT_ANGLE
  local function UpdatePosition()
    local radius = (Minimap:GetWidth() / 2) + 5
    local rad = math.rad(angle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
  end
  UpdatePosition()

  local function SaveMinimapAngle()
    local db = LA.db or ClassicGloryDB
    if type(db) ~= "table" or not IsFiniteNumber(angle) then
      return
    end
    GetUIPrefs().minimapAngle = Round(angle * 10) / 10
  end

  btn:RegisterForDrag("LeftButton")
  btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      cx, cy = cx / scale, cy / scale
      angle = math.deg(math.atan2(cy - my, cx - mx))
      btn.angle = angle
      UpdatePosition()
    end)
  end)
  btn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    SaveMinimapAngle()
  end)

  btn.angle = angle
  btn.UpdatePosition = UpdatePosition
  if not UI._minimapSizeHooked then
    UI._minimapSizeHooked = true
    Minimap:HookScript("OnSizeChanged", function()
      local b = UI.minimapButton
      if b and b.UpdatePosition then
        b.UpdatePosition()
      end
    end)
  end

  btn:SetScript("OnClick", function()
    UI:Toggle()
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(LA.displayName or "Classic Glory", 1, 0.82, 0)
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

  local f = CreateFrame("Frame", "ClassicGloryFrame", UIParent, "BackdropTemplate")
  f:SetSize(PANEL_W, PANEL_H)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:SetResizable(true)
  if f.SetResizeBounds then
    f:SetResizeBounds(PANEL_MIN_W, PANEL_MIN_H, PANEL_MAX_W, PANEL_MAX_H)
  else
    f:SetMinResize(PANEL_MIN_W, PANEL_MIN_H)
    f:SetMaxResize(PANEL_MAX_W, PANEL_MAX_H)
  end
  f:SetClampedToScreen(true)
  f:SetFrameStrata("HIGH")
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveFrameLayout(self)
  end)
  RestoreFrameLayout(f)
  f:Hide()
  f:SetScript("OnHide", function(self)
    self:StopMovingOrSizing()
    SaveFrameLayout(self)
  end)

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
  title:SetText(LA.displayName or "Classic Glory")
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
  local sideScroll = CreateFrame("ScrollFrame", "ClassicGloryCatScroll", sidebar, "UIPanelScrollFrameTemplate")
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
  playersToolbar:SetHeight(LIST_TOOLBAR_H)
  playersToolbar:Hide()
  UI.playersToolbar = playersToolbar

  local searchBox = CreateFrame("EditBox", "ClassicGloryPlayerSearch", playersToolbar, "InputBoxTemplate")
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
    { id = "noaddon", label = "No addon", width = 78 },
  }
  playersToolbar.filterButtons = {}
  local filterX = 4
  for _, def in ipairs(filterDefs) do
    local btn = MakeChipButton(playersToolbar, def)
    btn:SetPoint("TOPLEFT", filterX, -30)
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

  local inspectBtn = MakeChipButton(playersToolbar, {
    id = "inspect",
    label = "Inspect current target",
    width = 168,
  })
  inspectBtn:SetPoint("TOPRIGHT", -4, -30)
  inspectBtn:SetScript("OnClick", InspectCurrentTarget)
  inspectBtn:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(0.95, 0.80, 0.30, 1)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Inspect current target", 1, 0.82, 0)
    GameTooltip:AddLine("Request achievements from the player you have targeted.", 0.75, 0.75, 0.75, true)
    GameTooltip:Show()
  end)
  inspectBtn:SetScript("OnLeave", function(self)
    ApplyChipVisual(self, false)
    GameTooltip:Hide()
  end)
  ApplyChipVisual(inspectBtn, false)
  playersToolbar.inspectBtn = inspectBtn
  UpdatePlayerFilterButtons()

  -- Achievement search + filter + sort strip (shown under catBar)
  local achToolbar = CreateFrame("Frame", nil, main)
  achToolbar:SetPoint("TOPLEFT", 12, -46)
  achToolbar:SetPoint("TOPRIGHT", -32, -46)
  achToolbar:SetHeight(LIST_TOOLBAR_H)
  achToolbar:Hide()
  UI.achToolbar = achToolbar

  local achSearch = CreateFrame("EditBox", "ClassicGloryAchSearch", achToolbar, "InputBoxTemplate")
  achSearch:SetAutoFocus(false)
  achSearch:SetHeight(22)
  achSearch:SetPoint("TOPLEFT", 4, -2)
  achSearch:SetPoint("TOPRIGHT", -4, -2)
  achSearch:SetFont(FONT, 13, "")
  achSearch:SetTextColor(0.95, 0.90, 0.75, 1)
  achSearch:SetMaxLetters(60)
  achToolbar.searchBox = achSearch

  local achHint = achToolbar:CreateFontString(nil, "OVERLAY")
  SetFS(achHint, 12)
  achHint:SetPoint("LEFT", achSearch, "LEFT", 8, 0)
  achHint:SetText("Search achievements…")
  achHint:SetTextColor(0.55, 0.50, 0.40, 1)
  achToolbar.searchHint = achHint

  achSearch:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    if text == "" and not self:HasFocus() then
      achHint:Show()
    else
      achHint:Hide()
    end
    if text == achievementSearchText then
      return
    end
    achievementSearchText = text
    if not playersMode and selectedCategory and selectedCategory ~= SUMMARY_ID then
      PopulateAchievements(selectedCategory)
    end
  end)
  achSearch:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    if (self:GetText() or "") ~= "" then
      self:SetText("")
      achievementSearchText = ""
      if not playersMode and selectedCategory and selectedCategory ~= SUMMARY_ID then
        PopulateAchievements(selectedCategory)
      end
    end
  end)
  achSearch:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  achSearch:SetScript("OnEditFocusGained", function()
    achHint:Hide()
  end)
  achSearch:SetScript("OnEditFocusLost", function(self)
    if (self:GetText() or "") == "" then
      achHint:Show()
    end
  end)

  achToolbar.filterButtons = {}
  for _, def in ipairs(ACH_FILTER_DEFS) do
    local btn = MakeChipButton(achToolbar, def)
    btn:SetScript("OnClick", function(self)
      local ui = GetUIPrefs()
      if ui.achFilter == self.filterId then
        return
      end
      ui.achFilter = self.filterId
      UpdateAchFilterButtons()
      if not playersMode and selectedCategory and selectedCategory ~= SUMMARY_ID then
        PopulateAchievements(selectedCategory)
      end
    end)
    achToolbar.filterButtons[def.id] = btn
  end

  local sortBtn = MakeChipButton(achToolbar, { id = "sort", label = "Sort: Default", width = 108 })
  sortBtn:SetPoint("TOPRIGHT", -4, -2)
  achSearch:ClearAllPoints()
  achSearch:SetPoint("TOPLEFT", 4, -2)
  achSearch:SetPoint("RIGHT", sortBtn, "LEFT", -10, 0)
  sortBtn:SetScript("OnClick", function()
    local ui = GetUIPrefs()
    local current = ui.achSort or "default"
    local nextMode = SORT_CYCLE[1]
    for i, mode in ipairs(SORT_CYCLE) do
      if mode == current then
        nextMode = SORT_CYCLE[(i % #SORT_CYCLE) + 1]
        break
      end
    end
    ui.achSort = nextMode
    UpdateAchSortButton()
    if not playersMode and selectedCategory and selectedCategory ~= SUMMARY_ID then
      PopulateAchievements(selectedCategory)
    end
  end)
  achToolbar.sortBtn = sortBtn
  UpdateAchFilterButtons()

  -- Scroll area
  local scrollFrame = CreateFrame("ScrollFrame", "ClassicGloryScrollFrame", main, "UIPanelScrollFrameTemplate")
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
    RelayoutMain()
  end)

  f:SetScript("OnShow", function()
    if LA.Share and LA.Share.Announce then
      LA.Share:Announce()
    end
    UpdateHeaderContext()
    -- Defer one frame so widths are valid after Show()
    f._pending = true
    f:SetScript("OnUpdate", function(self)
      self:SetScript("OnUpdate", nil)
      self._pending = nil
      RelayoutMain()
    end)
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
    SaveFrameLayout(f)
    RelayoutMain()
  end)

  self.frame = f
  CreateMinimapButton()

  SelectCategory(SUMMARY_ID)

  tinsert(UISpecialFrames, "ClassicGloryFrame")
end

function UI:PersistLayout()
  if self.frame then
    SaveFrameLayout(self.frame)
  end
  local btn = self.minimapButton
  if not btn or not IsFiniteNumber(btn.angle) then
    return
  end
  local db = LA.db or ClassicGloryDB
  if type(db) ~= "table" then
    return
  end
  GetUIPrefs().minimapAngle = Round(btn.angle * 10) / 10
end

function UI:Refresh()
  if not self.frame then
    return
  end
  UpdateHeaderContext()
  UpdateCategoryCounts()
  if not self.frame:IsShown() then
    return
  end
  RelayoutMain()
end

function UI:OnShareUpdate()
  if not self.frame or not self.frame:IsShown() then
    return
  end
  if playersMode or viewingPeer then
    RelayoutMain()
  end
  UpdateHeaderContext()
  UpdateCategoryCounts()
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
