-- Phase 3 test: the Pact command on the built patch.
-- Only the fight fixture is patched in memory: event $10 loads the overworld as
-- usual, then fights the formations in FORMS one after another, reloading the
-- map after each (without that the screen stays garbled after the last fight,
-- with Fight as well as Pact). Rydia's menu is
-- the built one (Fight Black Call Item Pact), driven through the real menu.
-- Env:
--   FORMS    comma list of formation numbers in hex, e.g. "21,82"
--   ACTIONS  per battle, separated by ';': a comma list of P (Pact) / F (Fight);
--            the last entry repeats. Default: P for every battle.
-- Writes result.txt: one line per Pact action plus a PASS/FAIL summary.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
H.require_scenario_completion()
local ROM = emu.memType.snesPrgRom
local EXEC = emu.callbackType.exec
local function off(snes) return ((snes >> 16) & 0x7F) * 0x8000 + ((snes & 0xFFFF) - 0x8000) end
local function rom(snes) return emu.read(off(snes), ROM) end

local START = { 0xFE, 0xFB, 0x9A, 0xC8, 0x00 }  -- load overworld outside Mysidia (tools/late_game.py)
local forms = {}
for x in (os.getenv("FORMS") or "21"):gmatch("%x+") do forms[#forms + 1] = tonumber(x, 16) end
local ev = { table.unpack(START) }
for _, fm in ipairs(forms) do
  ev[#ev + 1] = 0xEC; ev[#ev + 1] = fm
  for _, b in ipairs(START) do ev[#ev + 1] = b end  -- reload the map after each fight
end
ev[#ev + 1] = 0xFF
for i, b in ipairs(ev) do emu.write(off(0x1283E0) + i - 1, b, ROM) end

local plans = {}
for p in ((os.getenv("ACTIONS") or "") .. ";"):gmatch("([^;]*);") do
  local t = {}
  for a in p:gmatch("[PF]") do t[#t + 1] = a end
  plans[#plans + 1] = t
end

local results, fails = {}, 0
local function out(fmt, ...) local s = string.format(fmt, ...); results[#results + 1] = s; H.log("%s", s) end
local function check(ok, fmt, ...)
  if not ok then fails = fails + 1; H.fail() end
  out("%s " .. fmt, ok and "PASS" or "FAIL", ...)
end
local function bits() return H.dump(0x1180, 29) end
local function bit_set(n) return (H.ram(0x1181 + (n >> 3)) >> (n & 7)) & 1 == 1 end
local CAPTURABLE = H.symbol("capturable_table")
local function capturable(n) return (rom(CAPTURABLE + (n >> 3)) >> (n & 7)) & 1 == 1 end

-- Battles.
local battle, battleAt, actionNo = 0, nil, 0
local starts = {}
emu.addMemoryCallback(function()
  if battle > 0 then
    out("battle %d (formation %02X) over: $00A8=%02X, $29CD=%02X", battle, forms[battle], H.ram(0xA8), H.ram(0x29CD))
  end
  battle = battle + 1
  battleAt, actionNo = H.frame, 0
  starts[#starts + 1] = H.frame
  out("battle %d starts: formation %02X", battle, emu.getState()["cpu.a"] & 0xFF)
end, EXEC, off(0x00E394), off(0x00E394), emu.cpuType.snes, ROM)

-- Pact handler: entry, return to the dispatcher's caller, and after $03:B1B0.
local cur, pacts = nil, 0
local resolvedByBattle = {}
emu.addMemoryCallback(function()
  local ce = H.ram(0xCE)
  local s = ce & 7
  local ty = H.ram(0x29B5 + s)
  local sp = ty < 3 and H.ram(0x29AD + ty) or 0xFF
  pacts = pacts + 1
  cur = { ce = ce, slot = s, species = sp, cap = sp < 0xE0 and capturable(sp), had = sp < 0xE0 and bit_set(sp),
          left = H.ram(0x29CD), before = bits(), frame = H.frame }
  out("pact #%d (battle %d): target $CE=%02X slot %d species %02X capturable=%s already=%s left=%d",
    actionNo + 1, battle, ce, s, sp, tostring(cur.cap), tostring(cur.had), cur.left)
end, EXEC, off(0x03FEE3), off(0x03FEE3), emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  if not cur or cur.done then return end
  cur.msg = H.ram(0x34CA)
  cur.script = H.dump(0x33C2, 8)
end, EXEC, off(0x03B02F), off(0x03B02F), emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  if not cur or cur.done or cur.msg == nil then return end
  cur.done = true
  local c = cur
  local gone = H.ram(0x29B5 + c.slot) == 0xFF
  local left = H.ram(0x29CD)
  local after = bits()
  if c.cap then
    check(c.msg == 0x07, "capture message $34CA=%02X (want 07), script %s", c.msg, c.script)
    check(bit_set(c.species), "species %02X bit set: %s", c.species, after)
    check(gone and left == c.left - 1, "slot %d removed ($29B5=%02X), monsters left %d -> %d", c.slot, H.ram(0x29B5 + c.slot), c.left, left)
    -- only this species' bit may change
    local exp = {}
    for i = 0, 28 do exp[i] = H.ram(0x1180 + i) end
    local diff = 0
    for i = 0, 28 do
      local b = tonumber(c.before:sub(i * 3 + 1, i * 3 + 2), 16)
      if b ~= exp[i] then diff = diff + 1 end
    end
    check(diff <= 1 and H.ram(0x1180) == 0, "only one bitfield byte changed (%d), $1180=%02X", diff, H.ram(0x1180))
  else
    check(c.msg == 0x08, "refusal message $34CA=%02X (want 08)", c.msg)
    check(after == c.before, "bitfield unchanged: %s", after)
    check(not gone and left == c.left, "slot %d still there, monsters left %d -> %d", c.slot, c.left, left)
  end
  resolvedByBattle[battle] = (resolvedByBattle[battle] or 0) + 1
  H.shot(string.format("pact%d_%d_a", battle, actionNo + 1))
  c.shotAt = H.frame
  actionNo = actionNo + 1
end, EXEC, off(0x03B05D), off(0x03B05D), emu.cpuType.snes, ROM)

table.insert(H.on_frame, function(f)
  if cur and cur.shotAt and not cur.shot2 and f - cur.shotAt >= 70 then
    cur.shot2 = true
    H.shot(string.format("pact%d_%d_b", battle, actionNo))
  end
end)

-- Input: drive the real battle menu. $D7 = menu open, $1823 = 1 command list,
-- $1820 = opening animation, $60 = command cursor (0 Fight ... 4 Pact).
local step, waitUntil, closingSince = "idle", 0, 0
local function action()
  local plan = plans[battle] or { "P" }
  if #plan == 0 then plan = { "P" } end
  return plan[math.min(actionNo + 1, #plan)]
end
local fightsSeen = 0
emu.addMemoryCallback(function() fightsSeen = fightsSeen + 1 end, EXEC, off(0x03C499), off(0x03C499), emu.cpuType.snes, ROM)

H.override = function(f)
  if battle == 0 then
    if f >= 320 and f < 420 and f % 16 < 2 then return { a = true } end
    return {}
  end
  if f < waitUntil then return {} end
  local open = H.ram(0xD7) == 1 and H.ram(0x1823) == 1 and H.ram(0x1820) == 0
  if step == "idle" then
    if not open then
      -- out of the menu: press A now and then so post-battle messages move on
      if H.ram(0x29CD) == 0 and f % 40 == 0 then return { a = true } end
      return {}
    end
    step = "menu"; waitUntil = f + 8; return {}
  elseif step == "menu" then
    if not open then step = "idle"; return {} end
    local want = action() == "P" and 4 or 0
    local c = H.ram(0x60)
    waitUntil = f + 6
    if c < want then return { down = true } end
    if c > want then return { up = true } end
    step = "target"; waitUntil = f + 14
    if action() == "F" then actionNo = actionNo + 1 end
    return { a = true }
  elseif step == "target" then
    step = "closing"; waitUntil = f + 10; closingSince = f
    return { a = true }
  elseif step == "closing" then
    -- wait for the menu to close (or give up after a second and look again)
    if H.ram(0xD7) == 0 or f - closingSince > 60 then step = "idle" end
    waitUntil = f + 4
    return {}
  end
  return {}
end

table.insert(H.on_finish, function()
  out("end: battles started %d of %d, $29CD=%02X, $00A8=%02X, bitfield %s", battle, #forms, H.ram(0x29CD), H.ram(0xA8), bits())
  H.shot("end")
  -- guard against a run that tests nothing (menu driving broke, fixture didn't fight)
  check(battle >= #forms, "all %d battles started (%d)", #forms, battle)
  check(pacts > 0, "Pact ran %d times", pacts)
  local everyBattleResolved = battle >= #forms
  for b = 1, #forms do
    local resolved = resolvedByBattle[b] or 0
    check(resolved > 0, "battle %d has a resolved Pact (%d)", b, resolved)
    if resolved == 0 then everyBattleResolved = false end
  end
  local unfinished = cur ~= nil and not cur.done
  check(not unfinished, "no unfinished Pact action")
  if everyBattleResolved and not unfinished then H.mark_scenario_complete() end
  out("%s: %d failed checks", fails == 0 and "ALL PASS" or "FAILURES", fails)
  local fo = io.open(H.OUT .. "/result.txt", "w")
  fo:write(table.concat(results, "\n") .. "\n"); fo:close()
end)
