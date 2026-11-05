# Playtest 1: the MVP by hand

**Purpose:** confirm the MVP's done-when list ([mvp-plan.md](../mvp-plan.md)) in real play, and find anything that breaks solo open-world play. Six short runs, about 75 minutes in all. Everything Mesen checked headless is worth seeing once with human eyes.

## Setup

1. Build the patch: `python tools/build.py`. Play `build/rydia.sfc`, or apply `build/rydia.bps` to your clean ROM with Flips.
2. Delete any old save file (`.srm`) for this ROM in Mesen 2's `Saves` folder, so the title goes straight to New Game.
3. Keep this ready for Run 6: `python tools/pacts.py <path to the .srm>`
4. Log anything unexpected in the [Log](#log) table as you go.

## Goals

| # | Goal | Pass when | MVP criterion |
| --- | --- | --- | --- |
| G1 | Start | New Game: no intro, Rydia alone outside Mysidia with three vehicles | 1 |
| G2 | Capture | Pact captures, works on repeats, and the last capture ends the fight with EXP | 3, 6 |
| G3 | Refusal | Pact on a boss says "The pact is refused." and the fight goes on | 4 |
| G4 | Three worlds | You reach the underworld and the moon, capture in each, and get back | 2 |
| G5 | Persistence | After a save and reload, `pacts.py` lists exactly what you captured | 5 |
| G6 | Solo safety | Nowhere you go plays a story scene, adds a party member or softlocks | 2 |
| G7 | Feel | Answers to the questions below; not pass/fail | — |

## Runs

### Run 1: Start (5 min) · G1

1. New Game. **Expect:**
   - no intro
   - Rydia alone on the world map just below Mysidia
   - the Big Whale to her left, the Falcon below right, the Enterprise above right
2. Open the menu and check:
   - **Status:** level 60, 3000/3000 HP, 450/450 MP.
   - **Magic:** the Black list has 24 spells, Fire1 through Nuke and Meteo. The Call list is empty.
   - **Equip:** Ribbon on her head, Stardust rod in hand.
   - **Items:** 30 Cure3, 20 Ether2, 5 Elixir, 20 Heal, 10 Life. 500,000 GP.

### Run 2: Capture on the surface (15 min) · G2

1. Walk around Mysidia until a fight. **Expect:** the battle menu reads Fight / Black / Call / Item / Pact.
2. Pact every monster, one at a time. **Expect:**
   - "Pact formed!" each time, and the monster dissolves
   - after the last one, the fight ends with the normal victory screen and EXP
3. In a later fight, Pact a species you already have. **Expect:** the same result.
4. In a fight with several monsters, Pact one and kill the rest with magic. **Expect:** a normal win.
5. Write down every species you capture. Run 6 checks them.
6. Optional: if anything Silences you, try Pact. Ribbon probably blocks Silence, so this may not come up. The game has never been tested with Pact under Silence.

### Run 3: Refusal (10 min) · G3

Bosses and story monsters can't be pacted. The optional summon trials are left open, so they make good targets.

1. **Odin's trial** in Baron Castle's basement, reached through the throne room, if you can get there. Pact Odin. **Expect:**
   - "The pact is refused."
   - Odin is unharmed and the fight goes on
2. Win, or reset if Odin is too strong. Either way, nothing should be recorded for him in Run 6.
3. Other targets if you pass them: Asura and Leviathan in the Land of Monsters (underworld), Bahamut in his cave (moon).

### Run 4: Underworld (15 min) · G4, G6

1. Board the Falcon and fly to Agart. The hole is the crater beside the village. Land on it. **Expect:** you descend to the underworld.
2. Capture at least two underworld species. Note how hard the fights are.
3. Step inside the Dwarf Castle, Tomra, the Land of Monsters and the Sealed Cave entrance. Note any scene, extra party member or blocked path.
4. Fly back up: land the Falcon where you arrived. **Expect:** you're back on the surface.

### Run 5: Moon (15 min) · G4, G6

1. Board the Big Whale and use its crystal to fly to the moon. **Expect:** no cutscene on the way. This was fixed after your first trip.
2. Capture at least two moon species. Behemoth, Red D. and Blue D. are capturable by design, but strong. Note how Rydia fares.
3. Step into Lunar's Lair, the Lunar Path and Cave Bahamut. One spot in the Lunar's Lair area may play a long scene (map `161`, trigger at `10`,`10`). Note what it shows. It should not add anyone.
4. Fly back to Earth.

### Run 6: Save, reset, load (5 min) · G5

1. Save on the world map in Save 1.
2. Close and reopen the emulator, or reset it, and load Save 1. **Expect:** you're back where you saved.
3. Run `python tools/pacts.py <your .srm>`. **Expect:** Save 1 lists exactly the species you wrote down in Runs 2, 4 and 5, and nothing from Run 3.
4. Optional: capture one more, save in Save 2, rerun `pacts.py`. **Expect:** Save 2 has one more pact than Save 1, and Save 1 is unchanged.

## Severity

- **Blocker:**
  - softlock or crash
  - a story scene plays
  - someone joins the party
  - Pact records the wrong species or nothing
  - pacts are missing after a load
- **Bug:**
  - wrong or missing message
  - a path blocked by an NPC or locked door
  - a vehicle misbehaves
  - a monster's capturability feels wrong. Fix that in the `capturable` column of `data/monsters.csv`
- **Note:** odd NPCs or dialogue (expected), balance, feel.

## Known; don't report

- **Odd NPCs in the underworld and on the moon.** Some may show or hide wrongly; see [late-game-state.md](late-game-state.md). Do report one that blocks a path.
- **Places with no world-map entrance are untested:** the Tower of Babil, Tower of Zot, Giant of Babil and Baron's waterway. Some may be unreachable.
- **Behemoth and the dragons are capturable** on purpose, even though the game marks them as bosses.
- **Tellah's join event** has never been triggered. Do report it if Tellah joins.

## Feel questions

Answer briefly after the runs:

1. Does Pact feel good? Is "Pact formed!" enough, or should it name the monster?
2. With no chance of failure, is capturing too easy? Should weakening the monster matter next?
3. In each world: about how many casts does a typical fight take, and how many fights before Rydia needs an Ether? Did she ever die?
4. Which monsters did you want to pact but couldn't, or could but shouldn't?
5. What did you wish the game showed you, such as a list of your pacts?

## Log

| # | Run | Where | What you did | Expected | What happened | Severity |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | | | | | | |
