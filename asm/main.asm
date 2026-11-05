; Rydia's monster game: patch entry point. Build with: python tools/build.py
; Addresses are SNES LoROM bus addresses; see notes/addresses.md.
;
; Free ROM allocation (all $FF in the clean ROM):
;   $0E:B439-$0E:B6BF  data tables generated from data/*.csv (gen/data.asm)
;   $0F:CF40-$0F:D1FF  new-game WRAM table (gen/newgame.asm)
;   $03:FEE3-$03:FF5F  battle code (Pact handler, asm/pact.asm)
;   $03:FF60-$03:FFFF  battle code (Call stubs, asm/call.asm)
;   $0E:B98A-$0E:BABF  Call: battle start, roster checks (asm/call.asm)
;   $0A:EF00-$0A:EFFF  Call: roster add on a new pact
;   $0E:F0BB-$0E:F1FF  Call: cast, MP, menu names
;   $0E:E522-$0E:E5FF  Call: summon graphic
;   $0E:E840-$0E:E8FF  Call: summon arrangement, caption
;   $0F:B33D-$0F:B3FF  battle message text (Pact messages)
;   $00:FD31-$00:FFAF  field code (new-game hook)

lorom

incsrc "charmap.asm"
incsrc "commands.asm"
incsrc "pact.asm"
incsrc "call.asm"
incsrc "newgame.asm"
incsrc "gen/data.asm"     ; generated into build/gen by tools/build.py
incsrc "gen/newgame.asm"
