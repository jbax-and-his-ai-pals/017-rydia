-- Signature abilities (asm/ability.asm): one battle per case against formation
-- $21 (Turtle + 2 Imps). Before each battle the test owns species 01, puts it
-- in Call slot 0 and writes its call_ability_table row in ROM, then casts slot 0.
--   fire    Fire2 data/animation, one enemy: element set loaded, target HP drops
--   all     Ice-1 data, all-enemies targeting: menu entry and every monster hit
--   sleep   Sleep data at 100% hit: the Turtle gains a status bit
--   heal    Cure2 data, an ally: Rydia (set to 1000 HP) is healed
--   <hex>   a species: its built row (data/monsters.csv, call_verified=y) is cast
--           as is; checks the data, damage for damage effects, and that the
--           battle finishes. Shots every 25 frames show the animation.
-- Env: CASES (default "fire,all,sleep,heal"; e.g. "02,05,0B"),
--      FORM (hex formation, default 21; e.g. 82 = one Imp, for statuses the
--      Turtle resists)
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
H.require_scenario_completion()
local ROM, EXEC = emu.memType.snesPrgRom, emu.callbackType.exec
local function off(a) return ((a >> 16) & 0x7F) * 0x8000 + ((a & 0xFFFF) - 0x8000) end
local function rom(a) return emu.read(off(a), ROM) end
local results, fails = {}, 0
local function check(ok, fmt, ...)
  local msg = string.format(fmt, ...)
  results[#results + 1] = (ok and "PASS " or "FAIL ") .. msg
  H.log("%s", results[#results])
  if not ok then fails = fails + 1; H.fail(msg) end
end
local function out(fmt, ...) local s = string.format(fmt, ...); results[#results + 1] = s; H.log("%s", s) end

local cases = {}
for c in (os.getenv("CASES") or "fire,all,sleep,heal"):gmatch("%w+") do cases[#cases + 1] = c end
local SPELL = { fire = 0x1E, all = 0x20, sleep = 0x29, heal = 0x0F }

local START = {0xFE,0xFB,0x9A,0xC8,0x00}
local ev = {table.unpack(START)}
local FORM = tonumber(os.getenv("FORM") or "21", 16)
for _ = 1, #cases do
  ev[#ev+1]=0xEC; ev[#ev+1]=FORM
  for _,b in ipairs(START) do ev[#ev+1]=b end
end
ev[#ev+1]=0xFF
for i,b in ipairs(ev) do emu.write(off(0x1283E0)+i-1,b,ROM) end

local TABLE = H.symbol("call_ability_table")
local SP = 0x01                       -- the summoned species (fixed cases)
local function sp6(s) local t = {} for i = 0, 5 do t[i] = rom(0x0F97A0 + 6 * s + i) end return t end
local function write_row(case)
  local d = sp6(SPELL[case])
  local eff = d[3] & 0x7F
  local scaled = (eff == 0 or eff == 1 or eff == 2 or eff == 4) and 2 or 0
  local target = case == "all" and 0xC0 or (os.getenv("HEALTARGET") and case == "heal" and tonumber(os.getenv("HEALTARGET"), 16)) or (d[0] & 0xE0)
  local hit = case == "sleep" and 0x64 or d[2]
  local power = scaled ~= 0 and 10 or d[1]
  local row = { 1 | scaled, SPELL[case], target, power, hit, d[3], d[4], 0 }
  for i, b in ipairs(row) do emu.write(off(TABLE + 8 * SP + i - 1), b, ROM) end
  return row
end

local battle, case, row = 0, nil, nil
emu.addMemoryCallback(function()
  battle = battle + 1
  case = cases[battle]
  if not case then return end
  if SPELL[case] then
    SP = 0x01
    row = write_row(case)
  else
    SP = tonumber(case, 16)
    row = {}
    for i = 0, 7 do row[i + 1] = rom(TABLE + 8 * SP + i) end
    check(row[1] & 1 == 1, "%s: species row is live in the build", case)
  end
  for a = 0x1181, 0x11B7 do H.wram_write(a, 0) end   -- pool and all 24 roster entries
  H.wram_write(0x1181 + (SP >> 3), 1 << (SP & 7))   -- own only this species
  H.wram_write(0x119E, SP + 1)        -- in slot 0
  out("battle %d (%s): row %02X %02X %02X %02X %02X %02X %02X", battle, case,
    row[1], row[2], row[3], row[4], row[5], row[6], row[7])
end, EXEC, off(0x00E394), off(0x00E394), emu.cpuType.snes, ROM)

-- Menu build done: slot 0's menu targeting follows the row.
emu.addMemoryCallback(function()
  if not case then return end
  if case == "heal" then H.wram_write(0x2007, 1000 & 0xFF); H.wram_write(0x2008, 1000 >> 8) end
  for e = 0, 359 do
    if H.ram(0x2C7B + 4 * e) == 0x31 then
      local want = (row[3] >> 1) & 0x70
      check((H.ram(0x2C7A + 4 * e) & 0x70) == want, "%s: menu targeting %02X (want %02X)", case, H.ram(0x2C7A + 4 * e) & 0x70, want)
    end
  end
end, EXEC, off(0x038A7A), off(0x038A7A), emu.cpuType.snes, ROM)

local cast = nil
local function mon_hp() local t = {} for s = 0, 7 do t[s] = H.ram(0x29B5 + s) ~= 0xFF and H.ram16(0x2000 + 0x80 * (s + 5) + 7) or nil end return t end
emu.addMemoryCallback(function()
  if not case or (cast and cast.battle == battle) then return end
  if H.ram(0x2680) & 0x1F ~= 0x11 or H.ram(0x26D2) ~= 0x31 then return end   -- Rydia casting slot 0
  local ce = H.ram(0xCE)
  cast = { battle = battle, case = case, ce = ce, hp = mon_hp(), rhp = H.ram16(0x2007), frame = H.frame }
  local s = ce & 7
  cast.status = H.dump(0x2000 + 0x80 * (s + 5) + 3, 4)
end, EXEC, off(H.symbol("call_route")), off(H.symbol("call_route")), emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  if not cast or cast.battle ~= battle or cast.data then return end
  cast.data = H.dump(0x289C, 6)
  out("%s: $26D2=%02X $289C=%s", case, H.ram(0x26D2), cast.data)
  check(H.ram(0x289E) == row[5] and H.ram(0x289F) == row[6] and H.ram(0x28A0) == row[7] and (H.ram(0x289C) & 0xE0) == row[3],
    "%s: hit, effect, element and targeting come from the row", case)
end, EXEC, off(0x03CDCA), off(0x03CDCA), emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  if not cast or cast.battle ~= battle or not cast.data or cast.done then return end
  cast.done = true
  local s = cast.ce & 7
  local hp = mon_hp()
  local eff = (row[6] or 0) & 0x7F
  if not SPELL[case] and cast.ce >= 0x80 and (eff == 0 or eff == 1 or eff == 4) then
    check((hp[s] or 0) < (cast.hp[s] or 0), "%s: target HP %s -> %s", case, tostring(cast.hp[s]), tostring(hp[s]))
  elseif not SPELL[case] then
    out("%s: target $CE=%02X status %s -> %s", case, cast.ce, cast.status, H.dump(0x2000 + 0x80 * (s + (cast.ce >= 0x80 and 5 or 0)) + 3, 4))
  end
  if case == "fire" then
    check((hp[s] or 0) < (cast.hp[s] or 0), "fire: target HP %s -> %s", tostring(cast.hp[s]), tostring(hp[s]))
  elseif case == "all" then
    local hit, n = 0, 0
    for k, v in pairs(cast.hp) do n = n + 1; if (hp[k] or 0) < v then hit = hit + 1 end end
    check(n >= 2 and hit == n, "all: %d of %d monsters hit", hit, n)
  elseif case == "sleep" then
    local now = H.dump(0x2000 + 0x80 * (s + 5) + 3, 4)
    check(now ~= cast.status, "sleep: target status %s -> %s", cast.status, now)
  elseif case == "heal" then
    cast.healAt = H.frame        -- party HP may only change while the numbers show
    out("heal: target $CE=%02X, Rydia HP %d when the action ends", cast.ce, H.ram16(0x2007))
  end
end, EXEC, off(0x03B05D), off(0x03B05D), emu.cpuType.snes, ROM)

table.insert(H.on_frame, function(f)
  if cast and cast.healAt and f - cast.healAt == 240 then
    check(cast.ce < 0x80 and H.ram16(0x2007) > cast.rhp, "heal: target $CE=%02X, Rydia HP %d -> %d (240 frames later)", cast.ce, cast.rhp, H.ram16(0x2007))
  end
  if cast and f > cast.frame and (f - cast.frame) % 25 == 0 and f - cast.frame <= 375 then
    H.shot(string.format("ability-%s-%03d", cast.case, f - cast.frame))
  end
end)

-- Input: Call slot 0 once per battle, then Fight.
local step, waitUntil, closingSince = "idle", 0, 0
local function want_cmd() if cast and cast.battle == battle then return 0 end return 2 end
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
    local want, c = want_cmd(), H.ram(0x60)
    waitUntil = f + 6
    if c < want then return { down = true } end
    if c > want then return { up = true } end
    step = want == 2 and "spell" or "target"; waitUntil = f + 30
    return { a = true }
  elseif step == "spell" then
    if battle == 1 then H.shot("battle-call-menu") end
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

local doneCases = 0
emu.addMemoryCallback(function()
  if cast and cast.done and cast.battle == battle and not cast.counted then
    cast.counted = true; doneCases = doneCases + 1
  end
  if doneCases == #cases then
    H.mark_scenario_complete()
    H.finish(fails == 0 and 0 or 1)
  end
end, EXEC, off(0x00EDB1), off(0x00EDB1), emu.cpuType.snes, ROM)

table.insert(H.on_finish, function()
  out("%d of %d cases ran", doneCases, #cases)
  local f = assert(io.open(H.OUT .. "/result.txt", "w"))
  f:write(table.concat(results, "\n"), "\n"); f:close()
end)
