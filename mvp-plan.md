# Rydia MVP — Plan

Nov 2, 2026 · builds on [handoff.md](handoff.md)

## The MVP

Adult Rydia, alone, in a late-game FF4 world she can travel freely. She has a battle command that captures the monster she's fighting. Every capture is recorded and survives a save and reload.

That's narrower than the handoff's MVP in two ways:

- **Capture is a command, not a drop.** It's deterministic and repeatable: choose the command, choose a monster, and the pact is made. No weakening, no roll, nothing consumed. Echo drops come back later as a second way to earn pacts.
- **Summoning (Call) moves out.** It's the first milestone after this one. The handoff calls it the hardest piece, and it can't be tested until capture exists anyway.

### Done when

1. New Game puts adult Rydia alone on the world map next to the airships. No intro.
2. She can reach the surface, underworld and moon, and enter every area on the access checklist without a story scene firing.
3. In a normal battle, the capture command removes the target with a message and records its pact.
4. Against a boss, the command fails with a message and the fight continues.
5. The pact shows in Mesen's memory viewer, and survives save → reset → load.
6. The command works every time, on any species and on repeats.
7. One command builds a BPS from a clean ROM and refuses the wrong ROM.

## Changes from the handoff

| Handoff | This plan | Why |
| --- | --- | --- |
| Echo drops are the MVP tier | A capture command is | It's the requested MVP, and a deterministic command is easy to test |
| Call in battle is in the MVP | First milestone after the MVP | Hardest piece; needs capture first |
| One byte per species | One bit per species: 28 bytes for 224 species, in Tellah's unused parked-character slot | Already saved and checksummed, so no SRAM expansion and no save code. Byte-per-species returns with per-pact growth; dev saves can be thrown away |
| Start at level 10 | Start strong (around level 60) | Open world puts moon encounters in reach, and a level-10 solo Rydia dies on contact. The level-10 targets return with the encounter redesign |
| FF4kster in the build | FF4kster as a viewer only; all changes in asar + Python | FF4kster edits the ROM in place, which can't be rebuilt from source or reviewed as a diff. Text source also lets an AI assistant make and check changes |
| New game with no assembly | One small assembly hook in new-game init | Writing the late-game flag and vehicle bytes in bulk is simpler in code than through event commands |
| Full monster export with abilities | Slim export: ID, name, level, HP, boss flag | Ability curation is for Call, not capture |

## Phase 0 — Setup and lookups (no ROM changes)

### Setup

- [ ] `git init`. Ignore `rom/`, `build/`, `*.sfc`, `*.smc`, `*.srm`, `*.mss`. Never commit a ROM or patched ROM.
- [ ] Put the ROM at `rom/ff2us-v1.1.sfc`. Get the expected hash for the Final Fantasy II (USA) v1.1 / Rev A entry from No-Intro and hard-code it in the build script. An unheadered file is exactly 1,048,576 bytes; 512 more means a copier header to strip.
- [ ] Install asar, Flips, Mesen 2 and Python 3. Record versions in `README.md`.
- [ ] Layout: `asm/`, `data/`, `tools/`, `notes/`, plus ignored `rom/` and `build/`.

### Lookups

Record each answer in `notes/addresses.md` with the address and how it was found. Check the FF4 docs first, then confirm in Mesen 2. **Every address and ID in this plan is a lookup, not a known value.**

| # | Find | Needed for | Where to start |
| --- | --- | --- | --- |
| L1 | New-game init: the event it runs, how it sets the party, how it loads the first map | Phase 2 | Breakpoint after choosing New Game |
| L2 | Event flags, NPC visibility flags, vehicle state (position, map, availability) | Phase 2 | RAM map in the docs |
| L3 | Adult Rydia's actor ID and starting record: level, stats, EXP, spells, command list | Phases 2–3 | FF4kster shows it; find the ROM table behind it |
| L4 | Battle command table: IDs, names, handlers, targeting | Phase 3 | Edge's steal command and the scan-type command |
| L5 | Battle RAM per enemy slot: species ID, HP, status | Phase 3 | Mesen memory watch during a fight |
| L6 | Monster record layout, the boss flag, species count | Phases 1, 3 | Docs; FF4kster for spot checks |
| L7 | How a monster is KO'd and removed, and how the battle checks for victory | Phase 3 | Breakpoint when a monster dies |
| L8 | Battle message table, and how a handler shows a message | Phase 3 | The steal command's success and fail messages |
| L9 | Save routine: the RAM range it copies to SRAM, the checksum, free bytes in that range | Phases 3–4 | Breakpoint on SRAM writes while saving |
| L10 | Free ROM space for new code, or ROM expansion | Phases 2–3 | Docs; asar's `freecode` once expanded |
| L11 | Event script format and the event pointer table | Phase 2 | Docs' event command list; FF4kster's event view to compare |
| L12 | Formation data: any can't-escape or boss-fight flag on a formation | Phase 3 | Docs; compare a boss formation with a normal one |

## Phase 1 — Build pipeline

**Status: done (Nov 5).** `python tools/build.py` builds `build/rydia.bps` (verified to re-apply byte for byte). The first change, renaming Peep to "Pact", shows in a battle in Mesen. `data/monsters.csv` is exported, and the capturable table is generated into `$0E:B439`.

- [ ] `tools/build.py`:
  1. Check the input ROM hash; stop with a clear message if it's wrong.
  2. Copy it to `build/rydia.sfc`.
  3. Generate assembly from data: read `data/*.csv`, write `build/gen/*.asm`.
  4. Run asar with `asm/main.asm`, which includes everything else, generated files too.
  5. Write `build/rydia.bps` with Flips (clean → patched).
  6. Print the output hash.
- [ ] Only asar writes to the ROM. Python generates assembly instead of poking bytes, so ordering and overlaps stay in one place.
- [ ] `tools/export_monsters.py`: read monster data from the clean ROM into `data/monsters.csv` with id, name, level, HP, boss bit and a seeded `capturable` column (L12). It doubles as proof the data map is right; spot-check a handful against FF4kster.
- [ ] If writing event scripts as raw bytes gets painful, add a small Python event encoder that turns a readable script into asar `db` lines (L11).

**Done when** a one-line test change, such as renaming an item, shows up in game from a fresh build.

## Phase 2 — New game and open world

Goal: power on, choose New Game, and Rydia is standing on the world map with the airships.

This is mostly data and event bytes, plus one small assembly hook (2.2). Since FF4kster is viewer-only, the new-game event is written in asar from the format in L11.

**Status (Nov 5): done.** Done-when criterion 1 is met; criterion 2 is met except the Whale's trip to the moon, which needs a manual check.
- **Access audit** ([notes/access.md](notes/access.md)): all 44 world-map locations start quiet: no scenes, fights or party joins.
- **Fixes:**
  - The audit found Lunar's Lair adding FuSoYa, so flag `47` is set.
  - Playtest then found the first Whale trip playing the Giant of Babil cutscene, so the whole Giant arc (`47–49`) is now marked done.
- **Travel:** the Falcon reaches the underworld through the hole. The Whale's trip to the moon needs a manual re-check after the Giant fix.
- **Known gaps:** depth inside dungeons; places with no world-map entrance; NPC flags in the underworld and moon may be off.
- The world state comes from the event scripts rather than a real save, using the snapshot route. The flag reasoning is in [notes/late-game-state.md](notes/late-game-state.md).
- The hook is in `asm/newgame.asm`, with its data generated from `tools/late_game.py`.
- Verified in Mesen on the built patch: New Game puts level-60 Rydia outside Mysidia, with the Big Whale, Falcon and Enterprise.

### 2.1 Starting record

- [ ] Build adult Rydia's full 64-byte character record (L3): ID `$11`, sprite `$0B`, level ~60, with HP, MP, stats and EXP to match. She has no initial-stats record in the ROM; vanilla's add-character restores her from child Rydia's parked slot, which is empty on a new game. So the hook (2.2) writes this record straight into party slot 0, and the event never uses add-character.
- [ ] Her black magic for that level, in her spell list.
- [ ] Gear that blocks Silence and Stone; solo KO or Stone ends the game.
- [ ] Items: a stack of Cures, Ethers and status cures.
- [ ] Call list empty.

### 2.2 New-game init

Split the work between a short assembly hook and the event. Event commands may not be able to write whole RAM regions, and this is the step most likely to stall if forced through events.

- [ ] **Hook** at the end of vanilla new-game init (L1), new code in free ROM (L10). It copies a ROM table of bytes into RAM:
  - adult Rydia's record into party slot 0 (`$1000`), with slots 1–4 cleared (2.1)
  - the late-game plot flags (`$1280–$129F`) and NPC flags (`$12E0–$131F`) (2.3)
  - the vehicle state bytes (2.4)
  - zeros over the pact bitfield (`$1181–$119C`). Unused RAM isn't guaranteed to start at zero.
- [ ] **Event** (L1, L11), rewritten to do only one thing: load the world map at the start spot (`FE`), skipping the opening entirely.

### 2.3 Late-game flag state

Use the first route that works:

- **Snapshot.** From a late-game save you made yourself (after the Big Whale, before the final dungeon), dump the event-flag, NPC-flag and vehicle regions in Mesen and bake those bytes into the hook's table. Fastest, and the flags are guaranteed consistent with each other.
- **By hand.** Set flags one by one from the docs' flag list. Slower, but it documents what each flag does.

Free Enterprise, the open-world FF4 randomizer, is a useful reference for which flags and events gate which areas.

### 2.4 Vehicles

- [ ] Enterprise, Falcon (heat-shielded, for the underworld) and Big Whale available and parked near the start; hovercraft too if cheap. Confirm the Falcon can go down through the hole.

### 2.5 Access audit

- [ ] Build `notes/access.md` with one row per town or dungeon, grouped into surface, underworld and moon. Not one per map: FF4kster's map list counts every room and runs to hundreds. Columns: reachable, forced scene fires, locked, notes.
- [ ] Walk every row: enter it and reach its far end. Fix blockers by setting a flag or removing a trigger.
- [ ] Some maps exist only during their story event (likely the Tower of Zot and the Giant of Babil). Record those as known exclusions rather than forcing them open.
- [ ] Watch for any event that adds a party member; a second member breaks solo.

**Done when** criteria 1 and 2 hold. Playtest the bare sandbox here, before writing any assembly.

## Phase 3 — The capture command

**Status (Nov 5): done.** Criteria 3, 4 and 6 hold, verified headless in Mesen on the built patch with `tools/mesen/pact.lua`. Details are in [notes/addresses.md](notes/addresses.md), L4–L8.
- **The command:** Peep (`$14`) is renamed Pact and fills adult Rydia's empty fifth menu slot. Its jump-table entry points to a new handler, `asm/pact.asm` at `$03:FEE3`.
- **The handler:**
  - It reads the target from `$CE` and gets the species from `$29AD[$29B5[slot]]`.
  - It checks the capturable table.
  - On success it sets the bit in `$1181+`, gives the target pending swoon (`$338E`) and shows "Pact formed!" (message `$07`). Vanilla's status-apply routine `$03:B1B0` then KOs it exactly like a Fight kill: the sprite dissolves, counts update, and the battle ends at zero.
  - Otherwise it shows "The pact is refused." (message `$08`) and nothing changes.
- **Verified:**
  - Turtle + 2 Imps: three Pacts covered two species, a repeat species and the last monster. The battle ends with the same `$00A8` as a Fight-only win, and the next fight follows.
  - Officer + 3 Soldiers (not capturable): two refusals, then Fight wins.
  - Antlion (`$E0`, a boss): four refusals in a row, and the fight goes on.
- **Edge cases:**
  - Last monster: the battle ends normally and **EXP is awarded**, because kills are counted.
  - Multiple types: the right species is recorded per slot.
  - Already pacted: still works.
  - Target already dead, or an ally targeted: the handler returns quietly with no message. Not exercised at runtime.
  - Silence: not tested.

Repurpose an existing command rather than adding one. Edge's steal command and the scan-type command both target a single enemy and show a message, and their owners won't be in a solo game. Choose in L4, preferring whichever handler is simplest.

- [ ] Rename it in the command name table. "Pact" is a placeholder; naming is still open in the handoff.
- [ ] Add it to adult Rydia's command list (L3).
- [ ] Replace its effect handler with new code in free ROM (L10):
  1. Read the target's species ID (L5).
  2. If the species isn't marked capturable, show a refusal message and stop. Neither the boss bit nor the fight-level flags draw a clean line (L6, L12), so the build compiles a 28-byte capturable table from the `capturable` column of `monsters.csv`. That column is seeded as "appears in a fight you can run from" (156 yes, 66 no) and curated by hand.
  3. Set the species' bit in the pact bitfield. Its location comes from L9 (see Phase 4).
  4. KO the target through the normal monster-death path (L7), so it fades out and the battle ends as vanilla does.
  5. Show "Pact formed!" (L8). Add the monster's name to the message later if the message system makes that hard.
- [ ] Edge cases:
  - The last monster captured: the battle should end normally. Note whether EXP is awarded; either way is fine for now.
  - The target died before the command resolved: retarget or fail quietly, like other commands.
  - Formations with several monster types: the right species is recorded for each slot.
  - A species already pacted: still works, no harm.
  - Silence: note whether it blocks the command. Either is acceptable for now.

**Plan B** if the repurposed handler is too tangled with its own animation or targeting: make capture a black magic spell with a custom effect routine. Steps 1–5 stay the same; only the dispatch changes.

**Done when** criteria 3, 4 and 6 hold.

## Phase 4 — Persistence

- [ ] The bitfield lives at `$1181–$119C`, inside Tellah's parked-character slot (L9): one bit per species, 28 bytes. Saves copy `$1000–$17FF` and checksum `$1000–$17FA`, so saving and loading need no new code. Byte `$1180` stays `$00` so the slot still reads as empty.
- [ ] Confirm nothing else writes there: Mesen write watch on `$1180–$11BF` across a varied session. If something does, fall back to hooking save and load, or expanding SRAM.
- [ ] Test: capture, save on the world map, reset in Mesen, load, and confirm the bits. Also confirm two save slots don't share bits.

**Done when** criterion 5 holds.

## Phase 5 — Playtest

- [ ] Smoke run: New Game → capture one monster each on the surface, underworld and moon → save → reset → load → check the bits.
- [ ] Optional: a Mesen 2 Lua script that lists pacted monsters by name (a lookup table generated from `monsters.csv`), so checking doesn't mean reading hex.
- [ ] Log findings in `notes/playtest.md`. Odd NPC dialogue is fine. Softlocks, forced scenes and extra party members are bugs.

## After the MVP, in order

1. **Call.** Pact slot spells resolved at runtime, the loadout auto-filled with the most recent N pacts, signature abilities curated in the CSV.
2. **Scaling and MP cost.**
3. **More ways to earn pacts.** Echo drops, plus a success chance on the capture command if wanted.
4. **Byte-per-species pact data**, for per-pact growth.
5. **The rest of the handoff:** loadout and bestiary menus, witness and trial tiers, encounter and rarity redesign, level-10 tuning, then story.

## Risks

- **Late-game flags may leave maps changed or blocked** in ways the snapshot doesn't fix. The access audit finds these; fix each or list it as an exclusion.
- **The repurposed handler may be tangled** with its animation or targeting code. Plan B is the spell route.
- **Something may write Tellah's parked slot after all.** Static reading says no; a Mesen write watch settles it. Fallback: hook save and load, or expand SRAM.
- **Capturing inside a scripted fight** goes through the vanilla KO path, so it's the same as killing that monster; nothing new can break. Which species are capturable is a design call, made in the `capturable` column.
- **Writing the new-game event without FF4kster** means learning the event format first (L11). The assembly hook keeps the event itself short.
