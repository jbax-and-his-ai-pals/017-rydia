; Expanded 2 MiB LoROM allocation. End symbols are exclusive.
; Keep code/data blocks separate so generated tables cannot overwrite code.

!roster_code = $208000       ; $208000-$208FFF: roster/capture runtime
!roster_code_end = $209000
!field_call_code = $209000   ; $209000-$209FFF: field Call runtime
!field_call_code_end = $20A000
!call_data = $218000         ; $218000-$21BFFF: generated capturable/ability data
!call_data_end = $21C000
!newgame_table = $21C000     ; $21C000-$21CFFF: generated new-game WRAM table
!newgame_table_end = $21D000

assert !roster_code_end == !field_call_code, "roster and field Call blocks must stay adjacent"
assert !field_call_code_end <= !call_data, "runtime code overlaps generated call data"
assert !call_data_end == !newgame_table, "generated table blocks must stay adjacent"
assert !newgame_table_end <= $21FFFF, "allocation exceeds the expanded LoROM"
