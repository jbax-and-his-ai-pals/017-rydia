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
| Battle menu | `$13:FDA5` = `00 03 04 01 FF`: Fight, Black, Call, Item, **empty**. The patch makes the fifth `$14` (Pact) | confirmed |
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
| Command handler jump table | `$03:B37C + 2 × command`; Peep's entry is at `$03:B3A4` → `$E153` (the patch points it at `$FEE3`) | confirmed (runtime) |
| Dispatch | `$03:B02C JSR $B10F` → `$B14A`: `$33C4 = $C0 + command`, then `JML [$80]` from the table. The handler's `RTS` returns to `$03:B02F` | confirmed (runtime) |
| Handler entry state | 8-bit A, 16-bit X/Y, DB = `$7E`, D = 0. Target in `$CE` (L5) | confirmed (runtime) |

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

**Pact replaces Peep** (`asm/pact.asm`, handler at `$03:FEE3`). It doesn't reuse Peep's boss test (`LDA $2770; BPL`): the boss bit also covers Behemoth, the dragons and others (L6). It checks the capturable table (L12) instead.

Sneak (`$03:E1CC`) is a second template: `$34C8 = $17`, `$34C7 = $10`, display script `F8 04` then `F8 03` (`JSR $85B1`), target in `$CE`.

A bank `$03` table that might fit a 26-entry command list (`$03:B372 JSR ($C38D,X)`) isn't one; its entries are code bytes.

## L5 · Battle RAM

| What | Address | Status |
| --- | --- | --- |
| Battle records, `$80` each: party slots 0–4, monster slots 5–12 | `$2000`; monsters from `$2280` | confirmed (runtime) |
| Record `+$51` command, `+$52` sub-action, `+$53` monster targets, `+$54` party targets | | docs |
| Record `+$70` (monsters): level and boss bit | | docs |
| Formation number (16-bit) | `$1800` | confirmed (event `EC` handler stores it) |
| Species for each of the 3 monster types; `$FF` once that type is wiped out | `$29AD–$29AF` | confirmed (runtime) |
| Type index (0–2) for each of the 8 monster slots; `$FF` once dead | `$29B5–$29BC` | confirmed (runtime) |
| Same, kept when the monster dies | `$29BD–$29C4` | docs |
| Count per type; total remaining (battle ends at 0) | `$29CA–$29CC`; `$29CD` | confirmed (runtime) |
| Kills per type (EXP comes from these) | `$3585–$3587` | confirmed (code, `$03:B216`) |
| How the battle ended | `$00A8` | docs (bot) |
| Monsters invincible | `$3881` | docs |
| Actor group / slot; target group (`$80` = monsters) / target mask | `$34C2–$34C5` | confirmed (runtime) |
| **Action target**: bit 7 = monster, bits 0–2 = monster slot 0–7; bit 7 clear = party member | `$CE` | confirmed (runtime; set at `$03:AE42` from the actor's `+$53` mask, bit 7 = slot 0) |
| Target's record copy; actor's record copy (actor command `$26D1`, monster target mask `$26D3`) | `$2700`; `$2680` | confirmed (runtime) |
| **Pending status** to add, 4 bytes per battle slot (`+$03..+$06` order) | `$338E + 4 × slot` | confirmed (runtime) |
| Battle menu open; opening animation; menu (1 = command list); command cursor (0–4) | `$D7`; `$1820`; `$1823`; `$60` | confirmed (runtime; from the bot) |

So monster slot *s* (0–7) is species `$29AD[$29B5[s]]`: confirmed with formation `$21` (Turtle in slot 0, Imps in slots 1–2).

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
| **Apply pending status** (the normal death path) | `$03:B1B0`, called after every handler from `$03:B05A` | confirmed (runtime) |
| `_set monster swooned` | `$03:8EA3–$03:8ED5`; only called from a special-formation path at `$03:8C20` | confirmed (code) |
| Victory check: remaining count reaches 0 | `$29CD` | confirmed (runtime) |

**How a monster dies.** The handler ORs `$80` (swoon) into the target's pending status, `$338E + 4 × battle slot`; Fight does this at `$03:CAEE` when HP runs out. Then `$03:B1B0` ORs every slot's pending bytes into its record (`+$03..+$06`). For a monster that gains swoon or stone it zeroes HP, sets `$29B5[s] = $FF`, decrements `$29CA[type]`, increments kills `$3585[type]` (so EXP is awarded), sets `$29AD[type] = $FF` when the type is gone, and recomputes `$29CD`. The sprite then dissolves as usual and the battle ends at 0. Pact uses this path.

## L8 · Battle messages

| What | Address | Status |
| --- | --- | --- |
| Battle message pointers: 59 × 16-bit (`$00–$3A`), bank `$0F`; text ends with `$00`, `!` = `$C4` | `$0F:B000–$0F:B075`; text `$0F:B076–$0F:B33C` | confirmed |
| Status-ailment text pointers | `$0F:B400–$0F:B4BA` | docs |
| Battle dialogue pointers | `$0E:F200–$0E:FFFF` | docs |
| Message list for the action: message IDs, ended by `$FF` | `$34CA+` | confirmed (runtime) |
| Action display script, ended by `$FF` | `$33C2+` | confirmed (runtime) |
| Message display: copies the text straight from the table | `$02:CBFF` | confirmed (code) |
| Per-message flag (1 = no wait; post-battle messages) | `$16:FD74 + ID` | confirmed |

**Display script.** The dispatcher writes `F8 02 (C0 + command) 00` at `$33C2`. `JSR $85A6` appends `F8 03` at `$33C6`, which shows the messages in `$34CA+`; `$859B` writes it at `$33C2`, and `$85B1` at `$33C8`. Fight appends `F8 04`. Handlers also set `$34C8` = command and `$34C7` = `$10` (Peep, Sneak).

**Peep's messages:** `$1E` (HP as `{06}0/{06}1`), then `$14` (no weak points) or `$15 + element`.

**Unused message IDs.** One-letter "D" stubs: `$07 $08 $09 $0F $10 $12 $13 $2E $36 $39 $3A`. All but `$07`, `$08` and `$2E` are loaded by handlers (`LDA #id; STA $34CA`); `$2E` sits among the status messages. **Pact uses `$07` ("Pact formed!") and `$08` ("The pact is refused.")**, with text at `$0F:B33D`.

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
| `$03:FEE3–$03:FFFF` | 285 | Bank `$03` (battle). Pact handler `$FEE3–$FF5F`; Call stubs `$FF60+` |
| `$0F:B33D–$0F:B3FF` | 195 | After the battle message text. Pact messages use `$B33D–$B35E` |
| `$0E:B439–$0E:B6BF` | 647 | |
| `$0E:B98A–$0E:BABF` | 310 | Call: battle start |
| `$0E:E522–$0E:E5FF` | 222 | Call: summon graphic |
| `$0E:E840–$0E:E8FF` | 192 | Call: arrangement, caption |
| `$0E:F0BB–$0E:F1FF` | 325 | Call: cast, MP, menu names |
| `$0F:CF40–$0F:D1FF` | 704 | |
| `$0A:EF00–$0A:EFFF` | 256 | Call: roster add |
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

## L13 · Spells and summons (Call)

Design and plan: [call-design.md](call-design.md). Code: `asm/call.asm`. Test: `tools/mesen/call.lua`.

| What | Address | Status |
| --- | --- | --- |
| Spell data, 6 bytes: targeting/cast time, power, hit, effect (bits 0–6), element/status set, MP (bits 0–6) | `$0F:97A0 + 6 × id` | confirmed |
| Effect routine pointers (bank `$03`), dispatched by `$03:D2A7` | `$03:E091 + 2 × effect` | confirmed. Effect `$00` = magic damage by power (all black magic, Imp's summon); `$7E` = summon spell, does nothing itself |
| Menu spell names, icon + 5 letters, IDs `$00–$47` | `$0F:8900 + 6 × id` | confirmed. Battle menu reads them at `$02:A107` (icon), `$02:A11F` (letters) |
| 8-letter names for IDs `$48+` (summon effect spells, enemy abilities) | `$0F:8AB0 + 8 × (id − $48)` | confirmed. Caption reader `$02:CBAF` |
| Spell visuals, 4 bytes | `$0F:A050 + 4 × (id − 1)` | confirmed (read at `$02:EB04`) |
| Copy 6 bytes of `[$80]` record `$E5` to `$289C–$28A1` | `$03:845E` | confirmed. **It moves the ID from `$E5` to `$DF`** and leaves the record size in `$E5` |
| Battle spell menu: 4 bytes per entry, `+1` spell, `+3` MP; built at battle start | `$2C7A` (`$03:8A44–$8A78`) | confirmed (runtime) |
| Summon dispatch: spells `$31–$3F` → `$03:E050` | `$03:CD27–$CD38` | confirmed (runtime) |
| Summon → effect spell: `$4D + (id − $31)`; Asura random `$5A–$5C`; Bahamut `$5D`. Stored in `$26D2` | `$03:E050–$E077` | confirmed (runtime) |
| The cast copies the effect spell's data, and **charges that copy's MP** | `$03:CDC7` | confirmed (runtime) |
| Spell visuals entry; effect spells `$4D–$5D` load the summoned monster first | `$02:EABE` → `$02:EA7F` | confirmed (runtime) |
| Summon graphic tables (index = effect spell − `$4D`): palette, tile address (bank `$0D`), arrangement | `$0D:FE4C`, `$0D:87F0`, `$0D:F260` | confirmed. Imp, Bomb and Mage entries equal their species' own palette and graphic |
| 3bpp → 4bpp tile decoder: `$02`–`$04` source, X dest, `$00` tile count | `$02:DA3A` | confirmed. The summon path decodes into `$7E:DBE6` |
| Arrangement uploader: one byte per tile, `row << 4 \| column`, bit 7 set = skip, `$FF` = end. Reads it only while it runs | `$02:8409` | confirmed (code) |
| **Monster graphics, 4 bytes per species**: size (bits 0–5 → `$0D:FF5E`; bit 6 character-style; bit 7 irregular), palette, graphics | `$0F:CA00 + 4 × species` | confirmed. Graphics at file offset `$48000 + (v & $7FFF) × 8`, i.e. bank `$09 + (v >> 12)`, address `$8000 \| (v & $0FFF) << 3` |
| Monster sizes, (width, height) in tiles | `$0D:FF5E + 2 × size` | confirmed. All 156 capturable species are plain rectangles, 2×2 to 12×6; 5 are taller than 8 rows |
| Battle-start hook point, before the spell menu build | `$03:89CB` | confirmed (runtime) |
| Actor's level (battle record copy) | `$2682` | confirmed (runtime) |

**Call's RAM** (Tellah's parked slot, saved): roster `$119E` (16 × species+1), ring index `$119D`, battle snapshot `$11AE` (16), summon in progress `$11BE`, scratch `$11BF`. Summon drawing also uses `$7E:EB00+` (arrangement) and `$7E:EBE0–$EBE2`, the unused tail of the decode buffer.

**Gotchas met while building it:**
- asar assembles `bra $02EAA7` (a number, not a label) as the raw offset byte. Put a label at the target instead.
- Vanilla code often does `TAX` with 8-bit A, so the accumulator's high byte must survive a hook. A hook that left it as `$A8` made `$845E` copy about 43 KB over RAM.

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
  - The target is `$CE` (L5): monster slot = `$CE & 7`, species `$29AD[$29B5[slot]]`.
- **Battle code reads `$1180`.** `$03:EDD0` does `LDA $1000,X` over character slots, reaching Tellah's slot. It reads only the ID byte, sees `$00` and skips. Keep `$1180` at `$00`.
- **Tellah's slot, long watch** (`monkey.lua`): 30,000 frames covering the opening plus random walking, talking and menu presses in Baron Castle (16 map changes, 2 opening fights). The only accesses were the three startup ones: the boot clear (`$15:C9ED`), the title's save-slot setup (`$01:99AA`, read) and the no-saves new-game clear (`$01:9B25`).
  - With the Imp fights from `peep.lua`, the only in-battle access is the `$03:EDD3` ID-byte read above.
  - Not exercised at runtime: random battles outside the opening, actual saving and loading (both are whole-block `MVN` copies by code), and later-game menus.
  - **Verdict: `$1181–$119C` is safe for the pact bitfield.**
- **Phase 3 verified** (`tools/mesen/pact.lua`, on the built patch): findings are folded into L4, L5, L7, L8 and L10.
  - The harness drives the real menu with `$D7`/`$1823`/`$60` and checks RAM after each Pact. Its fixture rewrites event `$10` to load the overworld, then fight each formation in `FORMS` and reload the map. Without the reload the screen stays garbled after the last fight, with Fight as well as Pact.
  - Runs: `FORMS=21,82` (Turtle + 2 Imps, then 1 Imp) and `FORMS=ED,82 ACTIONS="P,P,F;P"` (Officer + Soldiers: refused twice, then won with Fight) and `FORMS=E0` (Antlion, a boss: refused four times, fight goes on). `result.txt` ends `ALL PASS` only if every battle started and at least one Pact ran.
