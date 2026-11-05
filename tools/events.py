"""Decode FF4 event scripts (bank $12).

Usage: python tools/events.py [event ...]   prints the decoded events (hex numbers)

Format (notes/addresses.md, L11): 256 pointers at $12:8000 are offsets from
$12:8200. Bytes below $D0 are 1-byte movement codes; $D0-$FE take 0-4
parameter bytes; $FF ends a branch. Events with a yes/no prompt (F8) or some
fights (EC) hold a second branch after the first $FF. Parsing every event and
landing exactly on the next one is the self-check for these lengths.
"""

import sys

from ff4rom import Rom, decode

PTRS, BASE, END = 0x128000, 0x128200, 0x6E00
PARAMS = {op: 0 for op in range(0xD0, 0xDB)}
PARAMS.update({op: 1 for op in range(0xDB, 0xFE)})
PARAMS.update({0xE2: 2, 0xEB: 2, 0xFE: 4, 0xFF: 0})

NAMES = {
    0xE0: "add item", 0xE1: "remove item", 0xE7: "add character", 0xE8: "remove character",
    0xE9: "wait", 0xEC: "fight", 0xF0: "message", 0xF1: "message", 0xF6: "message", 0xF8: "yes/no message",
    0xF2: "set plot flag", 0xF3: "clear plot flag", 0xF4: "set NPC flag", 0xF5: "clear NPC flag",
    0xFA: "play song", 0xFE: "load map", 0xFF: "end",
}


def pointers(rom: Rom) -> list[int]:
    return [rom.u16(PTRS + 2 * i) for i in range(256)]


def parse_all(rom: Rom) -> dict[int, list[list[tuple[int, bytes]]]]:
    """Return {event number: [branch, ...]}, each branch a list of (opcode, params)."""
    ptrs = pointers(rom)
    starts = sorted(set(ptrs))
    parsed = {}
    for k, start in enumerate(starts):
        limit = starts[k + 1] if k + 1 < len(starts) else None
        pc, branches, cur = start, [], []
        while limit is None or pc < limit:
            op = rom.u8(BASE + pc)
            n = PARAMS.get(op, 0)
            cur.append((op, rom.read(BASE + pc + 1, n)))
            pc += 1 + n
            if op == 0xFF:
                branches.append(cur)
                cur = []
                if limit is None:
                    break
        if limit is not None and pc != limit:
            raise ValueError(f"event at offset {start:04X} overruns the next event")
        parsed[start] = branches
    return {e: parsed[p] for e, p in enumerate(ptrs)}


def describe(op: int, p: bytes) -> str:
    if op < 0xD0:
        return f"move {op:02X}"
    name = NAMES.get(op, f"op {op:02X}")
    return f"{name} {p.hex(' ')}".rstrip()


if __name__ == "__main__":
    rom = Rom()
    events = parse_all(rom)
    for arg in sys.argv[1:] or ["10"]:
        e = int(arg, 16)
        for b, branch in enumerate(events[e]):
            print(f"event {e:02X} branch {b}: " + "; ".join(describe(op, p) for op, p in branch if op >= 0xD0))
