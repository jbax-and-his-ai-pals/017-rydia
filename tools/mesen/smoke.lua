-- Smoke test: boot, log CPU state keys once, log a few RAM bytes every second.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")

local s = emu.getState()
local keys = {}
for k, _ in pairs(s) do if k:match("^cpu%.") then keys[#keys + 1] = k end end
table.sort(keys)
H.log("cpu state keys: %s", table.concat(keys, " "))
H.log("rom: %s", (emu.getRomInfo() or {}).name or "?")

table.insert(H.on_frame, function(f)
  if f % 60 == 0 then
    H.log("world=%02X map=%02X%02X veh=%02X xy=%02X,%02X party0=%s",
      H.ram(0x1700), H.ram(0x1701), H.ram(0x1702), H.ram(0x1704), H.ram(0x1706), H.ram(0x1707),
      H.dump(0x1000, 4))
  end
end)
