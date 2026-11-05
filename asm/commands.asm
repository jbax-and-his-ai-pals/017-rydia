; Battle commands.
;
; Peep ($14) becomes the capture command (Phase 3 repoints its handler).
; "Pact" is a placeholder name; command names are 5 bytes, padded with $FF.

org $0FA7C6+(5*$14)       ; command name table, entry $14
    db "Pact", $FF
