--[[
  LaucobsAchievements - Share
  Social-graph peer discovery and completion sync (guild / party / raid / whisper).
]]

local addonName, LA = ...

local Share = {}
LA.Share = Share

local PREFIX = "LAACH"
local PROTOCOL_VER = 1
local PEER_TTL = 600 -- seconds; drop silent peers after ~10 minutes
local SEND_GAP = 0.35 -- throttle between outbound addon messages
local MAX_MSG = 240 -- stay under 255 with headroom

Share.peers = {} -- [fullName] = { name, realm, points, count, completed, lastSeen, version, syncing }
Share.viewing = nil -- fullName of peer being inspected, or nil for self

local frame = CreateFrame("Frame")
local sendQueue = {}
local sendElapsed = 0
local started = false
local lastHelloAt = 0
local HELLO_COOLDOWN = 5

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
  local db = LA.db or LaucobsAchievementsDB
  if not db then
    return true
  end
  if db.shareEnabled == nil then
    return true
  end
  return db.shareEnabled and true or false
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
      version = PROTOCOL_VER,
      syncing = false,
      syncBuf = {},
    }
    Share.peers[fullName] = peer
  else
    peer.lastSeen = time()
  end
  return peer, fullName
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
  return string.format("H|%d|%d|%d", PROTOCOL_VER, points, count)
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

local function HandleHello(sender, parts)
  local ver = tonumber(parts[2]) or 0
  local points = tonumber(parts[3]) or 0
  local count = tonumber(parts[4]) or 0
  if ver > PROTOCOL_VER + 5 then
    -- Far-future protocol; still track presence lightly
  end
  local peer = EnsurePeer(sender)
  if not peer then
    return
  end
  peer.version = ver
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
  local seq = tonumber(parts[2]) or 1
  local total = tonumber(parts[3]) or 1
  local body = parts[4] or ""
  local peer, key = EnsurePeer(sender)
  if not peer then
    return
  end

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
  end
end

local function HandleNew(sender, parts)
  local id = tonumber(parts[2])
  if not id then
    return
  end
  local peer = EnsurePeer(sender)
  if not peer then
    return
  end
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
    HandleHello(sender, parts)
  elseif kind == "R" then
    HandleRequest(sender)
  elseif kind == "S" then
    HandleSync(sender, parts)
  elseif kind == "N" then
    HandleNew(sender, parts)
  end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Share:IsEnabled()
  return IsSharingEnabled()
end

function Share:SetEnabled(enabled)
  local db = LA.db or LaucobsAchievementsDB
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
    }
  end
  table.sort(list, function(a, b)
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
  EnsurePeer(fullName)
  Enqueue("WHISPER", "R", fullName)
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

  frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
      local prefix, message, channel, sender = ...
      OnAddonMessage(prefix, message, channel, sender)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
      SendHello(false)
    elseif event == "PLAYER_ENTERING_WORLD" then
      SendHello(true)
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
