-- Trace what the game does from New Game: events looked up, key event opcodes,
-- map changes, party writes, and every access to Tellah's parked slot.
-- Env: MASH_FROM (frame to start mashing A, default 320), MASH_EVERY (default 16)
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
local ROM, WRAM, EXEC = emu.memType.snesPrgRom, emu.memType.snesWorkRam, emu.callbackType.exec
local READ, WRITE = emu.callbackType.read, emu.callbackType.write

local MASH_FROM = tonumber(os.getenv("MASH_FROM") or "320")
local MASH_EVERY = tonumber(os.getenv("MASH_EVERY") or "16")
H.override = function(f)
  if f >= MASH_FROM and f % MASH_EVERY < 2 then return { a = true } end
  if f >= 300 and f < 304 then return { start = true } end
  return {}
end

local function off(snes)  -- LoROM bus address to ROM file offset
  local bank, lo = (snes >> 16) & 0x7F, snes & 0xFFFF
  return bank * 0x8000 + (lo - 0x8000)
end
local function A() return emu.getState()["cpu.a"] & 0xFF end

-- Event pointer table reads ($12:8000-$12:81FF): one log line per lookup.
emu.addMemoryCallback(function(addr)
  local i = addr - off(0x128000)
  if i % 2 == 0 then H.log("EVENT %3d ($%02X) looked up by $%06X", i // 2, i // 2, H.pc()) end
end, READ, off(0x128000), off(0x1281FF), emu.cpuType.snes, ROM)

-- Opcode handlers, hooked just after each has fetched its parameter into A.
local hooks = {
  { 0x00EF84, "F2 set plot flag" }, { 0x00EF8D, "F3 clear plot flag" },
  { 0x00EF96, "F4 set NPC flag" }, { 0x00EF9F, "F5 clear NPC flag" },
  { 0x00E394, "EC fight formation" }, { 0x00E59C, "E7 add character (A=id-1)" },
  { 0x00E8C2, "E0 add item" },
}
for _, h in ipairs(hooks) do
  emu.addMemoryCallback(function() H.log("%s %02X", h[2], A()) end, EXEC, off(h[1]), off(h[1]), emu.cpuType.snes, ROM)
end
emu.addMemoryCallback(function() H.log("E8 remove character (handler entry)") end, EXEC, off(0x00E6AF), off(0x00E6AF), emu.cpuType.snes, ROM)
emu.addMemoryCallback(function() H.log("FE load map (handler entry)") end, EXEC, off(0x00EDB1), off(0x00EDB1), emu.cpuType.snes, ROM)

-- Map / position changes.
local last = ""
table.insert(H.on_frame, function()
  local s = string.format("world=%02X map=%02X%02X veh=%02X xy=%02X,%02X",
    H.ram(0x1700), H.ram(0x1701), H.ram(0x1702), H.ram(0x1704), H.ram(0x1706), H.ram(0x1707))
  local k = s:sub(1, 26)
  if k ~= last then H.log("MAP %s", s); last = k end
end)

-- First write to each party record, by writer PC.
local partySeen = {}
emu.addMemoryCallback(function(addr)
  local slot = addr // 0x40
  local key = slot .. ":" .. H.pc()
  if not partySeen[key] then partySeen[key] = true; H.log("PARTY slot %d first write by $%06X (addr $%04X)", slot, H.pc(), 0x1000 + addr % 0x1000) end
end, WRITE, 0x1000, 0x113F, emu.cpuType.snes, WRAM)

-- Tellah's parked slot: count every read and write by PC.
local tellah = {}
local function note(kind)
  return function(addr, value)
    local k = string.format("%s $%06X", kind, H.pc())
    local e = tellah[k]
    if not e then e = { n = 0, lo = addr, hi = addr, first = H.frame }; tellah[k] = e end
    e.n = e.n + 1; e.lo = math.min(e.lo, addr); e.hi = math.max(e.hi, addr)
  end
end
emu.addMemoryCallback(note("read "), READ, 0x1180, 0x11BF, emu.cpuType.snes, WRAM)
emu.addMemoryCallback(note("write"), WRITE, 0x1180, 0x11BF, emu.cpuType.snes, WRAM)

table.insert(H.on_finish, function()
  H.log("--- Tellah slot $1180-$11BF accesses (kind PC: count, range, first frame)")
  local ks = {}
  for k in pairs(tellah) do ks[#ks + 1] = k end
  table.sort(ks)
  for _, k in ipairs(ks) do
    local e = tellah[k]
    H.log("  %s: %d, $%04X-$%04X, frame %d", k, e.n, e.lo, e.hi, e.first)
  end
  H.log("party0 at end: %s", H.dump(0x1000, 16))
end)
