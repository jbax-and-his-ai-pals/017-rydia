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
    bpl .list
    and #$7F                ; bit 7: column labels this frame, list next frame
    sta.l !picker_redraw
    jsl call_picker_labels
    bra .done
.list:
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

; Field Call readers. They act only while the field menu shows Rydia's Call
; list (list 4); there a slot token reads the live roster entry behind it (or,
; while the picker is open, the page cell). Save full A (with its hidden high
; byte), X/Y and P; only the low A byte and N/Z change, as the displaced
; 8-bit LDA. DB/D are untouched.

; Icon and letters: Y = $8900 + spell x 6 + n (n 0 icon, 1-5 letters), DB = $0F.
call_field_name:
    php
    rep #$30
    pha
    phx
    phy
    sep #$20
    jsr field_gate
    bcc .vanilla
    rep #$20
    lda 1,s                 ; saved Y
    sec
    sbc.w #$8900
    tax
    sep #$20
    bcc .vanilla
    jsr x_div6              ; A = spell, Y = n
    jsr field_value         ; A = entry
    bcc .vanilla
    cpy.w #0
    beq .icon
    cmp #!eid_value
    bcs .eidolon
    dec a                   ; species: call_name_table + species x 5 + n - 1
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
    lda.l call_name_table-1,x
    bra .return
.eidolon:
    jsr eidolon_x6          ; X = spell x 6: its vanilla name
    rep #$20
    tya
    sta.l !call_div
    txa
    clc
    adc.l !call_div
    tax
    sep #$20
    lda.l $0F8900,x
    bra .return
.icon:
    ; Pool view: bench entries bright, active ones grey. The list sets $DB (the
    ; entry's palette) just before this read and its letters use it; the field
    ; greys every summon ($34 | $04) since none can be cast there.
    pha                     ; the entry
    lda.l !picker_mode
    beq +++
    pla
    jsr entry_active
    lda.b $DB
    and #$FB
    bcc +
    ora #$04
+   sta.b $DB
    bra ++
+++ pla
++  lda.l !summon_icon
    bra .return
.vanilla:
    rep #$20
    lda 1,s
    tay
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

; Shared vanilla field MP helper (display and affordability), X = spell x 6.
; Caller masks bit 7.
call_field_mp:
    php
    rep #$30
    pha
    phx
    phy
    sep #$20
    jsr field_gate
    bcc .vanilla
    jsr x_div6              ; A = spell
    jsr field_value
    bcc .vanilla
    cmp #!eid_value
    bcs .eidolon
    dec a
    jsr mon_level20         ; MP = 1 + level / 2
    lsr
    inc a
    bra .return
.eidolon:
    jsr eidolon_x6
    lda.l $0F97A5,x
    bra .return
.vanilla:
    rep #$20
    lda 3,s                 ; saved X
    tax
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

; Carry set when the field Magic menu's current column is list 4 (Rydia's
; Call list). Keeps X, Y. M=8.
field_gate:
    phx
    lda.l $7E1B81
    rep #$20
    and.w #$00FF
    tax
    sep #$20
    lda.l $7E1B7E,x
    plx
    cmp #$04
    beq .yes
    clc
    rts
.yes:
    sec
    rts

; A = spell. Carry set and A = the entry behind a slot token (the live roster,
; or the picker's page cell while it is open); clear for none. Keeps X, Y.
field_value:
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
    lda.l !picker_mode
    beq .roster
    lda.l !picker_buf,x
    bra .got
.roster:
    lda.l !roster,x
.got:
    beq .no
    plx
    sec
    rts
.no:
    plx
    clc
    rts

; A = entry. Carry set when the picker is open and the entry is already in the
; active roster. Keeps A, X, Y.
entry_active:
    pha
    phx
    sta.l !call_div
    lda.l !picker_mode
    beq .no
    ldx.w #0
-   lda.l !roster,x
    cmp.l !call_div
    beq .yes
    inx
    cpx.w #!call_slots
    bne -
.no:
    plx
    pla
    clc
    rts
.yes:
    plx
    pla
    sec
    rts

assert pc() <= !field_call_code_end, "Field Call code exceeds its expanded allocation"
