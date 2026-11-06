"""Unit tests for tools/abilities.py and tools/monster_ai.py against the clean ROM."""

import unittest

import abilities
import monster_ai
from ff4rom import Rom


def row(s, **kw):
    r = {"id": f"{s:02X}", "name": "x", "call_anim": "", "call_data": "", "call_power": "",
         "call_target": "", "call_verified": ""}
    r.update(kw)
    return r


class AbilityTable(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rom = Rom()

    def test_unverified_rows_stay_plain_strike(self):
        data, live = abilities.table(self.rom, [row(2, call_anim="6B", call_data="6B")])
        self.assertEqual(live, [])
        self.assertEqual(data[16:24], bytes(8))

    def test_verified_row_copies_data_spell(self):
        data, live = abilities.table(self.rom, [row(0), row(1, call_anim="A0", call_data="1F", call_verified="y")])
        fire3 = abilities.spell(self.rom, 0x1F)
        self.assertEqual(live, ["01 x"])
        # live + scaled, animation, targeting, base 10, hit, effect, element set
        self.assertEqual(data[8:16], bytes([3, 0xA0, fire3[0] & 0xE0, 10, fire3[2], fire3[3], fire3[4], 0]))

    def test_monster_only_routine_is_rejected(self):
        with self.assertRaises(ValueError):   # Explode ($A0) uses effect $25
            abilities.table(self.rom, [row(0, call_data="A0", call_verified="y")])

    def test_ai_decoder_known_monsters(self):
        self.assertEqual(monster_ai.species_spells(self.rom, 0x01)[0], [0x6C])   # Basilisk: Petrify
        self.assertEqual(monster_ai.species_spells(self.rom, 0x55)[0], [0xA0])   # Bomb: Explode
        self.assertEqual(monster_ai.species_spells(self.rom, 0x00), ([], []))    # Imp: fights only


if __name__ == "__main__":
    unittest.main()
