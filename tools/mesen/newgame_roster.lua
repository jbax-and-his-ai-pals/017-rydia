-- Prove New Game clears roster state after an existing roster save is loaded.
-- SAVE is a raw 8 KiB .srm dumped by roster_persist.lua. The harness library
-- clears SRAM first; this script then restores that existing save for the run.
-- No ROM patching or direct roster lifecycle calls are used here.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
H.require_scenario_completion()

local ROM, SRAM = emu.memType.snesPrgRom, emu.memType.snesSaveRam
local function off(snes)
  return ((snes >> 16) & 0x7F) * 0x8000 + ((snes & 0xFFFF) - 0x8000)
end
local SAVE = assert(os.getenv("SAVE"), "SAVE must name an existing .srm file")
local saveFile = assert(io.open(SAVE, "rb"), "could not open SAVE: " .. SAVE)
local saveBytes = saveFile:read("*a")
saveFile:close()
local sramSize = emu.getMemorySize(SRAM)
assert(#saveBytes == sramSize,
  string.format("SAVE length %d does not match SRAM size %d", #saveBytes, sramSize))
for i = 0, sramSize - 1 do emu.write(i, saveBytes:byte(i + 1), SRAM) end
H.log("loaded SAVE=%s (%d SRAM bytes)", SAVE, #saveBytes)

local slotBase = 0 -- title cursor 1 is Save 1; SRAM slot 0 is Save 1
assert(saveBytes:byte(slotBase + 0x7FF + 1) == 0x1B
    and saveBytes:byte(slotBase + 0x7FE + 1) == 0xE4,
  "SAVE slot 1 has no valid FF4 save marker")

local STATE, STATE_N = 0x1180, 64
local CALL_LIST, CALL_N = 0x15C0, 24
local function sram_value(wramAddr)
  return saveBytes:byte(slotBase + wramAddr - 0x1000 + 1)
end
local function check_loaded_authoritative()
  -- The restore routine may repair derived state, but the saved ownership,
  -- replacement cursor and five active roster entries must survive the load.
  for addr = 0x1181, 0x119C do
    if H.ram(addr) ~= sram_value(addr) then
      return false, string.format("ownership byte $%04X differs: WRAM %02X SAVE %02X",
        addr, H.ram(addr), sram_value(addr))
    end
  end
  for addr = 0x119D, 0x11A2 do
    if H.ram(addr) ~= sram_value(addr) then
      return false, string.format("roster/ring byte $%04X differs: WRAM %02X SAVE %02X",
        addr, H.ram(addr), sram_value(addr))
    end
  end
  return true
end
local function source_slot_unchanged()
  for addr = 0x1181, 0x11A2 do
    local off = slotBase + addr - 0x1000
    if emu.read(off, SRAM) ~= saveBytes:byte(off + 1) then
      return false, string.format("source SRAM slot 1 changed at offset $%04X", off)
    end
  end
  for _, off in ipairs({ 0x7FE, 0x7FF }) do
    if emu.read(off, SRAM) ~= saveBytes:byte(off + 1) then
      return false, string.format("source SRAM slot 1 marker changed at $%04X", off)
    end
  end
  return true
end

local loadedRosterCount = 0
for addr = 0x119E, 0x11A2 do
  if saveBytes:byte(slotBase + addr - 0x1000 + 1) ~= 0 then
    loadedRosterCount = loadedRosterCount + 1
  end
end
local ownershipNonzero = false
for addr = 0x1181, 0x119C do
  if saveBytes:byte(slotBase + addr - 0x1000 + 1) ~= 0 then ownershipNonzero = true end
end
assert(loadedRosterCount > 0 and ownershipNonzero,
  "SAVE slot 1 must contain at least one owned species in the active roster")

local loadReadyPC = off(0x01965F)
local loadStubPC = off(H.symbol("call_field_load_stub"))
local newGameConfirmPC = off(0x019648)
local eventPC = off(0x00DF63)
local loadReady, loadHookSeen, newGameConfirmed, injected, event10Started =
  false, false, false, false, false
local phase = "open_load_list"
local pulseButton, pulseLeft = nil, 0

emu.addMemoryCallback(function()
  if phase == "open_load_list" or phase == "open_newgame_list" then
    loadReady = true
  end
end, emu.callbackType.exec, loadReadyPC, loadReadyPC, emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  if phase == "wait_load" then
    loadHookSeen = true
    pulseLeft = 0
    H.log("confirmed load reached call_field_load_stub at frame %d", H.frame)
  end
end, emu.callbackType.exec, loadStubPC, loadStubPC, emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  if phase ~= "confirm_newgame" or H.ram(0x1A3C) ~= 0 then return end
  -- Poison the authoritative and derived state at the actual New Game branch,
  -- after load-list previews, so only the New Game initializer can clear it.
  for addr = STATE, STATE + STATE_N - 1 do H.wram_write(addr, 0xFF) end
  for addr = CALL_LIST, CALL_LIST + CALL_N - 1 do H.wram_write(addr, 0xFF) end
  newGameConfirmed, injected = true, true
  pulseLeft = 0
  phase = "wait_event10"
  H.log("New Game confirm at $01:9648: poisoned $1180-$11BF and $15C0-$15D7")
end, emu.callbackType.exec, newGameConfirmPC, newGameConfirmPC, emu.cpuType.snes, ROM)

emu.addMemoryCallback(function()
  if phase == "wait_event10" and newGameConfirmed
      and (emu.getState()["cpu.a"] & 0xFF) == 0x10 then
    event10Started = true
    H.log("event $10 start reached at frame %d", H.frame)
  end
end, emu.callbackType.exec, eventPC, eventPC, emu.cpuType.snes, ROM)

local function press(btn)
  if pulseLeft <= 0 then pulseButton, pulseLeft = btn, 2 end
end
local stepStart = 0
local function every(n) return (H.frame - stepStart) % n == 0 end
local cursorStableSince, cursorStableTarget = nil, nil
local waitUntil = 0
local function pause(n)
  if waitUntil == 0 then waitUntil = H.frame + n end
  if H.frame >= waitUntil then waitUntil = 0; return true end
end
local function select_cursor(target, label)
  local cursor = H.ram(0x1A3C)
  if cursor ~= target then
    cursorStableSince, cursorStableTarget = nil, nil
    if every(18) then press(cursor < target and "down" or "up") end
    return false
  end
  if cursorStableTarget ~= target then
    cursorStableTarget, cursorStableSince = target, H.frame
  end
  if H.frame - cursorStableSince < 30 then return false end
  if pulseLeft > 0 then return false end
  H.log("confirming %s at title cursor %d", label, cursor)
  press("a")
  return true
end

local steps = {
  { "open initial load list", function()
      if loadReady then return true end
      if every(24) then press("a") end
    end },
  { "select Save 1", function()
      if select_cursor(1, "Save 1") then phase = "wait_load"; return true end
    end },
  { "wait for confirmed load", function()
      if loadHookSeen then
        H.shot("loaded_save")
        local ok, why = check_loaded_authoritative()
        if not ok then H.fail(why); H.shot("load_mismatch"); H.finish(1); return end
        H.log("PASS: loaded ownership, roster, and ring match Save 1")
        return true
      end
      if every(30) then press("a") end
    end },
  { "settle loaded save", function() return pause(180) end },
  { "reset to title", function()
      phase = "open_newgame_list"
      loadReady, loadHookSeen = false, false
      emu.reset()
      return true
    end },
  { "open New Game/load list", function()
      if loadReady then return true end
      if every(24) then press("a") end
    end },
  { "select New Game", function()
      if H.ram(0x1A3C) == 0 and pulseLeft == 0 then phase = "confirm_newgame" end
      if select_cursor(0, "New Game") then return true end
    end },
  { "wait for New Game and event 10", function()
      if event10Started then H.shot("newgame_event10"); return true end
      if not newGameConfirmed and every(30) then press("a") end
    end },
  { "settle New Game", function() return pause(180) end },
  { "verify empty new-game state", function()
      if not injected then H.fail("New Game confirmation poison callback did not run"); return true end
      for addr = STATE, STATE + STATE_N - 1 do
        if H.ram(addr) ~= 0 then
          H.log("FAIL: new-game state $%04X = %02X, expected 00", addr, H.ram(addr))
          H.shot("newgame_state_failure"); H.finish(1); return true
        end
      end
      for addr = CALL_LIST, CALL_LIST + CALL_N - 1 do
        if H.ram(addr) ~= 0 then
          H.log("FAIL: new-game Call list $%04X = %02X, expected 00", addr, H.ram(addr))
          H.shot("newgame_list_failure"); H.finish(1); return true
        end
      end
      if (H.ram(0x1000) & 0x3F) ~= 0x11 then
        H.log("FAIL: party slot 0 ID is %02X, expected adult Rydia $11", H.ram(0x1000) & 0x3F)
        H.shot("party_failure"); H.finish(1); return true
      end
      for _, addr in ipairs({ 0x1040, 0x1080, 0x10C0, 0x1100 }) do
        if H.ram(addr) ~= 0 then
          H.log("FAIL: extra party slot $%04X has ID %02X", addr, H.ram(addr))
          H.shot("party_failure"); H.finish(1); return true
        end
      end
      local ok, why = source_slot_unchanged()
      if not ok then H.fail(why); H.shot("source_sram_failure"); H.finish(1); return true end
      H.log("PASS: poisoned roster state and Call list cleared; adult Rydia alone; source Save 1 unchanged")
      H.shot("newgame_final")
      H.mark_scenario_complete()
      H.finish(0)
      return true
    end },
}

local idx = 1
H.override = function()
  if pulseLeft > 0 then
    pulseLeft = pulseLeft - 1
    return { [pulseButton] = true }
  end
  return {}
end

table.insert(H.on_frame, function(f)
  local step = steps[idx]
  if not step then return end
  if f - stepStart > 1800 then
    H.log("TIMEOUT in '%s': phase=%s cursor=%02X ready=%s loadHook=%s injected=%s event10=%s",
      step[1], phase, H.ram(0x1A3C), tostring(loadReady), tostring(loadHookSeen),
      tostring(injected), tostring(event10Started))
    H.shot("timeout")
    H.fail("timeout in " .. step[1])
    H.finish(2)
    return
  end
  if step[2]() then
    H.log("done: %s", step[1])
    idx = idx + 1
    stepStart = f
  end
end)
