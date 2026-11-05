"""List the pacts in each save slot of an FF4 save file (.srm).

Usage: python tools/pacts.py <file.srm>

Mesen 2 keeps battery saves in its Saves folder (for example
Documents\\Mesen2\\Saves\\<rom name>.srm). Each 2 KB slot is a copy of WRAM
$1000-$17FF; pacts are one bit per species at $1181-$119C (species n is byte
n>>3, bit n&7). A slot is valid when its last word is $1BE4.
"""

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SLOT, PACTS, SPECIES, MAGIC = 0x800, 0x181, 224, 0x1BE4


def names() -> list[str]:
    with (ROOT / "data" / "monsters.csv").open(newline="", encoding="utf-8") as f:
        return [r["name"] for r in csv.DictReader(f)]


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    data = Path(sys.argv[1]).read_bytes()
    monster = names()
    for slot in range(len(data) // SLOT):
        block = data[slot * SLOT:(slot + 1) * SLOT]
        if int.from_bytes(block[0x7FE:0x800], "little") != MAGIC:
            print(f"Save{slot + 1}: empty")
            continue
        bits = block[PACTS:PACTS + SPECIES // 8]
        have = [s for s in range(SPECIES) if bits[s >> 3] & (1 << (s & 7))]
        listed = ", ".join(f"{monster[s]} ({s:02X})" for s in have) or "none"
        print(f"Save{slot + 1}: {len(have)} pact{'s' if len(have) != 1 else ''}: {listed}")


if __name__ == "__main__":
    main()
