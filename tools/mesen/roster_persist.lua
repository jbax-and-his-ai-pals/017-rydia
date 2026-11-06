-- Phase 4: the real save/load path preserves ownership, roster order, and ring
-- position, then repairs derived roster state and the field Call projection.
-- Modes: MODE=roster (default) checks a populated roster; MODE=legacy checks
-- that an ownership-only save is upgraded from its owned species on load.
-- The menu is driven through RAM like persist.lua; no lifecycle routine is
-- invoked by the fixture.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
H.require_scenario_completion()
local ROM, SRAM = emu.memType.snesPrgRom, emu.memType.snesSaveRam
local function off(snes) return ((snes >> 16) & 0x7F) * 0x8000 + ((snes & 0xFFFF) - 0x8000) end

local MODE = os.getenv("MODE") or "roster"
if MODE ~= "roster" and MODE ~= "legacy" then error("MODE must be roster or legacy") end

local ID, OWN, OWN_N = 0x1180, 0x1181, 28
local RING, ROSTER, ROSTER_N = 0x119D, 0x119E, 16
local SNAP, SNAP_N, CUR, TMP = 0x11AE, 16, 0x11BE, 0x11BF
local CALL_LIST, CALL_N = 0x15C0, 24
local ACTIVE_N, SLOT_FIRST = 5, 0x31
local A_SPECIES, B_SPECIES = { 0, 1, 2, 3, 5, 26 }, { 10, 12, 14, 16, 18, 20 }
local A_ROSTER, B_ROSTER = { 27, 1, 6, 3, 4 }, { 21, 11, 19, 13, 17 }
local A_RING, B_RING = 3, 1
local b_slot, load_stub_seen = nil, false

local function bytes_equal(addr, expected, n)
  for i = 0, n - 1 do if H.ram(addr + i) ~= expected[i + 1] then return false end end
  return true
end

local function ownership_bytes(species)
  local bits = {}
  for i = 1, OWN_N do bits[i] = 0 end
  for _, s in ipairs(species) do
    local i = (s >> 3) + 1
    bits[i] = bits[i] | (1 << (s & 7))
  end
  return bits
end

local function fixture(species, roster, ring, eidolons, legacy)
  local own = ownership_bytes(species)
  local active = {}
  if not legacy then
    for i = 1, ACTIVE_N do active[i] = roster[i] end
  end
  for i = #active + 1, ROSTER_N do active[i] = 0 end
  local list = {}
  for i = 1, CALL_N do list[i] = 0 end
  -- Old slot spell IDs are deliberately mixed with ordinary eidolons and
  -- duplicates. Restore should rebuild $31-$35 and keep each eidolon once.
  list[1], list[2], list[3], list[4], list[5], list[6] = eidolons[1], 0x31, eidolons[2], 0x32, 0x31, eidolons[1]
  return { ownership = own, roster = active, ring = legacy and 0 or ring, list = list }
end

local A = fixture(A_SPECIES, A_ROSTER, A_RING, { 0x36, 0x37 }, MODE == "legacy")
local B = fixture(B_SPECIES, B_ROSTER, B_RING, { 0x38, 0x39 }, false)
local EXPECTED_ROSTER = MODE == "legacy" and { 1, 2, 3, 4, 6 } or A_ROSTER
local EXPECTED_RING = MODE == "legacy" and 0 or A_RING

local function poke_fixture(f)
  H.wram_write(ID, 0)
  for i = 1, OWN_N do H.wram_write(OWN + i - 1, f.ownership[i]) end
  H.wram_write(RING, f.ring)
  for i = 1, ROSTER_N do H.wram_write(ROSTER + i - 1, f.roster[i]) end
  for i = 0, SNAP_N - 1 do H.wram_write(SNAP + i, 0xA0 + i) end
  H.wram_write(CUR, 0xCC)
  H.wram_write(TMP, 0xDD)
  for i = 1, CALL_N do H.wram_write(CALL_LIST + i - 1, f.list[i]) end
end

local function sram_addr(slot, wram_addr) return slot * 0x800 + (wram_addr - 0x1000) end
local function sram_fixture_is(slot, f)
  if emu.read(sram_addr(slot, ID), SRAM) ~= 0 then return false end
  for i = 1, OWN_N do if emu.read(sram_addr(slot, OWN + i - 1), SRAM) ~= f.ownership[i] then return false end end
  if emu.read(sram_addr(slot, RING), SRAM) ~= f.ring then return false end
  for i = 1, ROSTER_N do if emu.read(sram_addr(slot, ROSTER + i - 1), SRAM) ~= f.roster[i] then return false end end
  return emu.read(slot * 0x800 + 0x7FE, SRAM) == 0xE4 and emu.read(slot * 0x800 + 0x7FF, SRAM) == 0x1B
end

local pulse, pulseLeft = nil, 0
local function press(btn) if pulseLeft <= 0 then pulse = { [btn] = true }; pulseLeft = 2 end end
local stepStart, waitUntil = 0, 0
local function pause(n) if waitUntil == 0 then waitUntil = H.frame + n end; if H.frame >= waitUntil then waitUntil = 0; return true end end
local function every(n) return (H.frame - stepStart) % n == 0 end
local function menu_to(addr, target, confirm)
  if H.ram(addr) == target then if every(20) then press("a") end return confirm() end
  if every(12) then press(H.ram(addr) < target and "down" or "up") end
end

local events = 0
emu.addMemoryCallback(function() events = events + 1 end, emu.callbackType.exec,
  off(0x00DF63), off(0x00DF63), emu.cpuType.snes, ROM)
local load_stub = off(H.symbol("call_field_load_stub"))
emu.addMemoryCallback(function()
  load_stub_seen = true
  H.log("observed call_field_load_stub at $%06X", H.symbol("call_field_load_stub"))
end, emu.callbackType.exec, load_stub, load_stub, emu.cpuType.snes, ROM)

local results, failures = {}, 0
local function record(ok, description)
  results[#results + 1] = string.format("%s %s", ok and "PASS:" or "FAIL:", description)
  H.log("%s", results[#results])
  if not ok then failures = failures + 1; H.fail(description) end
  return ok
end

local steps = {
  { "boot to New Game", function() if events > 0 then return true end if every(16) then press("a") end end },
  { "settle on the world map", function() return pause(180) end },
  { "write fixture A", function() poke_fixture(A); return true end },
  { "open field menu", function() if H.ram(0x0500) ~= 0 then return true end if every(30) then press("x") end end },
  { "choose Save", function() return menu_to(0x1A76, 7, function() return H.ram(0x1B47) ~= 0 end) end },
  { "save fixture A to slot 1", function()
      if sram_fixture_is(0, A) then record(true, "fixture A stored in SRAM slot 1"); return true end
      if every(30) then press("a") end
    end },
  { "write distinct fixture B", function() poke_fixture(B); return pause(60) end },
  { "dismiss save confirmation", function() if every(60) then press("a") end return pause(90) end },
  { "let save menu settle", function() return pause(60) end },
  { "return to save screen", function()
      if H.ram(0x1B47) ~= 0 then return true end
      if H.ram(0x0500) == 0 then if every(30) then press("x") end return end
      return menu_to(0x1A76, 7, function() return H.ram(0x1B47) ~= 0 end)
    end },
  { "move to another save slot", function() press("down"); return pause(30) end },
  { "save fixture B to another slot", function()
      for slot = 1, 3 do
        if sram_fixture_is(slot, B) then
          b_slot = slot
          record(true, string.format("fixture B stored in SRAM slot %d", slot + 1))
          return true
        end
      end
      if sram_fixture_is(0, B) then record(false, "fixture B overwrote save slot 1"); H.finish(1); return end
      if every(30) then press("a") end
    end },
  { "confirm independent saved fixtures", function()
      if not b_slot or not sram_fixture_is(0, A) or not sram_fixture_is(b_slot, B) then
        record(false, "save A or B does not match its independent fixture"); H.finish(1); return
      end
      record(true, string.format("fixture A is separate from fixture B in SRAM slot %d", b_slot + 1))
      return true
    end },
  { "reset", function() poke_fixture(fixture({}, {}, 0, { 0x36, 0x37 }, true)); emu.reset(); return true end },
  { "wait for title screen", function() return pause(330) end },
  { "open load list", function()
      local t = H.frame - stepStart
      if t == 100 then press("a") end
      if t == 210 then H.shot("load_screen") end
      return pause(220)
    end },
  { "select and load Save 1", function()
      if load_stub_seen then return true end
      local cursor = H.ram(0x1A3C)
      if cursor == 1 then
        if every(20) then press("a") end
      elseif every(12) then
        press(cursor < 1 and "down" or "up")
      end
      if H.frame - stepStart == 90 then H.shot("load_cursor") end
    end },
  { "settle after load", function() return pause(240) end },
  { "check restored roster state", function()
      local ok = true
      ok = record(H.ram(ID) == 0, "$1180 remains zero") and ok
      ok = record(bytes_equal(OWN, A.ownership, OWN_N), "ownership bits match fixture A") and ok
      for i = 1, ACTIVE_N do
        ok = record(H.ram(ROSTER + i - 1) == EXPECTED_ROSTER[i], string.format("active roster slot %d = %02X", i, EXPECTED_ROSTER[i])) and ok
      end
      for i = ACTIVE_N + 1, ROSTER_N do
        ok = record(H.ram(ROSTER + i - 1) == 0, string.format("unused roster byte %d is zero", i)) and ok
      end
      ok = record(H.ram(RING) == EXPECTED_RING, string.format("ring index = %d", EXPECTED_RING)) and ok
      local snapshot_zero = true
      for i = 0, SNAP_N - 1 do if H.ram(SNAP + i) ~= 0 then snapshot_zero = false end end
      ok = record(snapshot_zero, "all 16 battle snapshot bytes are cleared") and ok
      ok = record(H.ram(CUR) == 0, "current summon byte is cleared") and ok
      ok = record(H.ram(TMP) == 0, "scratch byte is cleared") and ok
      for i = 0, ACTIVE_N - 1 do
        ok = record(H.ram(CALL_LIST + i) == SLOT_FIRST + i, string.format("field Call slot %d = %02X", i + 1, SLOT_FIRST + i)) and ok
      end
      local tail = { 0x36, 0x37 }
      ok = record(H.ram(CALL_LIST + ACTIVE_N) == tail[1], "eidolon $36 retained once at front of tail") and ok
      ok = record(H.ram(CALL_LIST + ACTIVE_N + 1) == tail[2], "eidolon $37 retained once in tail") and ok
      for i = ACTIVE_N + 2, CALL_N - 1 do
        ok = record(H.ram(CALL_LIST + i) == 0, string.format("field Call tail byte %d is zero", i)) and ok
      end
      ok = record(sram_fixture_is(0, A), "SRAM slot 1 still contains fixture A") and ok
      ok = record(b_slot ~= nil and sram_fixture_is(b_slot, B), "SRAM slot for fixture B remains unchanged") and ok
      ok = record(load_stub_seen, "actual call_field_load_stub executed during load") and ok
      if ok and failures == 0 then H.mark_scenario_complete(); H.shot("loaded"); H.finish(0)
      else H.shot("loaded"); H.finish(1) end
      return true
    end },
}

local idx = 1
H.override = function()
  if pulseLeft > 0 then pulseLeft = pulseLeft - 1; return pulse end
  return {}
end
table.insert(H.on_frame, function(f)
  local s = steps[idx]
  if not s then return end
  if f - stepStart > 1500 then
    H.log("TIMEOUT in step '%s' ($0500=%02X $1A76=%02X $1B47=%02X $1A3C=%02X)",
      s[1], H.ram(0x0500), H.ram(0x1A76), H.ram(0x1B47), H.ram(0x1A3C))
    H.shot("timeout"); H.finish(2); return
  end
  if s[2]() then
    H.log("done: %s", s[1])
    idx = idx + 1; stepStart = f
  end
end)

table.insert(H.on_finish, function()
  local save = assert(io.open(H.OUT .. "/sram.srm", "wb"))
  for i = 0, emu.getMemorySize(SRAM) - 1 do save:write(string.char(emu.read(i, SRAM))) end
  save:close()
  H.log("end: mode=%s step=%s ownership=%s roster=%s ring=%02X call-list=%s",
    MODE, idx <= #steps and steps[idx][1] or "complete", H.dump(OWN, OWN_N), H.dump(ROSTER, ROSTER_N),
    H.ram(RING), H.dump(CALL_LIST, CALL_N))
  H.shot("end")
  local fo = assert(io.open(H.OUT .. "/result.txt", "w"))
  fo:write(string.format("mode=%s\n", MODE), table.concat(results, "\n"), "\n",
    string.format("failures=%d\n", failures),
    string.format("final ownership=%s\nfinal roster=%s\nfinal ring=%02X\nfinal call-list=%s\n",
      H.dump(OWN, OWN_N), H.dump(ROSTER, ROSTER_N), H.ram(RING), H.dump(CALL_LIST, CALL_N)))
  fo:close()
end)
