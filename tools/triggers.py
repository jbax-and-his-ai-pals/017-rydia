"""Decode what runs each event: map and world-map triggers, NPC talk, and code.

Usage: python tools/triggers.py [event ...]   lists where each event can run from

Each source is (kind, where, bank): bank is the NPC-flag bank an event's
F4/F5 use when it runs there (None if unknown). The game picks bank 1 when
$0FE5 bit 7 (map properties byte 10) is set or $1701 is non-zero ($00:F18C).
Formats, all confirmed in the field code (notes/addresses.md, L11):
- event calls ($00:EFA5): 256 pointers at $12:F260 into $12:F460. Cases of
  plain xx (plot flag clear), FE xx (set), then FF yy (run event yy; 0 = none).
- NPC talk ($00:F03F): 512 pointers at $13:9800 into $13:9C00, indexed by the
  9-bit NPC ID. Same cases; bytes after the last FF yy are message parameters.
- map properties ($00:83EF): 13 bytes per map at $15:9C84. Byte 3 is the
  NPC placement set, byte 10 bit 7 becomes $0FE5.
- map triggers ($00:9A1E): 384 pointers (maps $000-$17F) at $15:8000 into
  $15:8300, 5 bytes each: x, y, then $FF + event call, or a destination.
- world-map triggers ($00:9B77): 3 pointers at $19:FE60 into $19:FE66.
- NPC placements ($00:BE8F): set (byte 3 + 256 * bank) at $13:8000 into
  $13:8300, 4 bytes each starting with the NPC ID's low byte, ended by 0.
"""

import sys
from collections import defaultdict

from ff4rom import Rom

CALL_PTRS, CALL_DATA = 0x12F260, 0x12F460
NPC_PTRS, NPC_DATA = 0x139800, 0x139C00
PROPS = 0x159C84
MAP_PTRS, MAP_DATA, MAP_END, MAPS = 0x158000, 0x158300, 0x131F, 0x180
WORLD_PTRS, WORLD_DATA, WORLD_END = 0x19FE60, 0x19FE66, 0x19A
PLACE_PTRS, PLACE_DATA = 0x138000, 0x138300

# Events and event calls run straight from field code (every JSR $DF63 and
# every constant passed to $EFA5), with the bank where it's known.
CODE_EVENTS = {
    0x10: None,     # $00:8081 New Game; loads its own map first
    0xDB: None,     # $00:8285
    0x76: None,     # $00:9A0F
    0xC6: 1,        # $00:9422, only on the underworld map ($00:811C: $1700 = 1, so $1701 = 1)
}
CODE_CALLS = {
    0x2D: 0,        # $00:9B52: vehicle 4 ($1704) on tile type $10, surface map
    0x2F: 1,        # $00:9B5E: the same, underworld map
    0x52: None,     # $00:A635
    0x54: None,     # $00:A0DD
}


def cases(rom: Rom, data: int, start: int, end: int) -> list[tuple[list, list, int]]:
    """Cases [(flags that must be set, flags that must be clear, event)], read
    up to the last FF yy the way the game finds it (scanning back from end)."""
    last = end - 1
    while last >= start and rom.u8(data + last) != 0xFF:
        last -= 1
    if last < start:
        return []
    out, need_set, need_clear, i = [], [], [], start
    while i < last + 2:
        b = rom.u8(data + i)
        if b == 0xFE:
            need_set.append(rom.u8(data + i + 1))
            i += 2
        elif b == 0xFF:
            out.append((need_set, need_clear, rom.u8(data + i + 1)))
            need_set, need_clear = [], []
            i += 2
        else:
            need_clear.append(b)
            i += 1
    return out


def _table(rom: Rom, ptrs: int, data: int, n: int) -> list:
    p = [rom.u16(ptrs + 2 * i) for i in range(n)]
    # The last entry's end isn't stored; every table's last entry is empty.
    return [cases(rom, data, p[k], p[k + 1]) if k + 1 < n else [] for k in range(n)]


def event_calls(rom: Rom) -> list:
    return _table(rom, CALL_PTRS, CALL_DATA, 256)


def npc_calls(rom: Rom) -> list:
    return _table(rom, NPC_PTRS, NPC_DATA, 512)


def props(rom: Rom, m: int) -> bytes:
    return rom.read(PROPS + 13 * m, 13)


def map_bank(rom: Rom, m: int) -> int:
    """NPC bank on map m ($000-$17F): the high byte, or properties byte 10 bit 7."""
    return 1 if m >= 0x100 or props(rom, m)[10] & 0x80 else 0


def load_bank(rom: Rom, p: bytes) -> int:
    """NPC bank after event command FE map x y p ($00:EDB1)."""
    if p[0] >= 0xFB:
        # World map: $1701 is 0 on the surface, 1 underground, 2 on the moon
        # ($00:8502). $0FE5 keeps the last local map's bit, which is clear for
        # every map an event leaves for a world map (notes/late-game-state.md).
        return 0 if p[0] == 0xFB else 1
    return map_bank(rom, p[0] + (0x100 if p[3] & 0x80 else 0))


def triggers(rom: Rom, ptrs: int, data: int, end: int, n: int):
    """Yield (index, x, y, event call) for every event-call trigger."""
    p = [rom.u16(ptrs + 2 * i) for i in range(n)] + [end]
    for i in range(n):
        for k in range(p[i], p[i + 1], 5):
            x, y, dest, call, _ = rom.read(data + k, 5)
            if dest == 0xFF:
                yield i, x, y, call


def placements(rom: Rom) -> dict[int, set[int]]:
    """9-bit NPC ID -> maps it's placed on."""
    where = defaultdict(set)
    for m in range(MAPS):
        b = map_bank(rom, m)
        k = rom.u16(PLACE_PTRS + 2 * (props(rom, m)[3] + 256 * b))
        while (low := rom.u8(PLACE_DATA + k)) != 0:
            where[b * 256 + low].add(m)
            k += 4
    return where


def sources(rom: Rom) -> dict[int, set[tuple[str, int, int | None]]]:
    """Event -> {(kind, where, bank)}. NPCs count only if some map places them."""
    calls, src = event_calls(rom), defaultdict(set)

    def via(call, kind, where, bank):
        for _, _, e in calls[call]:
            if e:
                src[e].add((kind, where, bank))

    for m, _, _, call in triggers(rom, MAP_PTRS, MAP_DATA, MAP_END, MAPS):
        via(call, "map", m, map_bank(rom, m))
    for w, _, _, call in triggers(rom, WORLD_PTRS, WORLD_DATA, WORLD_END, 3):
        via(call, "world", w, 0 if w == 0 else 1)
    placed = placements(rom)
    for n, cs in enumerate(npc_calls(rom)):
        if n in placed:
            for _, _, e in cs:
                if e:
                    src[e].add(("npc", n, n >> 8))
    for call, bank in CODE_CALLS.items():
        via(call, "code call", call, bank)
    for e, bank in CODE_EVENTS.items():
        src[e].add(("code", e, bank))
    return src


if __name__ == "__main__":
    src = sources(Rom())
    for arg in sys.argv[1:] or ["9E"]:
        e = int(arg, 16)
        print(f"event {e:02X}: " + ", ".join(
            f"{k} {w:03X} (bank {b})" for k, w, b in sorted(src[e], key=str)) if src[e] else f"event {e:02X}: nothing runs it")
