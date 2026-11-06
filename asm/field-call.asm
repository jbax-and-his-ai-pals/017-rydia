; Field Call uses the live roster. Battle display/casts keep using call_snap.
; Confirmed readers: $01:B320 (five letters, DB=$0F, Y=spell*6+$8901+letter)
; and $01:B422 (MP, X=spell*6). Both enter with M=8, X/Y=16 and D=$0100.

org $01B223                 ; field Magic list redraw: was JSR $84A2
    jsr call_field_sync_stub
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
    jsl call_roster_sync
    jsr $84A2
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
    cmp.w #($8901+(!slot_first*6))
    bcc .vanilla
    cmp.w #($8901+((!slot_first+!call_slots)*6))
    bcs .vanilla
    sec
    sbc.w #($8901+(!slot_first*6))
    ldx.w #0
.divide:
    cmp.w #6
    bcc .slot
    sbc.w #6
    inx
    bra .divide
.slot:
    pha                     ; letter index, word
    sep #$20
    lda.l !roster,x
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
    lda.l $0E9800,x
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
    cpx.w #((!slot_first+!call_slots)*6)
    bcs .vanilla
    txa
    sec
    sbc.w #(!slot_first*6)
    ldx.w #0
.divide:
    cmp.w #6
    bcc .slot
    sbc.w #6
    inx
    bra .divide
.slot:
    sep #$20
    lda.l !roster,x
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

assert pc() <= !field_call_code_end, "Field Call code exceeds its expanded allocation"
