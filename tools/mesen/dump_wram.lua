-- Mash A from the title into New Game, then dump WRAM $1000-$17FF to wram.bin
-- at frame DUMP_AT (default 1000) and stop. No ROM patching: test the build as is.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
local AT = tonumber(os.getenv("DUMP_AT") or "1000")
H.override = function(f)
  if f >= 320 and f < 420 and f % 16 < 2 then return { a = true } end
  return {}
end
table.insert(H.on_frame, function(f)
  if f == AT then
    local t = {}
    for a = 0x1000, 0x17FF do t[#t + 1] = string.char(H.ram(a)) end
    local fo = io.open(H.OUT .. "/wram.bin", "wb"); fo:write(table.concat(t)); fo:close()
    H.shot("newgame")
    H.log("map %s pos %02X,%02X vehicle %02X", H.dump(0x1700, 3), H.ram(0x1706), H.ram(0x1707), H.ram(0x1704))
    H.finish(0)
  end
end)
