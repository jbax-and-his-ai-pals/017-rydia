# Rydia's Monster Game — Handoff

Nov 2, 2026 · @Joshua Baxter

## Concept

A Final Fantasy IV (SNES) overhaul in which Rydia travels an open world forming pacts with monsters. Each pact becomes a one-shot summon that uses that creature's own ability.

- **Only borrowed idea:** collecting summons. No Pokémon names, creatures, terms, UI or other mechanics. Acquisition stays in FF4's own language: pacts, echoes, trials.
- **FF4 stays FF4:** its world, tone and assets. Less conflict, with monster collecting at the center.
- **Distribution:** a BPS patch against the player's own ROM. No ROMs shared or committed.
- **Near-term goal:** a playable sandbox of collecting and summoning. Story comes later.

## Decisions locked

- **Battle system:** vanilla ATB, unchanged.
- **Summons:** one-shot (appear, act, leave). The Call list keeps growing. A monster party is a long-term stretch goal, deferred mainly because of art.
- **Party:** Rydia solo for the MVP. She keeps her black magic.
- **Acquisition:** through items and/or a custom battle command, not "weaken then catch" as the core idea.
- **Roster:** a curated active set, with full bestiary completion still supported.
- **World:** open. For the MVP, travel anywhere is simply enabled.
- **Encounters:** monster placement, rarity and encounter tables get redesigned later around progression.
- **Scaling:** summon power uses both Rydia's level and the monster's level.

## Core mechanics

Pacts come in three tiers, live in a permanent bestiary, and are summoned from a fixed-size loadout. The MVP builds only the first tier.

### Acquiring pacts

Vanilla precedent: eidolons join through trials (Asura, Leviathan, Odin, Bahamut), and a few minor summons (Goblin, Bomb, Cockatrice, Mind Flayer) come from rare drops used from the menu.

1. **Echoes (common monsters).** A rare post-battle drop that sets the pact directly. The chance rises when Rydia lands the final blow or the monster is asleep or charmed. **MVP tier.**
2. **Witness (notable monsters).** Rydia survives the monster's signature ability, then wins. A Commune command or an offering item seals the pact. Follows FF's blue magic lineage.
3. **Trials (eidolons).** Hand-built fights with special conditions.

### Collection vs. loadout

- **Bestiary:** every pact ever made. Never lost, so completionists keep progress.
- **Call list:** a loadout drawn from the bestiary, fixed in size. This replaces the idea of discarding summons.

### Scaling and cost

- **Power:** the ability's base power, scaled by Rydia's magic stat and level and by the monster's level.
- **MP cost:** rises with monster level, so weak monsters become cheap utility rather than dead weight.
- **MVP:** monster level = the species' built-in level. Per-pact growth comes later.

### Signature abilities

- Pulled from each monster's AI script, then curated by hand.
- Monsters with only plain physical attacks get a scaled physical strike.

## Base ROM, tools and references

Build against Final Fantasy II (US) v1.1 (Rev A), unheadered. That's what FF4kster and the community documentation target. Verify it by checksum before anything else.

| Tool | Use |
| --- | --- |
| FF4kster | Character data, spells, events, maps, tilesets |
| asar | 65816 assembly patches |
| Python | Data extraction, CSV round-trip, build script |
| Mesen 2 | Debugger: breakpoints, memory watch, tracing |
| Flips | Output the BPS patch |

Addressing: the docs give addresses as SNES bus addresses. For an unheadered LoROM file, offset = bank × $8000 + (address − $8000).

References:

- [FF4 technical documentation](https://ff4-documentation.readthedocs.io/en/latest/introduction.html) — disassembly-based, targets US Rev A
- [FF4Hacking wiki](https://github.com/GameHackingDotOrg/FF4Hacking/wiki) — community docs, mostly v1.1 unheadered
- [SnesLab: Final Fantasy IV](https://sneslab.net/wiki/Final_Fantasy_IV) — tool list, including FF4kster and Free Enterprise as a precedent for deep engine changes

## Technical constraints and approach

The two hard limits are one-byte spell and item IDs; the design routes around both with runtime slots and pact bytes in save data.

- **Platform:** 8 Mbit LoROM, no coprocessor, 65816 at about 3.58 MHz. ROM expansion is routine and save RAM can be expanded. No enhancement chip is needed for the MVP.
- **Spells:** IDs are one byte, so one spell per monster won't fit. Reserve a fixed set of "pact slot" spells whose name, ability and graphic resolve at runtime from Rydia's loadout. Reuse vanilla's monster-summon path, which already displays a monster graphic.
- **Items:** IDs are one byte and the table is nearly full, so there's no item per monster. Echoes set pact data directly.
- **Pact storage:** one byte per monster species in save data. 0 = no pact; nonzero = the pact's level, so growth can be added later without breaking saves. Needs free space in the save block, or expanded SRAM.
- **Echo hook:** the post-battle victory routine rolls once per defeated monster. Fled or escaped monsters don't count.
- **Battle rendering:** party members are sprites and monsters are background graphics. This is why a monster party is deferred.
- **Data pipeline:** Python exports every monster's name, level, stats, elements and AI-script abilities to a CSV. Curation happens there, and the build compiles it back in.

To verify in the docs or debugger before coding: the Call list's slot count, free bytes in the save block, the victory routine's location, and how vanilla monster summons pick their graphic.

## MVP milestones

The MVP is done when Rydia can start a new game, fly anywhere, earn a pact from a battle, and summon that monster to use its ability.

1. **Build pipeline.** Clean ROM → FF4kster data → asar patches → BPS. Reproducible from source, with a checksum check on the input ROM.
2. **New game** (FF4kster, no assembly):
   - Skip the intro; adult Rydia is the only party member.
   - Start in a late-game world state: most story flags set, the underworld hole open, airships and the Big Whale available.
   - Disable events that add party members or force story scenes. Odd NPC dialogue is fine for now.
3. **Monster data export.** CSV of every monster; curate signature abilities there.
4. **Pact storage and echo drops.** First assembly milestone: pact bytes in save data, plus the victory-routine hook.
5. **Call in battle.** Pact slot spells resolved at runtime. The loadout auto-fills with the most recent N pacts, so no new menu is needed yet. This is the hardest piece.
6. **Scaling and MP cost.** Implement the formula; tune the curve.
7. **Playtest and tune.** Against the solo Rydia targets below.

After the MVP: loadout and bestiary menus, witness and trial tiers, per-pact growth, encounter and rarity redesign, then story.

## Solo Rydia: starting setup

Provisional values to tune in playtesting. Solo risks: she gets all the EXP and will level fast; KO or Stone ends the game; Silence shuts off both her magic and Call.

| Setting | Starting value |
| --- | --- |
| Level | 10 |
| HP | About 300 |
| MP | About 80 |
| Row | Back (halves physical damage taken) |
| Spells | Fire, Blizzard, Thunder, Sleep (FF2 US names differ) |
| Gear | Blocks Silence and Stone |
| Items | A stack of Cures, Ethers and status cures |
| Growth | Raised HP and Vitality per level |

Tuning targets:

- Survives about 4 turns of the hardest normal fight in the starting area.
- Clears a typical fight in 2–3 casts.
- Has MP for about 5 fights between rests.

## Open questions and parked ideas

Story and structure are deliberately open; none of these block the MVP.

- [ ] **Story premise.** Leading idea: Rydia's black magic is fading, so she turns to monster pacts.
- [ ] **Setting.** Rydia's lost years in the Feymarch, or after FF4.
- [ ] **Ending.** Candidate: a trial by Bahamut (or the Feymarch's rulers) proving people and monsters can coexist, unlocked by pact count or key eidolons.
- [ ] **Party.** Rydia alone, or a story about summoners: finding others, or teaching the existing cast to Call.
- [ ] **Names.** The Commune command and offering items.
- [ ] **Loadout size and MP curve.**
- [ ] **Traversal for the full game.** Candidate: surface, underworld and moon as layers, open inside and gated between by eidolon pacts that grant travel (rides, not field powers), with soft gating by monster strength.
- [ ] **Target platform.** Original hardware or FXPAK Pro vs. emulators only.

Parked for later:

- **Monster party:** monsters fighting on the party side. Blocked mainly by art.
- **Palette-swap families as upgrade lines:** FF4's recolored monsters as stronger forms.
- **Bestiary screen:** SNES FF4 has none, so it's new menu work.
- **MSU-1 audio:** optional, only if the target platform supports it.

## First steps in the code project

- [ ] Put the ROM in the project, gitignored, and verify it's v1.1 unheadered by checksum. Never commit the ROM or a patched ROM.
- [ ] Lay out the repo: `asm/` (patches), `data/` (CSVs), `tools/` (Python), plus one build script that outputs the BPS.
- [ ] From the docs and Mesen 2, locate: the new-game init event, the post-battle victory routine, how monster summons are cast and drawn, and the save block layout.
- [ ] Write the monster data exporter (milestone 3) early; it doubles as a check that the data map is understood.
- [ ] Complete milestones 1 and 2, then playtest the bare sandbox before any assembly.
