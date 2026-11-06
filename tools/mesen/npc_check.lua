-- NPC flag check for one map: New Game (built patch), but event $10 loads
-- EVENT instead of the overworld (as audit.lua does). Logs every NPC the game
-- tests for visibility ($00:C137, A = NPC ID low byte) with the bank it uses
-- ($0FE5 bit 7 or $1701) and the flag bit it reads. Writes result.txt and a
-- screenshot "map".
-- Optional EXPECT=042:1,043:1 asserts visibility reads; MAP=00C asserts arrival.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
H.require_scenario_completion()
local expected = {}
for id, bit in (os.getenv("EXPECT") or ""):gmatch("(%x+):([01])") do
  expected[tonumber(id, 16)] = tonumber(bit)
end
local expectedMap = tonumber(os.getenv("MAP") or "", 16)
local ROM, EXEC = emu.memType.snesPrgRom, emu.callbackType.exec
local function off(snes) return ((snes >> 16) & 0x7F) * 0x8000 + ((snes & 0xFFFF) - 0x8000) end

local i = 0
for byte in (os.getenv("EVENT") or ""):gmatch("%x%x") do emu.write(off(0x1283E0) + i, tonumber(byte, 16), ROM); i = i + 1 end

local started, arrived, seen, lines = false, nil, {}, {}
emu.addMemoryCallback(function()
  if (emu.getState()["cpu.a"] & 0xFF) == 0x10 then started = true end
end, EXEC, off(0x00DF63), off(0x00DF63), emu.cpuType.snes, ROM)
emu.addMemoryCallback(function()
  if not started then return end
  local low = emu.getState()["cpu.a"] & 0xFF
  local bank = ((H.ram(0x0FE5) & 0x80) ~= 0 or H.ram(0x1701) ~= 0) and 1 or 0
  local id = bank * 256 + low
  if seen[id] ~= nil then return end
  local bit = (H.ram(0x12E0 + (id >> 3)) >> (id & 7)) & 1
  seen[id] = bit
  lines[#lines + 1] = string.format("npc %03X flag=%d map=%02X%02X 0FE5=%02X", id, bit, H.ram(0x1701), H.ram(0x1702), H.ram(0x0FE5))
end, EXEC, off(0x00C137), off(0x00C137), emu.cpuType.snes, ROM)

H.override = function(f)
  if not started and f >= 320 and f < 420 and f % 16 < 2 then return { a = true } end
  return {}
end

table.insert(H.on_frame, function(f)
  if started and not arrived then arrived = f end
  if arrived and f - arrived == 240 then
    local map = (H.ram(0x1701) << 8) | H.ram(0x1702)
    if expectedMap and map ~= expectedMap then
      H.fail(string.format("map %03X, expected %03X", map, expectedMap))
    end
    for id, bit in pairs(expected) do
      if seen[id] ~= bit then
        H.fail(string.format("NPC %03X visibility %s, expected %d", id, tostring(seen[id]), bit))
      end
    end
    H.shot("map")
    local fo = io.open(H.OUT .. "/result.txt", "w")
    for _, s in ipairs(lines) do fo:write(s .. "\n") end
    fo:close()
    H.mark_scenario_complete()
    H.finish(0)
  end
end)
