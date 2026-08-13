--[[
  Classic Glory - Seal
  Tamper-evident ink for SavedVariables. Not cryptographic security:
  a determined reader of this file can forge ink. It stops notepad edits.

  Mix and canonical layout MUST match web/src/lib/seal.ts.
  Hash UTF-8 bytes (Lua string.byte == file bytes).

  Test vectors (keep in sync with seal.ts):
    mix32("abc", 1) -> 144903
    ticket Player-4408-0B2C3D4E | 1001 | 1722900000 | 2
      -> v1:f4864afb0330afb0
]]

local addonName, LA = ...

local Seal = {}
LA.Seal = Seal

local MOD = 4294967296
local HEX = "0123456789abcdef"
local VERSION = "v1"

-- Split fragments; XOR'd at runtime so a grep for a single "secret" misses.
local FRAG_A = { 0x51F3A91C, 0x0B7C22E5, 0x6D14C083, 0x9A2E17D4 }
local FRAG_B = { 0x3C08F6B1, 0xE5D40A27, 0xC61A7B0E, 0x47B8D192 }

local seedCache

local function u32(n)
  n = tonumber(n) or 0
  n = n % MOD
  if n < 0 then
    n = n + MOD
  end
  return n
end

local function bxor32(a, b)
  a, b = u32(a), u32(b)
  if bit and bit.bxor then
    return u32(bit.bxor(a, b))
  end
  local r, bitv = 0, 1
  for _ = 1, 32 do
    local ab, bb = a % 2, b % 2
    if ab ~= bb then
      r = r + bitv
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bitv = bitv * 2
  end
  return r
end

local function seeds()
  if seedCache then
    return seedCache
  end
  seedCache = {}
  for i = 1, 4 do
    seedCache[i] = bxor32(FRAG_A[i], FRAG_B[i])
  end
  return seedCache
end

--- 32-bit djb2-like mix. Portable: (h * 33 + b) % 2^32, exact in Lua doubles.
function Seal.Mix32(str, seed)
  str = str or ""
  local h = u32(seed)
  for i = 1, #str do
    h = (h * 33 + str:byte(i)) % MOD
  end
  return h
end

local function hex8(n)
  n = u32(n)
  local t = {}
  for i = 8, 1, -1 do
    local nib = n % 16
    t[i] = HEX:sub(nib + 1, nib + 1)
    n = math.floor(n / 16)
  end
  return table.concat(t)
end

local function ink64(str, s1, s2)
  return hex8(Seal.Mix32(str, s1)) .. hex8(Seal.Mix32(str, s2))
end

local function intstr(n)
  n = tonumber(n)
  if not n then
    return "0"
  end
  return string.format("%d", math.floor(n))
end

local function lookup(tbl, id)
  if type(tbl) ~= "table" then
    return nil
  end
  local v = tbl[id]
  if v ~= nil then
    return v
  end
  return tbl[tostring(id)] or tbl[tonumber(id)]
end

local function sortedTruthyKeys(t)
  local keys = {}
  if type(t) == "table" then
    for k, v in pairs(t) do
      if v then
        keys[#keys + 1] = string.lower(tostring(k))
      end
    end
  end
  table.sort(keys)
  return table.concat(keys, ",")
end

function Seal.TicketPayload(guid, id, earnedOn, lvl)
  return table.concat({
    VERSION,
    tostring(guid or ""),
    intstr(id),
    intstr(earnedOn),
    intstr(lvl),
  }, "|")
end

function Seal.Ticket(guid, id, earnedOn, lvl)
  local s = seeds()
  return VERSION .. ":" .. ink64(Seal.TicketPayload(guid, id, earnedOn, lvl), s[1], s[2])
end

function Seal.Canonical(char)
  if type(char) ~= "table" then
    return VERSION .. "||||||Alive|0|||"
  end

  local ids = {}
  for id in pairs(char.completed or {}) do
    local n = tonumber(id)
    if n then
      ids[#ids + 1] = n
    end
  end
  table.sort(ids)
  local cparts = {}
  for i = 1, #ids do
    local id = ids[i]
    local e = lookup(char.completed, id)
    if type(e) == "table" then
      cparts[#cparts + 1] = string.format(
        "%d:%s:%s:%s",
        id,
        intstr(e.earnedOn),
        intstr(e.lvl),
        tostring(e.ticket or "")
      )
    elseif e then
      cparts[#cparts + 1] = string.format("%d:0:0:", id)
    end
  end

  local pids = {}
  for id in pairs(char.progress or {}) do
    local n = tonumber(id)
    if n then
      pids[#pids + 1] = n
    end
  end
  table.sort(pids)
  local pparts = {}
  for i = 1, #pids do
    local id = pids[i]
    local row = lookup(char.progress, id)
    if type(row) == "table" then
      local idxs = {}
      for idx, val in pairs(row) do
        local nidx = tonumber(idx)
        if nidx and tonumber(val) then
          idxs[#idxs + 1] = nidx
        end
      end
      table.sort(idxs)
      for j = 1, #idxs do
        local idx = idxs[j]
        local val = lookup(row, idx)
        pparts[#pparts + 1] = string.format("%d.%d=%s", id, idx, intstr(val))
      end
    end
  end

  local status = char.status == "Dead" and "Dead" or "Alive"
  return table.concat({
    VERSION,
    tostring(char.guid or ""),
    intstr(char.level),
    tostring(char.class or ""),
    tostring(char.race or ""),
    tostring(char.faction or ""),
    status,
    intstr(char.deaths),
    table.concat(cparts, ","),
    sortedTruthyKeys(char.visitedZones),
    sortedTruthyKeys(char.visitedInstances),
    table.concat(pparts, ","),
  }, "|")
end

function Seal.Compute(char)
  local s = seeds()
  return VERSION .. ":" .. ink64(Seal.Canonical(char), s[3], s[4])
end

local function mintTickets(char)
  local guid = tostring(char.guid or "")
  if type(char.completed) ~= "table" then
    char.completed = {}
    return
  end
  for id, entry in pairs(char.completed) do
    if type(entry) ~= "table" then
      entry = { earnedOn = time(), lvl = tonumber(char.level) or 1 }
      char.completed[id] = entry
    end
    entry.earnedOn = tonumber(entry.earnedOn) or time()
    if not tonumber(entry.lvl) then
      entry.lvl = tonumber(char.level) or 1
    end
    entry.ticket = Seal.Ticket(guid, id, entry.earnedOn, entry.lvl)
  end
end

function Seal.Write(char)
  if type(char) ~= "table" then
    return
  end
  mintTickets(char)
  char.seal = Seal.Compute(char)
end

function Seal.Verify(char)
  if type(char) ~= "table" then
    return false
  end
  local guid = tostring(char.guid or "")
  for id, entry in pairs(char.completed or {}) do
    if type(entry) ~= "table" then
      return false
    end
    local want = Seal.Ticket(guid, id, entry.earnedOn, entry.lvl)
    if tostring(entry.ticket or "") ~= want then
      return false
    end
  end
  return tostring(char.seal or "") == Seal.Compute(char)
end

function Seal.WipeProgress(char)
  if type(char) ~= "table" then
    return
  end
  if type(char.completed) == "table" then
    wipe(char.completed)
  else
    char.completed = {}
  end
  if type(char.progress) == "table" then
    wipe(char.progress)
  else
    char.progress = {}
  end
  if type(char.visitedZones) == "table" then
    wipe(char.visitedZones)
  else
    char.visitedZones = {}
  end
  if type(char.visitedInstances) == "table" then
    wipe(char.visitedInstances)
  else
    char.visitedInstances = {}
  end
end

--- Adopt unsigned rows (pre-0.6.0) by minting tickets and writing a seal.
function Seal.Adopt(char)
  Seal.Write(char)
end

--- Login gate. Returns "ok", "adopt", or "wiped".
function Seal.VerifyOrAdopt(char)
  if type(char) ~= "table" then
    return "ok"
  end
  if type(char.seal) ~= "string" or char.seal == "" then
    Seal.Adopt(char)
    return "adopt"
  end
  if Seal.Verify(char) then
    return "ok"
  end
  Seal.WipeProgress(char)
  Seal.Write(char)
  return "wiped"
end

--- Grandfather every unsigned alt in the account-wide SavedVariables.
function Seal.AdoptUnsigned(db)
  if type(db) ~= "table" or type(db.characters) ~= "table" then
    return
  end
  for _, char in pairs(db.characters) do
    if type(char) == "table" and (type(char.seal) ~= "string" or char.seal == "") then
      Seal.Adopt(char)
    end
  end
end
