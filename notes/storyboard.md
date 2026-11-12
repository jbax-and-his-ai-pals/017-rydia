# Storyboard: the game from the player's side

Draft for discussion, Nov 6, 2026; updated Nov 12. Nothing here is built yet beyond Pact, Call,
the 24-slot roster, the pool picker and the first 32 signature summons.

Ground rules:
- **No new graphics.** Everything uses FF4's maps, monsters, bosses, vehicles and menus.
- **Text is cheap**, so a few new messages are fine.
- **Light framing, not a plot.** Rydia's black magic is fading and she rebuilds her strength through pacts, guided by the Feymarch. That's a few lines at the start and at each guardian.
- **World state:** the current late-game snapshot (peaceful towns, no story scenes). The player's progress is gated by **vehicles**, which FF4's geography already enforces, not by story flags.

Monster levels below come from `data/encounters.csv`: the median, then the range, per area.

## Where we are (Nov 12)

Current decisions and open questions. The original draft further down is kept
for reference; where it conflicts with this section, this section wins.

### Decided

**World and framing**
- **Setting:** long after FF4. Everything from FF4 is resolved; this is a new situation and challenge. Light framing for now, with a story possible later.
- **The moon:** simply back in the sky. Why it returned can come out in a later story; making its return a mid-game event later would also be fine.
- **Assets:** no new graphics; new text is fine.
- **Start:** Mist, on foot. Vehicles open new regions.
- **Difficulty:** low this time around. Revisit if it becomes a sticking point.

**Growth**
- **XP is the main way to grow.** Monsters give some XP, a first pact with a species gives more, and bosses and guardians give more again.
- **Summons don't grow** (for now).
- **Rydia isn't overpowered at the start,** even though she ended FF4 supremely powerful. The in-world reason is still open (below).

**Collection**
- **Capture:** one formula. Early captures are easy and straightforward; later ones need the conditions set up (low HP, status, level, per-species preferences).
- **Seen list:** monsters you've met appear greyed out in the pool list until you pact them.
- **Guide NPCs:** plain-spoken. They cover the world, what's nearby, tips and known weaknesses.
- **Guardians:** each region's gate is a mostly standard (or enhanced) monster from the *next* region. Beating it means you're ready for that region, and it can be a little easier than the previous guardian. FF4's eidolons can still have their own trials.
- **Goal:** a final trial ends the game. Completing the bestiary is its own motivation, supported by the seen list, the guides and per-region progress.

**Party and summoners (Nov 12)**
- **Several summoners, recruited over time.** A solo summoner is too thin.
- **Rydia is the heroine and, in the end, the most powerful summoner.** She is an **omni-summoner**, rare or unique, who can pact any type. Other summoners are bound to one type.
- **Types:** at least white (healing, support, protection) and black (damage, debuffs); others are possible.
- **Edge** is the first natural fit, as a black-type summoner. Some romantic tension between him and Rydia is welcome, kept light.
- **Old skills fade.** Edge, and anyone else who joins, keeps their FF4 commands (Ninja, Throw, ...), but those aren't end-game strong. Each leans into summoning over time, which becomes the main way to fight. Balance is open for discussion.
- **Collection:** one shared bestiary (the pool), a roster per summoner, and a way to restrict which types each summoner can take.
- **Captures:** a species may have its own capture conditions, as long as the game teaches the player about them.

**Rydia's starting point**
- **Her old pacts faded,** and she has forgotten most of her black magic through disuse. That's why she isn't overpowered at the start.
- **Background from *The After Years*** (fan wikis, not checked against the game): in "Rydia's Tale" the Feymarch's eidolons are turned to stone by the mysterious girl and Rydia can't summon them, so she falls back on black magic. Edge quietly helps her repair her bond with Leviathan and Asura. The Edge-Rydia romance stays a tease, never resolved. We don't depend on any of this, but it fits "her pacts faded" and gives Edge a reason to care about summoning.

### Decided (Nov 12, second round)

- **Chapters on FF2's pacing:** small chapters, each bringing a character, a batch of unique summons, story, and a boss at or near the end.
- **Characters:** anyone from FF4 can be considered (FuSoYa, Rosa, Cecil, Kain, ...), as long as the summoning style fits the character. **FuSoYa** fits especially well if the moon becomes a final or near-final chapter.
- **No child sprites or child characters.** Palom and Porom are in only if adult versions of their graphics reach a passable state. **Graphics are the gate:** pass, they're in; fail, they're out.
- **Edge and Rydia:** the tension the series established. Edge has the crush, never acts on it because of his immaturity, and lives with the fact that it never worked out. Rydia's motivation is purer: devoted to summoning and her monster friends. The story elements need a lot of work.
- **Rare captures through other means:** unique fights with unique mechanics, secret places, people, events, quests or triggers.

### Summon types: options considered

| System | Idea | For | Against |
| --- | --- | --- | --- |
| Role | white (support), black (damage), beast (physical) | Simple; clear party roles | Generic; most monsters do several things; a weak fit for characters like Kain or Cid |
| Element | fire, ice, lightning, earth, holy, dark, water, wind | FF-native | Most monsters have no element; it splits the bestiary unevenly |
| Habitat | land, sea, sky, underground, lunar | Easy to understand | Overlaps the regions; says little about what a summon does |
| **Kin (family)** | dragons, beasts, undead, machines, ... | **Partly in the ROM already**; very strong character fits (Kain and dragons, Cid and machines) | Needs curation for half the bestiary |
| Capture style | each summoner bonds differently (calm, subdue, outwit) | Makes capturing itself varied | On its own it doesn't divide the bestiary |

### Recommended: kin decides who can bond; capture style makes each summoner play differently

**1. Kin.** Every species belongs to one kin (a `kin` column in `data/monsters.csv`). Half come from the ROM's creature type; the rest are curated. Eight kin cover the 149 real species:

| Kin | Who's in it (examples) | Source | Leans towards |
| --- | --- | --- | --- |
| Dragon | Green D., Yellow D., D.Bone, Ging-Ryu | ROM dragon (10) | elemental breath, big hits |
| Sky | Eagle, Cave Bat, Roc, Raven, Cockatrice | curated | speed, wind, status from above |
| Sea | Pike, Piranha, Aligator, AquaWorm, ElecFish | curated | water, lightning, healing tides |
| Beast | Python, SwordRat, Panther, Basilisk, Hydra, lizards | ROM reptile (19) + curated | physical power, poison, petrify |
| Wild | SandMoth, TrapRose, Treant, Larva, slimes, Imps | ROM slime (6) + curated | status, pollen, healing, odd tricks |
| Shade | Zombie, Skull, Ghoul, Soul, Spirit, Weeper | ROM undead (12) + spirit (5) | death, drain, curses |
| Construct | Bomb, Beamer, Machine, Stoneman, MacGiant, Ogre | ROM machine (8) + giant (8) | beams, explosions, toughness |
| Arcane | TinyMage, Sorcerer, Marion, Witch, Lunar mages | ROM mage (14) + curated | spells, buffs and debuffs, MP tricks |

**2. Each summoner bonds with 2 kin.** Rydia bonds with all of them, so she is the only one who can complete the bestiary.

**3. Each summoner has a capture style**: a bonus condition for their Pact command. That teaches strategy without a tutorial, and the guides can mention it.

| Summoner | Kin | Capture style (bonus when...) | Role it gives the party |
| --- | --- | --- | --- |
| **Rydia** (omni) | all 8 | gentle: the target is calm (asleep, charmed) or trusts her (low level) | flexible; the heroine; strongest over time |
| **Edge** | Beast, Shade | outwit: the target is confused, stopped, or just struck by Edge | damage and debuffs (the "black" side) |
| **Kain** | Dragon, Sky | prove strength: the target's HP is low | heavy elemental and physical damage |
| **Rosa** | Sea, Wild | soothe: the target is asleep or slowed | healing and protection (the "white" side) |
| **Cid** | Construct | repair: the target is damaged but not weakened by status | toughness and beams; comic relief |
| **FuSoYa** | Arcane (and Shade?) | lunar insight: ignores the level gap | spells and late-game power; the moon chapter |

- Cecil or Yang could take Construct or Beast instead, if their story fits better.
- Palom (Arcane or Shade) and Porom (Wild or Sea) slot in the same way if their adult graphics pass the gate.
- Roles then **emerge from the kin** (Rosa heals, Kain hits hard) without hard white/black labels. Players still see "healer" and "attacker".

**Rare captures** fit this naturally:
- a unique species that only appears in a quest fight
- a secret room
- a guide who trades a hint for a favour
- a monster that only bonds with a particular summoner, or only when a particular party member is present

### Chapter outline v2 (for discussion)

FF2-sized chapters, each bringing a character, a batch of kin and summons, story and a boss:

| Ch | Region | New summoner | Kin batch introduced | Boss (guardian or story) |
| --- | --- | --- | --- | --- |
| 1 | Mist, Kaipo | Rydia (her pacts faded) | Wild, Sky | a guardian from Watery Pass |
| 2 | Watery Pass, Damcyan | Edge (comes looking for her) | Beast, Shade | an elder Hydra or Octomamm-class guardian |
| 3 | Mt. Hobs, Fabul | (Cid with an airship?) | Construct | a Mom Bomb-class guardian |
| 4 | Mysidia, Mt. Ordeals | Kain (a hermit on Mt. Ordeals, as in *The After Years*) | Dragon | a dragon trial on the mountain |
| 5 | Baron | Rosa | Sea | a castle or waterway guardian |
| 6 | Underworld: Agart, dwarves, Feymarch | (Cid / the dwarves) | eidolon trials (Asura, Leviathan) | Feymarch trial |
| 7 | Eblan, Cave Eblana, Sylvan | (Edge's homeland arc) | rares, elders | Eblan story boss |
| 8 | The moon (back in the sky) | FuSoYa | Arcane | Bahamut |
| Final | Lunar Subterrane or a new trial site | — | — | final trial |

**Party size:** FF4 battles hold 5. Rydia plus 4 is the simplest; with 5 or more other summoners we need a way to swap party members, which is new menu work (the picker pattern can be reused).

### Decided (Nov 12, third round)

Open questions 1-5 are settled, all as recommended above:

1. **Kin:** keep the eight. Check them against data before adjusting: fill a `kin` column in `data/monsters.csv` and count each kin per region with `data/encounters.csv`. Merge or split only if a chapter's region can't supply its kin batch.
2. **Breadth:** two kin per summoner, and Rydia bonds with all eight. **Specialists summon their own kin a bit stronger or cheaper** than Rydia does, so the others aren't just a narrower Rydia.
3. **Capture styles:** **bonus only.** Each summoner's style raises the odds and is never required. Hard conditions are reserved for a few rare species, so capture stays one formula.
4. **Cast:** **Edge, Kain, Rosa and Cid** as the four summoners besides Rydia; **FuSoYa joins as a guest** for the moon chapter. Cecil, Yang, Palom and Porom aren't planned. Palom and Porom remain possible if their adult graphics pass and the party grows.
5. **Party:** fixed at five. Characters come and go through story events, using vanilla's add and remove commands, so **no swap menu**. Revisit only if the cast grows past four.

Kin coverage with this cast: Edge Beast and Shade, Kain Dragon and Sky, Rosa Sea and Wild, Cid Construct. Arcane is Rydia's own until FuSoYa arrives.

### Open: next round

6. **The Palom/Porom graphics test:** when to try it. Approach: build adult versions from existing adult sprites, e.g. Rosa's body with Porom's palette and hair, and Edward's or Cecil's body for Palom. Battle poses, field sprites and menu portraits all need versions.
7. **Chapter order and bosses** (v2 above is a first pass).
8. **Rydia's starting level and spells,** and how "forgotten black magic" returns.
9. **Teaching captures:** hinting refusals, guides, seen-list hints, capture styles.

### Open: everything else (unchanged)

10. **Roster budget:** yes or no, now across several summoners.
11. **XP numbers:** how much a first pact and a boss give relative to an ordinary fight.
12. **Gear and shops:** FF4's town shops as they are, or curated per chapter.
13. **Final trial:** where, and what unlocks it.
14. **Encounters:** keep FF4's tables, or redesign per region (rare spawns, every capturable species findable).
15. **Capturable list:** prune the oddities (the seven debug "Dummy" species, scripted story enemies).
16. **Names:** the game, and terms such as Pact, Call, Pool, kin and guide.

## Original draft (Nov 6)

### How Rydia grows: what the player learns in the first hour

1. **Pacts are her levels.** Rydia's power, her **summoner rank**, comes from how many pacts she holds, not from EXP. Each new pact is a small permanent gain in HP, MP and magic. Grinding the same field doesn't make her stronger; finding new monsters does.
2. **Summons grow with use.** Each pact has its own level. Using a summon, or pacting the same species again (an "echo"), raises it. Power and MP scale with that level, so old favourites stay useful. (This uses the reserved byte-per-species space.)
3. **Capturing takes work.** Pact can fail. Weakened monsters (low HP), and ones asleep, held, confused or charmed, are easier, as are monsters at or below Rydia's rank. So **status summons are capture tools**: SandMoth's Powder, Hydra's Entangle, Ghost's Sleep. Bosses and guardians refuse.
4. **The roster is a build.** 24 slots, any mix, swapped in the field picker. Later a **budget** grows with rank: strong summons cost more of it, so you can't carry 24 heavy hitters early. That's what makes tiers matter.
5. **Black magic is a backup.** Rydia keeps a few spells (Fire, Blizzard, Thunder, Sleep) that scale slowly. Summons do the heavy lifting.

What the player feels: every region is a set of new pacts to win, and each one immediately makes Rydia and her roster stronger.

### Chapters

Each chapter is a region you can reach with the vehicles you have, a set of monsters to collect, and a **guardian**: an existing boss fight that refuses Pact. Beating it grants an **eidolon** (into the pool and roster) and the **next ride**.

| Ch | Region (FF4 areas) | Monster Lv | New species | You arrive with | Guardian (existing boss) | Reward |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Mist, Misty Cave, Kaipo | 4-5 (3-6) | ~8 | Rydia rank 1, no pacts, Fire/Sleep | Mist Dragon (Misty Cave) | Eidolon **Mist**; Watery Pass opens |
| 2 | Watery Pass, Damcyan, the lake | 6-7 (3-8) | ~14 | ~8 pacts | Octomamm (Lv 10) | **Hovercraft** |
| 3 | Antlion's Den, Mt. Hobs, Fabul | 12 (3-14) | ~15 | ~20 pacts | Mom Bomb (Lv 15) | Eidolon **Titan**; Mysidia by sea |
| 4 | Mysidia, Mt. Ordeals, Chocobo Forest, Baron | 9-20 | ~20 | ~35 pacts | Milon / Milon Z. (Lv 15), then Kainazzo (Lv 16) | Eidolon **Shiva**; **Enterprise** |
| 5 | Cave Magnes, Tower of Zot, Silvera, Toroia | 20-22 (15-40) | ~15 | ~50 pacts | Dark Elf (Lv 15-19), Valvalis (Lv 36) | Eidolon **Indra**; underworld hole |
| 6 | Underworld: Dwarves, Tower of Bab-il, Sylvan Cave, Feymarch | 26-45 (16-54) | ~35 | ~65 pacts | Asura (Lv 63) and Leviathan (Lv 79), the Feymarch trials | Eidolons **Asura**, **Leviathan**; **Falcon** |
| 7 | Eblan, Cave Eblana, Sealed Cave, Baron basement | 26-41 | ~15 | ~100 pacts | Rubicant (Lv 50), Odin (Lv 53) | Eidolon **Odin**, **Jinn**; **Big Whale** |
| 8 | Moon: Lunar Path, Lunar's Lair, Cave Bahamut | 39-54 (21-97) | ~20 | ~120 pacts | Bahamut (Lv 47) | Eidolon **Bahamut** |
| End | Lunar Subterrane | 97 (61-99) | ~16 | 140+ pacts | The Lunar bosses, then a final trial | Full bestiary (156) |

Notes on the table:
- **Species counts** are approximate and come from the encounter export. Many species repeat between neighbouring areas, which is fine: a missed pact can be found next door.
- **Guardians are vanilla bosses** fought again. Their event flags get reset or the fight is re-triggered. A few bosses (Asura, Leviathan, Odin, Bahamut) are already trial fights in vanilla.
- **Order is a suggestion.** FF4's geography only enforces the vehicle gates, so curious players can wander into harder corners early. That's soft gating by monster strength.

### Expectations between regions

What a player should feel when crossing into a new chapter:
- **Field monsters about 1.5-2x the last region's level.** The previous roster handles fights with effort, but the new monsters are hard to capture until a few local pacts are won. Status summons help a lot there.
- **Rank about 1.3x per chapter.** Collecting most of a region before moving on is the intended pace (rough pact counts are in the table).
- **The guardian checks the build, not just numbers.** Each guardian has a weakness or gimmick that this region's monsters cover:
  - Octomamm: lightning and status
  - Mom Bomb: ice, and splitting
  - Milon Z: reflect and healing
  - Asura: her healing
- **MP is the stamina meter.** Healing items and inns refill it. Rydia should manage about 4-6 fights between rests (the handoff's target), so cheap low-level summons stay useful as field tools.
- **Old summons don't go dead.** Echo-levelling keeps favourites viable; the budget pushes towards a mixed roster.

### A typical session in chapter 3

- **Exploring:** the player lands near Mt. Hobs with about 20 pacts. The Gargoyles and Bombs here hit harder than anything at Damcyan. Rydia opens with SandMoth's Powder (status), then pacts the confused Bomb.
- **First tries:** two failed attempts on a Cockatrice teach them to weaken it first.
- **Rank-up:** after a dozen captures her rank ticks up twice and the budget grows. In the field picker they swap Bomb in for an early Imp.
- **Guardian:** Mom Bomb splits into many bombs. The new Bomb's Fire3 and Sandpede's all-target Quake win the fight.
- **Payoff:** Titan joins the roster, and Mysidia opens across the sea.

### What it needs to build, by size

| Piece | Size | Notes |
| --- | --- | --- |
| Capture chance (HP, status, rank) | Small | In the Pact handler |
| Summoner rank from pact count | Medium | Recalculate Rydia's stats from pact count; turn off or ignore EXP |
| Pact growth (echoes, levels on use) | Medium | Byte-per-species save data (room reserved), then power and MP scale |
| Roster budget | Small-Medium | Picker check plus a tier column in the CSV |
| Starting state: on foot at Mist, no vehicles | Medium | New Game table: drop the vehicles, start at Mist, Rydia rank 1 |
| Guardians re-fightable, granting eidolon and vehicle | Medium-Large | Per-boss event work; the biggest piece |
| Framing text | Small | A few new messages |
| Balance pass per chapter | Ongoing | Monster levels are fixed by FF4; tune rank gains, summon scaling and MP |

### Open questions (Nov 6, now answered above)

1. **Starting point:** Mist on foot with nothing (as above), or a bit further along (e.g. with the hovercraft) to shorten the first hour?
2. **EXP:** remove it completely (rank only), or keep a small EXP curve alongside rank?
3. **Guardians:** use FF4's boss order as above, or theme them per region (each guardian matching the region's eidolon)?
4. **End goal:** complete the bestiary, defeat a final trial (Zeromus as a summon-only fight?), or both?
