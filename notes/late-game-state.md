# Late-game starting state

How the sandbox's starting world state is built without a real save. The code is in `tools/snapshot.py` (flags) and `tools/late_game.py` (everything else). `python tools/late_game.py` prints the WRAM writes.

## Plot flags (`$1280–$129F`)

Only event scripts change plot flags: `F2 xx` sets, `F3 xx` clears. No other code sets one; field code only tests five (`30`, `36`, `3D`, `3E`, `E1`). `tools/events.py` decodes all 255 events. Each must end exactly where the next begins, which checks the command lengths.

Events touch 87 flags: 80 are only ever set, 2 only cleared (`10`, `E1`), and 5 both. Flag numbers follow story order: `00` is the opening, `0D` D.Mist, `33` Dr. Lugae, `41` the Sealed Cave, and `43` the Big Whale (event `9E`). Event numbers do not follow story order.

The snapshot is "after the Giant of Babil, before the final dungeon":
- **Set:** set-only flags `00–43`, plus:
  - `53`: K. Eblan at the Tower of Babil, a mid-game fight with a high flag number
  - `47–49`: the whole Giant of Babil arc counts as done. These were added in two steps:
    1. `47` (FuSoYa joins, event `D0`), because the access audit found that walking into Lunar's Lair otherwise runs `D0` and adds FuSoYa to the party.
    2. `48` (CPU fight, `E6`) and `49` (Elements fight, `ED`), both inside the Giant. With `47` alone, event call `4E` ("if `47` set and `48` clear, run `9D`") played the 394-command Giant of Babil cutscene on the first Big Whale trip, with the full cast. Reported in play on the trip to the moon.
- **Not set:**
  - `08` (Odin's trial) and `44–46` (Asura, Leviathan, Bahamut), so the summon trials stay available
  - the moon's final dungeon and Zemus (flags `4A` and up)

**Event-call format** (`$12:F260` pointers into `$12:F460`). Each call is a list of cases. Within a case:
- a plain byte `xx` means "flag `xx` must be clear"
- `FE xx` means "flag `xx` must be set"
- `FF yy` ends the case and runs event `yy` if every condition holds

The first matching case wins. Example: call `03` is `FE 0B 09 FF 1A FF 00`: if `0B` is set and `09` is clear, run Baigan's event `1A`; otherwise run event `00`.
- **Set and cleared flags, decided from the story:**

| Flag | Value | Events |
| --- | --- | --- |
| `0A` | set | cleared by `95`, set by `96` |
| `30` | set | underworld passage: opened `84`, sealed `96` (Cid), reopened `C6` |
| `32` | clear | set `8B`, cleared `96`. While set, the Enterprise can't be boarded (`$00:9FF5`) |
| `3E` | clear | set `8C` (Calbrena), cleared `96` |
| `42` | clear | set `B6` (Kain leaves), cleared by the CPU fight `E6` inside the Giant (Kain returns) |

Result: 65 plot flags set.

**Party joins.** 17 events add a character (`E7`).
- 16 set a flag the snapshot already sets, so they count as done. That includes `E6`, which re-adds Kain after the CPU.
- `3B` (Tellah) sets no flag, so whatever triggers it decides whether it can still fire. The audit didn't trigger it.

**Still possible:** with `48` set, call `4D` (a trigger at (`10`,`10`) in moon map `161`) runs event `DD`, a 243-command scene. It adds no one; `DC` is the alternative.

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
- **The Falcon reaches the underworld.** Arriving on the Falcon over the hole near Agart (`6A`,`D4`), visibly open because flag `30` is set, and pressing A takes it down. The world byte becomes `1` and the party appears at the return point (`71`,`10`).
  - The descent is vehicle code, not an event: `$00:9C2A` fires when flag `3D` or `30` is set and an Enterprise or Falcon lands in x `69–6B`, y `D3–D5`.
  - In the underworld `$1700` and `$1701` both read `01`, so a vehicle's map byte is the world number.

## Not yet verified

- That story scenes stay quiet in towns and dungeons. That's the Phase 2.5 access audit.
- That the Big Whale can reach the moon. That goes through the crystal inside the Whale, which is hard to script blind; moon maps themselves load fine (access audit).
- New Game when save files already exist. Vanilla's no-saves path zeroes `$1040–$17FF` first; with saves present, any RAM the table doesn't cover may hold leftovers.
