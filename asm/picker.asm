; Field Call roster picker. Included after roster.asm so the Call RAM symbols
; and lifecycle entry points are already defined. Public longcalls preserve
; A/X/Y/P/DB/D; internal helpers use DB=$7E and M=8/X/Y=16.

!picker_buf_base   = !picker_buf&$FFFF
!picker_list_base  = !call_list&$FFFF
!picker_saved_base = !picker_saved_list&$FFFF
!picker_roster_base = !roster&$FFFF

org !picker_code

; Called after the vanilla controller poll at $01:B0D8. On entry DB=$7E,
; D=$0100, M=8, X/Y=16. The hook consumes picker buttons in the WRAM input
; bytes so the original menu cannot also cast or cycle characters.
call_picker_input:
    php
    phb
    phd
    rep #$30
    pha
    phx
    phy
    sep #$20
    lda #$7E
    pha
    plb
    jsr picker_input_body
    rep #$30
    ply
    plx
    pla
    pld
    plb
    plp
    rtl

; On spell-list redraw, either project the ordinary roster or the current
; picker page. In ordinary mode call_roster_sync retains the non-slot tail.
call_picker_project:
    php
    phb
    phd
    rep #$30
    pha
    phx
    phy
    sep #$20
    lda #$7E
    pha
    plb
    lda.l !picker_mode
    beq .project_normal
    jsr picker_project_body
    bra .project_done
.project_normal:
    jsl call_roster_sync
.project_done:
    rep #$30
    ply
    plx
    pla
    pld
    plb
    plp
    rtl

; ---------------------------------------------------------------------------
; Input state machine.

picker_input_body:
    lda.l !picker_mode
    beq .closed
    jmp .picker_modal
.not_now:
    rts
.closed:

    ; Y opens the picker only from adult Rydia's Call column (column 2).
    lda.l $7E0101
    and #$40
    beq .select
    jsr field_gate           ; only in Rydia's Call list (list 4)
    bcc .not_now
    lda.l $7E1B88            ; a spell is picked up for a vanilla swap
    bne .not_now
    lda.l $7E0101
    and #$BF
    sta.l $7E0101

    ; Reconcile the active five and Call tail before preserving the ordinary
    ; spell projection. The page scan also rejects an empty collection.
    jsl call_roster_sync
    stz.w !picker_page&$FFFF
    jsr picker_build_page
    lda.l !picker_total
    beq .not_now

    ldy.w #0
.save_list:
    lda.w !picker_list_base,y
    sta.w !picker_saved_base,y
    iny
    cpy.w #24
    bne .save_list

    ; If the user entered from a slot spell, retain that slot as the target;
    ; otherwise default to slot zero.
    stz.w !picker_slot&$FFFF
    lda.l $7E1B87
    beq .open_picker
    lda.l $7E1B83
    asl a
    clc
    adc.l $7E1B83
    clc
    adc.l $7E1B84
    cmp #!call_slots
    bcs .open_picker
    sta.l !picker_slot

.open_picker:
    lda #$01
    sta.l !picker_mode
    stz.w !picker_page&$FFFF
    stz.w $1B83
    stz.w $1B84
    lda #$01
    sta.l $7E1B87
    stz.w $1B88
    jsr picker_build_page
    jsr picker_project_body
    lda #$81                ; labels this frame, list next frame
    sta.l !picker_redraw
    rts

    ; Select on a filled slot in Rydia's Call grid stores it back in the pool.
    ; FF4's menu input folds Select into B ($0101 bit 7), so read the raw
    ; joypad ($4219 bit 5), take only a new press, and swallow that B.
.select:
    lda.l $004219
    and #$20
    pha
    lda.l !picker_prev
    eor #$FF
    and 1,s
    sta.l !picker_tmp0
    pla
    sta.l !picker_prev
    lda.l !picker_tmp0
    beq .select_done
    jsr field_gate
    bcc .select_done
    lda.l $7E1B87            ; in the grid, nothing picked up
    beq .select_done
    lda.l $7E1B88
    bne .select_done
    lda.l $7E0101
    and #$7F
    sta.l $7E0101
    lda.l $7E1B83
    asl a
    clc
    adc.l $7E1B83
    clc
    adc.l $7E1B84
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    cpx.w #!call_slots
    bcs .select_done
    lda #$00
    sta.w !picker_roster_base,x
    jsl call_roster_sync
    lda #$01                ; list only
    sta.l !picker_redraw
.select_done:
    rts

.picker_modal:
    ; Do not let X switch the active character while the picker is open.
    lda.l $7E0100
    and #$BF
    sta.l $7E0100

    ; B or Y cancels. Consume all non-direction inputs before returning to
    ; the Call grid so the same key cannot trigger vanilla behavior.
    lda.l $7E0101
    and #$C0
    beq .modal_page
    stz.w $0100
    lda.l $7E0101
    and #$3F
    sta.l $7E0101
    jsr picker_exit
    rts

.modal_page:
    ; L/R page the complete owned collection. Directions remain available to
    ; the vanilla 3x8 cursor movement below this hook.
    lda.l $7E0100
    and #$30
    beq .modal_confirm
    and #$20
    beq .page_right
    lda.l !picker_page
    beq .page_left_wrap
    dec a
    bra .page_changed
.page_left_wrap:
    lda.l !picker_pages
    dec a
    bra .page_changed
.page_right:
    lda.l !picker_page
    inc a
    cmp.l !picker_pages
    bcc .page_changed
    lda #$00
.page_changed:
    sta.l !picker_page
    ; Swallow A/X/L/R and preserve the four direction bits.
    stz.w $0100
    lda.l $7E0101
    and #$0F
    sta.l $7E0101
    jsr picker_build_page
    jsr picker_project_body
    lda #$81                ; labels this frame, list next frame
    sta.l !picker_redraw
    rts

.input_done:
    rts

.modal_confirm:
    lda.l $7E0100
    and #$80
    beq .input_done
    lda.l $7E0100
    and #$7F
    sta.l $7E0100

    ; Convert row/column to the current page's 0..23 buffer index.
    lda.l $7E1B83
    asl a
    clc
    adc.l $7E1B83
    clc
    adc.l $7E1B84
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    cpx.w #24
    bcs .input_done
    lda.l !picker_buf,x
    beq .input_done
    sta.l !picker_tmp0

    ; Validate ownership again before mutating the saved active roster.
    jsr entry_owned
    bcc .input_done

    ; If the chosen pact is already active in another slot, swap it with the
    ; target slot's old pact. Otherwise replace the target slot directly.
    lda.l !picker_slot
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.w !picker_roster_base,x
    sta.l !picker_tmp1
    ldy.w #0
.find_duplicate:
    lda.w !picker_roster_base,y
    cmp.l !picker_tmp0
    beq .duplicate_found
    iny
    cpy.w #!call_slots
    bne .find_duplicate
    bra .write_target
.duplicate_found:
    tya
    cmp.l !picker_slot
    beq .write_target
    lda.l !picker_tmp1
    sta.w !picker_roster_base,y
.write_target:
    lda.l !picker_slot
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l !picker_tmp0
    sta.w !picker_roster_base,x
    stz.w $0100
    lda.l $7E0101
    and #$0F
    sta.l $7E0101
    jsr picker_exit
    rts

; Restore the saved vanilla Call spell list, reconcile the changed roster,
; return the grid cursor to its target slot, and leave redraw set for the hook.
picker_exit:
    stz.w !picker_mode&$FFFF
    lda.l !picker_slot
    sta.l !picker_tmp0
    ldx.w #0
.restore_list:
    lda.w !picker_saved_base,x
    sta.w !picker_list_base,x
    stz.w !picker_saved_base,x
    inx
    cpx.w #24
    bne .restore_list

    ; Roster slot -> row/column (slot / 3, slot % 3), for 0..4.
    lda.l !picker_tmp0
    ldx.w #0
.cursor_divide:
    cmp #3
    bcc .cursor_ready
    sec
    sbc #3
    inx
    bra .cursor_divide
.cursor_ready:
    sta.l $7E1B84
    txa
    sta.l $7E1B83
    lda #$01                 ; stay in the Call grid, on the target slot
    sta.l $7E1B87
    stz.w $1B88
    jsl call_roster_sync
    jsr picker_clear_transients
    lda #$81                ; labels this frame, list next frame
    sta.l !picker_redraw
    rts

; ---------------------------------------------------------------------------
; Roster page construction and field-list projection.

; Enumerate the pool: every owned roster value in ascending order (species+1
; 1-224, then eidolons 225-234). Compute the page count and fill the current
; 24-cell page with those values (zero marks an empty cell).
picker_build_page:
    stz.w !picker_total&$FFFF
    ldy.w #1
.count_owned:
    tya
    jsr entry_owned
    bcc .count_next
    lda.l !picker_total
    inc a
    sta.l !picker_total
.count_next:
    iny
    cpy.w #!eid_value+!eid_count
    bne .count_owned

    lda.l !picker_total
    beq .no_pages
    clc
    adc #23
    ldx.w #0
.divide_pages:
    cmp #24
    bcc .pages_ready
    sec
    sbc #24
    inx
    bra .divide_pages
.pages_ready:
    txa                     ; floor((total + 23) / 24) pages
    sta.l !picker_pages
    bra .clear_page
.no_pages:
    stz.w !picker_pages&$FFFF

.clear_page:
    ldx.w #0
    lda #$00
.clear_buffer:
    sta.w !picker_buf_base,x
    inx
    cpx.w #24
    bne .clear_buffer

    ; skip = page * 24. Page count is at most ten, so repeated addition is
    ; small and avoids relying on accumulator width or a multiply routine.
    stz.w !picker_tmp2&$FFFF
    lda.l !picker_page
    sta.l !picker_tmp1
.page_skip_loop:
    lda.l !picker_tmp1
    beq .enumerate_page
    lda.l !picker_tmp2
    clc
    adc #24
    sta.l !picker_tmp2
    dec.w !picker_tmp1&$FFFF
    bra .page_skip_loop

.enumerate_page:
    ; Two passes over the pool: entries not in the active roster first (the
    ; bench, what a slot can take), then the active ones.
    lda.l !picker_tmp2
    sta.l !picker_tmp1
    ldx.w #0
    lda #$00
    sta.l !picker_reserved  ; pass: 0 bench, 1 active
.pass:
    ldy.w #1
.page_species:
    tya
    jsr entry_owned
    bcc .species_next
    tya
    jsr in_roster
    lda #$00
    rol a
    cmp.l !picker_reserved
    bne .species_next
    lda.l !picker_tmp1
    beq .put_species
    dec.w !picker_tmp1&$FFFF
    bra .species_next
.put_species:
    tya
    sta.w !picker_buf_base,x
    inx
    cpx.w #24
    beq .page_ready
.species_next:
    iny
    cpy.w #!eid_value+!eid_count
    bne .page_species
    lda.l !picker_reserved
    bne .page_ready
    inc a
    sta.l !picker_reserved
    bra .pass
.page_ready:
    rts

; A = roster value. Carry set iff it is one of the 24 active entries.
; Keeps A, X, Y.
in_roster:
    phx
    pha
    ldx.w #0
-   lda.l !roster,x
    cmp 1,s
    beq .yes
    inx
    cpx.w #!call_slots
    bne -
    pla
    plx
    clc
    rts
.yes:
    pla
    plx
    sec
    rts

; Project picker cells as the 24 slot tokens; the field readers resolve a token
; to its page cell while the picker is open.
picker_project_body:
    ldx.w #0
.project_cell:
    lda.w !picker_buf_base,x
    beq .project_empty
    lda.l slot_ids,x
    bra .project_store
.project_empty:
    lda #$00
.project_store:
    sta.w !picker_list_base,x
    inx
    cpx.w #24
    bne .project_cell
    rts

; A = species ID 0..223. Carry set iff the pact-ownership bit is set.
; Preserves X/Y; uses the two reserved picker bytes as private scratch.
picker_has_pact:
    phx
    phy
    sta.l !picker_reserved
    and #$07
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l picker_bit_mask,x
    sta.l !picker_res1
    lda.l !picker_reserved
    lsr a
    lsr a
    lsr a
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l !pact_bits|$7E0000,x
    and.l !picker_res1
    beq .not_owned
    sec
    bra .ownership_done
.not_owned:
    clc
.ownership_done:
    ply
    plx
    rts

picker_clear_transients:
    stz.w !picker_mode&$FFFF
    stz.w !picker_page&$FFFF
    stz.w !picker_total&$FFFF
    stz.w !picker_pages&$FFFF
    stz.w !picker_slot&$FFFF
    stz.w !picker_tmp0&$FFFF
    stz.w !picker_tmp1&$FFFF
    stz.w !picker_tmp2&$FFFF
    stz.w !picker_reserved&$FFFF
    stz.w !picker_res1&$FFFF
    rts

; ---------------------------------------------------------------------------
; Column labels. While the pool is open the top-left window reads "Pool" (on
; the Black line) and the page, e.g. "1 of 2" (on the Call line); on exit it
; goes back to "Black" / "Call". Text goes straight into the label layer's
; tilemap buffer ($7E:C600, two rows per line: $FF above, the glyph below, as
; $01:8301/$01:8E34 draw it), then that layer is selected for upload this
; frame ($01:8488 does the same); the poll stub redraws the list next frame.
!label_buf   = $7EC600
!label_black = $0170        ; tilemap offsets of the Black and Call lines
!label_call  = $01F0
!label_text  = $7EEB70      ; 12 bytes: Black line, then Call line

call_picker_labels:
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
    ldx.w #0
    lda.l !picker_mode
    beq .restore
-   lda.l .pool_text,x
    sta.l !label_text,x
    inx
    cpx.w #6
    bne -
    ldx.w #6                ; Call line: "a of b", or "aofb" with a 10
    lda.l !picker_page
    inc a
    jsr label_number
    lda.l !picker_page
    cmp #9
    bcs .tight
    lda.l !picker_pages
    cmp #10
    bcs .tight
    lda #$FF
    sta.l !label_text,x
    inx
.tight:
    lda #$6A                ; o
    sta.l !label_text,x
    inx
    lda #$61                ; f
    sta.l !label_text,x
    inx
    lda.l !picker_page
    cmp #9
    bcs +
    lda.l !picker_pages
    cmp #10
    bcs +
    lda #$FF
    sta.l !label_text,x
    inx
+   lda.l !picker_pages
    jsr label_number
-   cpx.w #12
    bcs .draw
    lda #$FF
    sta.l !label_text,x
    inx
    bra -
.restore:
-   lda.l .vanilla_text,x
    sta.l !label_text,x
    inx
    cpx.w #12
    bne -
.draw:
    ldx.w #!label_black
    ldy.w #0
    jsr label_line
    ldx.w #!label_call
    ldy.w #6
    jsr label_line
    rep #$20                ; select the label layer for upload ($01:8488)
    lda.w #$C600
    sta.l $7E0129
    lda.w #$7800
    sta.l $7E0135
    sep #$20
    lda #$02
    sta.l $7E01C3
    lda #$20
    sta.l $7E0134
    rep #$30
    ply
    plx
    pla
    plb
    plp
    rtl
.pool_text:
    db "Pool", $FF, $FF
.vanilla_text:
    db "Black", $FF, "Call", $FF, $FF

; A = 1-10: write its digits at !label_text,x. X advances.
label_number:
    cmp #10
    bcc +
    lda #$81
    sta.l !label_text,x
    inx
    lda #$80
    bra ++
+   clc
    adc #$80
++  sta.l !label_text,x
    inx
    rts

; X = tilemap offset of the line, Y = index of its 6 characters in !label_text.
label_line:
    lda #6
    sta.l !picker_tmp2
-   lda #$FF
    sta.l !label_buf,x
    phx
    tyx
    lda.l !label_text,x
    plx
    sta.l !label_buf+$40,x
    inx
    inx
    iny
    lda.l !picker_tmp2
    dec a
    sta.l !picker_tmp2
    bne -
    rts

picker_bit_mask:
    db $01,$02,$04,$08,$10,$20,$40,$80

assert pc() <= !picker_code_end, "Picker runtime exceeds its allocation"
