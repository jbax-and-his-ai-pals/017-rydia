"""Build the late-game world state (plot and NPC flags) from the event scripts.

Usage: python tools/snapshot.py          prints a summary and the bytes as hex

No real save is needed. Every plot flag is set or cleared only by event
scripts (F2/F3), and flag numbers follow story order, so the state "just after
the Big Whale" is:
- plot flags $00-$43 that events only ever set, plus $53 (K. Eblan at Babil),
  minus $08 (Odin's trial), so the optional trials stay open;
- the five flags events both set and clear, decided from the story (see FIXED);
- NPC flags: the game's starting values ($12:F200) with changes applied from
  events up to the Whale, ordered by the highest plot flag each event sets.
  Each F4/F5 goes to the NPC bank of the map the event runs on (tools/triggers.py).
See notes/late-game-state.md for the reasoning and known gaps.
"""

from collections import defaultdict

from events import parse_all
from ff4rom import Rom
from triggers import load_bank, sources

LAST_FLAG = 0x43          # set by event $9E, the Big Whale rising at Mysidia
# $53: K. Eblan at Babil (mid-game, high number).
# $47/$48/$49: the whole Giant of Babil arc counts as done. $47 alone (FuSoYa
# joined, event $D0) makes event call $4E (+47 -48) run the Giant cutscene $9D
# on the next Whale trip; $48 is the CPU fight ($E6, which also re-adds Kain)
# and $49 the Elements fight ($ED), both inside the Giant.
EXTRA = {0x53, 0x47, 0x48, 0x49}
SKIP = {0x08}             # Odin's trial: leave it available
FIXED = {                 # flags events both set and clear
    0x0A: True,           # cleared by $95, set by $96 (later)
    0x30: True,           # underworld passage: opened $84, sealed $96, reopened $C6
    0x32: False,          # set $8B, cleared $96: the Enterprise is usable again
    0x3E: False,          # set $8C (Calbrena), cleared $96
    0x42: False,          # set $B6 (Kain leaves), cleared by the CPU fight $E6 (Kain returns)
}
NPC_INIT = 0x12F200
# Events that set no plot flag still count as done, except these, which belong
# to the final dungeon or haven't happened yet in the snapshot:
NOT_YET = {
    0x58: "Lunar Subterrane B5 guardian (fight, item, then hides)",
    0x59: "Lunar Subterrane guardian, map $16E",
    0xA3: "Lunar Subterrane B3 guardian",
    0xA4: "Lunar Subterrane guardian, map $17A",
    0xDD: "moon scene: with $48 set, call $4D on map $161 still runs it",
}


def build(rom: Rom):
    events = parse_all(rom)
    sets, clears = defaultdict(set), defaultdict(set)
    for e, branches in events.items():
        for op, p in branches[0]:
            if op == 0xF2:
                sets[p[0]].add(e)
            elif op == 0xF3:
                clears[p[0]].add(e)

    plot = bytearray(32)
    chosen = []
    for f in range(256):
        if f in FIXED:
            on = FIXED[f]
        elif f in sets and f not in clears:
            on = (f <= LAST_FLAG or f in EXTRA) and f not in SKIP
        else:
            on = False
        if on:
            plot[f >> 3] |= 1 << (f & 7)
            chosen.append(f)

    # An event's story time is the highest plot flag it sets; events that set
    # a flag past the snapshot are out of scope.
    def time(e):
        fs = [p[0] for op, p in events[e][0] if op == 0xF2]
        return max(fs) if fs else None

    def in_scope(t, fs):
        return all(f <= LAST_FLAG or f in EXTRA for f in fs) and not (set(fs) & SKIP)

    npc = bytearray(rom.read(NPC_INIT, 64))
    src = sources(rom)
    latest = {}             # (bank, index) -> (time, set?)
    unreachable = []
    for e, branches in events.items():
        fs = [p[0] for op, p in branches[0] if op == 0xF2]
        if not in_scope(time(e), fs) or e in NOT_YET:
            continue
        ops = [(op, p) for op, p in branches[0] if op in (0xF4, 0xF5, 0xFE)]
        if not any(op != 0xFE for op, _ in ops):
            continue
        if not src[e]:
            unreachable.append(e)       # nothing in the game runs it
            continue
        banks = {b for _, _, b in src[e]}
        bank = banks.pop() if len(banks) == 1 else None
        for op, p in ops:
            if op == 0xFE:
                bank = load_bank(rom, p)
                continue
            if bank is None:
                raise ValueError(f"event {e:02X}: no single NPC bank for {op:02X} {p[0]:02X}; sources {sorted(src[e], key=str)}")
            key = (bank, p[0])
            t = time(e) if time(e) is not None else -1
            if key not in latest or t >= latest[key][0]:
                latest[key] = (t, op == 0xF4)
    for (b, i), (_, on) in latest.items():
        n = b * 256 + i
        if on:
            npc[n >> 3] |= 1 << (n & 7)
        else:
            npc[n >> 3] &= ~(1 << (n & 7)) & 0xFF
    return plot, npc, chosen, len(latest), unreachable


if __name__ == "__main__":
    plot, npc, chosen, changed, unreachable = build(Rom())
    print(f"plot flags set: {len(chosen)}")
    print(f"NPC flags changed from start: {changed}; skipped events nothing runs: "
          + " ".join(f"{e:02X}" for e in unreachable))
    print("plot $1280:", plot.hex().upper())
    print("npc  $12E0:", npc.hex().upper())
