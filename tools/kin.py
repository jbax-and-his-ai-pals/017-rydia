"""Kin (monster family) for each species: seeded from the ROM's creature type, curated for the rest.

Used by tools/export_monsters.py for the `kin` and `kin_source` columns of
data/monsters.csv. The eight kin and who bonds with them are in
notes/storyboard.md ("Recommended: kin decides who can bond").

Creature type: optional byte of the monster record (flag $08 in byte 9; see
tools/monster_ai.py). Bits: $80 undead, $40 mage, $20 slime, $10 giant,
$08 spirit, $04 reptile, $02 machine, $01 dragon. Several can be set; the first
match in ROM_KIN wins, so D.Bone (undead + dragon) is a Dragon.
"""

from ff4rom import Rom, decode

KIN = ["Dragon", "Sky", "Sea", "Beast", "Wild", "Shade", "Construct", "Arcane"]

ROM_KIN = [  # (creature-type bit, kin), in priority order
    (0x01, "Dragon"), (0x80, "Shade"), (0x08, "Shade"), (0x02, "Construct"),
    (0x10, "Construct"), (0x40, "Arcane"), (0x04, "Beast"), (0x20, "Wild"),
]

# Curated by name, for species with no creature type and for ROM types that fit
# a kin badly (aquatic reptiles, a winged gargoyle, a tree). A name applies to
# every species that has it; resolve() fails on a name that matches none.
CURATED = {
    "Sky": ["Eagle", "Cave Bat", "RocLarva", "Cocktric", "Roc Baby", "Raven", "GlomWing", "Roc",
            "GiantBat", "Were Bat", "FloatEye", "Red Eye", "FatalEye", "Gargoyle"],
    "Sea": ["Pike", "WaterBug", "Aligator", "Piranha", "ElecFish", "Crocdile", "AquaWorm", "EvilShel",
            "FangShel", "Ironback", "WaterHag", "Turtle", "Tortoise", "Carapace"],
    "Beast": ["SwordRat", "StingRat", "Python", "Panther", "Centaur", "Armadilo", "Chimera", "FlameDog",
              "BlackCat", "Mantcore", "IceBeast", "Behemoth", "Juclyote", "Procyote", "Medusa", "Gorgon",
              "Cannibal", "EpeeGirl"],
    "Wild": ["Imp", "Imp Cap.", "Dark Imp", "Larva", "TrapRose", "Treant", "SandMoth", "Sandpede",
             "SandWorm", "Needler", "HugeCell", "MoonCell", "Arachne", "Talantla", "Centpede", "Red Worm",
             "Crawler", "RockMoth", "Molbol", "Grudger", "DarkTree"],
    "Shade": ["Ghost"],
    "Construct": ["Bomb", "GrayBomb", "Grenade", "Balloon", "FlameMan", "Warrior"],
    "Arcane": ["Mage", "Puppet", "EvilDoll", "Tricker", "Kary", "Breath", "Mind"],
}
# Guesses worth a second look (humanoids, or names whose FF4 creature is unclear).
REVIEW = {"EpeeGirl", "Warrior", "Grudger", "Kary", "Tricker", "Cannibal", "Guard"}

NAMES, POINTERS = 0x0E9800, 0x0EA6A0


def creature_type(rom: Rom, s: int) -> int:
    r = 0x0E0000 | rom.u16(POINTERS + 2 * s)
    flags, a = rom.u8(r + 9), r + 10
    for bit, size in ((0x80, 3), (0x40, 3), (0x20, 1), (0x10, 1)):
        if flags & bit:
            a += size
    return rom.u8(a) if flags & 0x08 else 0


def resolve(rom: Rom) -> dict[int, tuple[str, str]]:
    """{species: (kin, source)} for every species with a kin; source is rom, curated or none."""
    names = [decode(rom.read(NAMES + 8 * s, 8)) for s in range(224)]
    by_name = {}
    for kin, members in CURATED.items():
        for n in members:
            hits = [s for s, m in enumerate(names) if m == n]
            if not hits:
                raise ValueError(f"kin.CURATED: no species named {n!r}")
            for s in hits:          # e.g. both Ravens (the regular one and the opening's)
                by_name[s] = kin
    out = {}
    for s in range(224):
        if s in by_name:
            out[s] = (by_name[s], "curated")
            continue
        t = creature_type(rom, s)
        kin = next((k for bit, k in ROM_KIN if t & bit), "")
        out[s] = (kin, "rom" if kin else "none")
    return out
