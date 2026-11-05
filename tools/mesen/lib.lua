-- Shared helpers for headless Mesen 2 runs (loaded with dofile by each script).
-- Env:
--   OUT_DIR    folder for logs and screenshots (required)
--   INPUT      optional input script: "<frame> <buttons>" per line, buttons joined
--              by + (a b x y l r start select up down left right), "-" releases all
--   MAX_FRAMES stop after this many frames (default 3600)
--   SHOTS      optional comma list of frames to screenshot (raw BGRA, see raw2png.py)

local H = {}
H.OUT = assert(os.getenv("OUT_DIR"), "OUT_DIR not set")
H.MAX = tonumber(os.getenv("MAX_FRAMES") or "3600")
H.frame = 0

local logf = assert(io.open(H.OUT .. "/log.txt", "w"))
function H.log(fmt, ...)
  logf:write(string.format("[%6d] ", H.frame) .. string.format(fmt, ...) .. "\n")
  logf:flush()
end

-- Memory helpers. WRAM by absolute offset ($7E:0000 = 0), so mirrors don't matter.
local WRAM = emu.memType.snesWorkRam
function H.ram(a) return emu.read(a, WRAM) end
function H.ram16(a) return emu.read(a, WRAM) | (emu.read(a + 1, WRAM) << 8) end
function H.wram_write(a, v) emu.write(a, v, WRAM) end
function H.dump(a, n)
  local t = {}
  for i = 0, n - 1 do t[#t + 1] = string.format("%02X", H.ram(a + i)) end
  return table.concat(t, " ")
end

-- 24-bit program counter of the current instruction (valid inside callbacks).
function H.pc()
  local s = emu.getState()
  return ((s["cpu.k"] or 0) << 16) | (s["cpu.pc"] or 0)
end

-- Input script.
local inputs, idx, cur = {}, 0, {}
local path = os.getenv("INPUT")
if path and path ~= "" then
  for line in io.lines(path) do
    local fr, b = line:match("^%s*(%d+)%s*(%S*)")
    if fr then
      local t = {}
      if b ~= "" and b ~= "-" then for x in b:gmatch("[^+]+") do t[x] = true end end
      inputs[#inputs + 1] = { tonumber(fr), t }
    end
  end
  table.sort(inputs, function(p, q) return p[1] < q[1] end)
end
H.override = nil  -- a script can set H.override = function(frame) return {a=true} end
emu.addEventCallback(function()
  while idx < #inputs and inputs[idx + 1][1] <= H.frame do idx = idx + 1; cur = inputs[idx][2] end
  local t = cur
  if H.override then t = H.override(H.frame) or cur end
  emu.setInput(t, 0, 0)
end, emu.eventType.inputPolled)

-- Screenshots.
local shots = {}
for n in (os.getenv("SHOTS") or ""):gmatch("%d+") do shots[tonumber(n)] = true end
function H.shot(name)
  local buf = emu.getScreenBuffer()
  local f = io.open(H.OUT .. "/" .. name .. ".raw", "wb")
  local parts = {}
  for i = 1, #buf do parts[#parts + 1] = string.pack("<I4", buf[i] & 0xFFFFFFFF) end
  f:write(table.concat(parts)); f:close()
end

-- Per-frame hooks run in order, then the frame counter advances.
H.on_frame = {}
emu.addEventCallback(function()
  if shots[H.frame] then H.shot(string.format("f%06d", H.frame)) end
  for _, fn in ipairs(H.on_frame) do fn(H.frame) end
  H.frame = H.frame + 1
  if H.frame >= H.MAX then H.finish(0) end
end, emu.eventType.endFrame)

H.on_finish = {}
local finished = false
function H.finish(code)
  if finished then return end
  finished = true
  for _, fn in ipairs(H.on_finish) do
    local ok, err = pcall(fn)
    if not ok then H.log("on_finish error: %s", tostring(err)); code = 3 end
  end
  H.log("finished at frame %d", H.frame)
  logf:close()
  emu.stop(code or 0)
end

-- Start every run with blank save RAM so the title screen behaves the same way.
local SRAM = emu.memType.snesSaveRam
for i = 0, emu.getMemorySize(SRAM) - 1 do emu.write(i, 0, SRAM) end

return H
