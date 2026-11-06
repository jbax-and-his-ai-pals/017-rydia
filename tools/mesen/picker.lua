-- Field Call roster picker (asm/picker.asm) through the real field menu, with
-- 24 generic slots. Pact in formation $21 (roster 01 1B), then give Rydia
-- species 00-1D and two eidolons (Shiva, Bahamut) in the pool, open
-- Magic > Rydia > Call, and:
-- The pool lists the bench (not active) first, then the active entries, and
-- the top-left window reads "Pool" / "1 of 2" while it is open.
--   1. Y on slot 1 opens the pool: page 0 is species 01-18 (bench).
--   2. R: species 19, 1B-1D, Shiva, Bahamut, then active 00 and 1A.
--   3. A on cell 0 puts species 19 in slot 1 (1A goes to the bench).
--   4. Left, Y, R, A on cell 5 puts Bahamut in slot 0.
--   5. Y, R, A on cell 6 (species 19, active in slot 1) into slot 0: they swap.
--   6. Y then B cancels: nothing changes.
--   7. Select on slot 0 clears it (stored in the pool).
-- Also: MP and the summon in progress are untouched, active entries are
-- marked in the pool view, and no code outside bank $20 writes the picker's
-- buffers ($7E:EB00-$EB6A) while it is open.
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

local ROSTER, LIST = 0x119E, 0x15C0
local MODE, PAGE, TOTAL, PAGES, TARGET = 0x11BA, 0xEB61, 0xEB62, 0xEB63, 0xEB64
local SLOT_IDS, NAMES = H.symbol("slot_ids"), H.symbol("call_name_table")
local battle, returned = false, nil
emu.addMemoryCallback(function() battle=true end,EXEC,off(0x00E394),off(0x00E394),emu.cpuType.snes,ROM)
emu.addMemoryCallback(function() if battle then returned=H.frame end end,
  EXEC,off(0x00EDB1),off(0x00EDB1),emu.cpuType.snes,ROM)

-- Rendered bytes at the name shim's return: A, with Y = $8900 + 6 x spell + n.
local names, icons, attrs = {}, {}, {}
local nameReturn = H.symbol("call_field_name_stub")+4
emu.addMemoryCallback(function()
  local s=emu.getState()
  local n=s["cpu.y"]-0x8900
  local id,k=n//6,n%6
  if k==0 then icons[id]=s["cpu.a"] & 0xFF; attrs[id]=H.ram(0x01DB)
  else names[id]=names[id] or {}; names[id][k-1]=s["cpu.a"] & 0xFF end
end,EXEC,off(nameReturn),off(nameReturn),emu.cpuType.snes,ROM)
local function token(cell) return rom(SLOT_IDS+cell) end
local function species_named(cell, sp)
  local id=token(cell)
  for l=0,4 do if not names[id] or names[id][l]~=rom(NAMES+sp*5+l) then return false end end
  return true
end
local function eidolon_named(cell, spell)
  local id=token(cell)
  for l=0,4 do if not names[id] or names[id][l]~=rom(0x0F8901+6*spell+l) then return false end end
  return true
end

local foreign = {}
emu.addMemoryCallback(function()
  if H.ram(MODE) == 0 then return end
  local pc = H.pc()
  if (pc >> 16) ~= 0x20 then foreign[string.format("%06X", pc)] = true end
end, emu.callbackType.write, 0xEB00, 0xEB6A, emu.cpuType.snes, emu.memType.snesWorkRam)

local presses = {
  [210]={x=true}, [270]={down=true}, [300]={a=true}, [350]={a=true},
  [430]={down=true}, [460]={a=true}, [520]={right=true},
  [580]={y=true}, [670]={r=true}, [750]={a=true},
  [840]={left=true}, [870]={y=true}, [930]={r=true}, [955]={down=true}, [970]={right=true}, [985]={right=true}, [1010]={a=true},
  [1090]={y=true}, [1150]={r=true}, [1165]={down=true}, [1180]={down=true}, [1210]={a=true},
  [1290]={y=true}, [1350]={b=true},
  [1420]={select=true},
}
local step,waitUntil,closingSince="idle",0,0
local cur0, mp0 = nil, nil
H.override=function(f)
  if not battle then
    if f>=320 and f%16<2 then return {a=true} end
    return {}
  end
  if returned then
    local t=f-returned
    if t==180 then
      for i,v in ipairs({0xFF,0xFF,0xFF,0x3F}) do H.wram_write(0x1180+i,v) end  -- species 00-1D
      H.wram_write(0x11B6, 0x01); H.wram_write(0x11B7, 0x02)                  -- Shiva, Bahamut
      cur0=H.ram(0x11BE); mp0=H.ram16(0x100B)
    end
    if t==570 or t==660 then names={}; icons={}; attrs={} end
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
local CHARS = { P=0x51, o=0x6A, l=0x67, f=0x61, B=0x43, a=0x5C, c=0x5E, k=0x66, C=0x44 }
CHARS[" "] = 0xFF
for d = 0, 9 do CHARS[tostring(d)] = 0x80 + d end
local function label(line)               -- the 6 glyphs of a top-left window line
  local base = 0xC600 + (line == "black" and 0x170 or 0x1F0) + 0x40
  local t = {} for i = 0, 5 do t[#t + 1] = H.ram(base + 2 * i) end
  return t
end
local function label_is(line, text)
  local g = label(line)
  for i = 1, 6 do
    local ch = text:sub(i, i); if ch == "" then ch = " " end
    if g[i] ~= CHARS[ch] then return false end
  end
  return true
end
local function roster(n) return H.dump(ROSTER, n) end
table.insert(H.on_frame,function(f)
  if not returned then return end
  local t=f-returned
  if t==560 then
    check(roster(5)=="01 1B 00 00 00","roster before the picker (no auto-fill): %s",roster(5))
    check(H.ram(0x1B81)==2 and H.ram(0x1B87)==1 and H.ram(0x1B83)==0 and H.ram(0x1B84)==1,
      "in the Call grid on slot 1 (col %d, grid %d, row %d, column %d)",H.ram(0x1B81),H.ram(0x1B87),H.ram(0x1B83),H.ram(0x1B84))
  elseif t==640 then
    H.shot("picker-page0")
    check(H.ram(MODE)==1 and H.ram(TARGET)==1,"picker open for slot 1 (mode %d, slot %d)",H.ram(MODE),H.ram(TARGET))
    check(H.ram(TOTAL)==32 and H.ram(PAGES)==2 and H.ram(PAGE)==0,"32 in the pool on 2 pages (%d, %d), page %d",H.ram(TOTAL),H.ram(PAGES),H.ram(PAGE))
    local ok=true for c=0,23 do ok=ok and H.ram(LIST+c)==token(c) end
    check(ok,"page 0 cells are the 24 slot tokens: %s",list(8))
    ok=true for c=0,23 do ok=ok and species_named(c,c+1) end
    check(ok,"page 0 shows the bench: species 01-18 by Call name")
    check(label_is("black","Pool") and label_is("call","1 of 2"),"labels read Pool / 1 of 2")
  elseif t==720 then
    H.shot("picker-page1")
    check(H.ram(PAGE)==1,"R pages to page 1 (%d)",H.ram(PAGE))
    local want={} for c=0,7 do want[#want+1]=string.format("%02X",token(c)) end
    check(list(8)==table.concat(want," ") and H.ram(LIST+8)==0,"page 1 has 8 cells: %s",list(9))
    local ok=species_named(0,0x19) and species_named(1,0x1B) and species_named(2,0x1C) and species_named(3,0x1D)
    check(ok and eidolon_named(4,0x36) and eidolon_named(5,0x3F),"page 1: species 19, 1B-1D, Shiva, Bahamut")
    check(species_named(6,0x00) and species_named(7,0x1A),"page 1 ends with the active entries 00 and 1A")
    check(attrs[token(6)]~=nil and attrs[token(6)]&0x04~=0 and attrs[token(7)]&0x04~=0 and attrs[token(0)]&0x04==0,
      "bench entries bright, active ones grey (palette cell 6 %s, 7 %s, bench cell 0 %s)",tostring(attrs[token(6)]),tostring(attrs[token(7)]),tostring(attrs[token(0)]))
    check(label_is("call","2 of 2"),"label reads 2 of 2")
  elseif t==810 then
    check(H.ram(MODE)==0 and roster(3)=="01 1A 00","species 19 now in slot 1: %s",roster(3))
    check(label_is("black","Black") and label_is("call","Call"),"labels back to Black / Call")
    check(list(3)==string.format("%02X %02X 00",token(0),token(1)),"Call list back to the roster: %s",list(3))
    check(H.ram(0x1B87)==1 and H.ram(0x1B83)==0 and H.ram(0x1B84)==1,"cursor back on slot 1 in the grid")
  elseif t==1070 then
    H.shot("picker-bahamut")
    check(roster(3)=="EA 1A 00","Bahamut (234) in slot 0: %s",roster(3))
  elseif t==1270 then
    check(roster(3)=="1A EA 00","choosing an active entry swaps it: %s",roster(3))
  elseif t==1400 then
    check(H.ram(MODE)==0 and roster(3)=="1A EA 00","B cancels without changes: %s",roster(3))
  elseif t==1480 then
    check(roster(3)=="00 EA 00" and H.ram(LIST)==0,"Select stores slot 0 in the pool: %s",roster(3))
    check(H.ram(0x1181+3)&0x02~=0,"species 19 is still in the pool")
    check(H.ram16(0x100B)==mp0,"MP unchanged (%d)",H.ram16(0x100B))
    check(H.ram(0x11BE)==cur0,"summon in progress unchanged")
    local k={} for pc in pairs(foreign) do k[#k+1]=pc end
    check(#k==0,"no foreign writes to the picker buffers while open (%s)",table.concat(k," "))
    H.shot("picker-end")
    H.mark_scenario_complete()
    H.finish(fails==0 and 0 or 1)
  end
end)
table.insert(H.on_finish,function()
  local out=assert(io.open(H.OUT.."/result.txt","w"))
  out:write(table.concat(results,"\n"),"\n");out:close()
end)
