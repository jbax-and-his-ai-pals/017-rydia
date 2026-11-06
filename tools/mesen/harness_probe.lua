-- Deterministic process-contract probe for run.py. Use --env PROBE_MODE=pass,
-- fail, incomplete, finish-error, or nested-finish and a small --frames value.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
local mode = os.getenv("PROBE_MODE") or "pass"
H.require_scenario_completion()

local result = io.open(H.OUT .. "/result.txt", "w")
local function record(s) result:write(s .. "\n"); result:flush(); H.log("%s", s) end

if mode == "finish-error" then
  table.insert(H.on_finish, function() error("intentional probe finish callback error") end)
end
if mode == "nested-finish" then
  table.insert(H.on_finish, function() H.finish(7) end)
end
table.insert(H.on_finish, function()
  if mode == "fail" then H.fail("intentional probe assertion failure"); record("FAIL: intentional assertion")
  elseif mode == "incomplete" then record("INCOMPLETE: scenario never completed")
  elseif mode == "finish-error" then record("finish callback chain continued")
  elseif mode == "nested-finish" then record("nested finish callback chain continued")
  else record("PASS: probe scenario completed") end
  if mode == "pass" or mode == "fail" or mode == "finish-error" or mode == "nested-finish" then H.mark_scenario_complete() end
  result:close()
end)

table.insert(H.on_frame, function(frame)
  if mode ~= "incomplete" and frame >= 2 then H.finish(0) end
end)
