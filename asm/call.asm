; Call: Rydia summons monsters she has a pact with. See notes/call-design.md.
;
; Spells $31-$35 (vanilla Imp, Bomb, Cockatrice, Mage, Chocobo) are the pact
; slots. Vanilla already runs them as summons: $03:E050 turns slot spell $31+i
; into effect spell $4D+i. We keep that path and swap in, per slot, the pacted
; species' graphic, name, MP cost and a scaled hit.
;
; Save RAM, in Tellah's parked slot after the pact bitfield ($1180 stays $00):
;   roster:  species+1 per slot (0 = empty), filled in pact order; when full a
;            new pact replaces the oldest (roster_next). A roster editor can
;            later write the same list.
;   snapshot: the roster as it was at battle start. Menus and casts in a battle
;            use this, so a pact formed mid-battle joins Call next battle.
;   call_cur: species+1 of the pact summon being cast (0 = vanilla summon).

!call_slots   = 5           ; active roster size (pact slot spells $31..$35)
!roster_max   = 16          ; bytes reserved for the roster and the snapshot
!slot_first   = $31         ; slot i is spell $31+i
!eff_first    = $4D         ; its effect spell
!roster_next  = $7E119D
!roster       = $7E119E     ; 16 bytes
!call_snap    = $7E11AE     ; 16 bytes
!call_cur     = $7E11BE
!call_tmp     = $7E11BF
!call_list    = $7E15C0     ; Rydia's Call spell list (24 bytes)
!arr_buf      = $7EEB00     ; tail of the summon decode buffer ($7E:DBE6, $1000 bytes)
!arr_tmp      = $7EEBE0     ; 3 scratch bytes there, used only while drawing

; Data copied by $03:845E for the current action (6 bytes of spell data).
!spell_target = $7E289C
!spell_power  = $7E289D
!spell_hit    = $7E289E
!spell_effect = $7E289F
!spell_elem   = $7E28A0
!spell_mp     = $7E28A1
!actor_level  = $7E2682     ; actor's battle record copy ($2680) + 2

; ---------------------------------------------------------------------------
; Bank $03 hooks/stubs: long-call bank $0E runtime and expanded roster code.

org $0389CB                 ; battle start, just before the battle spell menu is built
    jsr call_battle_start_stub          ; was TDC / TAX / TAY

org $038A59                 ; battle menu: copy each listed spell's data (for MP)
    jsr call_copy_stub                  ; was JSR $845E

org $03CD33                 ; cast: summon spells $31-$3F
    jsr call_summon_stub                ; was JSR $E050

org $03CDC7                 ; cast: copy the action's spell data to $289C
    jsr call_copy_stub                  ; was JSR $845E

org $03FF60                 ; bank $03 free space, after the Pact handler
call_battle_start_stub:
    jsl call_battle_start
    tdc
    tax
    tay
    rts
call_summon_stub:
    jsl call_summon
    jmp $E050
call_copy_stub:
    jsr $845E
    jsl call_copy
    rts
assert pc() <= $040000, "Call stubs overflow bank $03 free space"

; ---------------------------------------------------------------------------
; Bank $02 hooks (battle graphics). Each replaces a long table read.

org $02EAA7                 ; vanilla: JSR $DA3A (decode the tiles)
call_gfx_decode:
org $02EAB9                 ; vanilla: JSR $8409 (lay them out)
call_gfx_layout:

org $02EA86                 ; summon graphic: palette
    jsl call_gfx_pal                    ; was LDA $0DFE4C,X
org $02EA95                 ; summon graphic: tiles (A is 16-bit here)
    jsl call_gfx_src                    ; was LDA #$80 / STA $00 / LDA $0D87F0,X / TAY
    bra call_gfx_decode                 ;     LDX #$DBE6 / TDC / SEP #$20 / LDA #$0D
org $02EAAF                 ; summon graphic: arrangement (A is 16-bit here)
    jsl call_gfx_arr                    ; was LDA $0DF260,X / TAX / TDC / SEP #$20 / LDA #$0D
    bra call_gfx_layout
org $02CBAF                 ; caption at the top while the action runs (8 letters)
    jsl call_caption                    ; was LDA $0F8AB0,X
org $02A11F                 ; battle spell menu: name letters
    jsl call_menu_name                  ; was LDA $0F8901,X

; Roster lifecycle lives in expanded bank $20 (asm/roster.asm).

; ---------------------------------------------------------------------------
; Bank $0E code, block 2: the cast.

org $0EF0BB                 ; free to $0E:F1FF

; Summon start (A = spell $31-$3F, kept): note which pact, if any, it is.
call_summon:
    php
    rep #$30
    pha
    phx
    sep #$20
    sec
    sbc #!slot_first
    cmp #!call_slots
    bcs .none               ; not a pact slot (or below $31: wrapped)
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l !call_snap,x
    bra .set
.none:
    lda #$00
.set:
    sta.l !call_cur
    rep #$30
    plx
    pla
    plp
    rtl

; After $03:845E copied 6 bytes of spell data to $289C ([$80] = table,
; $DF = spell ID). Slot spell: set its MP. Pact effect spell: write the hit.
call_copy:
    php
    rep #$30                ; keep all of A and X: callers TAX with A's high byte
    pha
    phx
    sep #$20
    lda $82
    cmp #$0F
    bne .far
    ldx $80
    cpx.w #$97A0
    beq .table
.far:
    brl .out
.table:
    lda $DF                 ; spell ID ($845E moves it here from $E5)
    cmp #!slot_first
    bcc .far
    cmp #!slot_first+!call_slots
    bcs .effect
    sec                     ; slot spell: MP = 1 + monster level / 2
    sbc #!slot_first
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l !call_snap,x
    beq .far
    dec a
    pha                     ; species
    jsr mon_level
    lsr
    inc a
    sta.l !call_tmp
    lda.l !spell_mp
    and #$80
    ora.l !call_tmp
    sta.l !spell_mp
    pla
    jsl call_ability_slot   ; asm/ability.asm: menu targeting
    bra .far
.effect:
    cmp #!eff_first
    bcc .far
    cmp #!eff_first+!call_slots
    bcs .far
    lda.l !call_cur
    beq .far
    dec a
    jsr mon_level
    pha
    lsr                     ; MP = 1 + monster level / 2 (the cast charges this copy's MP)
    inc a
    sta.l !call_tmp
    lda.l !spell_mp
    and #$80
    ora.l !call_tmp
    sta.l !spell_mp
    pla
    clc
    adc.l !actor_level      ; monster level + Rydia's level
    jsl call_ability_cast   ; asm/ability.asm: the hit (or the plain strike)
.out:
    rep #$30
    plx
    pla
    plp
    rtl

; A = species. Returns A = its level (monster record byte 0, bits 0-6). Uses X.
mon_level:
    phb
    pha
    lda #$0E
    pha
    plb
    pla
    rep #$20
    and.w #$00FF
    asl
    tax
    lda.w $A6A0,x           ; record pointer, bank $0E
    tax
    sep #$20
    lda.w $0000,x
    and #$7F
    plb
    rts

; Battle spell menu letter (A 8-bit, X = spell x 6 + letter). Pact slots
; show the first 5 letters of the monster's name.
call_menu_name:
    cpx.w #!slot_first*6
    bcc .vanilla
    cpx.w #(!slot_first+!call_slots)*6
    bcs .vanilla
    phx
    rep #$20
    txa
    sec
    sbc.w #!slot_first*6
    ldx.w #0
-   cmp.w #6
    bcc +
    sbc.w #6
    inx
    bra -
+   pha                     ; letter
    sep #$20
    lda.l !call_snap,x      ; X = slot
    beq .empty
    dec a
    rep #$20
    and.w #$00FF
    asl
    asl
    asl
    clc
    adc 1,s
    tax
    pla
    sep #$20
    lda.l $0E9800,x
    plx
    rtl
.empty:
    rep #$20
    pla
    sep #$20
    plx
.vanilla:
    lda.l $0F8901,x
    rtl

assert pc() <= $0EF200, "Call block 2 overflows $0E:F0BB-$0E:F1FF"

; ---------------------------------------------------------------------------
; Bank $0E code, block 3: graphics and names (called from bank $02).

org $0EE522                 ; free to $0E:E5FF

; Returns carry clear and X = species x 4 when a pact summon is being drawn
; and its graphic is a plain rectangle; carry set otherwise. Leaves A 8-bit.
cur_monprop:
    sep #$20
    lda.l !call_cur
    beq .no
    dec a
    rep #$20
    and.w #$00FF
    asl
    asl
    tax
    sep #$20
    lda.l $0FCA00,x         ; size byte: bit 6 character-style, bit 7 irregular
    and #$C0
    bne .no
    clc
    rts
.no:
    sec
    rts

; X = species x 4 (kept). Returns A = rows to draw (height, at most 8) and
; call_tmp = width, from the size table $0D:FF5E.
cur_size:
    phx
    lda.l $0FCA00,x
    and #$3F
    asl
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l $0DFF5E,x
    sta.l !call_tmp
    lda.l $0DFF5F,x
    cmp #$09
    bcc +
    lda #$08                ; taller than the sprite area: show the top 8 rows
+   plx
    rts

; Palette (A 8-bit, X = summon index). Returns A.
call_gfx_pal:
    phx
    jsr cur_monprop
    bcs .vanilla
    lda.l $0FCA01,x
    plx
    rtl
.vanilla:
    plx
    lda.l $0DFE4C,x
    rtl

; Tiles (A 16-bit, X = 2 x summon index). Returns what $02:DA3A takes:
; $00 = tile count, Y = address, A = bank, X = $DBE6; A 8-bit.
call_gfx_src:
    phx
    jsr cur_monprop
    bcs .vanilla
    jsr cur_size            ; count = width x rows
    rep #$20
    and.w #$00FF
    tay
    sep #$20
    lda #$00
-   clc
    adc.l !call_tmp
    dey
    bne -
    rep #$20
    and.w #$00FF
    sta $00
    lda.l $0FCA02,x         ; graphics: file offset $48000 + (v & $7FFF) x 8
    and.w #$0FFF
    asl
    asl
    asl
    ora.w #$8000
    tay                     ; address = $8000 | (v & $0FFF) << 3
    lda.l $0FCA02,x
    and.w #$7FFF
    xba
    lsr
    lsr
    lsr
    lsr
    and.w #$000F
    clc
    adc.w #$0009            ; bank = $09 + (v >> 12)
    sep #$20
    plx
    ldx.w #$DBE6
    rtl
.vanilla:
    plx
    rep #$20
    lda.w #$0080
    sta $00
    lda.l $0D87F0,x
    tay
    ldx.w #$DBE6
    tdc
    sep #$20
    lda #$0D
    rtl

assert pc() <= $0EE600, "Call block 3 overflows $0E:E522-$0E:E5FF"

org $0EE840                 ; free to $0E:E8FF

; Arrangement (A 16-bit, X = 2 x summon index). Returns X = address, A = bank,
; A 8-bit. For a pact: row-major (row << 4 | column) for width x rows, then $FF.
call_gfx_arr:
    phx
    jsr cur_monprop
    bcs .vanilla
    jsr cur_size
    sta.l !arr_tmp          ; rows left
    lda #$00
    sta.l !arr_tmp+1        ; row << 4
    ldx.w #0                ; write index
.row:
    lda #$00
    sta.l !arr_tmp+2        ; column
.col:
    lda.l !arr_tmp+1
    ora.l !arr_tmp+2
    sta.l !arr_buf,x
    inx
    lda.l !arr_tmp+2
    inc a
    sta.l !arr_tmp+2
    cmp.l !call_tmp
    bne .col
    lda.l !arr_tmp+1
    clc
    adc #$10
    sta.l !arr_tmp+1
    lda.l !arr_tmp
    dec a
    sta.l !arr_tmp
    bne .row
    lda #$FF
    sta.l !arr_buf,x
    plx
    ldx.w #!arr_buf&$FFFF
    lda.b #!arr_buf>>16
    rtl
.vanilla:
    plx
    rep #$20
    lda.l $0DF260,x
    tax
    tdc
    sep #$20
    lda #$0D
    rtl

; Caption letter (A 8-bit, X = (spell - $48) x 8 + letter). Pact effect
; spells show the monster's name.
call_caption:
    lda.l !call_cur
    beq .vanilla
    cpx.w #(!eff_first-$48)*8
    bcc .vanilla
    cpx.w #(!eff_first-$48+!call_slots)*8
    bcs .vanilla
    phx
    rep #$20
    txa
    and.w #$0007
    pha
    lda.l !call_cur
    and.w #$00FF
    dec a
    asl
    asl
    asl
    clc
    adc 1,s
    tax
    pla
    sep #$20
    lda.l $0E9800,x         ; monster names, 8 letters
    plx
    rtl
.vanilla:
    lda.l $0F8AB0,x
    rtl

assert pc() <= $0EE900, "Call block 4 overflows $0E:E840-$0E:E8FF"
