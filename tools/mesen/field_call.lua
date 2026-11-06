-- Pact real monsters, then open the real field Magic/Call screen. MODE=repair
-- additionally injects invalid, unowned and duplicate roster entries (in slots
-- 0-4 and 16-23) and stray spells in the Call list before the redraw, proving
-- the field sync repairs them without touching the summon in progress.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
H.require_scenario_completion()
local ROM, EXEC = emu.memType.snesPrgRom, emu.callbackType.exec
local function off(a) return ((a >> 16) & 0x7F) * 0x8000 + ((a & 0xFFFF) - 0x8000) end
local function rom(a) return emu.read(off(a), ROM) end
local REPAIR = os.getenv("MODE") == "repair"
local results, fails = {}, 0
local function check(ok, fmt, ...)
  local msg = string.format(fmt, ...)
  results[#results + 1] = (ok and "PASS " or "FAIL ") .. msg
  H.log("%s", results[#results])
  if not ok then fails = fails + 1; H.fail(msg) end
end
local START = {0xFE,0xFB,0x9A,0xC8,0x00}
local ev = {table.unpack(START)}
ev[#ev+1]=0xEC; ev[#ev+1]=0x21
for _,b in ipairs(START) do ev[#ev+1]=b end
ev[#ev+1]=0xFF
for i,b in ipairs(ev) do emu.write(off(0x1283E0)+i-1,b,ROM) end

local battle, returned, battleSnap, pacts = false, nil, nil, 0
local SLOT_IDS = H.symbol("slot_ids")
emu.addMemoryCallback(function() battle=true end,EXEC,off(0x00E394),off(0x00E394),emu.cpuType.snes,ROM)
emu.addMemoryCallback(function()
  if battle then returned=H.frame end
end,EXEC,off(0x00EDB1),off(0x00EDB1),emu.cpuType.snes,ROM)
emu.addMemoryCallback(function() battleSnap=H.dump(0x119E,24) end,
  EXEC,off(0x038A7A),off(0x038A7A),emu.cpuType.snes,ROM)
emu.addMemoryCallback(function()
  if H.ram(0x26D1) ~= 0x14 or not battleSnap then return end
  pacts=pacts+1
  local stable=true
  for i=0,23 do
    local was=tonumber(battleSnap:sub(i*3+1,i*3+2),16)
    if was~=0 and H.ram(0x119E+i)~=was then stable=false end
  end
  check(stable,"Pact %d leaves occupied roster entries unchanged",pacts)
  for i=0,4 do
    local want=H.ram(0x119E+i)~=0 and rom(SLOT_IDS+i) or 0
    check(H.ram(0x15C0+i)==want,"Pact %d immediately projects live Call slot %d",pacts,i)
  end
end,EXEC,off(0x03B05D),off(0x03B05D),emu.cpuType.snes,ROM)

local names, costs, lastCostId = {}, {}, nil
local nameReturn=H.symbol("call_field_name_stub")+4
emu.addMemoryCallback(function()
  local s=emu.getState()
  local n=s["cpu.y"]-0x8901
  local id,letter=n//6,n%6
  if id>=0x31 and id<=0x3F and letter<5 then
    names[id]=names[id] or {}; names[id][letter]=s["cpu.a"] & 0xFF
  end
end,EXEC,off(nameReturn),off(nameReturn),emu.cpuType.snes,ROM)
emu.addMemoryCallback(function()
  local s=emu.getState()
  lastCostId=s["cpu.x"]//6
  costs[lastCostId]=s["cpu.a"] & 0x7F
end,EXEC,off(0x01B426),off(0x01B426),emu.cpuType.snes,ROM)

local seeded=false
-- Repair: 225 (eidolon 0, not owned), 1, a duplicate 1, 2 (species 01, not
-- owned) -> only the first 1 survives. Empty entries are never auto-filled.
local finalRoster=REPAIR and {0,1,0,0,0} or {1,0x1B,0,0,0}
local expectedSnap, expectedCur=nil,nil
local step,waitUntil,closingSince="idle",0,0
H.override=function(f)
  if not battle then
    if f>=320 and f%16<2 then return {a=true} end
    return {}
  end
  if returned then
    local t=f-returned
    if t>=180 and not seeded then
      seeded=true
      if REPAIR then
        local bad={225,1,1,2,0}
        for i,v in ipairs(bad) do H.wram_write(0x119D+i,v) end
        for i=16,23 do H.wram_write(0x119E+i,0x80+i) end   -- unowned species
        H.wram_write(0x11BE,0xAA)
        local old={0x36,0x31,0x37,0x32,0x31,0x36}
        for i=0,23 do H.wram_write(0x15C0+i,old[i+1] or 0) end
      end
      expectedCur=H.ram(0x11BE)
    end
    if t==210 then return {x=true} end
    if t==270 then return {down=true} end
    if t==300 or t==350 then return {a=true} end
    if t==430 then return {down=true} end
    if t==460 then return {a=true} end
    if t==520 then return {right=true} end
    return {}
  end
  if f<waitUntil then return {} end
  local open=H.ram(0xD7)==1 and H.ram(0x1823)==1 and H.ram(0x1820)==0
  if step=="idle" then
    if not open then if H.ram(0x29CD)==0 and f%40==0 then return {a=true} end return {} end
    step="menu";waitUntil=f+8;return {}
  elseif step=="menu" then
    if not open then step="idle";return {} end
    waitUntil=f+6
    if H.ram(0x60)<4 then return {down=true} end
    if H.ram(0x60)>4 then return {up=true} end
    step="target";waitUntil=f+14;return {a=true}
  elseif step=="target" then
    step="closing";waitUntil=f+10;closingSince=f;return {a=true}
  elseif step=="closing" then
    if H.ram(0xD7)==0 or f-closingSince>60 then step="idle" end
    waitUntil=f+4;return {}
  end
  return {}
end

table.insert(H.on_frame,function(f)
  if not returned or f-returned<640 then return end
  check(pacts>=3,"three real Pacts resolved (%d)",pacts)
  check(H.ram(0x0500)~=0,"field menu is open")
  check(lastCostId==0x32,"second Call slot selected (%s)",tostring(lastCostId))
  check(H.ram(0x1B93)==(REPAIR and 2 or 7),"selected MP cost %d",H.ram(0x1B93))
  check(H.ram16(0x100B)==450,"field browsing preserves Rydia's MP")
  check(H.ram(0x11BE)==expectedCur,"field sync leaves the summon in progress alone")
  local tailOK=true
  for i=5,23 do if H.ram(0x119E+i)~=0 or H.ram(0x15C0+i)~=0 then tailOK=false end end
  check(tailOK,"roster entries 5-23 and their Call entries are empty after the sync")
  for i,sp in ipairs(finalRoster) do
    check(H.ram(0x119D+i)==sp,"live roster slot %d = %02X",i,sp)
    check(H.ram(0x15BF+i)==(sp~=0 and rom(SLOT_IDS+i-1) or 0),"projected field slot %d",i)
    if sp~=0 then
      local id=rom(SLOT_IDS+i-1)
      for letter=0,4 do
        check(names[id] and names[id][letter]==rom(H.symbol("call_name_table")+(sp-1)*5+letter),"rendered slot %d letter %d matches the species' Call name",i,letter)
      end
      local ptr=rom(0x0EA6A0+2*(sp-1)) | (rom(0x0EA6A1+2*(sp-1))<<8)
      local mp=1+((rom(0x0E0000|ptr)&0x7F)>>1)
      check(costs[id]==mp,"rendered slot %d cost %s = %d",i,tostring(costs[id]),mp)
    end
  end
  check(costs[0x1B]==(rom(0x0F97A5+6*0x1B)&0x7F),"field-usable Black Warp MP remains vanilla")
  -- Stray spells in the Call list don't survive: the list is derived from the
  -- roster (eidolons join through the grant event, tested in slots24.lua).
  H.shot("field-call")
  H.mark_scenario_complete()
  H.finish(fails==0 and 0 or 1)
end)
table.insert(H.on_finish,function()
  local out=assert(io.open(H.OUT.."/result.txt","w"))
  out:write(table.concat(results,"\n"),"\n");out:close()
end)
