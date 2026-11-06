; Saved Call roster lifecycle. Included after call.asm so its RAM and game
; constants are available. All entry points preserve A, X, Y, P, and DB.
; Internal helpers are same-bank JSR targets and return with RTS.

; The existing decode buffer holds the old spell list only during this
; synchronous update, before the game draws summon graphics.
!roster_base       = !roster&$FFFF
!call_list_base    = !call_list&$FFFF
!arr_buf_base      = !arr_buf&$FFFF

org !roster_code

; Reconcile the five active entries against current pact ownership, remove
; invalid/duplicate entries (keeping the first), fill holes by species ID,
; normalize the replacement cursor, then rebuild the Call spell projection.
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

; Entry state is internal: M=8, X=16. Clobbers A/X/Y and call_tmp.
roster_sync_body:
    ldx.w #0
.validate:
    lda.l !roster,x
    beq .validate_next
    cmp #225                 ; valid stored values are species+1: 1..224
    bcs .clear_current
    pha                      ; keep the stored species+1 across ownership test
    dec a
    jsr roster_has_pact
    bcc .discard_candidate
    pla
    sta.l !call_tmp
    txa
    pha                      ; duplicate scan stops at this slot index
    ldy.w #0
.duplicate:
    tya
    cmp 1,s
    beq .unique
    lda.w !roster_base,y
    cmp.l !call_tmp
    beq .duplicate_found
    iny
    bra .duplicate
.duplicate_found:
    pla
.clear_current:
    lda #$00
    sta.l !roster,x
    bra .validate_next
.discard_candidate:
    pla
    bra .clear_current
.unique:
    pla
.validate_next:
    inx
    cpx.w #!call_slots
    bne .validate

    ; The ring pointer is always an active-slot index.
    lda.l !roster_next
    cmp #!call_slots
    bcc .fill
    lda #$00
    sta.l !roster_next

.fill:
    ldy.w #0                ; candidate species, ascending from 0 to 223
.fill_species:
    tya
    jsr roster_has_pact
    bcc .fill_next
    tya
    inc a
    sta.l !call_tmp
    ldx.w #0
.fill_duplicate:
    lda.l !roster,x
    cmp.l !call_tmp
    beq .fill_next
    inx
    cpx.w #!call_slots
    bne .fill_duplicate
    ldx.w #0
.find_empty:
    lda.l !roster,x
    beq .fill_put
    inx
    cpx.w #!call_slots
    bne .find_empty
    bra .project            ; all active slots are occupied
.fill_put:
    lda.l !call_tmp
    sta.l !roster,x
.fill_next:
    iny
    cpy.w #224
    bne .fill_species

.project:
    ; Copy the old list first. This prevents writing a displaced item at entry
    ; 5 from overwriting an unread original entry 5.
    ldy.w #0
.copy_list:
    lda.w !call_list_base,y
    sta.w !arr_buf_base,y
    iny
    cpy.w #24
    bne .copy_list

    ; Compact every non-slot, nonzero, unique spell into the tail. Source is
    ; the saved copy, destination is the live list, so order is preserved.
    ldx.w #!call_slots
    ldy.w #0
.source:
    cpy.w #24
    beq .clear_tail
    lda.w !arr_buf_base,y
    iny
    cmp #$00
    beq .source
    cmp #!slot_first
    bcc .keep_candidate
    cmp #!slot_first+!call_slots
    bcc .source
.keep_candidate:
    sta.l !call_tmp
    cpx.w #24
    bcs .source
    phy                      ; source cursor
    phx                      ; destination end, used as duplicate bound
    ldy.w #!call_slots
.tail_duplicate:
    tya
    cmp 1,s
    beq .tail_unique
    lda.w !call_list_base,y
    cmp.l !call_tmp
    beq .tail_duplicate_found
    iny
    bra .tail_duplicate
.tail_duplicate_found:
    plx
    ply
    bra .source
.tail_unique:
    plx
    ply
    lda.l !call_tmp
    sta.l !call_list,x
    inx
    bra .source

.clear_tail:
    cpx.w #24
    bcs .slots
    lda #$00
    sta.l !call_list,x
    inx
    bra .clear_tail
.slots:
    ldx.w #0
.slot:
    lda.l !roster,x
    beq .empty_slot
    txa
    clc
    adc #!slot_first
    bra .put_slot
.empty_slot:
    lda #$00
.put_slot:
    sta.l !call_list,x
    inx
    cpx.w #!call_slots
    bne .slot
    rts

; A = species 0..223. Carry set iff the ownership bit is set. Preserves X/Y;
; uses call_tmp as private scratch (the public wrapper restores its old byte).
roster_has_pact:
    phx
    sta.l !call_tmp
    rep #$20
    and.w #$0007
    tax
    sep #$20
    lda.l roster_bit_mask,x
    pha
    lda.l !call_tmp
    lsr
    lsr
    lsr
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    pla
    and.l !pact_bits|$7E0000,x
    beq .not_owned
    sec
    bra .ownership_done
.not_owned:
    clc
.ownership_done:
    plx
    rts

roster_bit_mask:
    db $01,$02,$04,$08,$10,$20,$40,$80

; Battle start reconciles the field roster, snapshots the active five, and
; clears the current summon marker. Sync itself never changes battle state.
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
    ldx.w #0
.snapshot:
    lda.l !roster,x
    sta.l !call_snap,x
    inx
    cpx.w #!call_slots
    bne .snapshot
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

; Add the just-captured species before syncing. Its pact bit is already set;
; inserting it first prevents the ascending fill from consuming the new slot.
; Y = species 0..223. Duplicate species are not inserted twice.
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
    bcs .add_done
    sep #$20
    tya
    inc a
    sta.l !call_tmp
    ldx.w #0
.add_duplicate:
    lda.l !roster,x
    cmp.l !call_tmp
    beq .add_sync
    inx
    cpx.w #!call_slots
    bne .add_duplicate
    ldx.w #0
.add_empty:
    lda.l !roster,x
    beq .add_put
    inx
    cpx.w #!call_slots
    bne .add_empty
    lda.l !roster_next
    cmp #!call_slots
    bcc .ring_valid
    lda #$00
.ring_valid:
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    txa
    inc a
    cmp #!call_slots
    bcc .ring_advance
    lda #$00
.ring_advance:
    sta.l !roster_next
    bra .add_write
.add_put:
.add_write:
    lda.l !call_tmp
    sta.l !roster,x
.add_sync:
    jsr roster_sync_body
.add_done:
    sep #$20
    pla
    sta.l !call_tmp
    rep #$30
    ply
    plx
    pla
    plb
    plp
    rtl

; Load/reset boundary: reconcile saved roster order, then clear battle-only
; snapshot/current/temp state. The active roster and ring cursor remain saved.
call_roster_restore:
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
    ldx.w #0
.clear_snapshot:
    lda #$00
    sta.l !call_snap,x
    inx
    cpx.w #!roster_max
    bne .clear_snapshot
    lda #$00
    sta.l !call_cur
    sta.l !call_tmp
    pla                      ; discard saved call_tmp; restore API clears it
    rep #$30
    ply
    plx
    pla
    plb
    plp
    rtl

assert pc() <= !roster_code_end, "Roster lifecycle exceeds $20:8000-$20:8FFF"
