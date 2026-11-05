# Rydia's Monster Game

A Final Fantasy IV (SNES) hack: Rydia alone in an open world, forming pacts with the monsters she fights. Distributed only as a BPS patch against your own ROM.

- Design: [handoff.md](handoff.md)
- MVP plan: [mvp-plan.md](mvp-plan.md)
- Addresses and lookups: [notes/addresses.md](notes/addresses.md)

## Layout

| Folder | Contents |
| --- | --- |
| `asm/` | asar patches |
| `data/` | CSVs (monster data, curation) |
| `tools/` | Python: ROM check, exporters, build |
| `notes/` | Research notes, audits, playtest logs |
| `rom/` | Your clean ROM. Ignored by git; never commit it |
| `build/` | Build output. Ignored by git |

## Base ROM

Final Fantasy II (USA) v1.1 (Rev 1), unheadered, 1,048,576 bytes, CRC32 `23084FCD`, SHA-1 `41a74eb369a7a91815529ef99ab1b20e2bdf3e26`. Put it in `rom/` as `ff2us-v1.1.sfc` or `ff2us-v1.1.smc` (same bytes; the tools accept either), then check it:

```bash
python tools/check_rom.py
```

## Build

```bash
python tools/build.py
```

This checks the clean ROM, generates `build/gen/data.asm` from `data/monsters.csv`, runs asar on `asm/main.asm`, and writes:
- `build/rydia.bps`: the patch to distribute
- `build/rydia.sfc`: a patched ROM for testing only
- `build/rydia.sym`: symbols for Mesen

It also re-applies the patch to confirm it reproduces the build byte for byte.

`data/monsters.csv` comes from the clean ROM. Re-run the export after adding columns; it keeps hand-edited `capturable` and `notes` values:

```bash
python tools/export_monsters.py
```

Test a build headless in Mesen (scripts in `tools/mesen/`):

```bash
python tools/mesen/run.py tools/mesen/peep.lua build/mesen-out --rom build/rydia.sfc --frames 800 --env MODE=idle
```

## Tools

| Tool | Version | Where | Status |
| --- | --- | --- | --- |
| Python | 3.14.7 | `C:\Python314` | installed |
| git | 2.55 | | installed |
| Mesen 2 | 2.1.1 | `C:\jbax-and-his-ai-pals\015-mmc6-nes\emu-stock\Mesen.exe` (shared with project 015) | installed |
| asar | 1.91 | `C:\tools\asar-1.91\asar.exe`, from [RPGHacker/asar](https://github.com/RPGHacker/asar/releases/tag/v1.91) | installed |
| Flips | v198 | `C:\tools\flips-v198\flips.exe`, from [Sir-Walrus/Flips](https://github.com/Sir-Walrus/Flips/releases/tag/v198) (formerly Alcaro/Flips) | installed |
| FF4kster | | [romhacking.net](https://www.romhacking.net/utilities/914/) | optional; viewer only |

asar and Flips are not on the global PATH; build scripts call them by full path. Downloaded 2026-11-02. GitHub publishes no hashes for these releases, so these are the SHA-256 values of the files as downloaded:

| File | Size | SHA-256 |
| --- | --- | --- |
| `asar191.zip` | 597,087 | `5d40f9cfa574360d8a3f382583556ba8757435274b35207977bf1cf20397b1e7` |
| `flips-windows.zip` | 63,562 | `802bfb315dca08a2f765dd6864472ecbb2b482681045c573d5e4b657b8e5295d` |

Tested on a dummy file: asar writes at the expected file offsets, and a BPS made by `flips --create --bps-delta` re-applies byte for byte. asar refuses a ROM whose internal title looks like garbage; that only matters for dummy test files (`--no-title-check`).

Mesen runs headless for scripted checks: `Mesen.exe --testRunner <rom> <script.lua> --debug.scriptWindow.allowIoOsAccess=true`. Lua output doesn't reach stdout in that mode, so scripts write files, and `emu.stop(code)` ends the run. See project 015's `tools/harness/README.md`.
