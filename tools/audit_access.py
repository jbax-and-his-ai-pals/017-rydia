"""Access audit: start the built patch inside every location reachable from the
world maps and record whether anything fires.

Usage: python tools/audit_access.py [--only N]   (needs a fresh python tools/build.py)

For each world-map entrance (triggers at $19:FE60) it runs tools/mesen/audit.lua
headless, then writes notes/access.csv. A location is "quiet" when, after
arriving and walking up a few steps, no event, fight, party change or forced map
change happened.
"""

import argparse
import csv
import subprocess
import sys
from pathlib import Path

from ff4rom import ROOT, Rom, decode

WORLDS = ["surface", "underworld", "moon"]
TRIGGERS, TRIGGER_DATA = 0x19FE60, 0x19FE66
TITLES, PROPS = 0x159620, 0x159C84
OUT_DIR = ROOT / "build" / "audit"


def locations(rom: Rom):
    titles = [decode(t) for t in rom.read(TITLES, 0x4D1).split(b"\x00")]
    ptrs = [rom.u16(TRIGGERS + 2 * i) for i in range(3)] + [0x19A]
    seen = {}
    for w in range(3):
        for k in range((ptrs[w + 1] - ptrs[w]) // 5):
            x, y, m, dx, dy = rom.read(TRIGGER_DATA + ptrs[w] + 5 * k, 5)
            mid = m + (0x100 if w else 0)
            if mid in seen or m >= 0xFB:
                continue
            title_idx = rom.u8(PROPS + 13 * mid + 11)
            name = titles[title_idx] if title_idx < len(titles) else f"title {title_idx}"
            seen[mid] = dict(world=WORLDS[w], x=x, y=y, map=mid, name=name,
                             event=bytes([0xFE, m, dx, dy, 0x80 if w else 0x00, 0xFF]))
    return list(seen.values())


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--only", type=lambda s: int(s, 16), default=None, help="one map ID (hex)")
    a = p.parse_args()
    rom_path = ROOT / "build" / "rydia.sfc"
    if not rom_path.exists():
        sys.exit("Run python tools/build.py first")
    locs = locations(Rom())
    if a.only is not None:
        locs = [loc for loc in locs if loc["map"] == a.only]
    rows = []
    for n, loc in enumerate(locs, 1):
        out = OUT_DIR / f"{loc['map']:03X}"
        subprocess.run([sys.executable, str(ROOT / "tools" / "mesen" / "run.py"),
                        str(ROOT / "tools" / "mesen" / "audit.lua"), str(out), "--rom", str(rom_path),
                        "--frames", "1400", "--timeout", "120", "--env", f"EVENT={loc['event'].hex().upper()}"],
                       capture_output=True)
        res = (out / "result.txt").read_text().splitlines() if (out / "result.txt").exists() else ["(no result)"]
        notes = [line for line in res[1:]]
        status = "quiet" if res[0].startswith("map=") and not notes else ("no result" if res == ["(no result)"] else "check")
        rows.append({"world": loc["world"], "entrance": f"{loc['x']:02X},{loc['y']:02X}", "map": f"{loc['map']:03X}",
                     "name": loc["name"], "status": status, "details": "; ".join(notes), "start": res[0]})
        print(f"[{n}/{len(locs)}] {loc['world']:<10} {loc['map']:03X} {loc['name']:<24} {status} {'; '.join(notes)[:80]}")
    with (ROOT / "notes" / "access.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


if __name__ == "__main__":
    main()
