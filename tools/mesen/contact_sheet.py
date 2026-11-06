"""Tile Mesen screenshots into one PNG, to review many summon animations at once.

Usage: python tools/mesen/contact_sheet.py OUT.png COLS IMG.png [IMG.png ...]

Reads the plain PNGs tools/mesen/run.py writes (8-bit RGB, filter 0), halves
them, and tiles them left to right, top to bottom. Pure standard library.
"""

import struct
import sys
import zlib
from pathlib import Path


def read_png(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    pos, idat, w, h = 8, b"", 0, 0
    while pos < len(data):
        n, tag = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if tag == b"IHDR":
            w, h = struct.unpack(">II", body[:8])
        elif tag == b"IDAT":
            idat += body
        pos += 12 + n
    raw = zlib.decompress(idat)
    stride = 3 * w
    rows = []
    for y in range(h):
        line = raw[y * (stride + 1):(y + 1) * (stride + 1)]
        if line[0] != 0:
            raise ValueError(f"{path}: only filter 0 is supported")
        rows.append(line[1:])
    return w, h, b"".join(rows)


def write_png(path: Path, w: int, h: int, rgb: bytes) -> None:
    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
    rows = b"".join(b"\x00" + rgb[y * 3 * w:(y + 1) * 3 * w] for y in range(h))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


def main() -> None:
    out, cols, paths = Path(sys.argv[1]), int(sys.argv[2]), [Path(p) for p in sys.argv[3:]]
    tiles = []
    for p in paths:
        w, h, rgb = read_png(p)
        hw, hh = w // 2, h // 2
        half = bytearray()
        for y in range(hh):
            for x in range(hw):
                o = 3 * ((2 * y) * w + 2 * x)
                half += rgb[o:o + 3]
        tiles.append((hw, hh, bytes(half)))
    tw, th = tiles[0][0], tiles[0][1]
    rows = (len(tiles) + cols - 1) // cols
    W, Hh = cols * (tw + 2), rows * (th + 2)
    sheet = bytearray(b"\x40" * (3 * W * Hh))
    for i, (w, h, rgb) in enumerate(tiles):
        ox, oy = (i % cols) * (tw + 2), (i // cols) * (th + 2)
        for y in range(h):
            d = 3 * ((oy + y) * W + ox)
            sheet[d:d + 3 * w] = rgb[3 * w * y:3 * w * (y + 1)]
    write_png(out, W, Hh, bytes(sheet))
    print(f"{out} ({len(tiles)} tiles, {cols} per row)")


if __name__ == "__main__":
    main()
