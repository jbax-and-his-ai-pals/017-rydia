-- Long random-input session watching Tellah's parked slot ($1180-$11BF).
-- Mashes A through the opening, then random walking, menus (X), confirms and cancels.
-- Logs every distinct (kind, PC, address) access, map changes and fights.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
local ROM, WRAM = emu.memType.snesPrgRom, emu.memType.snesWorkRam
local EXEC, READ, WRITE = emu.callbackType.exec, emu.callbackType.read, emu.callbackType.write
local function off(snes) return ((snes >> 16) & 0x7F) * 0x8000 + ((snes & 0xFFFF) - 0x8000) end

local RANDOM_FROM = tonumber(os.getenv("RANDOM_FROM") or "9000")
math.randomseed(tonumber(os.getenv("SEED") or "4"))
local dirs = { "up", "down", "left", "right" }
local hold, holdLeft = {}, 0
H.override = function(f)
  if f < RANDOM_FROM then
    if f >= 320 and f % 16 < 2 then return { a = true } end
    return {}
  end
  if holdLeft <= 0 then
    local r = math.random()
    if r < 0.45 then hold = { [dirs[math.random(4)]] = true }; holdLeft = math.random(10, 60)
    elseif r < 0.70 then hold = { a = true }; holdLeft = 2
    elseif r < 0.85 then hold = { b = true }; holdLeft = 2
    elseif r < 0.95 then hold = { x = true }; holdLeft = 2
    else hold = {}; holdLeft = math.random(5, 30) end
  end
  holdLeft = holdLeft - 1
  return hold
end

-- Accesses grouped by kind and PC: count, address range, first frame.
local byPc = {}
local function note(kind) return function(addr)
  local key = string.format("%s $%06X", kind, H.pc())
  local a = addr & 0xFFFF
  local e = byPc[key]
  if not e then e = { n = 0, lo = a, hi = a, first = H.frame }; byPc[key] = e end
  e.n = e.n + 1; e.lo = math.min(e.lo, a); e.hi = math.max(e.hi, a)
end end
emu.addMemoryCallback(note("read"), READ, 0x1180, 0x11BF, emu.cpuType.snes, WRAM)
emu.addMemoryCallback(note("write"), WRITE, 0x1180, 0x11BF, emu.cpuType.snes, WRAM)

local fights = 0
emu.addMemoryCallback(function() fights = fights + 1; H.log("fight formation %02X", emu.getState()["cpu.a"] & 0xFF) end,
  EXEC, off(0x00E394), off(0x00E394), emu.cpuType.snes, ROM)
local lastMap = ""
table.insert(H.on_frame, function(f)
  local m = string.format("%02X %02X%02X", H.ram(0x1700), H.ram(0x1701), H.ram(0x1702))
  if m ~= lastMap then H.log("map %s", m); lastMap = m end
end)

table.insert(H.on_finish, function()
  H.log("fights: %d", fights)
  local keys = {}
  for k in pairs(byPc) do keys[#keys + 1] = k end
  table.sort(keys)
  H.log("--- Tellah slot accesses: kind PC, count, address range, first frame")
  for _, k in ipairs(keys) do
    local e = byPc[k]
    H.log("  %s x%d $%04X-$%04X first %d", k, e.n, e.lo, e.hi, e.first)
  end
end)
