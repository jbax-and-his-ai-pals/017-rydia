; Rydia's monster game: patch entry point. Build with: python tools/build.py
; Addresses are SNES LoROM bus addresses; see notes/addresses.md.
;
; Free ROM allocation (all $FF in the clean ROM):
;   $0E:B439-$0E:B6BF  data tables generated from data/*.csv (gen/data.asm)
;   $03:FEE3-$03:FFFF  battle code (capture handler, Phase 3)
;   $00:FD31-$00:FFAF  field code (new-game hook, Phase 2)

lorom

incsrc "charmap.asm"
incsrc "commands.asm"
incsrc "gen/data.asm"     ; generated into build/gen by tools/build.py
