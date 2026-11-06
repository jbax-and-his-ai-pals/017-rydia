; Expanded 2 MiB LoROM allocation. End symbols are exclusive.
; Keep code/data blocks separate so generated tables cannot overwrite code.

!roster_code = $208000       ; $208000-$208FFF: roster/capture runtime
!roster_code_end = $209000
!field_call_code = $209000   ; $209000-$209FFF: field Call runtime
!field_call_code_end = $20A000
!picker_code = $20A000       ; $20A000-$20BFFF: field Call roster picker
!picker_code_end = $20C000
!ability_code = $20C000      ; $20C000-$20CFFF: signature abilities
!ability_code_end = $20D000
!slots_code = $20D000        ; $20D000-$20DFFF: generic Call slots
!slots_code_end = $20E000
!call_data = $218000         ; $218000-$21BFFF: generated capturable/ability data
!call_data_end = $21C000
!newgame_table = $21C000     ; $21C000-$21CFFF: generated new-game WRAM table
!newgame_table_end = $21D000

assert !roster_code_end == !field_call_code, "roster and field Call blocks must stay adjacent"
assert !field_call_code_end == !picker_code, "field Call and picker blocks must stay adjacent"
assert !picker_code_end == !ability_code, "picker and ability blocks must stay adjacent"
assert !ability_code_end == !slots_code, "ability and slot blocks must stay adjacent"
assert !slots_code_end <= !call_data, "runtime code overlaps generated call data"
assert !call_data_end == !newgame_table, "generated table blocks must stay adjacent"
assert !newgame_table_end <= $21FFFF, "allocation exceeds the expanded LoROM"

; Field picker RAM. The page buffer ($7E:EB00), saved Call list ($7E:EB40) and
; temps ($7E:EB6x) sit in the summon decode buffer's tail: valid only while the
; picker is open, since vanilla summons overwrite it in battle. The mode and
; redraw flags must read 0 when it is closed, so they live in spare saved bytes
; ($11BA/$11BB) that New Game and Load clear.
!picker_mode       = $7E11BA      ; must read 0 whenever the picker is closed
!picker_page       = $7EEB61
!picker_total      = $7EEB62
!picker_pages      = $7EEB63
!picker_slot       = $7EEB64
!picker_redraw     = $7E11BB      ; (saved bytes: the decode buffer is overwritten in battle)
!picker_prev       = $7E11BC      ; raw Select last poll, for new-press detection
!picker_tmp0       = $7EEB66
!picker_tmp1       = $7EEB67
!picker_tmp2       = $7EEB68
!picker_reserved   = $7EEB69
!picker_res1       = $7EEB6A
!picker_buf        = $7EEB00      ; = !arr_buf (24 cells, species+1)
!picker_saved_list = $7EEB40
