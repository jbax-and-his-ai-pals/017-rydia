"""Export every monster species from the clean ROM to data/monsters.csv.

Usage: python tools/export_monsters.py

Columns: id, name, level, hp, boss, formations, runnable, capturable, notes.
- boss: the species' boss bit (record byte 0, bit 7).
- formations / runnable: how many formations include the species, and how many
  of those you can run from (formation byte 6, bit 0 clear).
- capturable: y/n. Seeded as "appears in a runnable formation". Hand-edit it;
  re-running this script keeps existing capturable and notes values. Debug
  species (DEBUG_NAMES) are never capturable.
- kin: one of the eight kin (tools/kin.py), seeded from the ROM's creature type
  or curated. kin_source says where it came from: rom, curated, or hand when
  the CSV value differs from the seed.
- capture_tier: 1 (easy) to 5 (hard), seeded from level; boss-bit species are 5.
- capture_likes / capture_needs: per-species capture conditions for the capture
  formula (roadmap M2a): conditions that raise the odds, and hard requirements
  reserved for rare species. Semicolon lists from the vocabulary in
  notes/kin-report.md. Empty until curated.
Columns marked curated in CURATED keep their CSV values on re-export.
"""

import csv
from pathlib import Path

from ff4rom import ROOT, Rom, decode
import abilities
import kin as kin_mod
import monster_ai

SPECIES = 224
NAMES = 0x0E9800       # 8 bytes each
POINTERS = 0x0EA6A0    # 16-bit, low half of the record address in bank $0E
FORMATIONS = 0x0E8000  # 8 bytes each
FORMATION_COUNT = 512
OUT = ROOT / "data" / "monsters.csv"
CURATED = ["capturable", "notes", "call_name", "call_anim", "call_data", "call_power", "call_target", "call_verified",
           "kin", "capture_tier", "capture_likes", "capture_needs"]
FIELDS = ["id", "name", "level", "hp", "boss", "formations", "runnable", "capturable",
          "kin", "kin_source", "capture_tier", "capture_likes", "capture_needs",
          "ai_spells", "call_name", "call_anim", "call_data", "call_power", "call_target", "call_verified", "notes"]
DEBUG_NAMES = {"Dummy"}   # developer leftovers in seven formations; not real monsters


def capture_tier(level: int, boss: bool) -> int:
    """1 (easy) to 5 (hard): the seed for how much setup a capture needs."""
    if boss:
        return 5
    for tier, top in ((1, 9), (2, 19), (3, 34), (4, 59)):
        if level <= top:
            return tier
    return 5


def formation_species(rom: Rom):
    """Yield (species list, can_run) for every formation."""
    for f in range(FORMATION_COUNT):
        b = rom.read(FORMATIONS + 8 * f, 8)
        counts = ((b[4] >> 6) & 3, (b[4] >> 4) & 3, (b[4] >> 2) & 3)
        species = [s for s, c in zip(b[1:4], counts) if c and s < SPECIES]
        yield species, not (b[6] & 0x01)


def export(rom: Rom) -> list[dict]:
    seen = {s: 0 for s in range(SPECIES)}
    runnable = {s: 0 for s in range(SPECIES)}
    for species, can_run in formation_species(rom):
        for s in set(species):
            seen[s] += 1
            runnable[s] += can_run

    kins = kin_mod.resolve(rom)
    rows = []
    for s in range(SPECIES):
        record = 0x0E0000 | rom.u16(POINTERS + 2 * s)
        b0 = rom.u8(record)
        rows.append({
            "id": f"{s:02X}",
            "name": decode(rom.read(NAMES + 8 * s, 8)),
            "level": b0 & 0x7F,
            "hp": rom.u16(record + 1),
            "boss": 1 if b0 & 0x80 else 0,
            "formations": seen[s],
            "runnable": runnable[s],
            "capturable": "y" if runnable[s] else "n",
            "kin": kins[s][0],
            "kin_source": kins[s][1],
            "capture_tier": capture_tier(b0 & 0x7F, bool(b0 & 0x80)),
            "capture_likes": "",
            "capture_needs": "",
            "notes": "",
        })
        main_, counter = monster_ai.species_spells(rom, s)
        spells = main_ + [x for x in counter if x not in main_]
        rows[-1]["ai_spells"] = "; ".join(f"{x:02X} {monster_ai.spell_name(rom, x).strip()}" for x in spells)
        rows[-1]["call_anim"], rows[-1]["call_data"] = abilities.suggest(rom, spells)
        for k in ("call_name", "call_power", "call_target", "call_verified"):
            rows[-1][k] = ""
    return rows


def main() -> None:
    rows = export(Rom())
    seed_kin = {r["id"]: r["kin"] for r in rows}
    kept = 0
    if OUT.exists():
        with OUT.open(newline="", encoding="utf-8") as f:
            old = {r["id"]: r for r in csv.DictReader(f)}
        for r in rows:
            if r["id"] in old:
                for k in CURATED:
                    v = old[r["id"]].get(k)
                    if v is not None and (v != "" or k in ("capturable", "notes", "call_verified")):
                        r[k] = v
                kept += 1
    for r in rows:
        if r["kin"] != seed_kin[r["id"]]:
            r["kin_source"] = "hand"
        if r["name"] in DEBUG_NAMES and r["capturable"] != "n":
            r["capturable"] = "n"
            r["notes"] = "; ".join(x for x in (r["notes"], "debug species, never capturable") if x)
    OUT.parent.mkdir(exist_ok=True)
    with OUT.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)
    yes = sum(r["capturable"] == "y" for r in rows)
    print(f"Wrote {OUT} ({len(rows)} species, {yes} capturable; kept curation for {kept})")


if __name__ == "__main__":
    main()
