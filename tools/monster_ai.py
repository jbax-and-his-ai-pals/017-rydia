"""Decode monster AI (attack sequence groups) to the spells each species uses.

Usage: python tools/monster_ai.py [species hex ...]   prints groups and spells

Format (FF4Hacking "Tower of Bab-Il" docs, file offsets there are v1.0 headered;
the addresses below are ours, confirmed by decoding):
- Monster record byte 8: attack sequence group. Byte 9: flags for optional bytes,
  in order: $80 attack element/status (3), $40 defense (3), $20 weakness (1),
  $10 spell power (1), $08 creature type (1), $04 reflex (counter) group (1).
- Groups at $0E:E030, FF-terminated lists of (condition list, sequence) pairs.
  Found by counting FF terminators; there is no pointer table.
- Sequences at $0E:E900, found the same way. Codes:
    $00-$30 spell, $31-$5E spell + $30 (not castable by monsters),
    $5F-$BF enemy ability (a spell ID), $C0-$E7 command + $C0,
    $E8-$F9 take one parameter byte, $FA-$FE control, $FF end.
"""

import sys

from ff4rom import Rom, decode

SPECIES = 224
POINTERS = 0x0EA6A0
NAMES = 0x0E9800
GROUPS = 0x0EE030
SEQUENCES = 0x0EE900
SPELL_NAMES6 = 0x0F8900   # icon + 5 letters, IDs $00-$47
SPELL_NAMES8 = 0x0F8AB0   # 8 letters, IDs $48+


def _nth(rom: Rom, base: int, n: int, limit: int = 0x1000) -> int:
    """Address just after the n-th $FF terminator from base (n = 0: base)."""
    a = base
    for _ in range(n):
        while rom.u8(a) != 0xFF:
            a += 1
            if a - base > limit:
                raise ValueError(f"no terminator near ${base:06X}")
        a += 1
    return a


def record(rom: Rom, s: int) -> dict:
    """Group, reflex group (or None) and spell power (or None) of species s."""
    r = 0x0E0000 | rom.u16(POINTERS + 2 * s)
    flags = rom.u8(r + 9)
    a = r + 10
    if flags & 0x80:
        a += 3
    if flags & 0x40:
        a += 3
    if flags & 0x20:
        a += 1
    power = None
    if flags & 0x10:
        power = rom.u8(a)
        a += 1
    if flags & 0x08:
        a += 1
    reflex = rom.u8(a) if flags & 0x04 else None
    return {"group": rom.u8(r + 8), "reflex": reflex, "power": power}


def group_sequences(rom: Rom, g: int) -> list[int]:
    a = _nth(rom, GROUPS, g)
    seqs = []
    while True:
        cond = rom.u8(a)
        if cond == 0xFF:
            break
        seqs.append(rom.u8(a + 1))
        if rom.u8(a + 1) == 0xFF:   # the documented exception: FF is both
            break
        a += 2
        if len(seqs) > 12:
            break
    return seqs


def sequence_codes(rom: Rom, q: int) -> list[int]:
    a = _nth(rom, SEQUENCES, q)
    out = []
    while True:
        c = rom.u8(a)
        if c == 0xFF:
            return out
        if 0xE8 <= c <= 0xF9:
            a += 2
            continue
        out.append(c)
        a += 1
        if len(out) > 0x40:
            return out


def spell_of(code: int) -> int | None:
    """Spell ID for an action code, or None for commands and control codes."""
    if code <= 0x30 or 0x5F <= code <= 0xBF:
        return code
    if 0x31 <= code <= 0x5E:
        return code + 0x30
    return None


def spell_name(rom: Rom, sp: int) -> str:
    if sp < 0x48:
        return decode(rom.read(SPELL_NAMES6 + 6 * sp + 1, 5))
    return decode(rom.read(SPELL_NAMES8 + 8 * (sp - 0x48), 8))


def species_spells(rom: Rom, s: int) -> tuple[list[int], list[int]]:
    """(spells in the main AI, spells in the counter AI), first-seen order."""
    rec = record(rom, s)
    def collect(group):
        seen = []
        if group is None:
            return seen
        for q in group_sequences(rom, group):
            if q == 0xFF:
                continue
            for c in sequence_codes(rom, q):
                sp = spell_of(c)
                if sp is not None and sp not in seen:
                    seen.append(sp)
        return seen
    return collect(rec["group"]), collect(rec["reflex"])


def main() -> None:
    rom = Rom()
    ids = [int(x, 16) for x in sys.argv[1:]] or range(SPECIES)
    for s in ids:
        main_, counter = species_spells(rom, s)
        name = decode(rom.read(NAMES + 8 * s, 8))
        fmt = lambda xs: " ".join(f"{x:02X}:{spell_name(rom, x)}" for x in xs) or "-"
        print(f"{s:02X} {name:<8} ai {fmt(main_)} | counter {fmt(counter)}")


if __name__ == "__main__":
    main()
