"""Signature abilities: from data/monsters.csv columns to the ROM table.

Columns (all optional; blank = plain strike):
- call_name      the summon's name in the Call menus (battle and field), at
                 most 5 characters, unique among capturable species. Blank:
                 the first 5 letters of the monster name. The caption while the
                 summon acts still shows the full 8-letter monster name.
- ai_spells      exported by tools/export_monsters.py: every spell in the species'
                 AI, main then counter ("6C Petrify; 6B Beak"). Read-only.
- call_anim      hex spell whose animation plays after the monster appears.
                 Defaults to call_data.
- call_data      hex spell whose data (targeting, hit, effect, element/status)
                 the summon uses. Its effect routine must be one the player's
                 own spells use, so it works with Rydia as the caster.
- call_power     base power. Damage and heal effects scale it by
                 (monster Lv + Rydia's Lv) / 32; others use it as is.
                 Default: 10 for scaled effects, else the data spell's own.
- call_target    hex targeting byte (bits 5-7) to override the data spell's.
- call_verified  y once the animation has been checked in Mesen. Only these
                 entries go live; the rest keep the plain strike.

The exporter fills call_anim / call_data as suggestions from the AI.
"""

import ff4rom
from ff4rom import Rom

SPELLS = 0x0F97A0
SUMMONS = range(0x31, 0x40)
SCALED = {0x00, 0x01, 0x02, 0x04}   # magic damage, White/Virus, Cure, Drain
ROW = 8
SPECIES = 224


def spell(rom: Rom, sp: int) -> bytes:
    return rom.read(SPELLS + 6 * sp, 6)


def player_effects(rom: Rom) -> set[int]:
    """Effect routines used by the player's own spells ($01-$47, not summons)."""
    return {spell(rom, i)[3] & 0x7F for i in range(1, 0x48) if i not in SUMMONS}


def _hex(v: str) -> int | None:
    v = (v or "").strip()
    return int(v, 16) if v else None


def suggest(rom: Rom, spells: list[int]) -> tuple[str, str]:
    """(call_anim, call_data) suggestions from a species' AI spells."""
    if not spells:
        return "", ""
    allowed = player_effects(rom)
    abilities = [s for s in spells if s >= 0x5F] or spells
    anim = abilities[0]
    data = next((s for s in [anim] + spells if spell(rom, s)[3] & 0x7F in allowed), None)
    return f"{anim:02X}", f"{data:02X}" if data is not None else ""


def table(rom: Rom, rows: list[dict]) -> tuple[bytes, list[str]]:
    """The ROM table (8 bytes per species) and a list of live species."""
    allowed = player_effects(rom)
    out = bytearray(ROW * SPECIES)
    live = []
    for r in rows:
        if (r.get("call_verified") or "").strip().lower() != "y":
            continue
        s = int(r["id"], 16)
        data = _hex(r.get("call_data"))
        if data is None:
            raise ValueError(f"species {r['id']}: call_verified without call_data")
        d = spell(rom, data)
        eff = d[3] & 0x7F
        if eff not in allowed:
            raise ValueError(f"species {r['id']}: call_data ${data:02X} uses effect ${eff:02X}, "
                             f"which no player spell uses (allowed: {sorted(allowed)})")
        anim = _hex(r.get("call_anim"))
        anim = data if anim is None else anim
        target = _hex(r.get("call_target"))
        target = d[0] & 0xE0 if target is None else target & 0xE0
        scaled = eff in SCALED
        power = (r.get("call_power") or "").strip()
        power = int(power) if power else (10 if scaled else d[1])
        if not 0 <= power <= 255:
            raise ValueError(f"species {r['id']}: call_power {power} out of range")
        out[ROW * s:ROW * s + ROW] = bytes([1 | (2 if scaled else 0), anim, target, power,
                                             d[2], d[3], d[4], 0])
        live.append(f"{s:02X} {r['name']}")
    return bytes(out), live


NAME_LEN = 5


def names(rom: Rom, rows: list[dict]) -> bytes:
    """call_name_table: 5 encoded letters per species, padded with spaces."""
    enc = {v: k for k, v in ff4rom._TEXT.items()}
    out = bytearray([0xFF] * (NAME_LEN * SPECIES))
    seen = {}
    for r in rows:
        s = int(r["id"], 16)
        name = (r.get("call_name") or "").rstrip() or ff4rom.decode(rom.read(0x0E9800 + 8 * s, 8))[:NAME_LEN].rstrip()
        if len(name) > NAME_LEN:
            raise ValueError(f"species {r['id']}: call_name {name!r} is longer than {NAME_LEN}")
        bad = [c for c in name if c not in enc]
        if bad:
            raise ValueError(f"species {r['id']}: call_name {name!r} has characters the font lacks: {bad}")
        if r.get("capturable", "").strip().lower() == "y":
            if name in seen:
                raise ValueError(f"species {r['id']}: call_name {name!r} repeats species {seen[name]}")
            seen[name] = r["id"]
        out[NAME_LEN * s:NAME_LEN * s + len(name)] = bytes(enc[c] for c in name)
    return bytes(out)
