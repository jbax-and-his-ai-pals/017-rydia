"""The sandbox's starting state: every WRAM write New Game makes on top of vanilla.

Usage: python tools/late_game.py          print the writes as Mesen POKES (start_test.lua)

Used by Mesen tests now and by the Phase 2 new-game hook later, so the values
live in one place. Tunables (level, stats, gear, items, vehicle spots) are at
the top.
"""

from ff4rom import Rom
from snapshot import build as build_flags

# --- Tunables -----------------------------------------------------------------
LEVEL = 60
HP, MP = 3000, 450
BASE_STATS = (20, 40, 30, 60, 45)          # STR AGI VIT WIS WIL
EXP, EXP_TO_NEXT = 1_000_000, 50_000
HEAD, WEAPON = 0x7C, 0x0D                   # Ribbon, Stardust rod
BLACK_MAGIC = [0x1D, 0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25,   # Fire/Ice/Lit 1-3
               0x29, 0x2C, 0x26, 0x27, 0x28, 0x2D, 0x2E, 0x2B, 0x2A,   # Sleep Stop Virus Weak Quake Drain Psych Fatal Stone
               0x1B, 0x19, 0x1A, 0x1C, 0x30, 0x2F]                     # Warp Toad Piggy Venom Nuke Meteo
CALL_LIST = []                              # empty for the MVP; Call is a later milestone
ITEMS = [(0xD0, 30), (0xD2, 20), (0xD3, 5), (0xDD, 20), (0xD4, 10)]  # Cure3 Ether2 Elixir Heal Life
START = (0x9A, 0xC8)                        # overworld, on land just outside Mysidia
VEHICLES = {                                # record base: (x, y); map byte 0 = surface
    0x1720: (0x9C, 0xC8),                   # Falcon
    0x171C: (0x9D, 0xC6),                   # Enterprise
    0x1724: (0x99, 0xC7),                   # Big Whale, where event $9E lands it
}
GOLD = 500_000

RYDIA_ID, RYDIA_SPRITE = 0x11, 0x0B
CHILD_RYDIA_RECORD = 2                      # initial-stats record she inherits from
BLACK_LIST, CALL_LIST_ADDR = 0x15A8, 0x15C0  # spell lists 3 and 4


def rydia_record(rom: Rom) -> bytes:
    init = rom.read(0x0FA900 + 32 * CHILD_RYDIA_RECORD, 32)
    equip = rom.read(0x0FAB00 + 7 * CHILD_RYDIA_RECORD, 7)
    rec = bytearray(64)
    rec[0x00:0x14] = init[0x00:0x14]
    rec[0x2D:0x30] = init[0x14:0x17]
    rec[0x37:0x40] = init[0x17:0x20]
    rec[0x00] = (init[0] & 0xC0) | RYDIA_ID
    rec[0x01] = 0x80 | RYDIA_SPRITE        # back row
    rec[0x02] = LEVEL
    rec[0x03:0x07] = bytes(4)
    for off, v in ((0x07, HP), (0x09, HP), (0x0B, MP), (0x0D, MP)):
        rec[off:off + 2] = v.to_bytes(2, "little")
    rec[0x0F:0x14] = bytes(BASE_STATS)
    # Equipment: head, body, arms, right item, count, left item, count.
    rec[0x30:0x37] = bytes([HEAD, equip[1], equip[2], WEAPON, 1, 0, 0])
    rec[0x37:0x3A] = EXP.to_bytes(3, "little")
    rec[0x3D:0x40] = EXP_TO_NEXT.to_bytes(3, "little")
    return bytes(rec)


def spell_list(ids: list[int]) -> bytes:
    return bytes(ids + [0] * (24 - len(ids)))


def writes(rom: Rom) -> list[tuple[int, bytes]]:
    """(WRAM address, bytes) pairs, applied in order."""
    plot, npc, *_ = build_flags(rom)
    out = [
        (0x1000, rydia_record(rom)),
        (0x1040, bytes(0x100)),            # party slots 1-4 empty
        (0x1280, bytes(plot)),
        (0x12E0, bytes(npc)),
        (BLACK_LIST, spell_list(BLACK_MAGIC)),
        (CALL_LIST_ADDR, spell_list(CALL_LIST)),
        (0x1440, b"".join(bytes([i, n]) for i, n in ITEMS) + bytes(2 * (48 - len(ITEMS)))),
        (0x16A0, GOLD.to_bytes(3, "little")),
        (0x1181, bytes(28)),               # pact bitfield, cleared
    ]
    for base, (x, y) in VEHICLES.items():
        out.append((base, bytes([1, x, y, 0])))
    return out


OVERWORLD_SONG = 0x0D   # what vanilla events play right after loading the overworld ($15, $30, $43)


def start_event() -> bytes:
    """Event $10 replacement: load the overworld at START on foot, then start its music.

    Loading a map from an event doesn't change the music; events set it themselves.
    """
    return bytes([0xFE, 0xFB, START[0], START[1], 0x00, 0xFA, OVERWORLD_SONG, 0xFF])


if __name__ == "__main__":
    rom = Rom()
    print("EVENT=" + start_event().hex().upper())
    print("POKES=" + ";".join(f"{a:04X}:{b.hex().upper()}" for a, b in writes(rom)))
