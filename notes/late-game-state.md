# Late-game starting state

How the sandbox's starting world state is built without a real save. The code is in `tools/snapshot.py` (flags) and `tools/late_game.py` (everything else). `python tools/late_game.py` prints the WRAM writes.

## Plot flags (`$1280–$129F`)

Only event scripts change plot flags: `F2 xx` sets, `F3 xx` clears. No other code sets one; field code only tests five (`30`, `36`, `3D`, `3E`, `E1`). `tools/events.py` decodes all 255 events. Each must end exactly where the next begins, which checks the command lengths.

Events touch 87 flags: 80 are only ever set, 2 only cleared (`10`, `E1`), and 5 both. Flag numbers follow story order: `00` is the opening, `0D` D.Mist, `33` Dr. Lugae, `41` the Sealed Cave, and `43` the Big Whale (event `9E`). Event numbers do not follow story order.

The snapshot is "just after the Big Whale":
- **Set:** set-only flags `00–43`, plus `53` (K. Eblan at the Tower of Babil, a mid-game fight with a high flag number).
- **Not set:**
  - `08` (Odin's trial) and `44–46` (Asura, Leviathan, Bahamut), so the summon trials stay available
  - everything after the Whale: FuSoYa joins (`47`), Giant of Babil (`49`), moon dungeon, CPU, Zemus
- **Set and cleared flags, decided from the story:**

| Flag | Value | Events |
| --- | --- | --- |
| `0A` | set | cleared by `95`, set by `96` |
| `30` | set | underworld passage: opened `84`, sealed `96` (Cid), reopened `C6` |
| `32` | clear | set `8B`, cleared `96`. While set, the Enterprise can't be boarded (`$00:9FF5`) |
| `3E` | clear | set `8C` (Calbrena), cleared `96` |
| `42` | set | set `B6` (Kain leaves), cleared only by the final CPU fight |

Result: 63 plot flags set.

## NPC flags (`$12E0–$131F`)

New Game copies 64 starting bytes from `$12:F200` (`$00:82C6`). The snapshot applies `F4` (set) and `F5` (clear) from events up to the Whale. When an event both sets and clears a flag, the event that sets the highest plot flag wins.

**Known gap:** NPC flags come in two banks of 256. The bank depends on the map the event runs on (bank 1 for map IDs `$100+`). 114 of 127 changes come from events that never load a map first, so they're assumed to be bank 0. Underworld and moon NPCs may therefore show or hide wrongly. The access audit catches any that block a path. The fix is to decode the event-call table (`$12:F260` / `$12:F460`) and the map triggers (`$15:8000`) to learn each event's map.

## Party, spells, items, vehicles

- **Party slot 0:** adult Rydia (ID `$11`, sprite `$0B`, back row), built from child Rydia's initial-stats record 2.
  - Level 60, 3000 HP, 450 MP, base stats 20/40/30/60/45.
  - Ribbon and Stardust rod; body and arms are child Rydia's starting gear.
  - Slots 1–4 empty.
- **Spells:** Black magic list 3 (`$15A8`) has the 24 black spells; Call list 4 (`$15C0`) is empty. Unused slots are `$00` (the starting-list loader at `$15:C23E` stops at `$FF`).
- **Items:** 30 Cure3, 20 Ether2, 5 Elixir, 20 Heal, 10 Life. 500,000 gold.
- **Start:** event `$10` becomes `FE FB 9A C8 00 FF`, putting Rydia on foot just outside Mysidia.
  - `FE`'s fourth parameter: bits 0–4 are the vehicle to arrive riding (`6` = Big Whale); bit 7 is the underworld/moon plane.
- **Vehicles:** records `[present, x, y, map]`. The Big Whale is at (`99`,`C7`), where event `9E` lands it; the Falcon at (`9C`,`C8`); the Enterprise at (`9D`,`C6`). The map byte is `0` for the surface.
- **Pacts:** `$1181–$119C` cleared.

## How the patch applies it

`asm/newgame.asm` replaces the opening's `LDA #$10; JSR $DF63` at `$00:8081` with `JSR $00:FD31`. That routine does three things:
1. Walks the table at `$0F:CF40`, generated into `build/gen/newgame.asm` from `late_game.py`. Each entry is `dw address, length` followed by the bytes; `dw 0` ends it. It block-copies each entry into WRAM with `MVN`.
2. Calls `JSL $03:8006` with A = 0 to recalculate Rydia's stats.
3. Runs event `$10`.

Vanilla's world setup, Cecil and spell-list code all run before it, so nothing overwrites the table.

## Verified

- **The built patch, no test scripting** (`tools/mesen/dump_wram.lua`): after New Game, all 12 table regions in WRAM match `late_game.py` byte for byte.
  - Rydia's derived stats are filled in; Wisdom is 75, base 60 plus equipment.
  - She stands on the overworld at (`9A`,`C8`) outside Mysidia, with the Whale, Falcon and Enterprise around her.
- **Earlier, before the patch existed:** `tools/mesen/start_test.lua` applied the same writes from a script, with the same result.

## Not yet verified

- That story scenes stay quiet in towns and dungeons. That's the Phase 2.5 access audit.
- That the Falcon can descend to the underworld, and the Whale can reach the moon.
- New Game when save files already exist. Vanilla's no-saves path zeroes `$1040–$17FF` first; with saves present, any RAM the table doesn't cover may hold leftovers.
