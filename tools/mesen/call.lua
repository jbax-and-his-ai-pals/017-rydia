-- Call test: pact monsters, then summon one from Call (asm/call.asm).
-- Fixture as in pact.lua: event $10 loads the overworld, then fights each
-- formation in FORMS, reloading the map after each.
-- Battle 1 uses Pact until it ends; later battles cast Call slot SLOT once,
-- then Fight.
-- Env: FORMS (default "21,21"), SYM (path to build/rydia.sym),
--      SLOT (default 0; the cursor moves right SLOT times, so same row only)
-- Writes result.txt: checks plus a PASS/FAIL summary; screenshots call_NNN.png.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
local ROM = emu.memType.snesPrgRom
local EXEC = emu.callbackType.exec
local function off(snes) return ((snes >> 16) & 0x7F) * 0x8000 + ((snes & 0xFFFF) - 0x8000) end
local function rom(snes) return emu.read(off(snes), ROM) end

local START = { 0xFE, 0xFB, 0x9A, 0xC8, 0x00 }
local forms = {}
for x in (os.getenv("FORMS") or "21,21"):gmatch("%x+") do forms[#forms + 1] = tonumber(x, 16) end
local ev = { table.unpack(START) }
for _, fm in ipairs(forms) do
  ev[#ev + 1] = 0xEC; ev[#ev + 1] = fm
  for _, b in ipairs(START) do ev[#ev + 1] = b end
end
ev[#ev + 1] = 0xFF
for i, b in ipairs(ev) do emu.write(off(0x1283E0) + i - 1, b, ROM) end

-- Addresses (asm/call.asm, notes/call-design.md).
local SLOT = tonumber(os.getenv("SLOT") or "0")
local ROSTER, SNAP, CUR, LIST = 0x119E, 0x11AE, 0x11BE, 0x15C0
local function sym(name)
  for line in io.lines(os.getenv("SYM")) do
    local b, a, n = line:match("^(%x%x):(%x%x%x%x) (%S+)")
    if n == name then return (tonumber(b, 16) << 16) | tonumber(a, 16) end
  end
  error("no symbol " .. name)
end
local SUMMON = sym("call_summon")

local results, fails = {}, 0
local function out(fmt, ...) local s = string.format(fmt, ...); results[#results + 1] = s; H.log("%s", s) end
local function check(ok, fmt, ...)
  if not ok then fails = fails + 1 end
  out("%s " .. fmt, ok and "PASS" or "FAIL", ...)
end
local function mon_level(s)
  local ptr = rom(0x0EA6A0 + 2 * s) | (rom(0x0EA6A1 + 2 * s) << 8)
  return rom(0x0E0000 | ptr) & 0x7F
end
local function mon_name(s)
  local t = {}
  for i = 0, 7 do t[#t + 1] = string.format("%02X", rom(0x0E9800 + 8 * s + i)) end
  return table.concat(t, " ")
end
local function rydia_mp() return H.ram16(0x2000 + 0x0B) end

-- Battles.
local battle = 0
emu.addMemoryCallback(function()
  if battle > 0 then out("battle %d over: $29CD=%02X roster %s", battle, H.ram(0x29CD), H.dump(ROSTER, 5)) end
  battle = battle + 1
  out("battle %d starts: formation %02X", battle, emu.getState()["cpu.a"] & 0xFF)
end, EXEC, off(0x00E394), off(0x00E394), emu.cpuType.snes, ROM)

-- After the battle-start hook and the spell menu build ($03:8A7A): roster,
-- snapshot, Call list and the menu's MP for each slot.
local menuMp = {}
emu.addMemoryCallback(function()
  if battle < 2 then return end
  out("battle %d menu: roster %s snap %s list %s", battle, H.dump(ROSTER, 5), H.dump(SNAP, 5), H.dump(LIST, 8))
  for i = 0, 4 do
    local sp = H.ram(ROSTER + i)
    check(H.ram(SNAP + i) == sp, "slot %d snapshot = roster (%02X)", i, sp)
    check(H.ram(LIST + i) == (sp ~= 0 and 0x31 + i or 0), "Call list entry %d = %02X", i, H.ram(LIST + i))
  end
  -- $2C7A: 4 bytes per entry, +1 spell, +3 MP
  for e = 0, 359 do
    local id = H.ram(0x2C7B + 4 * e)
    if id >= 0x31 and id <= 0x35 then
      local sp = H.ram(SNAP + id - 0x31) - 1
      local want = 1 + (mon_level(sp) >> 1)
      menuMp[id] = H.ram(0x2C7D + 4 * e)
      check(menuMp[id] == want, "menu MP for %02X (species %02X, Lv %d) = %d (want %d)", id, sp, mon_level(sp), menuMp[id], want)
    end
  end
end, EXEC, off(0x038A7A), off(0x038A7A), emu.cpuType.snes, ROM)

-- The summon.
local cast = nil
emu.addMemoryCallback(function()
  local a = emu.getState()["cpu.a"] & 0xFF
  local ce = H.ram(0xCE)
  local slot = ce & 7
  local rec = 0x2000 + 0x80 * (slot + 5)
  cast = { spell = a, species = H.ram(SNAP + a - 0x31) - 1, ce = ce, rec = rec, hp = H.ram16(rec + 7), frame = H.frame }
  out("summon: spell %02X, target $CE=%02X HP %d, snapshot %s", a, ce, cast.hp, H.dump(SNAP, 5))
end, EXEC, off(SUMMON), off(SUMMON), emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  if not cast or cast.data then return end
  cast.data = H.dump(0x289C, 6)
  local sp = cast.species
  out("cast data: $26D2=%02X call_cur=%02X $289C=%s, Rydia Lv %d", H.ram(0x26D2), H.ram(CUR), cast.data, H.ram(0x2682))
  check(H.ram(0x26D2) == 0x4D + cast.spell - 0x31, "effect spell %02X", H.ram(0x26D2))
  check(H.ram(CUR) == sp + 1, "call_cur = species+1 (%02X)", H.ram(CUR))
  local pw = math.max(1, ((mon_level(sp) + H.ram(0x2682)) * 5) >> 4)
  check(H.ram(0x289D) == pw and H.ram(0x289E) == 0x64 and H.ram(0x289F) == 0 and H.ram(0x28A0) == 0,
    "hit data power %d (want %d), hit %02X, effect %02X, element %02X", H.ram(0x289D), pw, H.ram(0x289E), H.ram(0x289F), H.ram(0x28A0))
end, EXEC, off(0x03CDCA), off(0x03CDCA), emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  if not cast or not cast.data or cast.done then return end
  cast.done = true
  local hp = H.ram16(cast.rec + 7)
  check(hp < cast.hp, "target HP %d -> %d", cast.hp, hp)
  cast.after = H.frame
end, EXEC, off(0x03B05D), off(0x03B05D), emu.cpuType.snes, ROM)

table.insert(H.on_frame, function(f)
  if cast and f > cast.frame and (f - cast.frame) % 15 == 0 and f - cast.frame <= 300 then
    H.shot(string.format("call_%03d", f - cast.frame))
  end
end)

-- Input: drive the real battle menu ($D7 open, $1823 = 1 command list,
-- $1820 opening animation, $60 command cursor: 0 Fight 1 Black 2 Call 3 Item 4 Pact).
local step, waitUntil, closingSince, moved = "idle", 0, 0, 0
local mpBefore = nil
local function want_cmd()
  if battle == 1 then return 4 end
  if not cast then return 2 end
  return 0
end
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
    local want = want_cmd()
    local c = H.ram(0x60)
    waitUntil = f + 6
    if c < want then return { down = true } end
    if c > want then return { up = true } end
    if want == 2 then mpBefore = rydia_mp(); step = "spell" else step = "target" end
    waitUntil = f + 30
    return { a = true }
  elseif step == "spell" then
    -- spell list: the cursor starts on slot 0; move right SLOT times, A, then A on the target
    waitUntil = f + 30
    if moved < SLOT then moved = moved + 1; return { right = true } end
    step = "target"
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

table.insert(H.on_finish, function()
  out("end: battles %d of %d, roster %s next %02X, Rydia MP %d", battle, #forms, H.dump(ROSTER, 5), H.ram(0x119D), rydia_mp())
  H.shot("end")
  check(battle >= #forms, "all %d battles started (%d)", #forms, battle)
  check(cast ~= nil and cast.done == true, "a summon ran and finished")
  if cast and mpBefore then
    local want = menuMp[cast.spell] or -1
    check(mpBefore - rydia_mp() == want, "MP %d -> %d (cost %d)", mpBefore, rydia_mp(), want)
    out("summoned species %02X: name %s", cast.species, mon_name(cast.species))
  end
  out("%s: %d failed checks", fails == 0 and "ALL PASS" or "FAILURES", fails)
  local fo = io.open(H.OUT .. "/result.txt", "w")
  fo:write(table.concat(results, "\n") .. "\n"); fo:close()
end)
