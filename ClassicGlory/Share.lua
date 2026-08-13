--[[
  Classic Glory - Share
  Social-graph peer discovery and completion sync (guild / party / raid / whisper).
]]

local addonName, LA = ...

local Share = {}
LA.Share = Share

-- Keep the historical prefix so peers on older builds still share.
local PREFIX = "LAACH"
local PROTOCOL_VER = 1 -- wire format; bump only when HELLO/sync layout breaks
local PEER_TTL = 600 -- seconds; drop silent peers after ~10 minutes
local INSPECT_TIMEOUT = 8 -- seconds to wait for a valid inspect reply
local SEND_GAP = 0.35 -- throttle between outbound addon messages
local MAX_MSG = 240 -- stay under 255 with headroom
local UPDATE_URL = "https://github.com/7AC0B95/achievement-classic"

Share.peers = {} -- [fullName] = { name, realm, points, count, completed, lastSeen, version, protocol, syncing, hasAddon, pending, viaGroup, viaGuild, viaInspect }
Share.viewing = nil -- fullName of peer being inspected, or nil for self

local outdatedWarned = false
local pendingOutdated -- { version = "0.5.0" } deferred until out of combat

local frame = CreateFrame("Frame")
local sendQueue = {}
local sendElapsed = 0
local started = false
local lastHelloAt = 0
local HELLO_COOLDOWN = 5

-- Display categories for the Players browser (priority: group > guild > inspect)
Share.SOURCE_GROUP = "group"
Share.SOURCE_GUILD = "guild"
Share.SOURCE_INSPECT = "inspect"
Share.SOURCE_OTHER = "other"

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function PlayerFullName()
  local name, realm
  if UnitFullName then
    name, realm = UnitFullName("player")
  else
    name, realm = UnitName("player")
  end
  if not name then
    return nil
  end
  realm = realm or GetRealmName() or "Unknown"
  return name .. "-" .. realm, name, realm
end

local function NormalizeName(name)
  if not name or name == "" then
    return nil
  end
  if not name:find("-", 1, true) then
    name = name .. "-" .. (GetRealmName() or "Unknown")
  end
  return name
end

local function IsSharingEnabled()
  local db = LA.db or ClassicGloryDB
  if not db then
    return true
  end
  if db.shareEnabled == nil then
    return true
  end
  return db.shareEnabled and true or false
end

local function AddonVersion()
  local meta
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    meta = C_AddOns.GetAddOnMetadata(addonName, "Version")
  elseif GetAddOnMetadata then
    meta = GetAddOnMetadata(addonName, "Version")
  end
  if type(meta) == "string" and meta ~= "" then
    return meta
  end
  return LA.version or "0.0.0"
end

-- HELLO field: letters, digits, dots, dash, underscore, plus. No pipes.
local function SanitizeAddonVersion(s)
  if type(s) ~= "string" then
    return nil
  end
  s = s:match("^%s*(.-)%s*$") or s
  if s == "" then
    return nil
  end
  s = s:gsub("[^%w%.%-+_]", "")
  if s == "" then
    return nil
  end
  if #s > 32 then
    s = s:sub(1, 32)
  end
  return s
end

local function ParseSemver(s)
  s = SanitizeAddonVersion(s)
  if not s then
    return nil
  end
  local a, b, c = s:match("^(%d+)%.(%d+)%.(%d+)")
  if not a then
    a, b = s:match("^(%d+)%.(%d+)")
    c = "0"
  end
  if not a then
    a = s:match("^(%d+)")
    b, c = "0", "0"
  end
  if not a then
    return nil
  end
  return tonumber(a), tonumber(b) or 0, tonumber(c) or 0
end

local function IsNewerVersion(theirs, ours)
  local ta, tb, tc = ParseSemver(theirs)
  local oa, ob, oc = ParseSemver(ours)
  if not ta or not oa then
    return false
  end
  if ta ~= oa then
    return ta > oa
  end
  if tb ~= ob then
    return tb > ob
  end
  return tc > oc
end

local function PrintOutdated(theirs)
  if outdatedWarned then
    return
  end
  outdatedWarned = true
  pendingOutdated = nil
  local ours = AddonVersion()
  DEFAULT_CHAT_FRAME:AddMessage(
    "|cffffd100Classic Glory|r: you are on |cffff5555"
      .. ours
      .. "|r; a nearby player is on |cff00ff00"
      .. theirs
      .. "|r."
  )
  DEFAULT_CHAT_FRAME:AddMessage(
    "  Update from GitHub or the friend-sync watcher, then |cff00ff00/reload|r."
  )
  DEFAULT_CHAT_FRAME:AddMessage("  |cffaaaaaa" .. UPDATE_URL .. "|r")
end

local function MaybeWarnOutdated(addonVer)
  if outdatedWarned or not addonVer then
    return
  end
  if not IsNewerVersion(addonVer, AddonVersion()) then
    return
  end
  if UnitAffectingCombat and UnitAffectingCombat("player") then
    if not pendingOutdated or IsNewerVersion(addonVer, pendingOutdated.version) then
      pendingOutdated = { version = addonVer }
    end
    return
  end
  PrintOutdated(addonVer)
end

local function FlushPendingOutdated()
  if pendingOutdated and pendingOutdated.version then
    PrintOutdated(pendingOutdated.version)
  end
end

local function CountCompleted()
  local char = LA:GetCharDB()
  if not char or not char.completed then
    return 0
  end
  local n = 0
  for _ in pairs(char.completed) do
    n = n + 1
  end
  return n
end

local function CompletedIdList()
  local char = LA:GetCharDB()
  local ids = {}
  if not char or not char.completed then
    return ids
  end
  for id in pairs(char.completed) do
    ids[#ids + 1] = tonumber(id) or id
  end
  table.sort(ids)
  return ids
end

local function PrunePeers()
  local now = time()
  for key, peer in pairs(Share.peers) do
    if peer.lastSeen and (now - peer.lastSeen) > PEER_TTL then
      Share.peers[key] = nil
      if Share.viewing == key then
        Share.viewing = nil
      end
    end
  end
end

local function EnsurePeer(fullName)
  fullName = NormalizeName(fullName)
  if not fullName then
    return nil
  end
  local me = PlayerFullName()
  if me and fullName == me then
    return nil
  end
  local peer = Share.peers[fullName]
  if not peer then
    local short, realm = fullName:match("^(.+)%-(.+)$")
    peer = {
      name = short or fullName,
      realm = realm,
      points = 0,
      count = 0,
      completed = {},
      lastSeen = time(),
      version = nil, -- user-facing semver from HELLO; nil until a new-format peer answers
      protocol = PROTOCOL_VER,
      syncing = false,
      syncBuf = {},
      hasAddon = false,
      pending = false,
      viaGroup = false,
      viaGuild = false,
      viaInspect = false,
    }
    Share.peers[fullName] = peer
  else
    peer.lastSeen = time()
  end
  return peer, fullName
end

local function MarkSourceFromChannel(peer, channel)
  if not peer or not channel then
    return
  end
  channel = strupper(channel)
  if channel == "GUILD" then
    peer.viaGuild = true
  elseif channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT" then
    peer.viaGroup = true
  end
end

local function NamesMatch(fullName, unitName, unitRealm)
  if not fullName or not unitName then
    return false
  end
  local short, realm = fullName:match("^(.+)%-(.+)$")
  short = short or fullName
  if strlower(short) ~= strlower(unitName) then
    return false
  end
  if not unitRealm or unitRealm == "" then
    return true
  end
  return realm and strlower(realm) == strlower(unitRealm)
end

local function IsNameInGroup(fullName)
  if not fullName or not IsInGroup() then
    return false
  end
  if IsInRaid() then
    local n = GetNumGroupMembers() or 0
    for i = 1, n do
      local unit = "raid" .. i
      if UnitExists(unit) and UnitIsPlayer(unit) then
        local uname, urealm = UnitName(unit)
        if NamesMatch(fullName, uname, urealm) then
          return true
        end
      end
    end
  else
    local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or GetNumPartyMembers and GetNumPartyMembers() or 0
    for i = 1, n do
      local unit = "party" .. i
      if UnitExists(unit) and UnitIsPlayer(unit) then
        local uname, urealm = UnitName(unit)
        if NamesMatch(fullName, uname, urealm) then
          return true
        end
      end
    end
  end
  return false
end

-- Keep viaGroup in sync with the live party/raid roster.
local function SyncGroupSources()
  for _, peer in pairs(Share.peers) do
    peer.viaGroup = false
  end
  if not IsInGroup() then
    return
  end
  local function markUnit(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then
      return
    end
    local uname, urealm = UnitName(unit)
    if not uname then
      return
    end
    local key
    if urealm and urealm ~= "" then
      key = NormalizeName(uname .. "-" .. urealm)
    else
      key = NormalizeName(uname)
    end
    local peer = key and Share.peers[key]
    if peer then
      peer.viaGroup = true
    end
  end
  if IsInRaid() then
    local n = GetNumGroupMembers() or 0
    for i = 1, n do
      markUnit("raid" .. i)
    end
  else
    local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or GetNumPartyMembers and GetNumPartyMembers() or 0
    for i = 1, n do
      markUnit("party" .. i)
    end
  end
end

local function ClassifyPeer(peer, fullName)
  if not peer then
    return Share.SOURCE_OTHER
  end
  if IsNameInGroup(fullName) or peer.viaGroup then
    return Share.SOURCE_GROUP
  end
  if peer.viaGuild then
    return Share.SOURCE_GUILD
  end
  if peer.viaInspect then
    return Share.SOURCE_INSPECT
  end
  return Share.SOURCE_OTHER
end

-- Mark that this peer actually answered with a valid protocol message.
local function ConfirmPeerAddon(peer)
  if not peer then
    return
  end
  peer.hasAddon = true
  peer.pending = false
end

local function NotifyUI()
  if LA.UI and LA.UI.OnShareUpdate then
    LA.UI:OnShareUpdate()
  elseif LA.UI and LA.UI.Refresh then
    LA.UI:Refresh()
  end
end

---------------------------------------------------------------------------
-- Outbound queue (rate throttle)
---------------------------------------------------------------------------

local function Enqueue(chatType, message, target)
  if not IsSharingEnabled() then
    return
  end
  if not message or #message > 255 then
    return
  end
  sendQueue[#sendQueue + 1] = { chatType = chatType, message = message, target = target }
end

local function FlushSend(elapsed)
  if #sendQueue == 0 then
    return
  end
  sendElapsed = sendElapsed + (elapsed or 0)
  if sendElapsed < SEND_GAP then
    return
  end
  sendElapsed = 0
  local item = table.remove(sendQueue, 1)
  if not item then
    return
  end
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, item.message, item.chatType, item.target)
  elseif SendAddonMessage then
    pcall(SendAddonMessage, PREFIX, item.message, item.chatType, item.target)
  end
end

local function SendToSocial(message)
  if IsInRaid() then
    Enqueue("RAID", message)
  elseif IsInGroup() then
    Enqueue("PARTY", message)
  end
  if IsInGuild() then
    Enqueue("GUILD", message)
  end
end

---------------------------------------------------------------------------
-- Protocol builders
---------------------------------------------------------------------------

local function BuildHello()
  local points = LA:GetEarnedPoints() or 0
  local count = CountCompleted()
  -- H|protocol|points|count|addonVersion  (addonVersion omitted by older clients)
  return string.format(
    "H|%d|%d|%d|%s",
    PROTOCOL_VER,
    points,
    count,
    SanitizeAddonVersion(AddonVersion()) or "0.0.0"
  )
end

local function SendHello(force)
  if not IsSharingEnabled() then
    return
  end
  local now = GetTime()
  if not force and (now - lastHelloAt) < HELLO_COOLDOWN then
    return
  end
  lastHelloAt = now
  SendToSocial(BuildHello())
end

local function SendSyncTo(target)
  local ids = CompletedIdList()
  local total = #ids
  if total == 0 then
    Enqueue("WHISPER", "S|1|1|", target)
    return
  end

  local chunks = {}
  local current = {}
  local headerBase = "S|" -- seq and total filled later
  local budget = MAX_MSG - 12 -- reserve for "S|99|99|"

  local function flushChunk()
    if #current == 0 then
      return
    end
    chunks[#chunks + 1] = table.concat(current, ",")
    current = {}
  end

  local len = 0
  for _, id in ipairs(ids) do
    local piece = tostring(id)
    local add = (#current == 0) and #piece or (#piece + 1)
    if len + add > budget then
      flushChunk()
      len = 0
    end
    current[#current + 1] = piece
    len = len + add
  end
  flushChunk()

  local n = #chunks
  if n == 0 then
    Enqueue("WHISPER", "S|1|1|", target)
    return
  end
  for i, body in ipairs(chunks) do
    Enqueue("WHISPER", string.format("S|%d|%d|%s", i, n, body), target)
  end
end

---------------------------------------------------------------------------
-- Inbound handlers
---------------------------------------------------------------------------

local function HandleHello(sender, parts, channel)
  -- HELLO: H|protocol|points|count[|addonVersion]
  local protocol = tonumber(parts[2])
  local points = tonumber(parts[3])
  local count = tonumber(parts[4])
  if protocol == nil or points == nil or count == nil then
    return
  end
  if protocol > PROTOCOL_VER + 5 then
    -- Far-future protocol; still track presence lightly
  end
  local peer = EnsurePeer(sender)
  if not peer then
    return
  end
  ConfirmPeerAddon(peer)
  MarkSourceFromChannel(peer, channel)
  peer.protocol = protocol
  local addonVer = SanitizeAddonVersion(parts[5])
  if addonVer then
    peer.version = addonVer
    MaybeWarnOutdated(addonVer)
  end
  peer.points = points
  peer.count = count
  NotifyUI()
  -- No auto-whisper reply: social HELLO already reaches the group; replying
  -- would create N^2 traffic in large guilds.
end

local function HandleRequest(sender)
  if not IsSharingEnabled() then
    return
  end
  local target = NormalizeName(sender)
  if not target then
    return
  end
  -- Also refresh our hello summary
  Enqueue("WHISPER", BuildHello(), target)
  SendSyncTo(target)
end

local function HandleSync(sender, parts)
  -- Require a well-formed sync chunk: S|seq|total|id,id,...
  local seq = tonumber(parts[2])
  local total = tonumber(parts[3])
  if not seq or not total or seq < 1 or total < 1 then
    return
  end
  local body = parts[4] or ""
  local peer, key = EnsurePeer(sender)
  if not peer then
    return
  end

  ConfirmPeerAddon(peer)

  if seq == 1 then
    peer.syncBuf = {}
    peer.syncing = true
  end

  if body ~= "" then
    for idStr in string.gmatch(body, "([^,]+)") do
      local id = tonumber(idStr)
      if id then
        peer.syncBuf[id] = true
      end
    end
  end

  if seq >= total then
    peer.completed = peer.syncBuf or {}
    peer.syncBuf = nil
    peer.syncing = false
    local n = 0
    local pts = 0
    for id in pairs(peer.completed) do
      n = n + 1
      local def = LA.Achievements and LA.Achievements[id]
      if def then
        pts = pts + (def.points or 0)
      end
    end
    peer.count = n
    peer.points = pts
    NotifyUI()
  else
    NotifyUI()
  end
end

local function HandleNew(sender, parts, channel)
  local id = tonumber(parts[2])
  if not id then
    return
  end
  local peer = EnsurePeer(sender)
  if not peer then
    return
  end
  ConfirmPeerAddon(peer)
  MarkSourceFromChannel(peer, channel)
  peer.completed = peer.completed or {}
  if not peer.completed[id] then
    peer.completed[id] = true
    peer.count = (peer.count or 0) + 1
    local def = LA.Achievements and LA.Achievements[id]
    if def then
      peer.points = (peer.points or 0) + (def.points or 0)
    end
  end
  NotifyUI()
end

local function OnAddonMessage(prefix, message, channel, sender)
  if prefix ~= PREFIX then
    return
  end
  if not message or message == "" then
    return
  end

  local me = PlayerFullName()
  sender = NormalizeName(sender)
  if not sender or (me and sender == me) then
    return
  end

  local parts = { strsplit("|", message) }
  local kind = parts[1]
  if kind == "H" then
    HandleHello(sender, parts, channel)
  elseif kind == "R" then
    HandleRequest(sender)
  elseif kind == "S" then
    HandleSync(sender, parts)
  elseif kind == "N" then
    HandleNew(sender, parts, channel)
  end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Share:IsEnabled()
  return IsSharingEnabled()
end

function Share:SetEnabled(enabled)
  local db = LA.db or ClassicGloryDB
  if not db then
    return
  end
  db.shareEnabled = enabled and true or false
  if enabled then
    SendHello(true)
  else
    wipe(sendQueue)
  end
end

function Share:GetPeerList()
  PrunePeers()
  local list = {}
  for key, peer in pairs(self.peers) do
    list[#list + 1] = {
      key = key,
      name = peer.name,
      realm = peer.realm,
      points = peer.points or 0,
      count = peer.count or 0,
      syncing = peer.syncing,
      lastSeen = peer.lastSeen,
      version = peer.version,
      protocol = peer.protocol,
      hasAddon = peer.hasAddon and true or false,
      pending = peer.pending and true or false,
      source = ClassifyPeer(peer, key),
      viaGroup = peer.viaGroup and true or false,
      viaGuild = peer.viaGuild and true or false,
      viaInspect = peer.viaInspect and true or false,
    }
  end
  -- Confirmed addon peers first (by points), then pending, then no-addon
  table.sort(list, function(a, b)
    local ar = (a.hasAddon and 0) or (a.pending and 1) or 2
    local br = (b.hasAddon and 0) or (b.pending and 1) or 2
    if ar ~= br then
      return ar < br
    end
    if a.points == b.points then
      return (a.name or "") < (b.name or "")
    end
    return a.points > b.points
  end)
  return list
end

function Share:GetPeer(fullName)
  fullName = NormalizeName(fullName)
  return fullName and self.peers[fullName] or nil
end

function Share:IsPeerComplete(fullName, achievementId)
  local peer = self:GetPeer(fullName)
  return peer and peer.completed and peer.completed[achievementId] ~= nil
end

function Share:Announce()
  SendHello(false)
end

function Share:RequestPeer(fullName)
  fullName = NormalizeName(fullName)
  if not fullName then
    return false, "No player name."
  end
  local me = PlayerFullName()
  if me and fullName == me then
    return false, "That is you."
  end
  local peer = EnsurePeer(fullName)
  if not peer then
    return false, "No player name."
  end
  peer.viaInspect = true
  -- Inspect targets stay unconfirmed until a valid H/S/N reply arrives.
  if not peer.hasAddon then
    peer.pending = true
    peer.requestedAt = time()
    local requestedKey = fullName
    local function finishPending()
      local p = Share.peers[requestedKey]
      if p and p.pending and not p.hasAddon then
        p.pending = false
        NotifyUI()
      end
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(INSPECT_TIMEOUT, finishPending)
    else
      local delay = 0
      local waiter = CreateFrame("Frame")
      waiter:SetScript("OnUpdate", function(self, elapsed)
        delay = delay + elapsed
        if delay >= INSPECT_TIMEOUT then
          self:SetScript("OnUpdate", nil)
          finishPending()
        end
      end)
    end
  end
  Enqueue("WHISPER", "R", fullName)
  NotifyUI()
  return true
end

function Share:InspectTargetOrName(nameArg)
  local target
  if nameArg and nameArg ~= "" then
    target = nameArg
  elseif UnitExists("target") and UnitIsPlayer("target") then
    local n, r = UnitName("target")
    if n then
      if r and r ~= "" then
        target = n .. "-" .. r
      else
        target = n
      end
    end
  end
  if not target then
    return false, "Target a player or provide a name."
  end
  local ok, err = self:RequestPeer(target)
  if not ok then
    return false, err
  end
  self.viewing = NormalizeName(target)
  NotifyUI()
  return true, self.viewing
end

function Share:BroadcastEarned(achievementId)
  if not IsSharingEnabled() then
    return
  end
  if not achievementId then
    return
  end
  SendToSocial(string.format("N|%d", achievementId))
  -- Keep our hello summary fresh for late joiners
  SendHello(false)
end

function Share:ClearViewing()
  self.viewing = nil
  NotifyUI()
end

function Share:Start()
  if started then
    return
  end
  started = true

  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
  elseif RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(PREFIX)
  end

  frame:RegisterEvent("CHAT_MSG_ADDON")
  frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  frame:RegisterEvent("PLAYER_GUILD_UPDATE")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")

  frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
      local prefix, message, channel, sender = ...
      OnAddonMessage(prefix, message, channel, sender)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
      if event == "GROUP_ROSTER_UPDATE" then
        SyncGroupSources()
        NotifyUI()
      end
      SendHello(false)
    elseif event == "PLAYER_ENTERING_WORLD" then
      SendHello(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
      FlushPendingOutdated()
    end
  end)

  frame:SetScript("OnUpdate", function(_, elapsed)
    FlushSend(elapsed)
  end)

  -- Delayed first hello so guild/roster APIs are ready
  local function delayedHello()
    SendHello(true)
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(2, delayedHello)
  else
    local delay = 0
    local waiter = CreateFrame("Frame")
    waiter:SetScript("OnUpdate", function(self, elapsed)
      delay = delay + elapsed
      if delay >= 2 then
        self:SetScript("OnUpdate", nil)
        delayedHello()
      end
    end)
  end
end
