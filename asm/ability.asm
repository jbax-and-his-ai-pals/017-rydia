; Signature abilities for pact summons. See notes/call-design.md (D4).
;
; call_ability_table (generated from data/monsters.csv into bank $21) has
; 8 bytes per species:
;   +0 flags: bit 0 live (verified in Mesen), bit 1 scale power with levels
;   +1 animation spell (its visual plays after the monster appears)
;   +2 targeting (bits 5-7, as spell data byte 0)
;   +3 base power
;   +4 hit %
;   +5 effect routine (spell data byte 3; always a routine the player's own
;      spells use, so it works with Rydia as the caster)
;   +6 element/status set (spell data byte 4)
;   +7 unused
; A species that isn't live keeps the plain strike: effect $00, power
; 10 x (monster Lv + Rydia's Lv) / 32, no element, 100% hit.

org $02EAFB                 ; spell visuals: was DEC A / REP #$20 / ASL A
    jsl call_ability_visual

; Spell sounds come from their own table ($0F:A350 + spell - 1, X = $F47F),
; read separately from the visual. A borrowed animation takes its sound too.
org $02F5EE                 ; was LDA $0FA350,X
    jsl call_ability_sound

; Summon effects reach party targets only for Asura ($5A-$5C) in vanilla; other
; summons on the party are skipped as a miss. Live pact abilities may too.
org $03D18B                 ; vanilla: LDA $CE / BPL (party target: skip)
ability_party_vanilla:
org $03D18F                 ; vanilla: run the effect
ability_party_go:
org $03D180                 ; was LDA $26D2 / CMP #$5A / BCC / CMP #$5D / BCC $D18F
    jsl call_ability_party
    bcs ability_party_go
    bra ability_party_vanilla

; Summons leave and Rydia returns in $02:BE89 (when $F35A says a summon is out).
; Vanilla summon motions jump there; a spell visual ends with JMP $E704. $BE89
; starts with JSR $E704 and does nothing else without a summon, so ending every
; visual there lets a pact summon with a borrowed animation leave too.
org $02EB51                 ; was JMP $E704
    jmp $BE89

; Summon start position and sprite grid: vanilla copies 4 bytes per summon
; from $13:FA59 (X, Y, width and height in 16-pixel units) into $F321-$F324.
; A pact summon then gets a grid sized to its own graphic.
org $02EAE1                 ; was JSL $03FD53
    jsl call_summon_pos

; The summon sprite builder ($01:FE64) takes each 16x16 sprite's tile from a
; per-summon map ($0D:F660 + 2 x $F328). A pact summon uses a generated map
; for the grid its position hook set (summon_map_ptrs in build/gen/data.asm).
org $01FE80                 ; vanilla continues here
summon_map_done:
org $01FE6B                 ; was LDA $F328 / ASL / TAX / LDA $0DF660,X / STA $1C /
    jsl call_summon_map     ;     LDA $0DF661,X / STA $1D / LDA #$0D / STA $1E
    bra summon_map_done

org !ability_code

; Sprite map pointer into $1C-$1E (M=8, X=16; DP as the caller's).
call_summon_map:
    jsr pact_grid
    bcc .vanilla
    lda.l $7EF323           ; W
    dec a
    asl
    asl
    clc
    adc.l $7EF324           ; + H
    dec a
    asl
    rep #$20
    and.w #$00FF
    tax
    lda.l summon_map_ptrs,x
    sta $1C
    sep #$20
    lda.b #summon_map_ptrs>>16
    sta $1E
    rtl
.vanilla:
    lda.l $7EF328
    asl
    tax
    lda.l $0DF660,x
    sta $1C
    lda.l $0DF661,x
    sta $1D
    lda #$0D
    sta $1E
    rtl

; Carry set when the summon being drawn is a pact summon with a plain
; rectangular graphic (its position and grid come from call_summon_pos).
; Keeps X and A's high byte; A's low byte is clobbered.
pact_grid:
    lda.l $7EF325
    cmp #!eff_count          ; summon index: pact slots all use effect $4D (index 0)
    bcs .no
    lda.l !call_cur
    beq .no
    phx
    dec a
    rep #$20
    and.w #$00FF
    asl
    asl
    tax
    sep #$20
    lda.l $0FCA00,x
    plx
    bit #$C0
    bne .no
    sec
    rts
.no:
    clc
    rts

; After $03:FD53: for a pact summon, X = 240 - 8 x width, Y = 108 - 8 x rows
; (rows at most 8, as drawn), grid = tiles / 2. Keeps all registers.
call_summon_pos:
    jsl $03FD53
    php
    rep #$30
    pha
    phx
    sep #$20
    lda.l $7EF325           ; summon index (effect spell - $4D), set by $03:FD53
    cmp #!eff_count          ; summon index: pact slots all use effect $4D (index 0)
    bcs .done
    lda.l !call_cur
    beq .done
    dec a
    rep #$20
    and.w #$00FF
    asl
    asl
    tax
    sep #$20
    lda.l $0FCA00,x         ; size byte; character-style or irregular: leave vanilla
    bit #$C0
    bne .done
    and #$3F
    asl
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l $0DFF5E,x         ; width in tiles
    pha
    lsr
    sta.l $7EF323           ; grid width (16-pixel units)
    pla
    asl
    asl
    asl
    eor #$FF
    sec
    adc #240                ; 240 - 8 x width
    sta.l $7EF321
    lda.l $0DFF5F,x         ; height in tiles, drawn up to 8
    cmp #$09
    bcc +
    lda #$08
+   pha
    lsr
    sta.l $7EF324           ; grid height
    pla
    asl
    asl
    asl
    eor #$FF
    sec
    adc #108                ; 108 - 8 x rows
    sta.l $7EF322
.done:
    rep #$30
    plx
    pla
    plp
    rtl

; Battle menu build (A = species, M=8): a live ability sets the slot's
; targeting bits in $289C, which become its $2C7A menu entry.
call_ability_slot:
    php
    rep #$30
    pha
    phx
    sep #$20
    jsr ability_row
    bcc .out
    lda.l call_ability_table+2,x
    and #$E0
    pha
    lda.l !spell_target
    and #$1F
    ora 1,s
    sta.l !spell_target
    pla
.out:
    rep #$30
    plx
    pla
    plp
    rtl

; Cast (A = monster level + Rydia's level, M=8; the summon is call_cur):
; write targeting, power, hit, effect and element into $289C-$28A0. The MP
; byte $28A1 is left to the caller.
call_ability_cast:
    php
    rep #$30
    pha
    phx
    sep #$20
    sta.l !call_tmp
    lda.l !call_cur
    dec a
    jsr ability_row
    bcs .live
    lda #10                 ; plain strike
    jsr scale_power
    sta.l !spell_power
    lda #$64
    sta.l !spell_hit
    lda #$00
    sta.l !spell_effect
    sta.l !spell_elem
    bra .out
.live:
    lda.l call_ability_table+2,x
    and #$E0
    pha
    lda.l !spell_target
    and #$1F
    ora 1,s
    sta.l !spell_target
    pla
    lda.l call_ability_table,x
    and #$02
    beq .raw
    lda.l call_ability_table+3,x
    jsr scale_power
    bra .power
.raw:
    lda.l call_ability_table+3,x
.power:
    sta.l !spell_power
    lda.l call_ability_table+4,x
    sta.l !spell_hit
    lda.l call_ability_table+5,x
    sta.l !spell_effect
    lda.l call_ability_table+6,x
    sta.l !spell_elem
.out:
    rep #$30
    plx
    pla
    plp
    rtl

; Effect dispatch (M=8): carry set if this summon effect may reach a party
; target: Asura's effect spells, or a pact summon with a live ability.
call_ability_party:
    rep #$30
    pha
    phx
    sep #$20
    lda.l $7E26D2
    cmp #$5A
    bcc .pact
    cmp #$5D
    bcc .yes
.pact:
    cmp #!eff_first
    bcc .no
    cmp #!eff_first+!eff_count
    bcs .no
    lda.l !call_cur
    beq .no
    dec a
    jsr ability_row
    bcs .yes
.no:
    rep #$30
    plx
    pla
    sep #$20
    clc
    rtl
.yes:
    rep #$30
    plx
    pla
    sep #$20
    sec
    rtl

; Visuals (M=8, A = spell; vanilla then does DEC A / REP #$20 / ASL A).
; A pact effect spell with a live ability plays its animation spell instead.
; Only A's low byte changes, so the high byte reaches the index as in vanilla.
call_ability_visual:
    php
    rep #$30
    pha
    phx
    sep #$20
    lda 3,s
    cmp #!eff_first
    bcc .done
    cmp #!eff_first+!eff_count
    bcs .done
    lda.l !call_cur
    beq .done
    dec a
    jsr ability_row
    bcc .done
    lda.l call_ability_table+1,x
    sta 3,s
.done:
    rep #$30
    plx
    pla
    plp
    dec a
    rep #$20
    asl a
    rtl

; Sound (M=8, X = spell - 1): the animation spell's sound for a pact effect
; spell with a live ability, else vanilla. Keeps X and A's high byte.
call_ability_sound:
    php
    rep #$30
    pha
    phx
    sep #$20
    cpx.w #!eff_first-1
    bne .vanilla
    lda.l !call_cur
    beq .vanilla
    dec a
    jsr ability_row
    bcc .vanilla
    lda.l call_ability_table+1,x
    dec a
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l $0FA350,x
    bra .return
.vanilla:
    rep #$20
    lda 1,s
    tax
    sep #$20
    lda.l $0FA350,x
.return:
    sta 3,s
    rep #$30
    plx
    pla
    plp
    ora.b #$00
    rtl

; A = species (M=8). Returns X = its table offset and carry set if live.
ability_row:
    rep #$20
    and.w #$00FF
    asl
    asl
    asl
    tax
    sep #$20
    lda.l call_ability_table,x
    lsr
    rts

; A = base power. Returns A = base x call_tmp / 32, at least 1, at most 255.
; Uses the CPU's 8x8 multiplier. Keeps X.
scale_power:
    sta.l $004202
    lda.l !call_tmp
    sta.l $004203
    nop
    nop
    nop
    nop                     ; the product is ready 8 cycles later
    rep #$20
    lda.l $004216
    lsr
    lsr
    lsr
    lsr
    lsr
    cmp.w #$0100
    bcc +
    lda.w #$00FF
+   sep #$20
    cmp #$00
    bne +
    lda #$01
+   rts

assert pc() <= !ability_code_end, "Ability code exceeds its allocation"
