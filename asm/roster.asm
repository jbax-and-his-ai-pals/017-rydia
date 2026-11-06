; Saved Call roster lifecycle. Included after call.asm so its RAM and game
; constants are available. All public entry points preserve A, X, Y, P, DB.
; Internal helpers are same-bank JSR targets (M=8, X/Y=16) and return with RTS.
;
; Three layers (notes/call-design.md, "24 active slots"):
;   pool    pact bits ($1181-$119C, 224 species) + eidolon bits ($11B6-$11B7)
;   roster  24 saved entries: 0 empty, 1-224 species+1, 225-234 eidolon k+225
;   list    Rydia's Call list ($15C0): entry i holds slot token slot_ids[i]
;           when roster entry i is filled, else 0. Always derived.
; Occupied entries only change in the field (picker) or by a grant into an
; empty entry, so battles read the live roster; there is no snapshot.

!roster_base       = !roster&$FFFF
!call_list_base    = !call_list&$FFFF

org !roster_code

; Validate the 24 entries (drop invalid, unowned and duplicate ones, keeping
; the first) and rebuild the Call list. Never fills empty entries.
call_roster_sync:
    php
    phb
    rep #$30
    pha
    phx
    phy
    sep #$20
    lda.l !call_tmp
    pha
    lda #$7E
    pha
    plb
    jsr roster_sync_body
    pla
    sta.l !call_tmp
    rep #$30
    ply
    plx
    pla
    plb
    plp
    rtl

roster_sync_body:
    ldx.w #0
.validate:
    lda.l !roster,x
    beq .next
    jsr entry_owned
    bcc .clear
    sta.l !call_tmp
    phx                     ; scan the entries before this one
    ldy.w #0
.dup:
    tya
    cmp 1,s
    beq .unique
    lda.w !roster_base,y
    cmp.l !call_tmp
    beq .duplicate
    iny
    bra .dup
.duplicate:
    plx
    bra .clear
.unique:
    plx
    bra .next
.clear:
    lda #$00
    sta.l !roster,x
.next:
    inx
    cpx.w #!call_slots
    bne .validate
    ; Project the Call list.
    ldx.w #0
.project:
    lda.l !roster,x
    beq +
    lda.l slot_ids,x
+   sta.l !call_list,x
    inx
    cpx.w #24
    bne .project
    rts

; A = roster entry value. Carry set if it names something in the pool
; (an owned species or an owned eidolon). Keeps A, X, Y.
entry_owned:
    pha
    phx
    cmp #$00
    beq .no
    cmp #!eid_value
    bcs .eidolon
    dec a
    jsr species_owned
    bra .done
.eidolon:
    sec
    sbc #!eid_value
    cmp #!eid_count
    bcs .no
    jsr eidolon_owned
    bra .done
.no:
    clc
.done:
    plx
    pla
    rts

; A = species 0..223. Carry set iff its pact bit is set. Keeps X/Y; A clobbered.
species_owned:
    phx
    pha
    and #$07
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l roster_bit_mask,x
    sta.l !call_tmp+0       ; borrowed; callers that care save call_tmp
    pla
    lsr
    lsr
    lsr
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l !pact_bits|$7E0000,x
    and.l !call_tmp
    plx
    cmp #$01
    rts

; A = eidolon 0..9. Carry set iff its pool bit is set. Keeps X/Y; A clobbered.
eidolon_owned:
    phx
    pha
    and #$07
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l roster_bit_mask,x
    sta.l !call_tmp
    pla
    lsr
    lsr
    lsr
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l !eid_bits,x
    and.l !call_tmp
    plx
    cmp #$01
    rts

; A = roster entry value (owned). Put it in the first empty entry unless it is
; already active; with no empty entry it stays in the pool only.
roster_put:
    sta.l !call_tmp
    ldx.w #0
.dup:
    lda.l !roster,x
    cmp.l !call_tmp
    beq .done
    inx
    cpx.w #!call_slots
    bne .dup
    ldx.w #0
.empty:
    lda.l !roster,x
    beq .put
    inx
    cpx.w #!call_slots
    bne .empty
    rts
.put:
    lda.l !call_tmp
    sta.l !roster,x
.done:
    rts

roster_bit_mask:
    db $01,$02,$04,$08,$10,$20,$40,$80

; Battle start: validate and project; no summon in progress.
call_battle_start:
    php
    phb
    rep #$30
    pha
    phx
    phy
    sep #$20
    lda.l !call_tmp
    pha
    lda #$7E
    pha
    plb
    jsr roster_sync_body
    lda #$00
    sta.l !call_cur
    pla
    sta.l !call_tmp
    rep #$30
    ply
    plx
    pla
    plb
    plp
    rtl

; A pact formed (from pact_command, Y = species; its bit is already set).
call_roster_add:
    php
    phb
    rep #$30
    pha
    phx
    phy
    sep #$20
    lda.l !call_tmp
    pha
    lda #$7E
    pha
    plb
    rep #$20
    cpy.w #224
    sep #$20
    bcs .done
    tya
    inc a
    jsr roster_put
    jsr roster_sync_body
.done:
    pla
    sta.l !call_tmp
    rep #$30
    ply
    plx
    pla
    plb
    plp
    rtl

; An event grants spell A ($36-$3F, an eidolon): set its pool bit and add it
; like a new pact. Other spells are not handled here (see asm/slots.asm).
call_eidolon_grant:
    php
    phb
    rep #$30
    pha
    phx
    phy
    sep #$20
    lda.l !call_tmp
    pha
    lda #$7E
    pha
    plb
    lda 6,s                 ; the granted spell (saved A, low byte)
    sec
    sbc #!eid_first
    cmp #!eid_count
    bcs .done
    pha
    and #$07
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l roster_bit_mask,x
    sta.l !call_tmp
    pla
    pha
    lsr
    lsr
    lsr
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l !eid_bits,x
    ora.l !call_tmp
    sta.l !eid_bits,x
    pla
    clc
    adc #!eid_value
    jsr roster_put
    jsr roster_sync_body
.done:
    pla
    sta.l !call_tmp
    rep #$30
    ply
    plx
    pla
    plb
    plp
    rtl

; Load / New Game boundary: validate, and give a roster with no entries at all
; (an ownership-only save) its first 24 owned entries, species then eidolons.
call_roster_restore:
    php
    phb
    rep #$30
    pha
    phx
    phy
    sep #$20
    lda #$7E
    pha
    plb
    jsr roster_sync_body
    ldx.w #0
.any:
    lda.l !roster,x
    bne .ready
    inx
    cpx.w #!call_slots
    bne .any
    lda #$01                ; empty: fill from the pool
.fill:
    jsr entry_owned
    bcc +
    pha
    jsr roster_put
    pla
+   inc a
    cmp #!eid_value+!eid_count
    bne .fill
    jsr roster_sync_body
.ready:
    lda #$00
    sta.l !call_cur
    sta.l !call_tmp
    sta.l !picker_mode
    sta.l !picker_redraw
    rep #$30
    ply
    plx
    pla
    plb
    plp
    rtl

assert pc() <= !roster_code_end, "Roster lifecycle exceeds $20:8000-$20:8FFF"
