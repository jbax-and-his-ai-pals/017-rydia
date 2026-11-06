-- Call test: pact monsters, then summon one from Call (asm/call.asm).
-- Fixture as in pact.lua: event $10 loads the overworld, then fights each
-- formation in FORMS, reloading the map after each.
-- Battle 1 uses Pact until it ends; later battles cast Call slot SLOT once,
-- then Fight.
-- Env: FORMS (default "21,21"), SYM (path to build/rydia.sym),
--      SLOT (default 0; the cursor moves right SLOT times, so same row only),
--      SEED=1: at battle 1, Rydia owns species 01-18 and all 24 roster entries
--        are filled with them. New pacts must then join only the pool.
--      BLACK=1: battle 2 first casts the first Black spell and checks its MP.
-- Writes result.txt: checks plus a PASS/FAIL summary; screenshots call_NNN.png.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
H.require_scenario_completion()
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
local SEED = os.getenv("SEED") == "1"
local BLACK = os.getenv("BLACK") == "1"
local ROSTER, CUR, LIST, NSLOTS = 0x119E, 0x11BE, 0x15C0, 24
local ROUTE = H.symbol("call_route")
local SLOT_IDS, SLOT_OF = H.symbol("slot_ids"), H.symbol("slot_of")

local results, fails = {}, 0
local function out(fmt, ...) local s = string.format(fmt, ...); results[#results + 1] = s; H.log("%s", s) end
local function check(ok, fmt, ...)
  if not ok then fails = fails + 1; H.fail() end
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

-- Find the real Pact->roster JSL in the emitted bank-$03 handler. Compare the
-- caller state at that instruction and its return address to test the ABI.
local roster_add = H.symbol("call_roster_add")
local roster_add_site
for a = 0x03FEE3, 0x03FF60 - 4 do
  if rom(a) == 0x22 and rom(a + 1) == (roster_add & 0xFF)
      and rom(a + 2) == ((roster_add >> 8) & 0xFF)
      and rom(a + 3) == ((roster_add >> 16) & 0xFF) then
    roster_add_site = a
    break
  end
end
assert(roster_add_site, "could not locate Pact JSL to call_roster_add")
local abi_regs = {
  { "A", "a" }, { "X", "x" }, { "Y", "y" }, { "PS", "ps" },
  { "DBR", "dbr" }, { "D", "d" }, { "SP", "sp" },
}
local abi_before, abi_species, abiChecks = nil, nil, 0
local latestAddedSpecies, latestAddedBattle = nil, nil
local rosterAtAdd = nil       -- live roster when the latest pact formed
local battle = 0
local function cpu_snapshot()
  local state, snap = emu.getState(), {}
  for _, reg in ipairs(abi_regs) do snap[reg[2]] = state["cpu." .. reg[2]] end
  return snap
end
local function abi_values_equal(before, after)
  if not before or not after then return false end
  for _, reg in ipairs(abi_regs) do
    local key = reg[2]
    if before[key] == nil or after[key] == nil or before[key] ~= after[key] then return false end
  end
  return true
end
emu.addMemoryCallback(function()
  abi_before = cpu_snapshot()
  abi_species = (abi_before.y or 0) & 0xFF
  rosterAtAdd = H.dump(ROSTER, NSLOTS)
end, EXEC, off(roster_add_site), off(roster_add_site), emu.cpuType.snes, ROM)
emu.addMemoryCallback(function()
  local after = cpu_snapshot()
  local same = abi_values_equal(abi_before, after)
  check(same, "call_roster_add preserves A/X/Y/PS/DBR/D/SP at $%06X (species %02X)", roster_add_site, abi_species or 0)
  abiChecks = abiChecks + 1
  out("roster_add ABI before A/X/Y/PS/DBR/D/SP=%s/%s/%s/%s/%s/%s/%s after=%s/%s/%s/%s/%s/%s/%s",
    tostring(abi_before and abi_before.a), tostring(abi_before and abi_before.x), tostring(abi_before and abi_before.y),
    tostring(abi_before and abi_before.ps), tostring(abi_before and abi_before.dbr), tostring(abi_before and abi_before.d),
    tostring(abi_before and abi_before.sp), tostring(after.a), tostring(after.x), tostring(after.y),
    tostring(after.ps), tostring(after.dbr), tostring(after.d), tostring(after.sp))
  latestAddedSpecies, latestAddedBattle = abi_species, battle
  abi_before, abi_species = nil, nil
end, EXEC, off(roster_add_site + 4), off(roster_add_site + 4), emu.cpuType.snes, ROM)

-- Battles.
local battleSnapshots = {}
local seeded = nil
local successfulPactChecks = 0
emu.addMemoryCallback(function()
  if battle > 0 then out("battle %d over: $29CD=%02X roster %s", battle, H.ram(0x29CD), H.dump(ROSTER, 5)) end
  battle = battle + 1
  out("battle %d starts: formation %02X", battle, emu.getState()["cpu.a"] & 0xFF)
  if SEED and battle == 1 then
    for a = 0x1181, 0x11B7 do H.wram_write(a, 0) end
    for sp = 1, 24 do                          -- own species 01-18, all active
      H.wram_write(0x1181 + (sp >> 3), H.ram(0x1181 + (sp >> 3)) | (1 << (sp & 7)))
      H.wram_write(ROSTER + sp - 1, sp + 1)
    end
    seeded = H.dump(ROSTER, NSLOTS)
  elseif SEED and battle == 2 then
    check(H.dump(ROSTER, NSLOTS) == seeded, "a full roster keeps its 24; new pacts only join the pool")
    check(H.ram(0x1181) & 0x01 ~= 0 and H.ram(0x1184) & 0x04 ~= 0, "the new pacts (00, 1A) are owned")
  end
end, EXEC, off(0x00E394), off(0x00E394), emu.cpuType.snes, ROM)

-- After the battle-start hook and the spell menu build ($03:8A7A): roster,
-- snapshot, Call list and the menu's MP for each slot.
local menuMp = {}
emu.addMemoryCallback(function()
  out("battle %d menu: roster %s list %s", battle, H.dump(ROSTER, 8), H.dump(LIST, 8))
  battleSnapshots[battle] = H.dump(ROSTER, NSLOTS)
  local listOK = true
  for i = 0, NSLOTS - 1 do
    local sp = H.ram(ROSTER + i)
    if H.ram(LIST + i) ~= (sp ~= 0 and rom(SLOT_IDS + i) or 0) then listOK = false end
  end
  check(listOK, "battle %d: Call list = slot tokens of the filled roster entries", battle)
  -- $2C7A: 4 bytes per entry, +1 spell, +3 MP
  for e = 0, 359 do
    local id = H.ram(0x2C7B + 4 * e)
    local slot = rom(SLOT_OF + id)
    if id ~= 0 and slot ~= 0xFF and H.ram(ROSTER + slot) ~= 0 and H.ram(ROSTER + slot) < 225 then
      local sp = H.ram(ROSTER + slot) - 1
      local want = 1 + (mon_level(sp) >> 1)
      menuMp[id] = H.ram(0x2C7D + 4 * e)
      check(menuMp[id] == want, "menu MP for %02X (species %02X, Lv %d) = %d (want %d)", id, sp, mon_level(sp), menuMp[id], want)
    end
  end
end, EXEC, off(0x038A7A), off(0x038A7A), emu.cpuType.snes, ROM)

-- After Pact resolves, the saved battle snapshot must stay fixed while the
-- field-facing Call spell IDs immediately reflect the updated active roster.
emu.addMemoryCallback(function()
  if H.ram(0x26D1) ~= 0x14 then return end
  local saved = battleSnapshots[battle]
  -- Occupied entries never change mid-battle; a new pact may only fill an empty one.
  local stable = saved ~= nil
  for i = 0, NSLOTS - 1 do
    local was = saved and tonumber(saved:sub(i * 3 + 1, i * 3 + 2), 16) or 0
    if was ~= 0 and H.ram(ROSTER + i) ~= was then stable = false end
  end
  check(stable, "battle %d Pact leaves occupied roster entries unchanged", battle)
  local listOK = true
  for i = 0, NSLOTS - 1 do
    local species1 = H.ram(ROSTER + i)
    local expected = species1 ~= 0 and rom(SLOT_IDS + i) or 0
    if H.ram(LIST + i) ~= expected then listOK = false end
  end
  check(listOK, "battle %d Pact immediately projects the roster to the Call list (%s)",
    battle, H.dump(LIST, 8))
  if latestAddedSpecies ~= nil and latestAddedBattle == battle then
    local captured1 = latestAddedSpecies + 1
    local found, full = false, rosterAtAdd ~= nil and not rosterAtAdd:find("00")
    for i = 0, NSLOTS - 1 do if H.ram(ROSTER + i) == captured1 then found = true end end
    if full then
      -- All entries were chosen: the pact joins the pool, the roster stays.
      found = H.dump(ROSTER, NSLOTS) == rosterAtAdd
      check(found, "full roster keeps its entries after pacting %02X", latestAddedSpecies)
    else
      check(found, "captured species %02X is in live roster %s", latestAddedSpecies, H.dump(ROSTER, 5))
    end
    if stable and listOK and found then successfulPactChecks = successfulPactChecks + 1 end
  end
  latestAddedSpecies, latestAddedBattle = nil, nil
end, EXEC, off(0x03B05D), off(0x03B05D), emu.cpuType.snes, ROM)

-- The summon.
local cast = nil
emu.addMemoryCallback(function()
  -- call_route runs for every magic cast; keep Rydia's casts of a filled slot token.
  if H.ram(0x2680) & 0x1F ~= 0x11 then return end
  local a = H.ram(0x26D2)
  local slot = rom(SLOT_OF + a)
  if slot == 0xFF or H.ram(ROSTER + slot) == 0 then return end
  local ce = H.ram(0xCE)
  local ms = ce & 7
  local rec = 0x2000 + 0x80 * (ms + 5)
  cast = { spell = a, slot = slot, species = H.ram(ROSTER + slot) - 1, ce = ce, rec = rec, hp = H.ram16(rec + 7), frame = H.frame }
  out("summon: token %02X (slot %d), target $CE=%02X HP %d", a, slot, ce, cast.hp)
end, EXEC, off(ROUTE), off(ROUTE), emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  if not cast or cast.data then return end
  cast.data = H.dump(0x289C, 6)
  local sp = cast.species
  out("cast data: $26D2=%02X call_cur=%02X $289C=%s, Rydia Lv %d", H.ram(0x26D2), H.ram(CUR), cast.data, H.ram(0x2682))
  check(H.ram(0x26D2) == 0x4D, "effect spell %02X (every pact slot summons as $4D)", H.ram(0x26D2))
  check(H.ram(CUR) == sp + 1, "call_cur = species+1 (%02X)", H.ram(CUR))
  local row = H.symbol("call_ability_table") + 8 * sp
  cast.live = rom(row) & 1 == 1
  if cast.live then
    -- a curated signature ability (data/monsters.csv, asm/ability.asm)
    check(H.ram(0x289E) == rom(row + 4) and H.ram(0x289F) == rom(row + 5) and H.ram(0x28A0) == rom(row + 6),
      "signature ability data: hit %02X, effect %02X, element %02X", H.ram(0x289E), H.ram(0x289F), H.ram(0x28A0))
    return
  end
  local pw = math.max(1, ((mon_level(sp) + H.ram(0x2682)) * 5) >> 4)
  check(H.ram(0x289D) == pw and H.ram(0x289E) == 0x64 and H.ram(0x289F) == 0 and H.ram(0x28A0) == 0,
    "hit data power %d (want %d), hit %02X, effect %02X, element %02X", H.ram(0x289D), pw, H.ram(0x289E), H.ram(0x289F), H.ram(0x28A0))
end, EXEC, off(0x03CDCA), off(0x03CDCA), emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  if not cast or not cast.data or cast.done then return end
  cast.done = true
  local hp = H.ram16(cast.rec + 7)
  if not cast.live then check(hp < cast.hp, "target HP %d -> %d", cast.hp, hp) end
  cast.after = H.frame
end, EXEC, off(0x03B05D), off(0x03B05D), emu.cpuType.snes, ROM)

table.insert(H.on_frame, function(f)
  if cast and f > cast.frame and (f - cast.frame) % 15 == 0 and f - cast.frame <= 300 then
    H.shot(string.format("call_%03d", f - cast.frame))
  end
end)

-- Input: drive the real battle menu ($D7 open, $1823 = 1 command list,
-- $1820 opening animation, $60 command cursor: 0 Fight 1 Black 2 Call 3 Item 4 Pact).
local step, waitUntil, closingSince, moved, moves = "idle", 0, 0, 0, 0
local blackAt = nil
local mpBefore = nil
local function want_cmd()
  if battle == 1 then return 4 end
  if BLACK and not blackAt then return 1 end
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
    if want == 2 then
      mpBefore = rydia_mp()
      if blackAt and not blackAt.checked then
        blackAt.checked = true
        check(blackAt.mp - mpBefore == blackAt.cost, "Black %02X: MP %d -> %d (cost %d)", blackAt.id, blackAt.mp, mpBefore, blackAt.cost)
      end
      step = "spell"; moved = 0; moves = SLOT
    elseif want == 1 then
      local id = H.ram(0x15A8)
      blackAt = { mp = rydia_mp(), id = id, cost = rom(0x0F97A5 + 6 * id) & 0x7F }
      step = "spell"; moved = 0; moves = 0
    else step = "target" end
    waitUntil = f + 30
    return { a = true }
  elseif step == "spell" then
    -- spell list: the cursor starts on slot 0; move right SLOT times, A, then A on the target
    waitUntil = f + 30
    if moved < moves then moved = moved + 1; return { right = true } end
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
  out("end: battles %d of %d, roster %s next %02X, Rydia MP %d", battle, #forms, H.dump(ROSTER, 8), H.ram(0x119D), rydia_mp())
  H.shot("end")
  check(battle >= #forms, "all %d battles started (%d)", #forms, battle)
  check(abiChecks > 0, "call_roster_add ABI checked at least once (%d)", abiChecks)
  check(successfulPactChecks > 0, "a successful mid-battle Pact updated the live Call list and preserved its snapshot (%d)", successfulPactChecks)
  check(cast ~= nil and cast.done == true, "a summon ran and finished")
  if battle >= #forms and cast ~= nil and cast.done == true then H.mark_scenario_complete() end
  if BLACK then check(blackAt ~= nil and blackAt.checked == true, "a Black spell was cast and its MP checked") end
  if cast and mpBefore then
    local want = menuMp[cast.spell] or -1
    check(mpBefore - rydia_mp() == want, "MP %d -> %d (cost %d)", mpBefore, rydia_mp(), want)
    out("summoned species %02X: name %s", cast.species, mon_name(cast.species))
  end
  out("%s: %d failed checks", fails == 0 and "ALL PASS" or "FAILURES", fails)
  local fo = io.open(H.OUT .. "/result.txt", "w")
  fo:write(table.concat(results, "\n") .. "\n"); fo:close()
end)
