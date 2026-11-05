# Access audit

Phase 2.5. Run with `python tools/build.py` then `python tools/audit_access.py`; raw results are in [access.csv](access.csv).

## Method

`tools/audit_access.py` reads every world-map entrance (the triggers at `$19:FE60`) and keeps the 44 unique destination maps. For each one it boots the built patch headless (`tools/mesen/audit.lua`) and runs New Game, with event `$10` rewritten to load that map. Then it:
- idles 4 seconds
- walks up for 1 second, twice
- logs any event, fight, party change or map change
- takes a screenshot (`build/audit/<map>/end.png`)

## Result

**No location fires a story scene, fight or party change.**

- 33 are fully quiet.
- 11 had a map change only: walking up from the arrival spot left the map, or went through a door.
  - In underworld and moon caves, walking out lands on the surface map. That's a quirk of teleporting in, since the game never recorded which world we came from. It doesn't happen when you walk in from the world map.
- The first run found one scene: Lunar's Lair ran event `D0` (FuSoYa joins). Setting flag `47` fixed it.
- Playtest then showed `47` alone makes the first Big Whale trip play the Giant of Babil cutscene. The whole Giant arc (`47–49`) is now marked done (see [late-game-state.md](late-game-state.md)).
- Re-audited after both fixes, with the same result.

| World | Entrance | Map | Location | Result |
| --- | --- | --- | --- | --- |
| surface | `65,9C` | `024` | Baron | quiet |
| surface | `64,9D` | `000` | Town of Baron | quiet |
| surface | `4C,84` | `06C` | Misty Cave | quiet |
| surface | `60,77` | `001` | Village Mist | quiet |
| surface | `7D,68` | `002` | Kaipo | quiet |
| surface | `8A,53` | `06F` | Watery Pass-South | quiet |
| surface | `8A,4D` | `073` | Watery Pass-North | quiet (walked out to the world map) |
| surface | `86,48` | `074` | Waterfalls | quiet (walked out to the world map) |
| surface | `7D,42` | `076` | Lake | quiet (walked out to the world map) |
| surface | `76,3A` | `025` | Damcyan | quiet |
| surface | `88,38` | `077` | Antlion B1F | quiet (walked out to the world map) |
| surface | `98,31` | `07E` | Mt.Hobs-West | quiet |
| surface | `A0,31` | `080` | Mt.Hobs-East | quiet |
| surface | `D6,3A` | `026` | Fabul | quiet |
| surface | `9A,C7` | `003` | Mysidia | quiet |
| surface | `DA,C7` | `084` | Mt.Ordeals | quiet |
| surface | `22,52` | `027` | Toroian Castle | quiet |
| surface | `23,53` | `005` | Town of Toroia | quiet |
| surface | `4A,35` | `08C` | Cave Magnes | quiet (walked out to the world map) |
| surface | `2D,EB` | `028` | Eblan | quiet |
| surface | `18,E7` | `0C7` | Cave Eblana | quiet (walked out to the world map) |
| surface | `68,D7` | `006` | Agart | quiet |
| surface | `D2,82` | `004` | Silvera | quiet |
| surface | `DB,88` | `0A0` | Grotto Adamant | quiet |
| surface | `21,DB` | `0B5` | Mouth | quiet |
| surface | `22,DB` | `0C0` | (no title) | quiet |
| surface | `E4,2F` | `0CF` | Chocobo's Forest | quiet |
| surface | `D5,D1` | `0D1` | Chocobo's Forest | quiet |
| surface | `59,A3` | `0D2` | Chocobo's Forest | quiet |
| surface | `22,65` | `0D3` | Chocobo's Forest | quiet |
| surface | `56,4F` | `0D4` | Chocobo's Forest | quiet |
| surface | `29,35` | `021` | Chocobo's Village | quiet |
| underworld | `63,52` | `107` | Castle of Dwarves | quiet |
| underworld | `5B,53` | `10F` | Dwarf Base | quiet |
| underworld | `68,7B` | `100` | Kokkol' the Smith's | quiet (walked through a door) |
| underworld | `3E,79` | `101` | Tomra | quiet |
| underworld | `0D,0E` | `145` | Sylvan Cave | quiet (walked out to the world map) |
| underworld | `2E,6D` | `144` | Sealed Cave | quiet |
| underworld | `1B,56` | `136` | Land of Monsters | quiet (walked out to the world map) |
| moon | `3D,17` | `15A` | Cave Bahamut | quiet (walked out to the world map) |
| moon | `1C,19` | `160` | Lunar's Lair | quiet |
| moon | `12,14` | `163` | Lunar Path | quiet |
| moon | `29,18` | `164` | Lunar Path | quiet (walked out to the world map) |
| moon | `21,27` | `165` | (no title) | quiet |

## Travel

- **Surface to underworld: works.** Fly the Falcon onto the hole near Agart (`6A`,`D4`) and land; the party arrives at the underworld return point (`71`,`10`).
- **Surface to moon: needs a re-check by hand.** The first playtest reached the moon but played the Giant of Babil cutscene on the way, which the `47–49` fix addresses. The Whale's crystal is hard to reach blind, so this isn't automated. All five moon locations load and are quiet.

## Not covered

- **Depth.** Only the arrival spot and a few steps were checked. Scenes deeper inside, locked doors, and NPCs blocking corridors need a walkthrough.
- **Places with no world-map entrance:** the Tower of Babil, Tower of Zot, Giant of Babil, the Lunar Subterrane's lower floors and Baron's waterway. Some exist only during their story event.
- **NPC flags in the underworld and moon** may be wrong (see [late-game-state.md](late-game-state.md)). Expect odd NPCs; report any that block a path.
