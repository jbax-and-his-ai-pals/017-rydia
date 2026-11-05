-- Replace the opening event ($10) with a custom script and log world state.
-- Env: EVENT = hex bytes for event $10 (default: arrive at Mysidia on the Big Whale),
--      POKES = optional "addr:hex;addr:hex" WRAM writes applied when the event starts.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
local ROM = emu.memType.snesPrgRom
local function off(snes) return ((snes >> 16) & 0x7F) * 0x8000 + ((snes & 0xFFFF) - 0x8000) end

local script = os.getenv("EVENT") or "FEFB99C706FF"
local i = 0
for byte in script:gmatch("%x%x") do emu.write(off(0x1283E0) + i, tonumber(byte, 16), ROM); i = i + 1 end
H.log("event $10 = %s", script)

local started = nil
emu.addMemoryCallback(function()
  if started then return end
  started = H.frame
  for addr, hex in (os.getenv("POKES") or ""):gmatch("(%x+):(%x+)") do
    local a = tonumber(addr, 16)
    for j = 0, #hex // 2 - 1 do H.wram_write(a + j, tonumber(hex:sub(2 * j + 1, 2 * j + 2), 16)) end
    H.log("poked $%04X = %s", a, hex)
  end
end, emu.callbackType.exec, off(0x00DF63), off(0x00DF63), emu.cpuType.snes, ROM)

H.override = function(f)
  if not started and f >= 320 and f % 16 < 2 then return { a = true } end
  -- AFTER_A=n: press A for 4 frames, n frames after the event starts.
  local n = tonumber(os.getenv("AFTER_A") or "")
  if started and n and f - started >= n and f - started < n + 4 then return { a = true } end
  return {}
end

local last = ""
table.insert(H.on_frame, function(f)
  local s = string.format("1700: %s | veh 1718: %s", H.dump(0x1700, 8), H.dump(0x1718, 16))
  if s ~= last then H.log("%s", s); last = s end
end)
