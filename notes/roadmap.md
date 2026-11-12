# Roadmap

Nov 12, 2026. Supersedes "After the MVP" in [mvp-plan.md](../mvp-plan.md). The game is defined in [storyboard.md](storyboard.md); its "Where we are" section wins over older docs.

## The target

A chaptered FF4 sequel about summoners, set long after FF4:
- **Start:** Rydia starts at Mist, on foot and weak; her old pacts have faded. She grows through XP. A first pact with a species gives extra XP.
- **Chapters:** each adds a summoner, a batch of kin, story, and a guardian or boss. Guardians gate regions; vehicles open new ones.
- **Cast:** Edge (Beast, Shade), Kain (Dragon, Sky), Rosa (Sea, Wild), Cid (Construct). FuSoYa joins as a guest on the moon.
  - The party is fixed at five; members come and go through story events.
  - Rydia bonds with all eight kin, so only she can complete the bestiary. Specialists summon their own kin stronger or cheaper.
- **Capture:** one formula. Early captures are easy; later ones need conditions set up. Each summoner's capture style is a bonus, never a requirement.
  - Rare species have special conditions or appear only in special places.
  - A seen list greys out species you've met but haven't pacted.
- **Support:** plain-spoken guide NPCs.
- **End:** a final trial. A complete bestiary is its own goal.

## Where the build is

**Built and tested:**
- Capture (Pact) and a pool of every pact.
- 24 active Call slots, which can also hold eidolons, plus a field picker.
- 32 summons that use their monster's own ability.
- The expanded 2 MB ROM.
- Persistence, the access audit, and a headless Mesen regression harness.
- Data: `data/monsters.csv` (abilities, Call names) and `data/encounters.csv`.

**Different from the target:**
- New Game starts level-60 Rydia alone in an open late-game world.
- There are no capture conditions, kin, second summoner, guides, guardians or new text.

**Keep the sandbox as a debug start.** It's how most systems get tested. Once the chapter start exists, make the sandbox a build option.

## Milestones

### M1 · Data foundations (low risk)

- **Kin:** a `kin` column in `data/monsters.csv`, seeded from the ROM's creature types (dragon, undead, spirit, reptile, slime, machine, giant, mage) and curated for the rest.
- **Kin per region:** count each kin's capturable species per region and per chapter from `data/encounters.csv`. Flag any chapter whose region can't supply its kin batch. This is what tests the eight-kin decision.
- **Capture data:** columns for a base capture difficulty and per-species preferences (status, HP, level), seeded from level and boss data.
- **Chapter regions:** map regions and locations to chapters, following the chapter outline in `storyboard.md`.

**Done when:** the CSVs are filled, a kin and chapter report is in `notes/`, and the user has agreed any kin adjustments.

**Status (Nov 12): data done; one decision open.**
- **Built:**
  - `kin`, `kin_source`, `capture_tier`, `capture_likes` and `capture_needs` in `data/monsters.csv` (`tools/kin.py`, `tools/export_monsters.py`)
  - `data/chapters.csv`
  - [kin-report.md](kin-report.md), from `tools/kin_report.py`
  - the seven Dummy debug species are no longer capturable, leaving 149
- **Findings:**
  - All eight kin are well populated (10 to 30 species each).
  - Capture tiers rise chapter by chapter.
  - **FF4's encounter geography doesn't match the outline's kin batches.** Chapter 4 has no Dragons, Sky, Shade, Construct and Arcane are thin in their chapters, and Toroia, Cave Magnes and the Tower of Zot (not in the outline) hold 19 species found nowhere else.
- **Open decision:** reorder the chapters around the geography, or move monsters through the encounter redesign.

### M2 · Risky systems, one spike each

Build each against the sandbox start, smallest working slice first.

| # | System | Main risk | Done when |
| --- | --- | --- | --- |
| a | **Capture formula:** HP, status and level gap, plus the per-species preferences from M1; a refusal hint; the seen list in the pool view | Fitting the odds math and messages into the Pact handler and free bank space | Odds behave as designed in scripted fights; the seen list shows met species |
| b | **Second summoner:** Edge with Pact, Call, his own roster limited to his kin, his capture-style bonus, and the specialist bonus | Today's Call, roster and pool assume one summoner, Rydia | Edge and Rydia both capture and summon in one battle, and Edge can't take a non-Beast/Shade pact |
| c | **Early-game start:** Mist, on foot, chapter-1 world state, vehicles locked, low-level Rydia, first-pact XP bonus | Early-game flag state, built the way the late-game snapshot was | New Game starts at Mist with the right flags; the access audit stays quiet for chapter-1 locations |
| d | **Text pipeline:** decode and re-encode dialogue (DTE, banks at `$10:8000`+), edit NPC lines, add new messages; an event-script encoder to go with `tools/events.py` | Text compression and space in the dialogue banks | A guide NPC in Mist says new text, built from a source file |
| e | **Guardians:** a region gate as an event-triggered fight with a flag; beating it opens the way | Building triggers and event calls from source | One guardian blocks the Watery Pass until beaten |

**Order:** a, b and the encoder half of d all touch battle code or event data; run them one at a time or in separate worktrees, and integrate serially. c depends on d's event encoder. e depends on c and d.

### M3 · Chapter 1 vertical slice: Mist to Kaipo

Wild and Sky kin, capture conditions, a guide in Mist and Kaipo, the Watery Pass guardian, the XP curve, and low difficulty.

**Done when:** a playtest of about 30–45 minutes captures 8–12 species, uses Call, beats the guardian, and feels like the game we want. Fold the outstanding roster playtest (package G in [next-build.md](next-build.md)) into this one.

### M4 · Chapter 2: Edge joins

Edge joins by an event; Beast and Shade kin; his capture style; the chapter's guardian; first balance pass with two summoners.

### M5 onward

- **Chapters 3–5:** Cid, Kain, Rosa.
- **Chapters 6–7:** the underworld: dwarves, Feymarch trials (Asura, Leviathan), Eblan.
- **Chapter 8:** the moon, with FuSoYa as guest; Bahamut.
- **Final trial,** bestiary completion and polish.
- **Encounter redesign** per region as each chapter is built, so every capturable species is findable. Starts from `data/encounters.csv`.

## Alongside, any time

- **Palom and Porom graphics test** (storyboard open question 6). It only matters if the cast grows.
- **Balance and difficulty**, kept low, checked at each chapter playtest.
- **Remaining open questions** (storyboard 6–16): settle each when its milestone needs it.
  - Starting level and spells: M2c.
  - Teaching captures: M2a, M3.
  - XP numbers: M3.
  - Shops: M3.
  - Encounters: M5.
  - The capturable list's oddities: M1.
  - Names: before any release.

## How we work

- One session per work package, with a brief that names its files and what "done" means.
- Sessions that edit assembly or `build/` outputs run in their own worktrees; one integrator merges and rebuilds.
- Every system gets a headless Mesen check in `tools/mesen/` before a hand playtest.
- Commit and push at milestones. Record findings in `notes/` as you go, so the next session starts from the notes, not the chat.
