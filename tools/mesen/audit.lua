-- Access audit for one location: New Game (built patch), but event $10 loads
-- EVENT instead of the overworld. Idle, then walk up a few steps, logging any
-- event, fight, party change or map change after arrival. Writes result.txt.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
local ROM, EXEC = emu.memType.snesPrgRom, emu.callbackType.exec
local function off(snes) return ((snes >> 16) & 0x7F) * 0x8000 + ((snes & 0xFFFF) - 0x8000) end

local i = 0
for byte in (os.getenv("EVENT") or ""):gmatch("%x%x") do emu.write(off(0x1283E0) + i, tonumber(byte, 16), ROM); i = i + 1 end

local arrived, notes = nil, {}
local function note(fmt, ...) local s = string.format(fmt, ...); notes[#notes + 1] = s; H.log("%s", s) end

emu.addMemoryCallback(function()
  local ev = emu.getState()["cpu.a"] & 0xFF
  if not arrived then if ev == 0x10 then arrived = H.frame end return end
  note("event %02X at +%d", ev, H.frame - arrived)
end, EXEC, off(0x00DF63), off(0x00DF63), emu.cpuType.snes, ROM)
emu.addMemoryCallback(function()
  if arrived then note("fight %02X at +%d", emu.getState()["cpu.a"] & 0xFF, H.frame - arrived) end
end, EXEC, off(0x00E394), off(0x00E394), emu.cpuType.snes, ROM)
emu.addMemoryCallback(function() if arrived then note("add character") end end, EXEC, off(0x00E578), off(0x00E578), emu.cpuType.snes, ROM)
emu.addMemoryCallback(function() if arrived then note("remove character") end end, EXEC, off(0x00E6AF), off(0x00E6AF), emu.cpuType.snes, ROM)

H.override = function(f)
  if not arrived then
    if f >= 320 and f < 420 and f % 16 < 2 then return { a = true } end
    return {}
  end
  local t = f - arrived
  if (t >= 240 and t < 300) or (t >= 360 and t < 420) then return { up = true } end
  return {}
end

local firstMap, lastMap = nil, nil
table.insert(H.on_frame, function(f)
  if not arrived then return end
  local m = string.format("%02X:%02X%02X", H.ram(0x1700), H.ram(0x1701), H.ram(0x1702))
  if f - arrived == 60 then firstMap = m end
  if firstMap and m ~= lastMap and lastMap then note("map %s -> %s at +%d", lastMap, m, f - arrived) end
  lastMap = m
  if f - arrived == 560 then
    H.shot("end")
    local fo = io.open(H.OUT .. "/result.txt", "w")
    fo:write(string.format("map=%s end=%s party=%02X\n", firstMap or "?", m, H.ram(0x1000)))
    for _, s in ipairs(notes) do fo:write(s .. "\n") end
    fo:close()
    H.finish(0)
  end
end)
