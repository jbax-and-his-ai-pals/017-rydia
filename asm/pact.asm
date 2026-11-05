; Pact: the capture command (battle command $14, was Peep).
;
; The command jump table entry for $14 points here instead of Peep's handler
; ($03:E153). The dispatcher ($03:B14A) enters with JML; we return with RTS to
; $03:B02F. Entry state: 8-bit A, 16-bit X/Y, DB = $7E, D = 0.
; $CE is the target: bit 7 set = monster, bits 0-2 = its monster slot (0-7).
;
; On success we set the species' bit in the pact bitfield and give the target
; pending swoon in $338E (4 bytes per battle slot). Vanilla's $03:B1B0 then runs,
; as after every command: it KOs the monster, updates the counts and ends the
; battle when none are left, exactly as a Fight kill does.

!pact_bits    = $1181       ; 28 bytes, species n: byte n>>3, bit n&7 ($1180 stays $00)
!msg_pact     = $07         ; battle message IDs; both were unused "D" stubs
!msg_refuse   = $08

org $03B37C+(2*$14)         ; command jump table, entry $14
    dw pact_command&$FFFF

org $03FEE3                 ; free space in bank $03, up to $03:FFFF
pact_command:
    tdc                     ; A = 0, high byte too, so TAX/TAY below see 8-bit values
    lda $CE
    bpl .quiet              ; aimed at an ally: nothing happens
    and #$07
    tax
    lda $29B5,x             ; monster slot -> type index ($FF once it's dead)
    bmi .quiet              ; target already gone: nothing happens
    tax
    lda $29AD,x             ; type -> species
    cmp #$E0
    bcs .refuse             ; not a species ID
    tay
    and #$07
    tax
    lda.l pact_mask,x
    sta $A9                 ; $A9: bit mask for the species (Peep uses $A9 as scratch too)
    tya
    lsr
    lsr
    lsr
    tax                     ; X = species >> 3
    lda.l capturable_table,x
    and $A9
    beq .refuse
    lda.w !pact_bits,x      ; record the pact
    ora $A9
    sta.w !pact_bits,x
    lda $CE                 ; KO: pending swoon for battle slot (monster slot + 5)
    and #$07
    clc
    adc #$05
    asl
    asl
    tax
    lda $338E,x
    ora #$80
    sta $338E,x
    lda #!msg_pact
    bra .show
.refuse:
    lda #!msg_refuse
.show:
    pha
    jsr $85A6               ; display script: show the queued messages
    pla
    sta $34CA               ; message list ($FF-terminated; the rest is already $FF)
    lda #$14                ; actor animation, as Peep does
    sta $34C8
    lda #$10
    sta $34C7
.quiet:
    rts

pact_mask:
    db $01, $02, $04, $08, $10, $20, $40, $80

assert pc() <= $040000, "Pact handler overflows bank $03 free space"

; Messages. Battle text ends with $00; the pointer table is at $0F:B000 (bank $0F).
org $0FB000+(2*!msg_pact)
    dw pact_text_ok&$FFFF
org $0FB000+(2*!msg_refuse)
    dw pact_text_refuse&$FFFF

org $0FB33D                 ; free space after the battle message text, up to $0F:B3FF
pact_text_ok:
    db "Pact formed!", $00
pact_text_refuse:
    db "The pact is refused.", $00

assert pc() <= $0FB400, "Pact messages overflow their free block"
