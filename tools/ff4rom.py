"""Read data from the clean FF2 US v1.1 ROM by SNES address.

Shared by the exporters, the disassembler and the build script.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROM_NAMES = ("ff2us-v1.1.sfc", "ff2us-v1.1.smc")  # same bytes; .smc here has no copier header


def find_rom() -> Path:
    """Return the clean ROM in rom/, whichever extension it has."""
    for name in ROM_NAMES:
        path = ROOT / "rom" / name
        if path.exists():
            return path
    return ROOT / "rom" / ROM_NAMES[0]


def to_offset(addr: int) -> int:
    """SNES LoROM bus address ($BBAAAA) to unheadered file offset."""
    bank, low = (addr >> 16) & 0x7F, addr & 0xFFFF
    if low < 0x8000:
        raise ValueError(f"${addr:06X} is not in ROM (LoROM banks map ROM at $8000-$FFFF)")
    return bank * 0x8000 + (low - 0x8000)


def to_snes(offset: int) -> int:
    """Unheadered file offset to SNES LoROM bus address."""
    return ((offset // 0x8000) << 16) | (0x8000 + offset % 0x8000)


# Menu/battle text encoding (from aexoden/edge util/memory.lua).
_TEXT = {0x3F: " ", 0x40: " ", 0x41: " ", 0xFF: " ", 0xC0: "'", 0xC1: ".", 0xC2: "-", 0xC3: ".", 0xC8: ":"}
_TEXT.update({0x42 + i: chr(ord("A") + i) for i in range(26)})
_TEXT.update({0x5C + i: chr(ord("a") + i) for i in range(26)})
_TEXT.update({0x80 + i: chr(ord("0") + i) for i in range(10)})


def decode(raw: bytes) -> str:
    """Decode fixed-width name text. Unknown bytes show as {XX}."""
    return "".join(_TEXT.get(b, "{%02X}" % b) for b in raw).rstrip()


class Rom:
    def __init__(self, path: Path | None = None):
        self.path = path or find_rom()
        self.data = self.path.read_bytes()

    def read(self, addr: int, length: int) -> bytes:
        start = to_offset(addr)
        return self.data[start:start + length]

    def u8(self, addr: int) -> int:
        return self.data[to_offset(addr)]

    def u16(self, addr: int) -> int:
        return int.from_bytes(self.read(addr, 2), "little")

    def u24(self, addr: int) -> int:
        return int.from_bytes(self.read(addr, 3), "little")
