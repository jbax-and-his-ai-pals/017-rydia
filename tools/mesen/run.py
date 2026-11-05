"""Run a Lua script headless in Mesen 2 against a ROM.

Usage: python tools/mesen/run.py <script.lua> <out_dir> [--rom PATH] [--frames N]
                                 [--input FILE] [--shots 60,120] [--env K=V ...]

The ROM is copied into out_dir first, so Mesen's battery save for it never
touches the clean ROM's name. Screenshots (.raw) are converted to PNG.
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from ff4rom import find_rom  # noqa: E402

MESEN = os.environ.get(
    "MESEN", r"C:\jbax-and-his-ai-pals\015-mmc6-nes\emu-stock\Mesen.exe")


def raw_to_png(raw_path: Path) -> None:
    import struct
    import zlib
    data = raw_path.read_bytes()
    w = 256 if len(data) // 4 <= 256 * 240 else 512
    h = len(data) // 4 // w
    rgb = bytearray()
    for i in range(0, len(data), 4):
        rgb += bytes((data[i + 2], data[i + 1], data[i]))
    rows = b"".join(b"\x00" + bytes(rgb[y * w * 3:(y + 1) * w * 3]) for y in range(h))

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))
    raw_path.with_suffix(".png").write_bytes(png)
    raw_path.unlink()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("script")
    p.add_argument("out_dir")
    p.add_argument("--rom", default=None)
    p.add_argument("--frames", type=int, default=3600)
    p.add_argument("--input", default="")
    p.add_argument("--shots", default="")
    p.add_argument("--timeout", type=int, default=600)
    p.add_argument("--env", nargs="*", default=[])
    a = p.parse_args()

    out = Path(a.out_dir).resolve()
    out.mkdir(parents=True, exist_ok=True)
    rom_src = Path(a.rom) if a.rom else find_rom()
    rom = out / "game.sfc"
    shutil.copyfile(rom_src, rom)

    env = dict(os.environ, OUT_DIR=str(out), MAX_FRAMES=str(a.frames),
               INPUT=str(Path(a.input).resolve()) if a.input else "", SHOTS=a.shots,
               HARNESS_DIR=str(HERE))
    for kv in a.env:
        k, v = kv.split("=", 1)
        env[k] = v

    cmd = [MESEN, "--testRunner", "--doNotSaveSettings",
           "--debug.scriptWindow.allowIoOsAccess=true", f"--timeout={a.timeout}",
           str(Path(a.script).resolve()), str(rom)]
    result = subprocess.run(cmd, env=env)
    for raw in out.glob("*.raw"):
        raw_to_png(raw)
    log = out / "log.txt"
    print(f"exit={result.returncode}  log={log if log.exists() else 'none'}")
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
