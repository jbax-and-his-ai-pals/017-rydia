; New Game: start as adult Rydia in the late-game world.
;
; Vanilla New Game ($00:8052) sets up the world ($00:8290), creates Cecil
; ($00:92D0) and the starting spell lists ($15:C23E), then runs the opening,
; event $10, at $00:8081. We take over that call: copy the new-game table
; (gen/newgame.asm, from tools/late_game.py) into WRAM, recalculate Rydia's
; stats, then run event $10, which now just loads the overworld.

org $008081                 ; was: lda #$10 : jsr $DF63
    jsr rydia_new_game
    nop
    nop

org $00FD31                 ; free space in bank $00, up to $00:FFAF
rydia_new_game:
    php
    phb
    rep #$30
    ldx.w #newgame_data
.next:
    lda.l 0+(newgame_data&$FF0000),x    ; WRAM address; 0 ends the table
    beq .done
    tay
    lda.l 2+(newgame_data&$FF0000),x    ; length
    dec
    inx
    inx
    inx
    inx
    ; MVN: copy A+1 bytes from (table bank):X to $7E:Y; X ends on the next entry.
    ; Raw bytes because the operand order varies between assemblers: 54 dest src.
    db $54, $7E, newgame_data>>16
    bra .next
.done:
    plb
    plp                     ; back to 8-bit A, 16-bit X/Y
    lda #$00                ; character slot 0, as $00:92D0 does
    jsl $038006             ; calculate character stats
    lda #$10
    jsr $DF63               ; run event $10
    rts

assert pc() <= $00FFB0, "new-game code overflows bank $00 free space"
