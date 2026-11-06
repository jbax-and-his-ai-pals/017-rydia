# Rydia's Monster Game

A Final Fantasy IV (SNES) hack: Rydia alone in an open world, forming pacts with the monsters she fights. Distributed only as a BPS patch against your own ROM.

- Design: [handoff.md](handoff.md)
- MVP plan: [mvp-plan.md](mvp-plan.md)
- Addresses and lookups: [notes/addresses.md](notes/addresses.md)
- Next build: [notes/next-build.md](notes/next-build.md)
- Branch review and verification: [notes/integration-review.md](notes/integration-review.md)
- Monster locations: [notes/monster-locations.md](notes/monster-locations.md), regenerated with `python tools/export_encounters.py`

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

This checks the clean 1 MiB ROM, expands the patched output to 2 MiB, generates
`build/gen/data.asm` from `data/monsters.csv`, runs asar on `asm/main.asm`, and writes:
- `build/rydia.bps`: the patch to distribute
- `build/rydia.sfc`: a patched ROM for testing only
- `build/rydia.sym`: symbols for Mesen

It verifies LoROM/SRAM metadata, the ROM size header and checksum, and re-applies
the patch to confirm it reproduces the build byte for byte. Expanded allocations
and the roster state contract are in [notes/roster-state.md](notes/roster-state.md).

`data/monsters.csv` comes from the clean ROM. Re-run the export after adding columns; it keeps hand-edited `capturable` and `notes` values:

```bash
python tools/export_monsters.py
```

List the pacts in each slot of a save file. Mesen 2 keeps battery saves in its `Saves` folder:

```bash
python tools/pacts.py path/to/rydia.srm
```

Test a build headless in Mesen (scripts in `tools/mesen/`):

```bash
python tools/mesen/run.py tools/mesen/peep.lua build/mesen-out --rom build/rydia.sfc --frames 800 --env MODE=idle
```

The runner exits successfully only when Mesen exits successfully and the current
Lua run writes a passing `harness-status.txt`. It clears stale status, log and
result files before launch. Pact, Call, save/load and access checks also require
their scenario to complete; a frame limit alone cannot pass them. Trace and
screenshot scripts can still finish successfully at their requested frame limit.

For new checks, call `H.require_scenario_completion()`, report assertions with
`H.fail(reason)`, and call `H.mark_scenario_complete()` only after the required
scenario has run. Finish callbacks still run after failures to preserve logs.

Check the Python runner contract without launching Mesen:

```bash
python -m unittest tools.test_build tools.mesen.test_run tools.test_audit_access -v
```

Probe the Lua/process contract through Mesen:

```bash
python tools/mesen/run.py tools/mesen/harness_probe.lua build/harness-probe --rom build/rydia.sfc --frames 8 --env PROBE_MODE=pass
```

`PROBE_MODE=pass` exits 0; `fail`, `incomplete`, `finish-error` and
`nested-finish` deliberately exit nonzero. Artifacts are for diagnosis; callers
must honor the runner's exit status.

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
