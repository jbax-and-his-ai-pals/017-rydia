"""Check that a ROM is Final Fantasy II (USA) v1.1, unheadered.

Usage: python tools/check_rom.py [path]   (default: rom/ff2us-v1.1.sfc)
Exit code 0 if it matches, 1 if not.
"""

import hashlib
import sys
import zlib
from pathlib import Path

EXPECTED_SIZE = 0x100000  # 8 Mbit
EXPECTED_CRC32 = 0x23084FCD  # v1.1 unheadered; v1.0 is 0x65D0A825
COPIER_HEADER = 0x200

# LoROM internal header, bank $00 at $FFC0 -> file offset 0x7FC0.
HEADER_TITLE = slice(0x7FC0, 0x7FD5)
HEADER_VERSION = 0x7FDB
HEADER_COMPLEMENT = slice(0x7FDC, 0x7FDE)
HEADER_CHECKSUM = slice(0x7FDE, 0x7FE0)


def check(path: Path) -> bool:
    data = path.read_bytes()
    ok = True

    print(f"File:     {path} ({len(data):,} bytes)")
    if len(data) == EXPECTED_SIZE + COPIER_HEADER:
        print("Size:     has a 512-byte copier header. Strip it first:")
        print("          python tools/check_rom.py --strip <in> <out>")
        return False
    if len(data) != EXPECTED_SIZE:
        print(f"Size:     WRONG, expected {EXPECTED_SIZE:,}")
        ok = False

    crc = zlib.crc32(data) & 0xFFFFFFFF
    crc_ok = crc == EXPECTED_CRC32
    print(f"CRC32:    {crc:08X}  {'ok' if crc_ok else 'differs from expected %08X' % EXPECTED_CRC32}")
    print(f"SHA-1:    {hashlib.sha1(data).hexdigest()}")
    print(f"MD5:      {hashlib.md5(data).hexdigest()}")

    header_ok = False
    if len(data) >= 0x8000:
        title = data[HEADER_TITLE].decode("ascii", "replace").rstrip()
        version = data[HEADER_VERSION]
        complement = int.from_bytes(data[HEADER_COMPLEMENT], "little")
        stored = int.from_bytes(data[HEADER_CHECKSUM], "little")
        computed = sum(data) & 0xFFFF
        sums_ok = stored == computed and (stored ^ complement) == 0xFFFF
        print(f"Title:    {title!r}")
        print(f"Version:  {version}  {'ok (v1.1)' if version == 1 else 'WRONG, expected 1'}")
        print(f"Checksum: stored {stored:04X}, computed {computed:04X}  {'ok' if sums_ok else 'MISMATCH'}")
        header_ok = "FINAL FANTASY" in title.upper() and version == 1 and sums_ok

    if ok and crc_ok and header_ok:
        print("RESULT:   matches FF2 US v1.1 unheadered")
        return True
    if ok and header_ok:
        # The expected CRC is unverified; a clean v1.1 header outranks it.
        print("RESULT:   header says clean v1.1, but the CRC differs from the unverified expected value.")
        print("          Record this CRC in notes/addresses.md and update EXPECTED_CRC32.")
        return False
    print("RESULT:   does NOT match")
    return False


def strip(src: Path, dst: Path) -> None:
    data = src.read_bytes()
    if len(data) != EXPECTED_SIZE + COPIER_HEADER:
        sys.exit(f"{src} is {len(data):,} bytes; expected {EXPECTED_SIZE + COPIER_HEADER:,} for a headered ROM")
    dst.write_bytes(data[COPIER_HEADER:])
    print(f"Wrote {dst} without the copier header")


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["--strip"] and len(args) == 3:
        strip(Path(args[1]), Path(args[2]))
        sys.exit(0)
    if args:
        target = Path(args[0])
    else:
        from ff4rom import find_rom
        target = find_rom()
    if not target.exists():
        sys.exit(f"Not found: {target}")
    sys.exit(0 if check(target) else 1)
