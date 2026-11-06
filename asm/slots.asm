; Generic Call slots (notes/call-design.md, "24 active slots"). A slot token is
; one of the 24 spell IDs in slot_ids; slot_of maps a spell ID back to its slot
; ($FF = not a token). Both are generated into build/gen/data.asm.
;
; Every hook here acts only for adult Rydia's Call list (record ID $11, the Call
; column), so FuSoYa's Comet/Flare and Edge's Ninja spells ($40-$47) stay vanilla.
; Exception: the cast-time read has no caster in reach and keys on the token.


org $039EB1                 ; queue a spell: cast time from spell data byte 0
    jsl call_cast_time      ; was LDA $0F97A0,X

org $00E7F9                 ; event: add a spell to a list (first empty entry)
    jsr call_grant_stub     ; was STA $1560,Y
org $00FF80                 ; bank $00 free space (the New Game hook ends below)
call_grant_stub:
    jsl call_grant
    rts
assert pc() <= $00FFB0, "Grant stub runs into the bank $00 header area"

org !slots_code

; A = spell ID. Carry set and A = roster entry when it is a slot token whose
; entry is filled. Keeps X, Y.
token_entry:
    phx
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l slot_of,x
    cmp #$FF
    beq .no
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l !roster,x
    beq .no
    plx
    sec
    rts
.no:
    plx
    clc
    rts

; A = eidolon roster value (225+k). Returns X = its spell x 6. A clobbered.
eidolon_x6:
    sec
    sbc #!eid_value
    clc
    adc #!eid_first
    rep #$20
    and.w #$00FF
    sta.l !call_div         ; spell
    asl
    clc
    adc.l !call_div         ; x3
    asl                     ; x6
    tax
    sep #$20
    rts

; X = byte offset of a $2C7A battle menu entry. Carry set if the entry is in
; adult Rydia's Call column (72 entries per party slot, Call = entries 48-71).
; Keeps X.
menu_entry_is_call:
    phx
    rep #$20
    txa
    lsr
    lsr                     ; entry
    sta.l $004204           ; dividend
    sep #$20
    lda #72
    sta.l $004206           ; divisor; 16 cycles
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    lda.l $004216           ; remainder: entry within the party slot
    cmp #48
    bcc .no
    rep #$20
    lda.l $004214           ; quotient: party slot
    and.w #$00FF
    xba
    lsr                     ; x $80
    tax
    sep #$20
    lda.l $7E2000,x         ; battle record byte 0: character ID in bits 0-4
    and #$1F
    cmp #!rydia_id
    bne .no
    plx
    sec
    rts
.no:
    plx
    clc
    rts

; X = spell x 6 + n (n 0-5). Returns A = spell, Y = n. Keeps X.
x_div6:
    rep #$20
    txa
    sta.l $004204
    sep #$20
    lda #6
    sta.l $004206
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    rep #$20
    lda.l $004216
    tay
    sep #$20
    lda.l $004214
    rts

; Cast: $03:CD20, before vanilla sorts the spell into white, black or summon.
; A token in Rydia's Call list becomes the summon to cast: a monster casts as
; $31 (vanilla maps it to effect $4D) with call_cur = species+1; an eidolon
; casts as its own spell. Anything else clears call_cur.
call_route:
    php
    rep #$30
    pha
    phx
    sep #$20
    lda #$00
    sta.l !call_cur
    lda.l $7E2680           ; caster's record copy, byte 0
    and #$1F
    cmp #!rydia_id
    bne .done
    lda.l $7E26D2
    jsr token_entry
    bcc .done
    cmp #!eid_value
    bcs .eidolon
    sta.l !call_cur
    lda #$31
    sta.l $7E26D2
    bra .done
.eidolon:
    sec
    sbc #!eid_value
    clc
    adc #!eid_first
    sta.l $7E26D2
.done:
    rep #$30
    plx
    pla
    plp
    rtl

; Battle menu build: after $03:845E copied a listed spell's data ($DF = ID,
; $A9 = entry offset). A token in Rydia's Call column gets its entry's MP and
; targeting: a monster's from its level and ability, an eidolon's from its
; own spell data.
call_copy_menu:
    php
    rep #$30
    pha
    phx
    phy
    sep #$20
    lda $82
    cmp #$0F
    bne .out
    ldx $80
    cpx.w #$97A0
    bne .out
    ldx $A9
    jsr menu_entry_is_call
    bcc .out
    lda $DF
    jsr token_entry
    bcc .out
    cmp #!eid_value
    bcs .eidolon
    dec a                   ; species
    pha
    jsr mon_level20
    lsr
    inc a
    sta.l !call_tmp
    lda.l !spell_mp
    and #$80
    ora.l !call_tmp
    sta.l !spell_mp
    pla
    jsl call_ability_slot
    bra .out
.eidolon:
    jsr eidolon_x6
    ldy.w #0
-   lda.l $0F97A0,x
    phx
    tyx
    sta.l !spell_target,x   ; $289C-$28A1
    plx
    inx
    iny
    cpy.w #6
    bne -
.out:
    rep #$30
    ply
    plx
    pla
    plp
    rtl

; A = species. Returns A = its level. Uses X.
mon_level20:
    rep #$20
    and.w #$00FF
    asl
    tax
    lda.l $0EA6A0,x
    tax
    sep #$20
    lda.l $0E0000,x
    and #$7F
    rts

; Battle spell menu, $02:A0D0 (X = WRAM address of a $2C7A entry): note whether
; this entry belongs to Rydia's Call column, then the displaced LDA $0001,X /
; STA $26.
call_menu_entry:
    php
    rep #$30
    pha
    phx
    txa
    sec
    sbc.w #$2C7A
    tax
    sep #$20
    lda #$00
    sta.l !menu_flag
    cpx.w #$05A0
    bcs .done
    jsr menu_entry_is_call
    bcc .done
    lda #$01
    sta.l !menu_flag
.done:
    rep #$30
    plx
    pla
    plp
    lda.w $0001,x
    sta $26
    rtl

; Battle spell menu icon (X = spell x 6) and letters (X = spell x 6 + letter,
; letter 0-4). Keep A's high byte, X, Y and P except the returned byte and N/Z,
; as the displaced LDA long,X.
call_menu_icon:
    php
    rep #$30
    pha
    phx
    phy
    sep #$20
    jsr menu_token
    bcc .vanilla
    lda.l !summon_icon
    bra .return
.vanilla:
    lda.l $0F8900,x
.return:
    sta 5,s
    rep #$30
    ply
    plx
    pla
    plp
    ora.b #$00
    rtl

call_menu_name:
    php
    rep #$30
    pha
    phx
    phy
    sep #$20
    jsr menu_token          ; A = entry, Y = letter
    bcc .vanilla
    cmp #!eid_value
    bcs .eidolon
    dec a                   ; species: call_name_table + species x 5 + letter
    rep #$20
    and.w #$00FF
    sta.l !call_div
    asl
    asl
    clc
    adc.l !call_div
    sta.l !call_div
    tya
    clc
    adc.l !call_div
    tax
    sep #$20
    lda.l call_name_table,x
    bra .return
.eidolon:
    jsr eidolon_x6          ; X = spell x 6
    rep #$20
    tya
    sta.l !call_div
    txa
    clc
    adc.l !call_div
    tax
    sep #$20
    lda.l $0F8901,x
    bra .return
.vanilla:
    lda.l $0F8901,x
.return:
    sta 5,s
    rep #$30
    ply
    plx
    pla
    plp
    ora.b #$00
    rtl

; For the battle menu hooks (X = spell x 6 + n): carry set when the menu is
; drawing Rydia's Call column and the spell is a filled slot token; then
; A = roster entry and Y = n. Keeps X; clobbers Y. M=8.
menu_token:
    lda.l !menu_flag
    beq .no
    phx
    jsr x_div6
    jsr token_entry
    plx
    rts
.no:
    clc
    rts

; Queue a spell, $03:9EB1 (X = spell x 6, $DF = spell): cast time byte. A filled
; token casts like its summon: a monster as Imp ($31), an eidolon as itself.
call_cast_time:
    php
    rep #$30
    pha
    phx
    sep #$20
    lda $DF
    jsr token_entry
    bcc .vanilla
    cmp #!eid_value
    bcs .eidolon
    lda.l $0F97A0+(6*$31)
    bra .set
.eidolon:
    jsr eidolon_x6
    lda.l $0F97A0,x
.set:
    sta 3,s
    rep #$30
    plx
    pla
    plp
    rtl
.vanilla:
    rep #$30
    plx
    pla
    plp
    lda.l $0F97A0,x
    rtl

; Event "add spell to a list" (A = spell, Y = list offset, as at $00:E7F9).
; Eidolons join the pool and roster instead of the list; the rest as vanilla.
call_grant:
    cmp #!eid_first
    bcc .vanilla
    cmp #!eid_first+!eid_count
    bcs .vanilla
    jsl call_eidolon_grant
    rtl
.vanilla:
    sta.w $1560,y
    rtl

assert pc() <= !slots_code_end, "Slot code exceeds its allocation"
