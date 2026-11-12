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

**Party**
- **More than Rydia.** A solo summoner is too thin, so several summoners should complement each other, e.g. some whose pacts lean towards healing and support and others towards damage.

### Open: a party of summoners (the biggest open area)

1. **Who.** Options:
   - FF4 characters who take up summoning years later. Palom and Porom are a natural black/white pair; Rosa, Edge and others are possible too.
   - New characters on existing sprites.
   - Constraint: we only have FF4's sprites, so an adult Palom or Porom still looks like a child. Is that acceptable?
2. **How they differ.** Options:
   - Each species has an affinity (white, black, neutral) and only a matching summoner can pact it.
   - Anyone can pact anything, but the summon acts differently by summoner (a white summoner's version heals or protects).
   - Each summoner reaches different monsters through their own capture conditions.
3. **Collection.** One shared bestiary (the pool) with a roster per summoner is the cleanest; separate pools are the alternative.
4. **Roster size per summoner** (24 each?). Technically each character already has their own spell lists; more rosters need more save space, so expanding save RAM becomes likely.
5. **When they join:** all at the start, or recruited region by region (natural chapter beats; FF4's party holds 5)?
6. **What else they keep:** their FF4 commands (Porom's White, Palom's Black, Edge's Ninja), or summoning only?
7. **Rydia's role:** the teacher and master (e.g. the only one who can pact anything), or one summoner among peers?

### Open: Rydia's power at the start

8. **Why she isn't at full strength.** Ideas to discuss:
   - Her old pacts faded or were released.
   - She chose to start over while teaching others.
   - Something changed in the Feymarch.
   - *The After Years* changed Rydia's situation with her eidolons; worth checking as input for this.
9. **Starting level and kit.**

### Open: everything else

10. **Black magic:** does Rydia (or the black summoner) learn it by level, or have a fixed set?
11. **Roster budget:** yes or no, and how it works across several summoners.
12. **XP numbers:** how much a first pact and a boss give relative to an ordinary fight.
13. **Gear and shops:** FF4's town shops as they are, or curated per chapter.
14. **Final trial:** where, and what unlocks it.
15. **Encounters:** keep FF4's tables, or redesign per region (rare spawns, every capturable species findable before the final trial).
16. **Capturable list:** prune the oddities (the seven debug "Dummy" species, scripted story enemies).
17. **Names:** the game, and terms such as Pact, Call, Pool and guide.

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
