; Rydia's monster game: patch entry point. Build with: python tools/build.py
; Addresses are SNES LoROM bus addresses; see notes/addresses.md.
;
; Free ROM allocation (all $FF in the clean ROM):
;   $03:FEE3-$03:FF5F  battle code (Pact handler, asm/pact.asm)
;   $03:FF60-$03:FFFF  battle code (Call stubs, asm/call.asm)
;   $01:FF35-$01:FF49  field-menu and validated-load shims
;   $0E:F0BB-$0E:F1FF  Call: cast, MP, menu names
;   $0E:E522-$0E:E5FF  Call: summon graphic
;   $0E:E840-$0E:E8FF  Call: summon arrangement, caption
;   $0F:B33D-$0F:B3FF  battle message text (Pact messages)
;   $00:FD31-$00:FFAF  field code (new-game hook)
; Expanded allocations are defined in layout.asm (2 MiB standard LoROM).

lorom

incsrc "layout.asm"
incsrc "expansion.asm"
incsrc "charmap.asm"
incsrc "commands.asm"
incsrc "pact.asm"
incsrc "call.asm"
incsrc "roster.asm"
incsrc "field-call.asm"
incsrc "picker.asm"
incsrc "ability.asm"
incsrc "slots.asm"
incsrc "newgame.asm"
incsrc "gen/data.asm"     ; generated into build/gen by tools/build.py
incsrc "gen/newgame.asm"
