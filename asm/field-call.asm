; Field Call uses the live roster. Battle display/casts keep using call_snap.
; Confirmed readers: $01:B320 (five letters, DB=$0F, Y=spell*6+$8901+letter)
; and $01:B422 (MP, X=spell*6). Both enter with M=8, X/Y=16 and D=$0100.

org $01B0D8                 ; field Magic loop: pad read, was JSR $82C0
    jsr call_picker_poll_stub
org $01B223                 ; field Magic list redraw: was JSR $84A2
    jsr call_field_sync_stub
org $01B302                 ; spell icon, was LDA $0000,Y (three bytes)
    jsr call_field_name_stub
org $01B320                 ; was LDA $0000,Y (three bytes)
    jsr call_field_name_stub
org $01B422                 ; was LDA $0F97A5,X (four bytes)
    jsl call_field_mp
org $019650                 ; committed, validated Load only: was JSR $D434
    jsr call_field_load_stub

; Pristine $FF space in bank $01. Same-bank shims preserve vanilla JSR/RTS
; conventions and replay displaced calls; expanded helpers use JSL/RTL.
org $01FF35
call_field_name_stub:
    jsl call_field_name
    rts
call_field_sync_stub:
    jsl call_picker_project     ; live roster, or the open picker page
    jsr $84A2
    rts
; After the pad read: let the picker take its buttons, then redraw the
; current list if it changed (as vanilla does when switching columns).
call_picker_poll_stub:
    jsr $82C0
    jsl call_picker_input
    pha
    lda.l !picker_redraw
    beq .done
    lda #$00
    sta.l !picker_redraw
    phx
    lda.l $7E1B81            ; column -> spell list number
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l $7E1B7E,x
    jsr $B223
    plx
.done:
    pla
    rts
call_field_load_stub:
    jsl call_roster_restore
    jsr $D434
    rts
assert pc() <= $020000, "Field Call shims exceed bank $01 free space"

org !field_call_code

; Return the live pact's menu letter, or exactly the displaced ROM read.
; Save full A (including its hidden high byte), X/Y and P. Only the low A
; byte and N/Z change, matching the original 8-bit LDA. DB/D are untouched.
call_field_name:
    php
    rep #$30
    pha
    phx
    phy
    tya
    cmp.w #($8900+(!slot_first*6))
    bcc .vanilla
    jsr field_cell_count    ; A = 6 x cells shown (5 slots, or 24 picker cells)
    sec
    sbc.w #($8900+(!slot_first*6))
    cmp 1,s
    plx                     ; drop the count; X is reset below, carry kept
    bcs .vanilla
    ldx.w #0
.divide:
    cmp.w #6
    bcc .slot
    sbc.w #6
    inx
    bra .divide
.slot:
    pha                     ; byte within the record: 0 icon, 1-5 letters
    sep #$20
    jsr field_cell_species  ; A = species+1 for cell X, 0 = none
    beq .empty
    cmp #225
    bcs .empty
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
    beq .icon
    lda.l $0E9800-1,x       ; letter n is name byte n-1
    bra .return
.icon:
    lda.l $0F8900+(6*!slot_first)   ; the summon icon
    bra .return
.empty:
    rep #$20
    pla
.vanilla:
    sep #$20
    lda.w $0000,y
.return:
    sta 5,s                 ; replace only saved A's low byte
    rep #$30
    ply
    plx
    pla
    plp
    ora.b #$00              ; original reader's N/Z; preserve other flags
    rtl

; Shared vanilla field MP helper serves display and affordability. Preserve
; full A/X/Y/P as above except the returned byte/N/Z. Caller masks bit 7.
call_field_mp:
    php
    rep #$30
    pha
    phx
    phy
    cpx.w #(!slot_first*6)
    bcc .vanilla
    txa
    jsr field_cell_count
    txa
    sec
    sbc.w #(!slot_first*6)
    cmp 1,s
    plx                     ; drop the count; X is reset below, carry kept
    bcs .vanilla
    ldx.w #0
.divide:
    cmp.w #6
    bcc .slot
    sbc.w #6
    inx
    bra .divide
.slot:
    sep #$20
    jsr field_cell_species
    beq .vanilla_original_x
    cmp #225
    bcs .vanilla_original_x
    dec a
    rep #$20
    and.w #$00FF
    asl
    tax
    lda.l $0EA6A0,x         ; species record pointer (bank $0E)
    tax
    sep #$20
    lda.l $0E0000,x
    and #$7F
    lsr
    inc a
    bra .return
.vanilla_original_x:
    rep #$20
    lda 3,s                 ; saved X word
    tax
.vanilla:
    sep #$20
    lda.l $0F97A5,x
.return:
    sta 5,s
    rep #$30
    ply
    plx
    pla
    plp
    ora.b #$00
    rtl

; Returns (on the stack, as a word under the return address) 6 x the number
; of Call cells with pacts behind them: 5 slots, or 24 while the picker is open.
; Call with M=16. Keeps A, X, Y; pushes one word the caller must pull.
field_cell_count:
    pha                     ; placeholder word, becomes the count
    pha                     ; saved A
    lda 5,s                 ; return address
    sta 3,s
    sep #$20
    lda.l !picker_mode
    rep #$20
    beq .slots
    lda.w #24*6
    bra .store
.slots:
    lda.w #!call_slots*6
.store:
    sta 5,s
    pla
    rts

; X = cell. Returns A = species+1 behind it (live roster, or the picker page),
; with N/Z set from it. M=8.
field_cell_species:
    lda.l !picker_mode
    beq .roster
    lda.l !picker_buf,x
    rts
.roster:
    lda.l !roster,x
    rts

assert pc() <= !field_call_code_end, "Field Call code exceeds its expanded allocation"
