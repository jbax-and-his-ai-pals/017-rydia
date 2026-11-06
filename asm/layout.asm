; Expanded 2 MiB LoROM allocation. End symbols are exclusive.
; Keep code/data blocks separate so generated tables cannot overwrite code.

!roster_code = $208000       ; $208000-$208FFF: roster/capture runtime
!roster_code_end = $209000
!field_call_code = $209000   ; $209000-$209FFF: field Call runtime
!field_call_code_end = $20A000
!picker_code = $20A000       ; $20A000-$20BFFF: field Call roster picker
!picker_code_end = $20C000
!call_data = $218000         ; $218000-$21BFFF: generated capturable/ability data
!call_data_end = $21C000
!newgame_table = $21C000     ; $21C000-$21CFFF: generated new-game WRAM table
!newgame_table_end = $21D000

assert !roster_code_end == !field_call_code, "roster and field Call blocks must stay adjacent"
assert !field_call_code_end == !picker_code, "field Call and picker blocks must stay adjacent"
assert !picker_code_end <= !call_data, "runtime code overlaps generated call data"
assert !call_data_end == !newgame_table, "generated table blocks must stay adjacent"
assert !newgame_table_end <= $21FFFF, "allocation exceeds the expanded LoROM"

; Field picker RAM: Tellah's parked slot, inside the reserved roster bytes
; (only $119E-$11A2 are active slots). Cleared by Load and New Game.
!picker_mode       = $7E11A3
!picker_page       = $7E11A4
!picker_total      = $7E11A5
!picker_pages      = $7E11A6
!picker_slot       = $7E11A7
!picker_redraw     = $7E11A8
!picker_tmp0       = $7E11A9
!picker_tmp1       = $7E11AA
!picker_tmp2       = $7E11AB
!picker_reserved   = $7E11AC
!picker_res1       = $7E11AD
!picker_buf        = $7EEB00      ; = !arr_buf (24 cells, species+1)
!picker_saved_list = $7EEB40
