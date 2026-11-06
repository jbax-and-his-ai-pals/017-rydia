-- 24 generic Call slots (asm/slots.asm, asm/roster.asm), on a --no-test-pacts build.
-- The opening event grants Shiva with the vanilla "add spell" opcode (E2 04 36):
-- Shiva must join the pool and roster slot 0, not the list. Battle 1 start also
-- puts species 05 (Cave Bat) in slot 23 (token $0C). Then:
--   battle 1: cast slot 0 -> vanilla Shiva (effect $52), no pact summon
--   battle 2: cast slot 23 -> pact summon (effect $4D, call_cur = 06)
-- Checks menu MP for both, damage, and that Black spells keep vanilla MP.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
H.require_scenario_completion()
local ROM, EXEC = emu.memType.snesPrgRom, emu.callbackType.exec
local function off(a) return ((a >> 16) & 0x7F) * 0x8000 + ((a & 0xFFFF) - 0x8000) end
local function rom(a) return emu.read(off(a), ROM) end
local results, fails = {}, 0
local function out(fmt, ...) local s = string.format(fmt, ...); results[#results + 1] = s; H.log("%s", s) end
local function check(ok, fmt, ...)
  local msg = string.format(fmt, ...)
  results[#results + 1] = (ok and "PASS " or "FAIL ") .. msg
  H.log("%s", results[#results])
  if not ok then fails = fails + 1; H.fail(msg) end
end

local START = {0xFE,0xFB,0x9A,0xC8,0x00}
local ev = {table.unpack(START)}
ev[#ev+1]=0xE2; ev[#ev+1]=0x04; ev[#ev+1]=0x36          -- grant Shiva to list 4
for _ = 1, 2 do
  ev[#ev+1]=0xEC; ev[#ev+1]=0x21
  for _,b in ipairs(START) do ev[#ev+1]=b end
end
ev[#ev+1]=0xFF
for i,b in ipairs(ev) do emu.write(off(0x1283E0)+i-1,b,ROM) end

local ROSTER, LIST = 0x119E, 0x15C0
local SLOT_IDS, SLOT_OF = H.symbol("slot_ids"), H.symbol("slot_of")
local function level(s)
  local p = rom(0x0EA6A0 + 2 * s) | (rom(0x0EA6A1 + 2 * s) << 8)
  return rom(0x0E0000 | p) & 0x7F
end

local battle = 0
emu.addMemoryCallback(function()
  battle = battle + 1
  if battle == 1 then
    check(H.ram(0x11B6) & 1 == 1, "grant: Shiva is in the pool (eidolon bits %s)", H.dump(0x11B6, 2))
    check(H.ram(ROSTER) == 225, "grant: Shiva (225) in roster slot 0 (%02X)", H.ram(ROSTER))
    check(H.ram(LIST) == rom(SLOT_IDS), "grant: Call list entry 0 is slot 0's token (%02X)", H.ram(LIST))
    local stray = false
    for i = 1, 23 do if H.ram(LIST + i) ~= 0 then stray = true end end
    check(not stray, "grant: nothing else in the Call list (%s)", H.dump(LIST, 8))
    H.wram_write(0x1181, H.ram(0x1181) | 0x20)   -- own species 05
    H.wram_write(ROSTER + 23, 0x06)               -- in slot 23
  end
end, EXEC, off(0x00E394), off(0x00E394), emu.cpuType.snes, ROM)

local menuMp = {}
emu.addMemoryCallback(function()
  if battle ~= 1 then return end
  for e = 0, 71 do                                 -- Rydia: party slot 0
    local id, mp = H.ram(0x2C7B + 4 * e), H.ram(0x2C7D + 4 * e)
    if e >= 48 and id ~= 0 then menuMp[id] = mp end
    if e < 48 and id ~= 0 and e == 24 then
      check(mp == rom(0x0F97A5 + 6 * id) & 0x7F, "Black %02X keeps vanilla MP %d", id, mp)
    end
  end
  check(menuMp[rom(SLOT_IDS)] == 30, "menu MP for Shiva in slot 0 = %s (want 30)", tostring(menuMp[rom(SLOT_IDS)]))
  local want = 1 + (level(5) >> 1)
  check(menuMp[0x0C] == want, "menu MP for Cave Bat in slot 23 ($0C) = %s (want %d)", tostring(menuMp[0x0C]), want)
end, EXEC, off(0x038A7A), off(0x038A7A), emu.cpuType.snes, ROM)

local cast = {}
local function mon_hp() local t = {} for s = 0, 7 do t[s] = H.ram(0x29B5 + s) ~= 0xFF and H.ram16(0x2000 + 0x80 * (s + 5) + 7) or nil end return t end
emu.addMemoryCallback(function()
  if H.ram(0x2680) & 0x1F ~= 0x11 or cast[battle] then return end
  local slot = rom(SLOT_OF + H.ram(0x26D2))
  if slot == 0xFF then return end
  cast[battle] = { slot = slot, hp = mon_hp() }
  out("battle %d: Rydia casts token %02X (slot %d)", battle, H.ram(0x26D2), slot)
end, EXEC, off(H.symbol("call_route")), off(H.symbol("call_route")), emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  local c = cast[battle]
  if not c or c.data then return end
  c.data = true
  if battle == 1 then
    check(c.slot == 0 and H.ram(0x26D2) == 0x52 and H.ram(0x11BE) == 0,
      "slot 0 casts vanilla Shiva: $26D2=%02X call_cur=%02X", H.ram(0x26D2), H.ram(0x11BE))
  else
    check(c.slot == 23 and H.ram(0x26D2) == 0x4D and H.ram(0x11BE) == 0x06,
      "slot 23 casts the pact summon: $26D2=%02X call_cur=%02X", H.ram(0x26D2), H.ram(0x11BE))
  end
end, EXEC, off(0x03CDCA), off(0x03CDCA), emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  local c = cast[battle]
  if not c or not c.data or c.done then return end
  c.done = true
  local hp, hit, n = mon_hp(), 0, 0
  for k, v in pairs(c.hp) do n = n + 1; if (hp[k] or 0) < v then hit = hit + 1 end end
  check(hit >= 1, "battle %d: the summon hit %d of %d monsters", battle, hit, n)
  c.shotAt = H.frame
end, EXEC, off(0x03B05D), off(0x03B05D), emu.cpuType.snes, ROM)

table.insert(H.on_frame, function(f)
  local c = cast[battle]
  if c and c.shotAt and f - c.shotAt == 40 then H.shot(string.format("slots24-b%d", battle)) end
end)

-- Input: battle 1 casts the first Call entry; battle 2 moves to slot 23
-- (row 7, column 2) first; then Fight.
local step, waitUntil, closingSince, moves = "idle", 0, 0, {}
H.override = function(f)
  if battle == 0 then
    if f >= 320 and f < 420 and f % 16 < 2 then return { a = true } end
    return {}
  end
  if f < waitUntil then return {} end
  local open = H.ram(0xD7) == 1 and H.ram(0x1823) == 1 and H.ram(0x1820) == 0
  if step == "idle" then
    if not open then
      if H.ram(0x29CD) == 0 and f % 40 == 0 then return { a = true } end
      return {}
    end
    step = "menu"; waitUntil = f + 8; return {}
  elseif step == "menu" then
    if not open then step = "idle"; return {} end
    local want = cast[battle] and 0 or 2
    local c = H.ram(0x60)
    waitUntil = f + 6
    if c < want then return { down = true } end
    if c > want then return { up = true } end
    if want == 2 then
      step = "spell"
      moves = battle == 2 and { "down","down","down","down","down","down","down","right","right" } or {}
    else step = "target" end
    waitUntil = f + 30
    return { a = true }
  elseif step == "spell" then
    waitUntil = f + 12
    if #moves > 0 then local m = table.remove(moves, 1); return { [m] = true } end
    step = "target"; waitUntil = f + 30
    return { a = true }
  elseif step == "target" then
    step = "closing"; waitUntil = f + 10; closingSince = f
    return { a = true }
  elseif step == "closing" then
    if H.ram(0xD7) == 0 or f - closingSince > 60 then step = "idle" end
    waitUntil = f + 4
    return {}
  end
  return {}
end

emu.addMemoryCallback(function()
  if battle >= 2 and cast[2] and cast[2].done then
    H.mark_scenario_complete()
    H.finish(fails == 0 and 0 or 1)
  end
end, EXEC, off(0x00EDB1), off(0x00EDB1), emu.cpuType.snes, ROM)

table.insert(H.on_finish, function()
  local fo = assert(io.open(H.OUT .. "/result.txt", "w"))
  fo:write(table.concat(results, "\n"), "\n"); fo:close()
end)
