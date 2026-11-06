# Call: design

Rydia summons monsters she has a pact with. This note covers what vanilla already does, the decisions to make, and the plan. Addresses are confirmed against our ROM and, where marked, by a Mesen trace of a vanilla Imp cast (`formation $21`, Imp put in Call slot 0).

## What vanilla does (findings)

**A summon is two spells.** Spells `$31–$3F` (Imp … Bahamut) are what the menu lists. Each has effect routine `$7E` ("do nothing") and the MP cost. When cast, `$03:CD27` sends IDs `$31–$3F` to `$03:E050`, which swaps the action for an *effect spell*: `$4D + (id − $31)`, except Asura (random `$5A–$5C`) and Bahamut (`$5D`). It stores that in the actor's sub-action `$26D2`. Everything after that (data, damage, caption, graphic) runs off the effect spell. Runtime: confirmed.

**Spell data**, 6 bytes at `$0F:97A0 + 6 × id`:

| Byte | Meaning |
| --- | --- |
| 0 | bits 5–7 targeting, bits 0–4 cast time |
| 1 | power |
| 2 | hit % |
| 3 | bits 0–6 effect routine (table `$03:E091`), bit 7 a flag |
| 4 | bit 7 a flag (`$38E2`); bits 0–6 index into element/status sets `$0F:A590` (3 bytes each) |
| 5 | bits 0–6 MP cost |

For a cast, `$03:CDC7 JSR $845E` copies the effect spell's 6 bytes into `$289C–$28A1`; the effect routine runs from there. Imp's effect spell `$4D` is `80 01 32 00 00 81`: one enemy, power 1, 50% hit, effect `$00` (power-based magic damage, the same routine as Quake, Glare and Odin's attack).

**Battle spell menu.** At battle start `$03:8A44–$8A78` builds `$2C7A`, 4 bytes per entry (5 characters × 3 lists × 24): `+1` spell ID, `+3` MP cost. It gets each spell's data through the same `JSR $845E` (at `$03:8A59`). Only the cast delay is read straight from ROM later (`$03:9EB1`).

**Names.**
- Menu names: 6 bytes (icon + 5 letters) at `$0F:8900 + 6 × id`, for IDs `$00–$47`. Battle menu reader: `$02:A107` (icon) and `$02:A11F` (letters).
- From `$48` on, names are 8 letters at `$0F:8AB0 + 8 × (id − $48)`: the summon effect spells (`$4D` "Imp", `$52` "Shiva", …) and the enemy abilities (`$61` Gaze … `$A7` Needle). This is the caption shown at the top while the summon acts (`$02:CBAF`). Monster names are also 8 letters (`$0E:9800`).
- `$33` (Cockatrice) is named "Dummy" in the US version; `$0C` is the other unused menu ID.

**Graphic.** `$02:EABE` plays a spell's visuals. For effect spells `$4D–$5D` it first calls `$02:EA7F`, which, with *i* = effect spell − `$4D`:
- loads palette `$0D:FE4C[i]` (`JSR $9150`),
- decodes `$80` 3bpp tiles from `$0D:(87F0[i])` into `$7E:DBE6` (`JSR $DA3A`, bank `$0D` hard-coded),
- lays them out with arrangement `$0D:(F260[i])` (`JSR $8409`): one byte per tile, `row << 4 | column`, `$FF` ends.

Then the summoned monster appears beside Rydia, and the effect spell's own animation plays (`$0F:A050 + 4 × (id − 1)`). Runtime: confirmed (screenshots show a second Imp next to Rydia).

**These are the species' own graphics.** The monster graphics table `$0F:CA00`, 4 bytes per species, is what battle start uses (`$02:8F16`):
- byte 0: size; bits 0–5 index the size table `$0D:FF5E` (width, height in tiles). Bit 6 = character-style, bit 7 = irregular shape.
- byte 1: palette.
- bytes 2–3: graphics at file offset `$48000 + (value & $7FFF) × 8`.

Imp, Bomb and Mage's summon entries are exactly their species' palette and graphic. **All 156 capturable species are plain rectangles** from 2×2 to 12×6 tiles (at most 72 tiles; Bahamut's summon is 48, the decoder does 128). So any pacted species can be drawn through the summon path with a generated row-major arrangement.

## Goal: the whole collection, through an active roster

From the user (Nov 5): every pact must stay reachable. The Call slots are an **active roster** drawn from the permanent collection (the pact bitfield), and the player gets a way to change the roster later, in town or elsewhere.

- This milestone auto-fills the roster (D2). The roster is a species list in save RAM, sized for 16 slots now so a bigger roster needs no save change.
- A roster editor writes the same list. Candidates: a field-menu screen (the handoff's loadout menu), or a town NPC (Mysidia or the Feymarch) that swaps pacts in and out. That's its own milestone, after Call works.

**Taken** (the user left the route open): D1 (a), D2 (a), D3 (a), D4 (signature spell with the effect-`$00` guard rail), D5 as proposed.

## Decisions (recommended option first)

**D1. Loadout size and slot spells.** One-byte spell IDs, so the Call list holds a fixed set of "pact slot" spells that resolve to a species at runtime.
- **(a) 5 slots on `$31–$35`** (Imp, Bomb, Cockatrice, Mage, Chocobo). Those IDs already take the summon path end to end (menu, targeting, cast time, mapping to `$4D–$51`), and pacts make the vanilla minor summons redundant. The eidolons `$36–$3F` stay for trials.
- (b) More slots (8–16) on unused IDs (`$0C`, `$48–$4C`, `$5F`, `$60`, …). Each needs the summon range check, the menu name reader and cast-time code taught about it. More hooks and more risk; better done with the loadout menu.

**D2. Fill order.** The pact bitfield has no order, so a small list of species goes in Tellah's parked slot after the bitfield (`$119D+`, 35 bytes free there).
- **(a) Ring buffer:** slots fill in pact order, then each new pact replaces the oldest slot. A slot keeps its place in the menu.
- (b) Newest first: every new pact shifts all slots down one.

Either way the battle works from a **snapshot**. The menu (names, MP in `$2C7A`) is built at battle start, so battle start also copies the 5 slot species into battle RAM, and casts resolve from that copy. A pact formed mid-battle shows up in Call from the next battle. So D2 is only about how the list feels.

Re-pacting a species already in the list leaves it where it is. A save with pacts but an empty list (made before this milestone) gets its first 5 pacted species by ID, filled in at battle start.

**Empty slot.** A `$31–$35` entry with no species behind it (from a vanilla path, or before the fill) casts the vanilla summon unchanged.

**D3. Graphic.**
- **(a) The species' own graphic,** read from `$0F:CA00` at cast time.
- (b) A fixed vanilla sprite (Imp) for every pact. Only for the first slice, if (a) runs into sprite limits.

**D4. What a summon does.** New columns in `data/monsters.csv`:
- `call_spell`: the spell whose data and animation the summon uses. Usually the monster's signature from its AI script (an enemy ability like `$9A` D.Breath, or a spell it casts). The caption shows the monster's name.
- `call_power`: base power, replacing the spell's own (blank keeps it).
- `call_name`: 5 letters for the menu, seeded from the monster name.
- **Plain attackers** get `strike`: effect `$00` (magic damage by power, as Imp's own summon), no element, one enemy. This is **magic** damage (Rydia's magic against the target's magic defense), not the handoff's physical strike. A physical routine that works with Rydia as the caster can replace it once one is found.
- **Guard rail:** many enemy abilities use effect routines written for a monster caster (`$1E` Blaze/Maser and `$14` Blizzard/Tornado take tiny powers, so they likely scale off the caster's monster stats). The build accepts only effect routines verified from Rydia's side, starting with `$00`, and falls back to `strike` for the rest until each is checked. The animation still comes from `call_spell`.
- `tools/export_monsters.py` gains an `ai_spells` column (every spell ID in the species' AI scripts) to curate from.

**D5. Power and MP.** Milestone 6 tunes these; this sets the shape.
- **Power** = base × (monster level + Rydia's level) / 32, clamped to 1–255. Rydia's magic stat enters through the effect routine's own formula, as it does for her black magic. Example, base 10: Imp (Lv 3) with Lv 60 Rydia → 19; a Lv 60 monster → 37.
- **MP** = 1 + monster level / 2, at most 99: Imp 2, Lv 20 → 11, Lv 60 → 31. Rydia starts with 450 MP.
- Per-species constants (monster level, base power, MP) are computed at build time into a ROM table; only Rydia's level is applied at runtime.

## Plan

New file `asm/call.asm`, generated tables in `build/gen/data.asm`. Free space: `$03:FF4A–$03:FFFF` (182 bytes) for the bank `$03` wrappers; the rest goes in the bank `$0E` blocks. If the per-species tables outgrow those (8 × 224 bytes with names), expand the ROM.

| Piece | Hook | Does |
| --- | --- | --- |
| Pact order | end of `pact_command` | add the species to the slot list; set `$15C0+` to `$31…` for each filled slot |
| Battle start | `$03:8A44`, before `$2C7A` is built | fill an empty list from the bitfield; copy the slot species into a battle-RAM snapshot |
| Summon start | `$03:E050` (only for `$31–$35`) | look up the slot's species in the snapshot (none: vanilla summon); remember it in a battle RAM byte; map as vanilla |
| Spell data | `JSR $845E` at `$03:8A59` and `$03:CDC7` | after the copy: slot spell → set MP; pact effect spell → write the ability (`call_spell` data, scaled power) into `$289C–$28A1` |
| Graphic | `$02:EA7F`'s three table reads | palette, graphic address and bank, arrangement from the species |
| Caption | `$02:CBAF` | 8-letter monster name for a pact effect spell |
| Menu name | `$02:A107`, `$02:A11F`; field menu reader (to find) | `call_name` for slot spells |
| Animation | `$02:EAFB` | play `call_spell`'s animation after the monster appears |

**First slice:** one pacted monster appears in Call; casting it shows that species' graphic and does damage through effect `$00`. That covers the pact order, summon start, spell data and graphic rows. Names, the `call_spell` animation and the CSV columns come after.

**Verification:** a Mesen script in the style of `pact.lua`. Pact a monster, start a new fight, cast slot 0, then check:
- `$26D2` is the slot's effect spell,
- `$289C–$28A1` hold the scaled ability,
- the target's HP dropped,
- MP fell by the table's cost,
- a screenshot shows the species next to Rydia.

## Status

**First slice done** (`asm/call.asm`, test `tools/mesen/call.lua`). Verified headless on the built patch:

| Run | Result |
| --- | --- |
| `call.lua`, formation `$21` twice, slot 0 | Battle 1 pacts Imp then Turtle; roster `01 1B`; Call list `31 32`; menu MP 2 and 7. The Imp summon hits for power 21 and takes the Turtle from 150 HP to 0; MP 450 → 448. ALL PASS |
| same, `SEED=1 BLACK=1` | An old save's pacts (species 01–05) fill the empty roster `02 03 04 05 06`; Shiva in Call entry 0 moves to entry 5. The new pacts (Imp, Turtle) replace the two oldest slots: `01 1B 04 05 06`, next `02`. Fire1 still costs 5 MP. ALL PASS |
| same, `SLOT=1` | The Turtle (8×6, bank `$09`) appears beside Rydia in its own colours, caption "Turtle"; power 24; MP 450 → 443. ALL PASS |
| `pact.lua` `FORMS=21,82` and `FORMS=ED,82 ACTIONS=P,P,F;P` | ALL PASS (Pact still works and refuses as before) |

```
python tools/mesen/run.py tools/mesen/call.lua <out> --rom build/rydia.sfc --frames 5200 --env SYM=<abs path>/build/rydia.sym SLOT=1
```

**Built beyond the minimum:** the battle-menu names (first 5 letters of the monster name, e.g. "Turtl") and the 8-letter caption.

**Next, in order:**
1. `call_spell` / `call_power` / `call_name` columns, an `ai_spells` column from the AI scripts, and per-species tables. Free space is nearly used up, so expand the ROM first.
2. Play `call_spell`'s animation after the monster appears (`$02:EAFB`).
3. Field magic menu names for the slots (still vanilla "Imp", "Bomb", …).
4. Check effect routines from Rydia's side, one by one, and widen the allowlist.
5. Tall species (MacGiant, Ging-Ryu, RedGiant, King-Ryu, Clapper) draw only their top 8 rows. Check in play.
6. The roster editor (its own milestone).

## Open issues (from the user's playtest, Nov 5)

Imp and Imp Captain were tested in play: pacts form and summons work. Two problems:

1. **Field menu shows no Call entries.** `$15C0` is only written at battle start, so outside battle the list is empty. Fix: have `call_roster_add` (`asm/call.asm`, bank `$0A`) also write the Call entries when a pact forms, and refill the list when a save loads or a new game starts.
2. **A pact formed in battle can't be summoned until the next battle.** This is intended for now: the spell menu is built once at battle start, and its names and MP are cached in `$2C7A`. Same-battle use is possible: after a pact forms, rebuild the affected `$2C7A` entries and re-snapshot the roster. Needs a test with a pact then a cast in one fight.

## Next steps

**Update, Nov 5: ROM expansion and roster state/display implemented.** The
patched output is 2 MiB. Lifecycle code moved to `asm/roster.asm` in bank `$20`;
generated data and the New Game table moved to bank `$21`. Public state rules,
allocations and test commands are in [roster-state.md](roster-state.md).

Issue 1 is fixed: successful Pact immediately projects the live Call list; field
Magic displays the roster's five-letter names and species-dependent MP costs.
Confirmed Load validates/fills the saved roster and clears transient battle
state. New Game explicitly clears the entire parked Tellah block. The field
menu uses live roster state; the ongoing battle still uses its original snapshot.

Same-battle summons (issue 2) remain deferred. The current ring replacement policy
remains until the roster editor can make every collected species selectable.

Next: roster editor and D4 signature-ability data/animation work. Verify effect
routines from Rydia's side before widening the allowlist. Tall-monster clipping
still needs its own visual pass.

## Signature abilities (built, Nov 5)

Code `asm/ability.asm` (bank `$20:C000`), table generated by `tools/abilities.py`
into bank `$21`, test `tools/mesen/ability.lua`. The CSV columns are documented
at the top of `tools/abilities.py`.

**Rules as built** (they replace the D4 sketch above):
- Each species resolves to an **animation spell** (`call_anim`, its visual plays after the monster appears) and a **data spell** (`call_data`, which supplies targeting, hit %, effect routine and element/status set). The caption stays the monster's name.
- **Guard rail:** the data spell's effect routine must be one the player's own spells use (`$00-$13`, `$17`), so it works with Rydia as the caster. The build rejects anything else. Enemy-only routines (Petrify `$1F`, Blaze/Fire `$1E`, Explode `$25`, Tornado `$14`, ...) are reached through a player spell with a matching role instead, e.g. Bomb = Explode's animation with Fire3's data.
- **Only rows marked `call_verified=y` go live**, once their animation has been checked in Mesen. Every other species keeps the plain strike (effect `$00`, magic damage). `ai_spells` and the seeded `call_anim`/`call_data` are suggestions.
- **Power:** damage and heal routines (`$00` magic damage, `$01` White/Virus, `$02` Cure, `$04` Drain) use `call_power` (default 10) × (monster Lv + Rydia's Lv) / 32, clamped to 1-255. Status routines use the data spell's own power and hit %. MP is unchanged (1 + monster Lv / 2). Milestone 6 tunes all of this.
- **Targeting** follows the data spell (or `call_target`), both in the battle menu and at the cast.
- **Party targets:** vanilla skips summon effects aimed at the party except Asura's. Live pact abilities may reach the party too, so ally heals work. Plain strikes keep the vanilla rule.

**Starter set (live):**

| Species | Animation | Data | Role | Checked |
| --- | --- | --- | --- | --- |
| 02 Eagle | Beak | Beak | stone (status) | target gains stone |
| 05 Cave Bat | Vampire | Vampire | drain-type damage | HP drops |
| 0A SandMoth | Powder | Powder | status | status bit set |
| 0B Sandpede | Quake | Quake | damage, all enemies | HP drops |
| 0D CaveToad | Toad | Toad | Toad | Toad status set |
| 25 Gargoyle | Weak | Weak | cut HP | status/HP change |
| 38 Hydra | Entangle | Entangle | hold | paralyze bit set |
| 29 WaterBug | Remedy | Heal | cure an ally's status | targets Rydia |
| 55 Bomb | Explode | Fire3 | fire damage | HP drops |
| 5A FlameDog | Fire | Fire2 (all enemies) | fire, all enemies | HP drops |

Every animation was checked in screenshots: the effect plays on the intended side and the battle finishes. The ten are chosen from surface encounters (`data/encounters.csv`) for different roles. More species go live by curating the CSV and running `ability.lua` with their IDs.

**Fixed after the first playtest:** summons larger than their slot's vanilla summon were clipped and scrambled, and summons with a borrowed animation stayed on screen until the next round. Both fixed (see addresses.md, "Summon sprite placement and exit").

**Not done:** a physical strike for plain attackers (still magic damage); tuning; the other 71 species with suggested data; checking WaterBug's Heal against an actual status; same-battle summons.

**Testing them in play (the default for now, per the user):** `python tools/build.py`
builds a patch whose New Game starts owning every live species (the ten above).
The first five fill Call; Y in the field Call list reaches the rest. Newly
verified species join automatically. `python tools/build.py --no-test-pacts`
gives the normal empty start, which the Mesen regression tests expect.

**Batch 2 (live, Nov 5), 22 more:**

| Species | Animation → data | Role |
| --- | --- | --- |
| 01 Basil | Petrify → Stone | stone |
| 03 FlEye | Fatal | instant death |
| 04 Larva | Psych | drain MP |
| 06 Trent | Stop | stop |
| 08 TMage | Lit-1 | lightning |
| 0C SWorm | Tornado → Weak | cut HP |
| 11 Rose | Pollen | damage, all enemies |
| 20 Trick | Heat Ray | damage |
| 35 DBone | Ice-2 | ice |
| 3A Guard | Piggy | pig |
| 3F Mage | Blast → Drain | drain HP |
| 40 Naga | Tongue | paralyze |
| 4E BlMan | Wall | reflect on an ally |
| 54 Ghost | Sleep | sleep |
| 57 Chimr | Blaze → Fire3 | fire |
| 5E QLmia | Charm | confuse |
| 5F TToad | Poison | poison |
| 78 IBest | Blizzard → Ice-3, all enemies | ice, all |
| 7A Witch | Fast | haste an ally |
| 7C TLady | Size | mini |
| 85 GrnD. | Thunder → Lit-3 | lightning |
| 8B Molbl | Bad Breath | many statuses |

All 22 were cast in Mesen (`ability.lua`, four parallel runs), checked for damage
or status, and reviewed on contact sheets (`tools/mesen/contact_sheet.py`
tiles one frame per cast). The Turtle resists Pig, Mini and Bad Breath; those
three were rechecked against a lone Imp (`FORM=82`). **A summon whose effect
misses every target shows only the summoning circle,** as vanilla summons do
(`$34C5` = 0 at `$02:EAF1`).

**Call names:** `call_name` (data/monsters.csv) gives every capturable monster
a unique name of up to 5 letters for the battle and field Call menus and the
picker. Families share a pattern: CBat/GBat/WBat, GrnD./BluD./RedD./YelD.,
FlEye/RdEye/FtEye, SMoth/RMoth, Stone vs Stale. The build rejects names over 5
letters, glyphs the font lacks, and repeats. The caption while a summon acts
still shows the full monster name.

## Design: more than 5 active summons (proposal, Nov 5)

**What limits it today**
1. **Slot spell IDs.** Each active slot is its own spell ID in Rydia's Call list (`$31-$35`).
2. **Effect spells.** Slot *i* becomes effect spell `$4D+i`, and the hooks check those ranges. Each also brings its vanilla motion (Imp's punch, Bomb's, Cockatrice's, ...), so slots move differently today.
3. **Save bytes.** The roster and snapshot each reserve 16 bytes, but the picker's scratch RAM (`$11A3-$11AD`) sits inside the roster's.
4. **Shared list.** The Call list has 24 entries, shared with the eidolons (`$36-$3F`, 10 of them).

**Key simplification: one effect spell for every slot.** The graphic, name, ability, position and exit hooks all find the species through `call_cur`, not the effect spell. If every pact slot maps to effect spell `$4D`, limit 2 disappears and every summon uses the same motion.

**Spell IDs for extra slots** (checked against every monster AI sequence and the battle code):
- **`$40-$47`** (Comet, Flare, Flame, Flood, Blitz, Smoke, Pin, Image): no monster casts them, and nobody in the solo game has them. They're below `$48`, so the menus treat them as normal 6-byte-name spells.
- Not usable: IDs `$B0+` are also item IDs in battle (`$03:CDBE`). IDs `$48+` switch to 8-letter names in parts of the battle menu (`$02:A087`). The eidolons `$36-$3F` are staying.
- So **13 slots: `$31-$35` and `$40-$47`.** With all 10 eidolons that's 23 of the list's 24 entries.

**Changes**
- **Routing.** Hook the summon dispatch (`$03:CD20-$CD38`): a pact slot ID cast with Rydia's Call command becomes a summon with effect `$4D`. Today `$40+` would be cast as Black magic.
- **Slot table.** One table maps slot ID to slot index and back. Every hook (MP, targeting, names, picker, roster projection) uses it instead of `$31 + i` arithmetic.
- **Cast time.** One cast time for every pact slot (today `$33` waits 2 and `$35` waits 3), by hooking `$03:9EB1`. Per-species cast times could come later as a CSV column.
- **RAM.** Move the picker's scratch to field-only WRAM next to its page buffer (`$7E:EB60+`, extending the existing no-foreign-writes check). The roster and snapshot then have their full 16 bytes, and the active size becomes a single constant.
- **Picker.** The target slot is the cursor index if it's below N. The grid shows the N slots in rows of 3.
- **Saves.** Old saves keep their five; the new slots fill from owned species on load or at battle start.

**Caveat: party members.** `$40-$47` are FuSoYa's and Edge's spells. If the story later adds them, the hooks must also check the caster (Rydia's Call list). That's a small check to add now or later.

**Alternatives considered**
- **One spell ID repeated, identified by cursor position.** It would allow up to 24 slots, but needs battle-menu selection hooks I haven't mapped. Riskier.
- **Eidolons as pacts in the same roster.** This would free `$36-$3F` for up to 23 slots, but it decides the trial design now.

**Decisions so far (user, Nov 5):** uniform motion; caster check added now (hooks act only for Rydia's Call list).

**Absolute maximum.** The Call list (`$15C0`) and the battle spell menu hold 24 entries, one 3x8 page.
- **14 with the eidolons kept separate:** 24 - 10. IDs `$31-$35`, `$40-$47` and `$0C` (a white-range dummy no monster uses).
- **24 if eidolons become roster entries too.** That uses every safe ID below `$48` (`$0C`, `$31-$3F`, `$40-$47`). Above 16, the battle snapshot moves out of the saved block (it's rebuilt every battle) so the roster can take Tellah's slot.
- **More than 24 needs a paged battle Call menu,** i.e. new menu UI.

**Tiering summons: what the hooks can support.** Each item is a per-species CSV column the build turns into a table, keyed by the species behind a slot:
- **MP cost.** Already per-species (1 + Lv/2). A `call_tier` column could multiply it, or `call_mp` override it.
- **Cast time.** Per species, by hooking the cast-time read at `$03:9EB1`, which already knows the slot ID.
- **Power.** Already per species (`call_power`); a tier could scale it.
- **Level gate.** A summon above Rydia's level could show an unaffordable MP cost in menus, so the game itself greys it out.
- **Once per battle.** A small battle-RAM bitfield set at the cast and checked at the menu (needs a menu-disable hook).
- **Loadout budget.** The picker could limit the active roster's total tier cost, with a budget that grows with Rydia's level. This makes big summons a trade-off rather than just a cost. Picker logic only; no battle changes.

## Design: 24 active slots, eidolons in the roster, the whole bestiary in the pool

**Decided (user, Nov 5):** 24 active slots, and eidolons are roster entries like pacts.

**Three layers**
1. **Pool (storage):** permanent and never lost. 224 pact bits (`$1181-$119C`, as today) plus 10 eidolon bits (new). Every monster Rydia has ever pacted stays reachable forever.
2. **Active roster:** 24 saved entries, any mix of monsters and eidolons. An entry is species+1 (1-224), 225+k for eidolon k (Shiva ... Bahamut), or 0 (empty).
3. **Call list:** derived from the active roster, so menus and battles only ever see it.

**Slots are generic.** The 24 safe spell IDs (`$0C`, `$31-$3F`, `$40-$47`) are slot 0 ... slot 23, whatever they hold. Casting slot *i* checks roster entry *i*:
- a **monster** goes through the pact path (effect `$4D`, its graphic, ability, MP, name);
- an **eidolon** is handed to vanilla's own summon (`$03:E050` with that eidolon's spell), so Shiva, Asura's random effect and Bahamut behave exactly as in vanilla. Its name and MP come from the vanilla tables.

**Eidolons join the pool** when vanilla grants one: the trials add the eidolon's spell to the Call list. Each roster sync spots an eidolon spell sitting in the list, sets its pool bit, and adds it to the roster: into an empty slot, or the pool only if all 24 are full.

**Swap, store, retrieve.** All three happen in the field picker, which is extended:
- **Retrieve:** Y on a slot opens the pool (24 per page, up to 10 monster pages plus an eidolon page). A puts the chosen entry in the slot; an entry active elsewhere swaps (as today).
- **Store:** a "clear slot" action, e.g. Select on the slot, empties it. The entry stays in the pool.
- **Markers:** entries already active are marked in the pool view, so the roster is visible while browsing.
- **New pacts** fill an empty slot; otherwise they go to the pool only (the current rule).
- **Later:** sort or filter (by level, role, element), a details view, a loadout budget for tiers, and a town NPC as an alternative entry point.

**No battle snapshot.** New pacts never replace an occupied slot, and the picker only runs in the field, so occupied slots can't change during a battle. A pact made mid-battle can only fill a slot whose Call list entry was empty at battle start, so it can't be selected until the next battle. The hooks therefore read the live roster, and the snapshot's 16 bytes are freed.

**Save layout (Tellah's parked slot, 64 bytes)**

| Bytes | Use |
| --- | --- |
| `$1180` | 0 (empty character ID) |
| `$1181-$119C` | pact bits, 224 species (unchanged) |
| `$119D` | eidolon bits 0-7 (was the ring index, now unused) |
| `$119E-$11B5` | active roster, 24 entries (slots 0-4 unchanged) |
| `$11B6` | eidolon bits 8-9 |
| `$11B7-$11BD` | spare (7) |
| `$11BE` / `$11BF` | summon in progress / scratch (transient) |

The picker's scratch moves to field-only WRAM next to its page buffer (`$7E:EB60+`).

**Old saves:** loading repairs the roster as today. Slots 5-23 there hold old picker and snapshot bytes, which are transient copies of the five, so the existing check that drops invalid, unowned and duplicate entries cleans them up. Empty slots then fill from the pool.

**Plan, in order**
1. RAM layout plus a generic slot table. Hooks read the live roster; the snapshot and ring code go.
2. Routing at `$03:CD20` with the caster check; uniform effect `$4D`; one cast time (`$03:9EB1`).
3. 24 slots in the projection, the menus and the picker. Retest everything; old-save repair.
4. Eidolons: pool bits, spotting granted eidolon spells, routing to vanilla summons, names and MP.
5. Picker: clear slot, active markers, eidolon page.
