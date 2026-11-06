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

-- A small process contract consumed by run.py. The runner removes this before
-- launch, so its presence proves this script reached H.finish in this run.
local status_path = H.OUT .. "/harness-status.txt"
local statusf = assert(io.open(status_path, "w"))
statusf:write("running\n"); statusf:close()
H.failed = false
function H.fail(reason)
  H.failed = true
  if reason then H.log("HARNESS FAILURE: %s", tostring(reason)) end
end
H.require_completion = false
H.scenario_complete = false
function H.require_scenario_completion() H.require_completion = true end
function H.mark_scenario_complete() H.scenario_complete = true end

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

-- Resolve labels from the current build, including code/data in expanded banks.
local symbols = nil
function H.symbol(name)
  if not symbols then
    symbols = {}
    local path = os.getenv("SYM") or (assert(os.getenv("HARNESS_DIR")) .. "/../../build/rydia.sym")
    for line in io.lines(path) do
      local bank, addr, label = line:match("^(%x%x):(%x%x%x%x) (%S+)")
      if label then symbols[label] = (tonumber(bank, 16) << 16) | tonumber(addr, 16) end
    end
  end
  return assert(symbols[name], "no build symbol " .. name)
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
  if finished then
    if tonumber(code) and tonumber(code) ~= 0 then
      H.fail("nested finish requested nonzero status " .. tostring(code))
    end
    return
  end
  -- Set the guard before running user callbacks. A callback may call finish or
  -- raise an error; neither should recurse or skip the remaining callbacks.
  finished = true
  code = tonumber(code) or 0
  for _, fn in ipairs(H.on_finish) do
    local ok, err = pcall(fn)
    if not ok then
      H.fail("on_finish error: " .. tostring(err))
      if code == 0 then code = 3 end
    end
  end
  if H.require_completion and not H.scenario_complete then
    H.fail("required scenario did not complete")
    if code == 0 then code = 2 end
  end
  if H.failed and code == 0 then code = 1 end
  H.log("finished at frame %d", H.frame)
  logf:close()
  local sf = io.open(status_path, "w")
  if sf then sf:write(code == 0 and "passed\n" or ("failed " .. code .. "\n")); sf:close() end
  emu.stop(code or 0)
end

-- Start every run with blank save RAM so the title screen behaves the same way.
local SRAM = emu.memType.snesSaveRam
for i = 0, emu.getMemorySize(SRAM) - 1 do emu.write(i, 0, SRAM) end

return H
