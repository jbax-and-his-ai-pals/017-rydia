"""Contracts for the expanded ROM image and build diff reporting."""

import sys
import unittest
from pathlib import Path


TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import build


def valid_clean() -> bytearray:
    data = bytearray(build.SOURCE_SIZE)
    data[build.LOROM_MAP_MODE] = 0x20
    data[build.LOROM_CARTRIDGE_TYPE] = 0x02
    data[build.LOROM_SRAM_SIZE] = 0x03
    data[build.LOROM_SIZE_HEADER] = 0x0A
    return data


def valid_rom() -> bytearray:
    data = bytearray(build.OUTPUT_SIZE)
    data[build.LOROM_MAP_MODE] = 0x20
    data[build.LOROM_CARTRIDGE_TYPE] = 0x02
    data[build.LOROM_SRAM_SIZE] = 0x03
    data[build.LOROM_SIZE_HEADER] = 0x0B
    rest = sum(data[:build.LOROM_COMPLEMENT]) + sum(data[build.LOROM_CHECKSUM + 2:])
    checksum = (rest + 510) & 0xFFFF
    data[build.LOROM_COMPLEMENT:build.LOROM_CHECKSUM] = (checksum ^ 0xFFFF).to_bytes(2, "little")
    data[build.LOROM_CHECKSUM:build.LOROM_CHECKSUM + 2] = checksum.to_bytes(2, "little")
    return data


class ExpandedRomValidationTests(unittest.TestCase):
    def test_accepts_valid_two_megabyte_header_and_checksum(self):
        self.assertEqual(build.OUTPUT_SIZE_CODE, 0x0B)
        build.validate_expanded_rom(valid_rom(), valid_clean())

    def test_rejects_wrong_output_size(self):
        with self.assertRaisesRegex(ValueError, "expected 2,097,152"):
            build.validate_expanded_rom(valid_rom()[:-1], valid_clean())

    def test_rejects_wrong_rom_size_header(self):
        clean = valid_clean()
        data = valid_rom()
        data[build.LOROM_SIZE_HEADER] = 0x0A
        with self.assertRaisesRegex(ValueError, "ROM size header"):
            build.validate_expanded_rom(data, clean)

    def test_rejects_changed_mapping_or_sram_metadata(self):
        clean = valid_clean()
        data = valid_rom()
        data[build.LOROM_MAP_MODE] = 0x21
        with self.assertRaisesRegex(ValueError, "map mode changed"):
            build.validate_expanded_rom(data, clean)

        data = valid_rom()
        data[build.LOROM_SRAM_SIZE] = 0x04
        with self.assertRaisesRegex(ValueError, "SRAM size metadata changed"):
            build.validate_expanded_rom(data, clean)

    def test_rejects_wrong_checksum_complement(self):
        clean = valid_clean()
        data = valid_rom()
        data[build.LOROM_COMPLEMENT] ^= 1
        with self.assertRaisesRegex(ValueError, "complement"):
            build.validate_expanded_rom(data, clean)

    def test_rejects_checksum_that_does_not_sum_to_image(self):
        clean = valid_clean()
        data = valid_rom()
        checksum = (int.from_bytes(data[build.LOROM_CHECKSUM:build.LOROM_CHECKSUM + 2], "little") + 1) & 0xFFFF
        data[build.LOROM_CHECKSUM:build.LOROM_CHECKSUM + 2] = checksum.to_bytes(2, "little")
        data[build.LOROM_COMPLEMENT:build.LOROM_CHECKSUM] = (checksum ^ 0xFFFF).to_bytes(2, "little")
        with self.assertRaisesRegex(ValueError, "computed"):
            build.validate_expanded_rom(data, clean)

    def test_diff_counts_appended_bytes(self):
        self.assertEqual(build.expanded_diff_count(b"abc\xFF\xFF", b"abc"), 2)
        self.assertEqual(build.expanded_diff_count(b"abc", b"ax"), 2)


if __name__ == "__main__":
    unittest.main()
