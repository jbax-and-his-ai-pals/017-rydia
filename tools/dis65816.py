"""Minimal 65816 disassembler for reading FF4 routines.

Usage: python tools/dis65816.py <$BB:AAAA or BBAAAA> [count] [--m8|--m16] [--x8|--x16]

Defaults to 8-bit A and 16-bit X/Y, FF4's usual mode. REP/SEP are tracked
linearly, so after a branch merge the widths may be wrong; check by eye.
Stops after `count` instructions (default 40) or at RTS/RTL/RTI/JMP/BRA.
"""

import sys

from ff4rom import Rom

# 16 rows of 16 "MNEMONIC:mode" entries, opcode $00-$FF.
_TABLE = """
BRK:i8 ORA:dpxi COP:i8 ORA:sr TSB:dp ORA:dp ASL:dp ORA:dpil PHP:- ORA:iM ASL:A PHD:- TSB:ab ORA:ab ASL:ab ORA:al
BPL:r8 ORA:dpiy ORA:dpi ORA:sriy TRB:dp ORA:dpx ASL:dpx ORA:dpily CLC:- ORA:aby INC:A TCS:- TRB:ab ORA:abx ASL:abx ORA:alx
JSR:ab AND:dpxi JSL:al AND:sr BIT:dp AND:dp ROL:dp AND:dpil PLP:- AND:iM ROL:A PLD:- BIT:ab AND:ab ROL:ab AND:al
BMI:r8 AND:dpiy AND:dpi AND:sriy BIT:dpx AND:dpx ROL:dpx AND:dpily SEC:- AND:aby DEC:A TSC:- BIT:abx AND:abx ROL:abx AND:alx
RTI:- EOR:dpxi WDM:i8 EOR:sr MVP:mv EOR:dp LSR:dp EOR:dpil PHA:- EOR:iM LSR:A PHK:- JMP:ab EOR:ab LSR:ab EOR:al
BVC:r8 EOR:dpiy EOR:dpi EOR:sriy MVN:mv EOR:dpx LSR:dpx EOR:dpily CLI:- EOR:aby PHY:- TCD:- JML:al EOR:abx LSR:abx EOR:alx
RTS:- ADC:dpxi PER:r16 ADC:sr STZ:dp ADC:dp ROR:dp ADC:dpil PLA:- ADC:iM ROR:A RTL:- JMP:abi ADC:ab ROR:ab ADC:al
BVS:r8 ADC:dpiy ADC:dpi ADC:sriy STZ:dpx ADC:dpx ROR:dpx ADC:dpily SEI:- ADC:aby PLY:- TDC:- JMP:abxi ADC:abx ROR:abx ADC:alx
BRA:r8 STA:dpxi BRL:r16 STA:sr STY:dp STA:dp STX:dp STA:dpil DEY:- BIT:iM TXA:- PHB:- STY:ab STA:ab STX:ab STA:al
BCC:r8 STA:dpiy STA:dpi STA:sriy STY:dpx STA:dpx STX:dpy STA:dpily TYA:- STA:aby TXS:- TXY:- STZ:ab STA:abx STZ:abx STA:alx
LDY:iX LDA:dpxi LDX:iX LDA:sr LDY:dp LDA:dp LDX:dp LDA:dpil TAY:- LDA:iM TAX:- PLB:- LDY:ab LDA:ab LDX:ab LDA:al
BCS:r8 LDA:dpiy LDA:dpi LDA:sriy LDY:dpx LDA:dpx LDX:dpy LDA:dpily CLV:- LDA:aby TSX:- TYX:- LDY:abx LDA:abx LDX:aby LDA:alx
CPY:iX CMP:dpxi REP:i8 CMP:sr CPY:dp CMP:dp DEC:dp CMP:dpil INY:- CMP:iM DEX:- WAI:- CPY:ab CMP:ab DEC:ab CMP:al
BNE:r8 CMP:dpiy CMP:dpi CMP:sriy PEI:dpi CMP:dpx DEC:dpx CMP:dpily CLD:- CMP:aby PHX:- STP:- JML:abil CMP:abx DEC:abx CMP:alx
CPX:iX SBC:dpxi SEP:i8 SBC:sr CPX:dp SBC:dp INC:dp SBC:dpil INX:- SBC:iM NOP:- XBA:- CPX:ab SBC:ab INC:ab SBC:al
BEQ:r8 SBC:dpiy SBC:dpi SBC:sriy PEA:ab SBC:dpx INC:dpx SBC:dpily SED:- SBC:aby PLX:- XCE:- JSR:abxi SBC:abx INC:abx SBC:alx
"""
OPS = [tuple(e.split(":")) for e in _TABLE.split()]
assert len(OPS) == 256

_FMT = {
    "-": (0, "{m}"), "A": (0, "{m} A"),
    "i8": (1, "{m} #${v:02X}"),
    "dp": (1, "{m} ${v:02X}"), "dpx": (1, "{m} ${v:02X},X"), "dpy": (1, "{m} ${v:02X},Y"),
    "dpi": (1, "{m} (${v:02X})"), "dpxi": (1, "{m} (${v:02X},X)"), "dpiy": (1, "{m} (${v:02X}),Y"),
    "dpil": (1, "{m} [${v:02X}]"), "dpily": (1, "{m} [${v:02X}],Y"),
    "sr": (1, "{m} ${v:02X},S"), "sriy": (1, "{m} (${v:02X},S),Y"),
    "ab": (2, "{m} ${v:04X}"), "abx": (2, "{m} ${v:04X},X"), "aby": (2, "{m} ${v:04X},Y"),
    "abi": (2, "{m} (${v:04X})"), "abxi": (2, "{m} (${v:04X},X)"), "abil": (2, "{m} [${v:04X}]"),
    "al": (3, "{m} ${v:06X}"), "alx": (3, "{m} ${v:06X},X"),
    "mv": (2, "{m} ${s:02X},${d:02X}"),
}
_STOP = {"RTS", "RTL", "RTI", "JMP", "JML", "BRA", "BRL", "STP"}


def disassemble(rom: Rom, addr: int, count: int = 40, m8: bool = True, x8: bool = False, stop: bool = True):
    """Yield (address, raw bytes, text) for each instruction."""
    for _ in range(count):
        op = rom.u8(addr)
        mn, mode = OPS[op]
        if mode == "iM":
            size, fmt = (1, "{m} #${v:02X}") if m8 else (2, "{m} #${v:04X}")
        elif mode == "iX":
            size, fmt = (1, "{m} #${v:02X}") if x8 else (2, "{m} #${v:04X}")
        elif mode in ("r8", "r16"):
            size = 1 if mode == "r8" else 2
            fmt = None
        else:
            size, fmt = _FMT[mode]
        raw = rom.read(addr, 1 + size)
        v = int.from_bytes(raw[1:], "little")
        if fmt is None:
            disp = v - (0x100 if size == 1 and v >= 0x80 else 0x10000 if size == 2 and v >= 0x8000 else 0)
            target = (addr & 0xFF0000) | ((addr + 1 + size + disp) & 0xFFFF)
            text = f"{mn} ${target & 0xFFFF:04X}"
        elif mode == "mv":
            text = fmt.format(m=mn, s=raw[2], d=raw[1])
        else:
            text = fmt.format(m=mn, v=v)
        yield addr, raw, text
        if mn == "REP":
            m8 = m8 and not (v & 0x20)
            x8 = x8 and not (v & 0x10)
        elif mn == "SEP":
            m8 = m8 or bool(v & 0x20)
            x8 = x8 or bool(v & 0x10)
        addr = (addr & 0xFF0000) | ((addr + 1 + size) & 0xFFFF)
        if stop and mn in _STOP:
            break


def parse_addr(text: str) -> int:
    return int(text.replace("$", "").replace(":", ""), 16)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    if not args:
        sys.exit(__doc__)
    start = parse_addr(args[0])
    n = int(args[1]) if len(args) > 1 else 40
    rom = Rom()
    for a, raw, text in disassemble(rom, start, n, m8="--m16" not in flags, x8="--x8" in flags):
        print(f"${a >> 16:02X}:{a & 0xFFFF:04X}  {raw.hex(' '):<12} {text}")
