# Expanded ROM and roster state contract

Implementation contract, November 5, 2026. Builds on `c660bf8`.

## ROM layout

The clean input remains the verified, unheadered 1 MiB FF2 US v1.1 ROM.
The patched output expands to 2 MiB, filled with `$FF` outside allocated data.
Keep standard LoROM mapping and 8 KiB SRAM. Update the ROM size byte and verify
the assembled output's size, header, checksum/complement, and BPS reconstruction.

| Allocation | Purpose |
| --- | --- |
| `$20:8000-$20:8FFF` | Roster lifecycle code |
| `$20:9000-$20:9FFF` | Field Call display/hooks |
| `$21:8000-$21:BFFF` | Generated pact/ability data |
| `$21:C000-$21:CFFF` | Generated New Game WRAM table |

`asm/layout.asm` defines the shared symbols. Existing battle/graphic code stays
in place except the roster routines, which move as a unit to bank `$20`; local
JSR helpers must remain in their caller's bank. Hooks use JSL across banks.

## Persistent and derived state

- `$1180`: Tellah's empty character ID, always zero.
- `$1181-$119C`: permanent ownership bits for all 224 species.
- `$119D`: ring replacement index, normalized to 0-4.
- `$119E-$11AD`: reserved roster storage; first five species+1 entries are active.
- `$11AE-$11BD`: derived battle snapshot, not authoritative save data.
- `$11BE-$11BF`: transient current summon and scratch.
- `$15C0-$15D7`: derived Call spell list; first five entries correspond to slots
  `$31-$35`, later entries retain ordinary eidolons.

The roster controls selection; ownership controls which selections are valid.
Invalid, unowned, and duplicate active entries are removed before filling empty
slots from owned species in ID order. An old bitfield-only save gets a usable
roster immediately after loading. Existing valid roster order and ring position
survive save/load.

**Superseded by the picker (below): a full roster now keeps its five.** Keep the current ring replacement policy in this step. The proposed switch to
preserving a chosen full roster belongs with the future roster picker; changing
it now would strand newly collected species without a selection UI.

## Public lifecycle calls

Each public entry accepts JSL and preserves full A, X, Y, P, and DB.

| Entry | Behavior |
| --- | --- |
| `call_roster_sync` | Validate/fill roster and project the live field Call list; preserve battle snapshot/current summon. Preserve and deduplicate non-slot spells in the tail. |
| `call_roster_add` | Y = acquired species ID. Add without duplicates, filling an empty slot or replacing the oldest; then synchronize the field list. The newly acquired pact gets priority before fallback filling. |
| `call_battle_start` | Synchronize, copy active roster to snapshot, clear current summon. Battle menus, MP, and casts use this stable snapshot. |
| `call_roster_restore` | Synchronize after load/New Game, then clear transient snapshot/current/scratch. Preserve valid saved roster and ring index. |

New Game explicitly zeros the entire `$1180-$11BF` block, even if an existing
save has previously populated RAM. Load restores the saved roster and ownership,
then repairs derived state. Entering the field Magic menu synchronizes again as
a defensive boundary for old saves and future roster edits.

## Display behavior

Field Call names and MP resolve from the live roster. Battle names, MP, graphics,
and casts continue to resolve from the battle-start snapshot. Acquiring a pact
updates the field list immediately without changing an ongoing battle's menu or
queued summon. Same-battle summons remain deferred.

Use the same five-letter species names as the battle list and the existing cost
`1 + floor(monster level / 2)`. Non-slot spells and empty slot fallbacks preserve
vanilla behavior. Summons retain their vanilla field castability restrictions;
this change makes them visible and accurately priced outside battle.

## Acceptance

Verify expanded bank code executes in Mesen, existing Pact/Call/Black MP checks
still pass, and BPS reconstructs the 2 MiB output. Then check: pact followed by
the real field Call menu; names and MP for more than one species; stable battle
snapshot after a mid-battle pact; ownership/roster/ring save/reset/load; an old
bitfield-only save; malformed roster repair; and New Game with an existing save.
Use the hardened harness's explicit completion and failure status for each.

## Implemented and verified

The contract above is implemented in `asm/roster.asm` and `asm/field-call.asm`.
The expanded build has CRC32 `344B9E14`, size 2,097,152 bytes, and a 1,866-byte
BPS that re-applies exactly. Header `$0B`, map mode, cartridge/SRAM metadata and
the full-image checksum/complement pass build validation. All 15 Python tests
pass, including seven expansion checks.

Actual Mesen checks pass for:

- Imp Call and seeded Turtle Call, including Black MP, roster fill/replacement,
  eidolon move-out, three caller-state ABI checks, and three mid-battle Pacts
  that update the live field list without changing the battle snapshot.
- Refused Pacts followed by a successful Pact, and the original bitfield
  save/reset/load test with relocated generated tables.
- A real Pact followed by the actual field Call screen. Both species' five
  rendered letters and costs are checked; selecting Turtle shows 7 MP. Browsing
  leaves MP unchanged. Non-slot field Warp retains its vanilla cost.
- Invalid, unowned and duplicate roster entries are repaired at field redraw;
  an invalid replacement cursor normalizes to zero. Eidolons are retained once,
  and a deliberately distinct snapshot/current-summon marker stays unchanged.
- Two separate real saves preserve ownership/roster/ring independently. Confirmed
  Load preserves the selected roster order, clears all 16 snapshot bytes and
  current/scratch, and restores the field list with deduplicated eidolons.
- Ownership-only saves fill their roster immediately on confirmed Load.
- A real existing-save Load, reset and New Game. The test poisons all 64 roster
  storage bytes and the Call list at the actual New Game branch, then verifies
  they clear, Rydia remains solo, and the source save is unchanged.
- The relocated New Game table reproduces all 11 non-party WRAM write regions
  exactly (world flags, inventory, spells, vehicles and cleared pact state).

Artifacts are in `build/roster-work/` (ignored). Example commands, from the repo:

```powershell
python -m unittest tools.test_build tools.mesen.test_run tools.test_audit_access -v
python tools/build.py
python tools/mesen/run.py tools/mesen/call.lua build/roster-check/call --rom build/rydia.sfc --frames 5200 --env SLOT=1 SEED=1 BLACK=1
python tools/mesen/run.py tools/mesen/field_call.lua build/roster-check/field --rom build/rydia.sfc --frames 5200
python tools/mesen/run.py tools/mesen/field_call.lua build/roster-check/repair --rom build/rydia.sfc --frames 5200 --env MODE=repair
python tools/mesen/run.py tools/mesen/roster_persist.lua build/roster-check/save --rom build/rydia.sfc --frames 6200
python tools/mesen/run.py tools/mesen/roster_persist.lua build/roster-check/legacy --rom build/rydia.sfc --frames 6200 --env MODE=legacy
python tools/mesen/run.py tools/mesen/newgame_roster.lua build/roster-check/newgame --rom build/rydia.sfc --frames 6200 --env SAVE=build/roster-check/save/sram.srm
```

Symbol-based checks resolve the current `build/rydia.sym`; pass `SYM` explicitly
when testing another build. The save file for the last command must come from
the normal roster-persistence run, since that test first verifies the saved
active roster before starting New Game. Full dungeon traversal, the roster
picker, signature abilities and same-battle summons remain separate milestones.

## Roster picker (package E)

`asm/picker.asm` (bank `$20:A000-$20:BFFF`), hooked from `asm/field-call.asm`.
Verified by `tools/mesen/picker.lua` (21 checks) on the real field menu.

**Use:** field menu > Magic > Rydia > Call. In the grid, put the cursor on a pact
slot (or anywhere: slot 0) and press **Y**. The grid becomes the whole collection,
24 pacts per page in species order, with names, the summon icon and MP. **L/R**
page, **A** puts the pact under the cursor into the slot (if it was active in
another slot, the two swap), **B** or **Y** cancels. Either way the grid returns to
the five slots with the cursor on the target slot.

**Rule change:** with all five slots chosen, a new pact joins the collection only
(`call_roster_add` no longer replaces the oldest slot). Empty slots still fill
from new pacts first, then from owned species in ID order. `$119D` (ring index)
is kept and normalized but no longer advances.

| Piece | Where |
| --- | --- |
| Pad read hook, after `JSR $82C0` | `$01:B0D8` → `call_picker_poll_stub` (bank `$01` shim): runs `call_picker_input`, then redraws the list with `$01:B223` when the picker asks |
| List redraw shim | `$01:B223` now calls `call_picker_project` (live roster, or the open page as spell IDs `$31-$48`) |
| Icon and letters | `$01:B302` and `$01:B320` share `call_field_name`; MP `$01:B422`. In picker mode they cover 24 cells from the page buffer |
| Pad bytes (D = `$0100`) | `$0100`: A `$80`, X `$40`, L `$20`, R `$10`. `$0101`: B `$80`, Y `$40`, Up `$08`, Down `$04`, Left `$02`, Right `$01` |
| Magic menu state | `$1B81` column (0 White, 1 Black, 2 Call); `$1B7E+col` spell list number (bit 7 = unavailable); `$1B87` 0 column / 1 grid; `$1B88` 1 = spell picked up for a vanilla swap; `$1B85` its cursor; `$1B83` row, `$1B84` column |
| Picker RAM | `$11A3` mode, `$11A4` page, `$11A5` total, `$11A6` pages, `$11A7` target slot, `$11A8` redraw, `$11A9-$11AD` scratch. Page buffer `$7E:EB00` (24), saved Call list `$7E:EB40` (24). Load and New Game clear `$11A3-$11AD` |

The picker only opens from the Call column with nothing picked up for a vanilla
swap. While it's open it swallows A, B, X, Y, L and R, so vanilla never casts,
swaps, switches column or leaves the menu. Directions go to the vanilla cursor.
The test also watches `$7E:EB00-$EB5F`: no code outside bank `$20` writes it
while the picker is open.

Not covered: Rydia not being the selected character (solo game only), and more
than 10 pages (224 species fit in 10).

Regression set (all pass, Nov 5; build with `python tools/build.py --no-test-pacts`
first, since the default build now starts with test pacts): `call.lua` default and `SLOT=1 SEED=1 BLACK=1`,
`field_call.lua` default and `MODE=repair`, `roster_persist.lua` default and
`MODE=legacy`, `newgame_roster.lua` (pass `SAVE` as an **absolute** path; Mesen
can't open a relative one), `pact.lua` both cases, `picker.lua`, `ability.lua` (default four cases), and
the Python tests (`tools.test_build`, `tools.mesen.test_run`,
`tools.test_audit_access`, plus `tools/test_abilities.py` run from `tools/`).
