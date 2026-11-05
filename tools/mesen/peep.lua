-- Differential trace for the Peep command.
-- Patches the ROM image in memory: Cecil's menu = Fight, Peep, Item; the opening
-- event loads its first map and then fights formation $082 (one Imp).
-- Env: MODE = fight | peep. Writes pcs.txt (bank $02-$03 code executed in battle)
-- and logs reads of Cecil's battle command byte ($2051) and Tellah-slot accesses.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
local ROM, WRAM = emu.memType.snesPrgRom, emu.memType.snesWorkRam
local EXEC, READ, WRITE = emu.callbackType.exec, emu.callbackType.read, emu.callbackType.write
local MODE = os.getenv("MODE") or "fight"

local function off(snes) return ((snes >> 16) & 0x7F) * 0x8000 + ((snes & 0xFFFF) - 0x8000) end
local function poke(snes, bytes) for i, b in ipairs(bytes) do emu.write(off(snes) + i - 1, b, ROM) end end
poke(0x13FD55, { 0x00, 0x14, 0x01, 0xFF, 0xFF })                    -- Cecil DK menu
poke(0x1283E0, { 0xFE, 0xC0, 0x8C, 0x0B, 0x00, 0xEC, 0x82, 0xFF })   -- event $10
H.log("patched: menu %02X %02X %02X, event %02X %02X %02X", emu.read(off(0x13FD55), ROM), emu.read(off(0x13FD56), ROM),
  emu.read(off(0x13FD57), ROM), emu.read(off(0x1283E5), ROM), emu.read(off(0x1283E6), ROM), emu.read(off(0x1283E7), ROM))

local battleAt = nil
emu.addMemoryCallback(function()
  battleAt = H.frame
  H.log("battle starts, formation %02X", emu.getState()["cpu.a"] & 0xFF)
end, EXEC, off(0x00E394), off(0x00E394), emu.cpuType.snes, ROM)

H.override = function(f)
  if not battleAt then
    if f >= 320 and f % 16 < 2 then return { a = true } end  -- get past the title
    return {}
  end
  local t = f - battleAt - 90
  if MODE == "idle" or t < 0 or f - battleAt > 900 then return {} end
  local p = t % 48
  if MODE == "peep" then
    if p < 2 then return { down = true } end
    if (p >= 12 and p < 14) or (p >= 24 and p < 26) then return { a = true } end
  else
    if p < 2 or (p >= 12 and p < 14) then return { a = true } end
  end
  return {}
end

-- Code executed in banks $02-$03 while the battle runs.
-- Callback addresses are CPU addresses ($BB:AAAA), even for an absolute memType.
-- With BASE_PCS set, log (in order) the first execution of each bank-$03 address
-- that the base run never executed.
local pcs, base, firsts = {}, nil, 0
local basePath = os.getenv("BASE_PCS")
if basePath and basePath ~= "" then
  base = {}
  for l in io.lines(basePath) do base[tonumber(l, 16)] = true end
end
emu.addMemoryCallback(function(addr)
  if not battleAt then return end
  if base and not pcs[addr] and not base[addr] and (addr >> 16) == 3 and firsts < 40 then
    firsts = firsts + 1
    H.log("first new $%06X", addr)
  end
  pcs[addr] = true
end, EXEC, 0x10000, 0x1FFFF, emu.cpuType.snes, ROM)

-- Who reads Cecil's battle command byte, and with which value.
local seen = {}
emu.addMemoryCallback(function(addr, value)
  local k = string.format("$%06X=%02X", H.pc(), value)
  if not seen[k] then seen[k] = true; H.log("read $2051 by %s", k) end
end, READ, 0x2051, 0x2051, emu.cpuType.snes, WRAM)

-- Tellah's slot.
local tellah = {}
local function note(kind) return function()
  local k = string.format("%s $%06X", kind, H.pc()); tellah[k] = (tellah[k] or 0) + 1
end end
emu.addMemoryCallback(note("read "), READ, 0x1180, 0x11BF, emu.cpuType.snes, WRAM)
emu.addMemoryCallback(note("write"), WRITE, 0x1180, 0x11BF, emu.cpuType.snes, WRAM)

table.insert(H.on_frame, function(f)
  if battleAt and (f - battleAt) % 60 == 0 and f - battleAt <= 900 then H.shot(string.format("b%04d", f - battleAt)) end
end)

table.insert(H.on_finish, function()
  local list = {}
  for a in pairs(pcs) do list[#list + 1] = a end
  table.sort(list)
  local fo = io.open(H.OUT .. "/pcs.txt", "w")
  for _, a in ipairs(list) do fo:write(string.format("%05X\n", a)) end
  fo:close()
  H.log("battle pcs: %d", #list)
  for k, n in pairs(tellah) do H.log("tellah %s x%d", k, n) end
end)
