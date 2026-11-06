-- Phase 4: pacts survive save -> reset -> load, and save slots don't share them.
-- New Game; write pattern A into the pact bytes ($1181-$119C); save to slot 1;
-- write pattern B; save to slot 2; reset; load slot 1; expect pattern A.
-- Menus are driven by RAM (addresses from aexoden/edge): field menu open
-- $0500, main cursor $1A76 (7 = Save), save/load menu open $1B47, slot cursor $1A3C.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
H.require_scenario_completion()
local ROM, SRAM = emu.memType.snesPrgRom, emu.memType.snesSaveRam
local function off(snes) return ((snes >> 16) & 0x7F) * 0x8000 + ((snes & 0xFFFF) - 0x8000) end

local PACT, N = 0x1181, 28
local function pattern(seed) local t = {} for i = 0, N - 1 do t[i] = (seed + i * 37) & 0xFF end return t end
local A, B = pattern(0x11), pattern(0x5A)
local function poke(p) for i = 0, N - 1 do H.wram_write(PACT + i, p[i]) end end
local function ram_is(p) for i = 0, N - 1 do if H.ram(PACT + i) ~= p[i] then return false end end return true end
local function sram_is(slot, p)
  local base = slot * 0x800 + (PACT - 0x1000)
  for i = 0, N - 1 do if emu.read(base + i, SRAM) ~= p[i] then return false end end
  return emu.read(slot * 0x800 + 0x7FE, SRAM) == 0xE4 and emu.read(slot * 0x800 + 0x7FF, SRAM) == 0x1B
end

local events = 0
emu.addMemoryCallback(function() events = events + 1 end, emu.callbackType.exec, off(0x00DF63), off(0x00DF63), emu.cpuType.snes, ROM)

-- Step list: each step returns true when done; press(btn) pulses a button.
local pulse, pulseLeft = nil, 0
local function press(btn) if pulseLeft <= 0 then pulse = { [btn] = true }; pulseLeft = 2 end end
local stepStart, waitUntil = 0, 0
local function pause(n) if waitUntil == 0 then waitUntil = H.frame + n end; if H.frame >= waitUntil then waitUntil = 0; return true end end
local function every(n) return (H.frame - stepStart) % n == 0 end
local function menu_to(addr, target, confirm)
  if H.ram(addr) == target then if every(20) then press("a") end return confirm() end
  if every(12) then press(H.ram(addr) < target and "down" or "up") end
end

local steps = {
  { "boot to New Game", function() if events > 0 then return true end if every(16) then press("a") end end },
  { "settle on the world map", function() return pause(180) end },
  { "write pattern A", function() poke(A); return true end },
  { "open field menu", function() if H.ram(0x0500) ~= 0 then return true end if every(30) then press("x") end end },
  { "choose Save", function() return menu_to(0x1A76, 7, function() return H.ram(0x1B47) ~= 0 end) end },
  -- The save screen opens with its cursor on Save 1 ($1A3C is not the slot cursor here).
  { "save to slot 1", function() if sram_is(0, A) then return true end if every(30) then press("a") end end },
  { "write pattern B", function() poke(B); return pause(60) end },
  -- Choosing a slot asks "Save? Yes/No", then shows "Done!" until a button press.
  { "dismiss Done!", function() if every(60) then press("a") end return pause(90) end },
  { "let the menu settle", function() return pause(60) end },
  { "back on the save screen", function()
      H.shot("after_save1")
      if H.ram(0x1B47) ~= 0 then return true end
      if H.ram(0x0500) == 0 then if every(30) then press("x") end return end
      return menu_to(0x1A76, 7, function() return H.ram(0x1B47) ~= 0 end)
    end },
  { "cursor down to Save 2", function() press("down"); return pause(30) end },
  -- One cursor press can move more than one row, so accept any other slot.
  { "save B to another slot", function()
      for k = 1, 3 do if sram_is(k, B) then H.log("pattern B saved to slot %d", k + 1); return true end end
      if sram_is(0, B) then H.log("FAIL: pattern B went to slot 1"); H.finish(1) end
      if every(30) then press("a") end
    end },
  { "slot 1 still holds A", function() if sram_is(0, A) then return true end H.log("FAIL: slot 1 changed"); H.finish(1) end },
  { "reset", function() poke(pattern(0)); emu.reset(); return true end },
  { "wait for the title screen", function() return pause(330) end },
  -- The load list (New Game, Save1-4) opens with the cursor on the last slot
  -- saved (here the one holding B, below Save 1) and doesn't set $1B47, so drive it by timing.
  { "open load list", function()
      local t = H.frame - stepStart
      if t == 100 then press("a") end
      if t == 210 then H.shot("load_screen") end
      return pause(220)
    end },
  { "cursor up to Save 1", function()
      local t = H.frame - stepStart
      if t == 0 or t == 30 then press("up") end
      if t == 90 then H.shot("load_cursor") end
      return pause(100)
    end },
  { "load slot 1", function() if H.frame == stepStart then press("a") end return true end },
  { "settle after load", function() return pause(240) end },
  { "check pattern A in RAM", function()
      local t = {}
      for a = 0, emu.getMemorySize(SRAM) - 1 do t[#t + 1] = string.char(emu.read(a, SRAM)) end
      local fo = io.open(H.OUT .. "/sram.srm", "wb"); fo:write(table.concat(t)); fo:close()
      if ram_is(A) then H.log("PASS: pact bytes after load = pattern A"); H.shot("loaded"); H.mark_scenario_complete(); H.finish(0)
      else H.log("FAIL: pact bytes after load = %s", H.dump(PACT, N)); H.shot("loaded"); H.finish(1) end
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
    H.log("TIMEOUT in step '%s' ($0500=%02X $1A76=%02X $1B47=%02X $1A3C=%02X)", s[1], H.ram(0x0500), H.ram(0x1A76), H.ram(0x1B47), H.ram(0x1A3C))
    H.shot("timeout"); H.finish(2); return
  end
  if s[2]() then
    H.log("done: %s", s[1])
    idx = idx + 1; stepStart = f
  end
end)
