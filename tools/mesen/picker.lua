-- Field Call roster picker (asm/picker.asm), through the real field menu.
-- Pact in formation $21, then own species 00-1D (30, so two pages), open
-- Magic > Rydia > Call, and:
--   1. Y on slot 1 opens the picker: page 0 lists species 00-17 as $31-$48.
--   2. R pages to species 18-1D.
--   3. A on cell 0 puts species 18 in slot 1 and closes on slot 1.
--   4. Y on slot 0, A on species 03 (active in slot 4) swaps the two slots.
--   5. Y then B cancels: nothing changes.
-- Also: MP and the battle snapshot are untouched, and no code outside the
-- expanded banks writes the page buffer ($7E:EB00-$EB5F) while it's open.
local H = dofile(os.getenv("HARNESS_DIR") .. "/lib.lua")
H.require_scenario_completion()
local ROM, EXEC = emu.memType.snesPrgRom, emu.callbackType.exec
local function off(a) return ((a >> 16) & 0x7F) * 0x8000 + ((a & 0xFFFF) - 0x8000) end
local function rom(a) return emu.read(off(a), ROM) end
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

local ROSTER, LIST, MODE = 0x119E, 0x15C0, 0x11A3
local battle, returned = false, nil
emu.addMemoryCallback(function() battle=true end,EXEC,off(0x00E394),off(0x00E394),emu.cpuType.snes,ROM)
emu.addMemoryCallback(function() if battle then returned=H.frame end end,
  EXEC,off(0x00EDB1),off(0x00EDB1),emu.cpuType.snes,ROM)

-- Rendered letters: the name shim's return (A = letter, Y = $8901 + 6*id + n).
local names = {}
local nameReturn = H.symbol("call_field_name_stub")+4
emu.addMemoryCallback(function()
  local s=emu.getState()
  local n=s["cpu.y"]-0x8901
  local id,letter=n//6,n%6
  if id>=0x31 and id<=0x48 and letter<5 then
    names[id]=names[id] or {}; names[id][letter]=s["cpu.a"] & 0xFF
  end
end,EXEC,off(nameReturn),off(nameReturn),emu.cpuType.snes,ROM)
local NAMES = H.symbol("call_name_table")   -- curated 5-letter Call names
local function name_ok(id, sp)
  for letter=0,4 do
    if not names[id] or names[id][letter] ~= rom(NAMES+sp*5+letter) then return false end
  end
  return true
end

-- Foreign writes to the page buffer while the picker is open.
local foreign = {}
emu.addMemoryCallback(function()
  if H.ram(MODE) == 0 then return end
  local pc = H.pc()
  if (pc >> 16) ~= 0x20 then foreign[string.format("%06X", pc)] = true end
end, emu.callbackType.write, 0xEB00, 0xEB5F, emu.cpuType.snes, emu.memType.snesWorkRam)

local presses = {
  [210]={x=true}, [270]={down=true}, [300]={a=true}, [350]={a=true},
  [430]={down=true}, [460]={a=true}, [520]={right=true},
  [580]={y=true}, [670]={r=true}, [750]={a=true},
  [840]={left=true}, [870]={y=true}, [930]={down=true}, [960]={a=true},
  [1050]={y=true}, [1110]={b=true},
}
local step,waitUntil,closingSince="idle",0,0
local snap, mp0 = nil, nil
H.override=function(f)
  if not battle then
    if f>=320 and f%16<2 then return {a=true} end
    return {}
  end
  if returned then
    local t=f-returned
    if t==180 then
      for i,v in ipairs({0xFF,0xFF,0xFF,0x3F}) do H.wram_write(0x1180+i,v) end  -- species 00-1D
      snap=H.dump(0x11AE,16); mp0=H.ram16(0x100B)
    end
    if t==570 or t==660 or t==740 then names={} end
    return presses[t] or {}
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

local function list(n) return H.dump(LIST, n) end
table.insert(H.on_frame,function(f)
  if not returned then return end
  local t=f-returned
  if t==560 then
    check(H.dump(ROSTER,5)=="01 1B 02 03 04","roster before the picker: %s",H.dump(ROSTER,5))
    check(H.ram(0x1B81)==2 and H.ram(0x1B87)==1 and H.ram(0x1B83)==0 and H.ram(0x1B84)==1,
      "in the Call grid on slot 1 (col %d, grid %d, row %d, column %d)",H.ram(0x1B81),H.ram(0x1B87),H.ram(0x1B83),H.ram(0x1B84))
  elseif t==640 then
    H.shot("picker-page0")
    local d={} for l=0,4 do d[#d+1]=string.format("%02X",(names[0x31] or {})[l] or 0) end
    H.log("page buffer %s; $31 letters %s; $1B93=%d", H.dump(0xEB00,24), table.concat(d," "), H.ram(0x1B93))
    check(H.ram(MODE)==1 and H.ram(0x11A7)==1,"picker open for slot 1 (mode %d, slot %d)",H.ram(MODE),H.ram(0x11A7))
    check(H.ram(0x11A5)==30 and H.ram(0x11A6)==2 and H.ram(0x11A4)==0,"30 pacts on 2 pages (%d, %d), page %d",H.ram(0x11A5),H.ram(0x11A6),H.ram(0x11A4))
    local want={} for i=0,23 do want[#want+1]=string.format("%02X",0x31+i) end
    check(list(24)==table.concat(want," "),"page 0 cells are $31-$48: %s",list(24))
    local ok=true for i=0,23 do ok=ok and name_ok(0x31+i,i) end
    check(ok,"page 0 shows species 00-17 by name")
    check(H.ram(0x1B83)==0 and H.ram(0x1B84)==0 and H.ram(0x1B87)==1,"picker cursor on cell 0")
  elseif t==720 then
    H.shot("picker-page1")
    check(H.ram(0x11A4)==1,"R pages to page 1 (%d)",H.ram(0x11A4))
    check(list(8)=="31 32 33 34 35 36 00 00","page 1 has 6 cells: %s",list(8))
    local ok=true for i=0,5 do ok=ok and name_ok(0x31+i,0x18+i) end
    check(ok,"page 1 shows species 18-1D by name")
  elseif t==810 then
    H.shot("picker-chosen")
    check(H.ram(MODE)==0,"A closes the picker")
    check(H.dump(ROSTER,5)=="01 19 02 03 04","species 18 now in slot 1: %s",H.dump(ROSTER,5))
    check(list(8)=="31 32 33 34 35 00 00 00","Call list back to the five slots: %s",list(8))
    check(H.ram(0x1B87)==1 and H.ram(0x1B83)==0 and H.ram(0x1B84)==1,"cursor back on slot 1 in the grid")
    check(name_ok(0x32,0x18),"slot 1 shows species 18's name")
  elseif t==1020 then
    check(H.dump(ROSTER,5)=="04 19 02 03 01","choosing an active pact swaps it: %s",H.dump(ROSTER,5))
  elseif t==1170 then
    check(H.ram(MODE)==0 and H.dump(ROSTER,5)=="04 19 02 03 01","B cancels without changes: %s",H.dump(ROSTER,5))
    check(list(8)=="31 32 33 34 35 00 00 00","Call list restored after cancel: %s",list(8))
    check(H.ram16(0x100B)==mp0,"MP unchanged (%d)",H.ram16(0x100B))
    check(H.dump(0x11AE,16)==snap,"battle snapshot unchanged")
    local k={} for pc in pairs(foreign) do k[#k+1]=pc end
    check(#k==0,"no foreign writes to the page buffer while open (%s)",table.concat(k," "))
    H.shot("picker-end")
    H.mark_scenario_complete()
    H.finish(fails==0 and 0 or 1)
  end
end)
table.insert(H.on_finish,function()
  local out=assert(io.open(H.OUT.."/result.txt","w"))
  out:write(table.concat(results,"\n"),"\n");out:close()
end)
