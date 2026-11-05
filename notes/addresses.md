# Addresses and lookups

Phase 0 lookups (L1–L12 in [mvp-plan.md](../mvp-plan.md)). Target: Final Fantasy II (USA) v1.1 / Rev 1, unheadered.

**Status key**
- **confirmed**: read from our ROM (`tools/dis65816.py`, or a Python dump of the table). Runtime behaviour not yet seen in Mesen unless it says so.
- **docs**: stated by a source below, not yet checked against our ROM.
- **open**: not answered yet. The "Next" line says how to answer it.

**Addressing.** SNES bus addresses are `$BB:AAAA`. Unheadered LoROM file offset = `(BB & $7F) × $8000 + (AAAA − $8000)`; `tools/ff4rom.py` has `to_offset` / `to_snes`. Confirmed with asar: `org $13FDA5` writes file offset `0x9FDA5`.

**Tools**
- `python tools/dis65816.py 00F165 20` disassembles from an address. It assumes 8-bit A and 16-bit X/Y, tracks REP/SEP, and stops at RTS/RTL/JMP/BRA.
- `tools/ff4rom.py` reads by SNES address and decodes name text.

**Sources**
- [FF4 technical documentation](https://ff4-documentation.readthedocs.io/en/latest/) (Aexoden). Targets v1.1.
- [FF4Hacking wiki](https://github.com/GameHackingDotOrg/FF4Hacking/wiki): its **ROM Map** page targets v1.1 unheadered. The **Tower of Bab-Il** pages and **Yousei's notes** target v1.0 *headered*: subtract `$200` from their file offsets.
- [aexoden/edge](https://github.com/aexoden/edge), `util/memory.lua`: RAM addresses used by a working FF4 speedrun bot.

**v1.0 → v1.1 differences.** Only code in bank `$03` (battle) moved, by 0 to 21 bytes depending on range; see the docs' [Versions](https://ff4-documentation.readthedocs.io/en/latest/versions.html) page. Data tables are at the same addresses in both versions.

## The ROM

| What | Value | Status |
| --- | --- | --- |
| File | `rom/ff2us-v1.1.smc`. The `.smc` name is cosmetic; there's no copier header | confirmed |
| Size | 1,048,576 bytes | confirmed |
| CRC32 | `23084FCD` | confirmed (matches the expected value) |
| SHA-1 | `41a74eb369a7a91815529ef99ab1b20e2bdf3e26` | confirmed |
| MD5 | `27d02a4f03e172e029c9b82ac3db79f7` | confirmed |
| Internal title / version / checksum | `FINAL FANTASY 2` / `1` / `$7728` (valid) | confirmed |

## L1 · New-game init

| What | Address | Status |
| --- | --- | --- |
| `init cecil` (ROM map label) | `$00:FFBC–$00:FFBF` | confirmed: a 4-byte stub `JSR $92D0; RTL`. The ROM map's end address (`$FFDF`) is wrong. The real init is `$00:92D0`; see the runtime section below |
| `_load initial equipment cecil` | `$00:E65E–$00:E699` | docs |
| Event 16 (`$10`) | `$12:83E0` (pointer table entry `$01E0`) | confirmed location; role unknown |

Next: breakpoint after choosing New Game in Mesen; find the first event it runs and the first map it loads.

## L2 · Flags and world state (RAM)

The save slot is WRAM `$1000–$17FF` (see L9).

| What | Address | Status |
| --- | --- | --- |
| Party records, 5 × `$40` | `$1000–$113F` | docs |
| Parked-character records, 5 × `$40` (slot 0 Kain, 1 Tellah, 2 Rosa, 3 Yang, 4 Rydia) | `$1140–$127F` | confirmed (add-character code; see L3) |
| **Plot flags**, 256: flag *n* is byte `$1280 + n/8`, bit `n%8` | `$1280–$129F` | confirmed (`_get plot flag` `$00:F165`, set `$00:F133`, clear `$00:F0FF`) |
| **NPC flags**, 512: same layout; `+$20` bytes when `$0FE5` bit 7 is set or `$1701` (map high byte) ≠ 0 | `$12E0–$131F` | confirmed (`$00:F14B` set, `$00:F118` clear, index `$00:F18C`) |
| Treasure-opened flags | probably `$12A0–$12DF` | open (`_check treasure open` `$00:98EF`) |
| Inventory, 48 × (item, count) | `$1440–$149F` | docs |
| Character names | `$1500–$1553` | docs |
| Spell lists, 13 × 24 bytes | `$1560–$1697` | docs |
| Gold (24-bit) | `$16A0` | docs (bot) |
| Frame counter, play timer | `$16A3`, `$16A4` | docs (bot) |
| Party formation | `$16A8` | docs (bot) |
| Battle speed, message speed | `$16AC`, `$16AD` | docs |
| World (`0` overworld, `1` underworld, `2` moon) | `$1700` | docs |
| Map ID | `$1701–$1702` | docs (bot) |
| Current vehicle, facing, X, Y | `$1704`, `$1705`, `$1706`, `$1707` | docs (bot) |
| Chocobo X, Y | `$1710`, `$1711` | docs (bot) |
| Other vehicles | `$1712–$172F` is heavily used by code | open |
| Encounter seeds | `$17EE`, `$17EF` | docs (bot) |

Whether a set NPC flag means "shown" or "hidden" is open.

## L3 · Adult Rydia

| What | Address / value | Status |
| --- | --- | --- |
| Character ID | `$11` (child Rydia is `$03`) | confirmed |
| Sprite/class ID | `$0B` | confirmed (add-character code forces it for ID `$11`) |
| Battle menu | `$13:FDA5` = `00 03 04 01 FF`: Fight, Black, Call, Item, **empty** | confirmed |
| Character → join source | `$00:E69A + (ID − 1)`: `< $80` is an initial-stats record, `$8n` restores parked slot *n* | confirmed |
| Adult Rydia's join source | `$84`: restore from parked slot 4 (`$1240–$127F`) | confirmed |
| Initial stats, 14 × 32 bytes | `$0F:A900–$0F:AABF` | confirmed |
| Initial equipment, 7 bytes each | `$0F:AB00–$0F:AB92` | docs |
| Initial spell lists | `$0F:C8C0–$0F:C9FF` | docs |
| Class spell list data | `$13:FDDD–$13:FE0C` | docs |
| Which of the 13 spell lists at `$1560` are adult Rydia's (Black, Call) | ? | open. Start from `$13:FDDD` |

**Adult Rydia has no initial-stats record.** Add-character (`E7 11`) copies parked slot 4 into the party, sets ID `$11` and sprite `$0B`, then refills HP and MP. On a new game that slot is empty, so she'd join with zeroed stats. Phase 2's new-game hook should write her full 64-byte record straight into party slot 0 (`$1000`) and skip `E7`.

Initial-stats records (index: character): 0 Cecil DK, 1 Kain, 2 child Rydia, 3 Tellah, 4 Edward, 5 Rosa, 6 Yang, 7 Palom, 8 Porom, 9 Cecil Paladin, 10 Cid, 11 Edge, 12 FuSoYa, 13 Golbez. Records 14–15 are `$FF` filler. Record layout (Yousei): `+00` ID and hand bits, `+01` sprite, `+02` level, `+03..06` status, `+07/09` HP / max HP, `+0B/0D` MP / max MP, `+0F..13` STR AGI VIT WIS WIL, `+17..19` EXP, `+1D..1F` EXP to next level.

Battle menus (`$13:FD50 + 5 × ID`): Cid (`$0E`) is Fight Peep Item; Edge (`$12`) is Fight Dart Sneak Ninja Item.

## L4 · Battle commands

| What | Address | Status |
| --- | --- | --- |
| Command names, 5 bytes each | `$0F:A7C6 + 5 × command` | confirmed |
| Command targeting, 1 byte each | `$13:FDC3 + command` | confirmed |
| Command handler jump table | `$03:B37C + 2 × command`; Peep's entry is at `$03:B3A4` → `$E153` | confirmed (runtime; see below) |

| ID | Name | Tgt | ID | Name | Tgt | ID | Name | Tgt |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `$00` | Fight | `50` | `$0A` | Dummy | `20` | `$14` | **Peep** | `58` |
| `$01` | Item | `00` | `$0B` | Dummy | `20` | `$15` | Dummy | `60` |
| `$02` | White | `00` | `$0C` | Aim | `50` | `$16` | Dart | `50` |
| `$03` | Black | `00` | `$0D` | Dummy | `50` | `$17` | **Sneak** | `50` |
| `$04` | Call | `00` | `$0E` | Kick | `60` | `$18` | Ninja | `00` |
| `$05` | Dummy | `60` | `$0F` | Dummy | `00` | `$19` | Dummy | `28` |
| `$06` | Jump | `58` | `$10` | Twin | `60` | `$1A` | Chang(e) | `FF` |
| `$07` | Dummy | `60` | `$11` | Dummy | `00` | `$1B` | Parry | `FF` |
| `$08` | Sing | `50` | `$12` | Dummy | `60` | `$1C` | Show | `FF` |
| `$09` | Hide | `00` | `$13` | Cover | `18` | `$1D` | Off | `FF` |

Targeting byte bits 4–6: `001` one ally, `010` all allies, `100` one enemy, `101` one ally/enemy defaulting to enemy, `110` all enemies. Peep (`$58`) and Sneak (`$50`) are both `101`.

**Peep is still the better template**, for its single-enemy targeting and messages. Its handler reportedly tests the boss bit, but **don't reuse that test**: the boss bit also covers Behemoth, the dragons and other monsters we want capturable (L6). Replace it with a lookup in the capturable table (L12).

A bank `$03` table that might fit a 26-entry command list (`$03:B372 JSR ($C38D,X)`) isn't one; its entries are code bytes.

Next: in Mesen, give Cid a Peep and set a breakpoint on reads of his battle record `+$51` after choosing Peep; follow it to the handler.

## L5 · Battle RAM

| What | Address | Status |
| --- | --- | --- |
| Battle records, `$80` each: party slots 0–4, monster slots 5–12 | `$2000`; monsters from `$2280` | docs |
| Record `+$51` command, `+$52` sub-action, `+$53` monster targets, `+$54` party targets | | docs |
| Record `+$70` (monsters): level and boss bit | | docs |
| Formation number (16-bit) | `$1800` | confirmed (event `EC` handler stores it) |
| Species for each of the 3 monster types | `$29AD–$29AF` | docs (bot) |
| Type index (0–2) for each of the 8 monster slots | `$29B5–$29BC` | docs (bot) |
| Same, kept when the monster dies | `$29BD–$29C4` | docs |
| Count per type; total remaining (battle ends at 0) | `$29CA–$29CC`; `$29CD` | docs |
| Kills per type | `$3585–$3587` | docs (bot) |
| How the battle ended | `$00A8` | docs (bot) |
| Monsters invincible | `$3881` | docs |
| Current actor / target group and slot | `$34C2–$34C5` | docs (bot) |

So slot *s* (0–7) is species `$29AD[$29B5[s]]`. Confirm in Mesen with a two-type formation.

## L6 · Monster data

| What | Address | Status |
| --- | --- | --- |
| Species count | 224 (`$00–$DF`): a 28-byte bitfield | confirmed |
| Names, 8 bytes each | `$0E:9800–$0E:9EFF` | confirmed (`$00` Imp … `$DF` Egg) |
| Gold, EXP (16-bit each) | `$0E:A000`, `$0E:A1C0` | docs |
| Record pointers (low 16 bits; bank `$0E`) | `$0E:A6A0–$0E:A85F` | confirmed |
| Records (variable length) | `$0E:A860–$0E:B42F` | confirmed |
| Record byte 0: bit 7 = boss, bits 0–6 = level; bytes 1–2 = max HP | | confirmed (Imp Lv3 HP6, Cave Bat Lv20 HP150) |

**The boss bit is set on 64 species**, and not only bosses. It's also on ordinary late-game monsters: Behemoth, Red D., Blue D., Breath, Mind, EvilMask, FatalEye, D. Lunar, Wyvern, Pale Dim, Plague, TrapDoor, Last Arm, Ogopogo. A "refuse if boss bit" rule would make those uncapturable. See L12 for the rule we're using instead.

## L7 · Monster KO and victory

| What | Address | Status |
| --- | --- | --- |
| `_set monster swooned` | `$03:8EA3–$03:8ED5` (v1.1) | docs |
| Victory check: remaining count reaches 0 | `$29CD` | docs |

Next: breakpoint on writes to `$29CD` when a monster dies; walk back to the death routine and find a safe entry point.

## L8 · Battle messages

| What | Address | Status |
| --- | --- | --- |
| Battle message pointers (16-bit, data in bank `$0F`) | `$0F:B000–$0F:B33C` | docs |
| Status-ailment text pointers | `$0F:B400–$0F:B4BA` | docs |
| Battle dialogue pointers | `$0E:F200–$0E:FFFF` | docs |
| Battle message work area | `$34CA` | docs |

Next: find Peep's output and the "immune" message, and how the handler queues them.

## L9 · Save routine

| What | Value | Status |
| --- | --- | --- |
| SRAM | 8 KB: 4 slots × `$800` at `$70:0000 + slot × $800` | confirmed |
| Save | `MVN`: `$800` bytes from WRAM `$7E:1000` to the slot (e.g. `$01:99A1`) | confirmed |
| Slot valid when | slot `+$7FE` = `$1BE4` (magic) **and** slot `+$7FC` = checksum | confirmed (`$01:9956`) |
| Checksum | 16-bit running sum (`ADC` with carry) of 16-bit words at slot offsets `$000–$7F9`, i.e. bytes `$000–$7FA`; routine `$01:CC34` | confirmed |
| Coverage | WRAM `$1000–$17FA` is saved and checksummed. Nothing to add for new data in that range | confirmed |

**Where to put the pact bitfield: Tellah's parked slot, `$1180–$11BF` (64 bytes).** Reading the code found two writers:
- add/remove character for Tellah (`$00:E5E4` / `$00:E6AF` paths), which never run in a solo game;
- the restore after the scripted Zemus fight (formation `$1B3`, `$00:E4CD`), which the sandbox won't trigger.

The static scan also flagged `$00:9EC8`, `$00:AEC8`, `$00:AEDF`, `$00:B47D`, `$00:B494`, `$01:AE7C`, `$01:C6B6` and `$02:E5F1`. Decoding each from three earlier start points always lands mid-instruction, so they're noise. Code that writes through a computed pointer can't be ruled out this way; the Mesen watch below settles it.

Keep byte `$1180` (the ID byte) at `$00` so the slot still reads as empty, and put the 28-byte bitfield at **`$1181–$119C`**.

A static scan for free bytes elsewhere in `$1280–$17FA` found only short gaps, the longest 18 bytes (`$17C2–$17D3`); `$12A0–$143F` is heavily referenced. The scan counts data that looks like code, so it errs toward "used".

Next: confirm in Mesen with a read **and** write watch on `$1180–$11BF` over a session (title → new game → walk → battles → menus → save/load).

## L10 · Free ROM space

All checked against our ROM: every byte is `$FF`.

| Range | Size | Note |
| --- | --- | --- |
| `$00:FD31–$00:FFAF` | 639 | Bank `$00` (field/event code). Stop before `$00:FFB0` |
| `$03:FEE3–$03:FFFF` | 285 | Bank `$03` (battle). Home for the capture handler |
| `$0E:B439–$0E:B6BF` | 647 | |
| `$0E:B98A–$0E:BABF` | 310 | |
| `$0E:E522–$0E:E5FF` | 222 | |
| `$0E:E840–$0E:E8FF` | 192 | |
| `$0E:F0BB–$0E:F1FF` | 325 | |
| `$0F:CF40–$0F:D1FF` | 704 | |
| `$0A:EF00–$0A:EFFF` | 256 | |
| `$1F:B900–$1F:B9BF` | 192 | |
| `$09:FFE0–$09:FFFF` | 32 | |

ROM expansion (asar can do it) gives whole free banks if these run short.

## L11 · Events

| What | Address | Status |
| --- | --- | --- |
| Event pointers: 256 × 16-bit offsets from `$12:8200` | `$12:8000–$12:81FF` | confirmed |
| Event scripts (each ends with `$FF`) | `$12:8200–$12:EFFF` | confirmed |
| Opcode jump table: `$D0 + i` → handler | `$00:E2E6`, 47 entries (`$D0–$FE`) | confirmed |
| Triggered-event pointers / data | `$12:F260` / `$12:F460` | docs |
| NPC placement pointers / data | `$13:8000` / `$13:8300` | docs |

Opcodes (handler addresses confirmed; meanings from Yousei unless marked):

| Op | Handler | Meaning |
| --- | --- | --- |
| `D1` | `$EB9D` | flash screen |
| `DA` | `$E7C4` | fade |
| `E0 xx` / `E1 xx` | `$E8BF` / `$E8CB` | add / remove item (`E0` stores its parameter in `$08FB` and calls `$00:9818`) |
| `E7 xx` | `$E578` | **add character** (confirmed: see L3) |
| `E8 xx` | `$E6AF` | **remove character** |
| `E9 xx` | `$EAB5` | wait |
| `EB` / `FC` | `$0000` | handled inside the decoder (repeat, etc.) |
| `EC xx` | `$E391` | **fight formation** (confirmed: stores `$1800`; 13 scripted fights get party special-casing, table `$00:E516`) |
| `F0`/`F1 xx` | `$EF4E` / `$EF5F` | show message (bank 1 lo / hi) |
| `F2 xx` | `$EF81` | **set plot flag** (confirmed) |
| `F3 xx` | `$EF8A` | **clear plot flag** (confirmed) |
| `F4 xx` | `$EF93` | **set NPC flag** (confirmed) |
| `F5 xx` | `$EF9C` | **clear NPC flag** (confirmed) |
| `F6 xx` | `$EF70` | show message (bank 2) |
| `FA xx` | `$E559` | play song |
| `FD xx` | `$C17C` | visual effect |
| `FE map x y p` | `$EDB1` | **load map** (`p` bit 7 = underworld/moon) |
| `FF` | — | end |

## L12 · Formation flags and the capture rule

Formations: 8 bytes each at `$0E:8000–$0E:8FFF` (512 formations). Confirmed by decoding all 512.

| Byte | Bits | Meaning |
| --- | --- | --- |
| 0 | 3 | forced back attack |
| 0 | 4 | dies like a boss |
| 0 | 7 | egg |
| 1–3 | | monster species for types 1–3 |
| 4 | 7–6, 5–4, 3–2 | count of types 1, 2, 3 |
| 5 | | arrangement |
| 6 | 0 | can't run |
| 6 | 1 | dying doesn't end the game |
| 6 | 3–2 | music: `0` normal, `1` boss, `2` fiend, `3` keep current |

**No single flag separates bosses from capturable monsters:**
- Boss music is also used for the Lunar Subterrane's monster-in-a-box fights (Behemoth, Red D., EvilMask).
- "Can't run" is also set on some ordinary Lunar encounters (Behemoth, Red D., Red D. + Blue D.).
- Some scripted fights use normal music (Golbez + Shadow `$1A8`, K. Eblan + Q. Eblan `$1AA`).

**Rule: a per-species `capturable` column in `data/monsters.csv`**, seeded as "appears in at least one formation you can run from". That gives 156 capturable and 66 not. The 66 are bosses, scripted story fights (Soldier, Officer, Fighter, General), the optional Lunar bosses (Plague, D. Lunar, Wyvern, Ogopogo, Pale Dim), Last Arm, TrapDoor, and the auto-battle intro monsters. Two species (`$53` Dummy, `$DF` Egg) are in no formation. Edit the column by hand to curate.

## In progress: runtime checks (not yet folded into the sections above)

- **L1 answered.**
  - New Game runs from `$00:8052`: `$17FB` = 0 means a new game.
  - It calls `$00:92D0`, which copies initial-stats record 0 into party slot 0, loads gear via `$00:E65E`, then does `JSL $03:8006` for stats. That's the hook point for building Rydia.
  - It then runs **event `$10`** (`LDA #$10; JSR $DF63` at `$00:8081`), the opening at `$12:83E0`.
  - `$00:FFBC` is a real 4-byte stub (`JSR $92D0; RTL`); only the ROM map's end address was wrong.
- **Event start** is `$00:DF63`, with A = event number.
- **New-game clear only runs without saves.** When no slot has a valid save, `$01:9B1D` zeroes `$1040–$17FF` at New Game. If any save exists it doesn't, so the hook must zero the pact bytes itself.
- **Spell lists.** The class table at `$13:FDDD` has 3 bytes per class (White, Black, Call). Adult Rydia (class `$B`) has no White list, Black is list 3 (`$15A8–$15BF`), and Call is list 4 (`$15C0–$15D7`).
- **Vehicles** (from `$00:9C1D`) are `[present, X, Y, map]` records:
  - hovercraft `$1718`, Enterprise `$171C`, Falcon `$1720`, Big Whale `$1724`; chocobos `$170F` and `$1712`
  - `$1704` while riding: 3 hovercraft, 4 Enterprise, 5 Falcon, 6 Big Whale
- **Tellah's slot, 7,200 frames from power-on** (title, New Game, opening, 4 map loads, 2 fights). Only three things touched it:
  - the boot RAM clear
  - the title's save-slot setup (a read)
  - `$01:9B1D`'s new-game clear

  Not covered yet: menus, save/load, longer play.
- **Harness:** `tools/mesen/run.py` with `lib.lua`, `smoke.lua`, `trace_events.lua`, `peep.lua` and `monkey.lua`. 900 frames take about 3 s; memory read/write watches slow it a lot. Memory callbacks receive **CPU addresses** (`$BB:AAAA`) even when registered on an absolute memory type.
- **L4 answered: battle command jump table at `$03:B37C`**, one 16-bit pointer (bank `$03`) per command ID.
  - Confirmed by a Fight-vs-Peep differential trace (`peep.lua`): Fight `$00` → `$C499` ran in both runs; Peep `$14` → `$E153` ran only when Peep was chosen.
  - Other entries: `$01` Item `$EB9D`, `$06` Jump `$E954`, `$0C` Aim `$E836`, `$10` Twin `$E43E`, `$13` Cover `$E60F`, `$16` Dart `$E34C`, `$17` Sneak `$E1CC`. Black, Call and Ninja are `$0000` (magic goes another way).
  - **Peep's table entry is at `$03:B3A4`.** Pointing it at new code in `$03:FEE3+` replaces Peep's effect.
- **Peep handler, `$03:E153–$03:E1B1`** (95 bytes, ends `RTS`):
  - The target's record is copied to `$2700` and the actor's to `$2680` (actor command byte at `$26D1`, sub-action at `$26D2`).
  - It tests the boss bit (`LDA $2770; BPL`) and just returns for bosses.
  - It copies target HP and max HP (`$2707`, `$2709`) into `$359A` and `$359D`, builds weakness message IDs at `$34CB+`, calls `$03:85A6`, then sets `$34CA = $1E`, `$34C8 = $14`, `$34C7 = $10` (message and animation queue).
  - Still to find for capture: where the target's slot number lives during the action, to get its species from `$29AD[$29B5[slot − 5]]`.
- **Battle code reads `$1180`.** `$03:EDD0` does `LDA $1000,X` over character slots, reaching Tellah's slot. It reads only the ID byte, sees `$00` and skips. Keep `$1180` at `$00`.
- **Tellah's slot, long watch** (`monkey.lua`): 30,000 frames covering the opening plus random walking, talking and menu presses in Baron Castle (16 map changes, 2 opening fights). The only accesses were the three startup ones: the boot clear (`$15:C9ED`), the title's save-slot setup (`$01:99AA`, read) and the no-saves new-game clear (`$01:9B25`).
  - With the Imp fights from `peep.lua`, the only in-battle access is the `$03:EDD3` ID-byte read above.
  - Not exercised at runtime: random battles outside the opening, actual saving and loading (both are whole-block `MVN` copies by code), and later-game menus.
  - **Verdict: `$1181–$119C` is safe for the pact bitfield.**
