#!/usr/bin/env python3
"""Generate the payloads for the PC-1600 program-area tests (see README.md).

BASIC files are plain text; `sde put` tokenizes them. Every line prints a
marker string  <TAG>:<line number, 5 digits>  followed by X padding, so a
memory dump shows which line sits where.

Machine-code files carry the 16-byte PC-1600 header (type 10H, 3-byte
load address = bank:address, auto-run = bank:FFFF = off). The payload is
16-byte records  <TAG>@<file offset, 5 hex digits>......  so a dump shows
exactly which file offset landed at which bank/address. They are not code;
never CALL them.

Run:  python3 make_tests.py      (writes into this directory)
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent
ML_RESERVE = 0xC5  # header + reserve at the base of every program area


def basic(name, tag, first, last, step=10, pad=80):
    lines = [f'{n} PRINT"{tag}:{n:05d} {"X" * pad}"' for n in range(first, last + 1, step)]
    (OUT / name).write_text("\n".join(lines) + "\n")
    return len(lines)


def ml(name, tag, bank, addr, size, first=0):
    """`first` = offset of this file's first byte within the whole ML image,
    so a file split in two carries exactly the records of the single file."""
    rec = lambda off: f"{tag}@{off:05X}".ljust(16, ".").encode()
    image = b"".join(rec(off) for off in range(0, first + size + 16, 16))
    body = image[first:first + size]
    load = (bank << 16) | addr
    run = (bank << 16) | 0xFFFF  # no auto-run
    header = (bytes([0xFF, 0x10, 0x00, 0x00, 0x10])
              + size.to_bytes(3, "little") + load.to_bytes(3, "little")
              + run.to_bytes(3, "little") + bytes([0x00, 0x0F]))
    (OUT / name).write_bytes(header + body)


# Test 1 -- merged S0, one big BASIC program (~68 KB: both modules hold 65339
# bytes of BASIC, so ~2.5 KB must spill into internal RAM) spanning both modules
# and internal RAM.
basic("t1_big.bas", "T1", 10, 7000)

# Test 2 -- program modules, ML area &1000 (3899 bytes, well inside one bank).
size2 = 0x1000 - ML_RESERVE
ml("t2_s1.bin", "T2S1", 0, 0x8000 + ML_RESERVE, size2)  # Slot 1 -> bank 0
ml("t2_s2.bin", "T2S2", 2, 0x8000 + ML_RESERVE, size2)  # Slot 2 -> bank 2
ml("t2_s0.bin", "T2S0", 0, 0xC000 + ML_RESERVE, size2)  # internal RAM
for area in ("S0", "S1", "S2"):
    basic(f"t2_{area.lower()}.bas", f"T2{area}", 10, 200, pad=40)

# Test 3 -- program modules, ML area &5000 (20283 bytes: rest of the leading
# bank + 4 KB of the second bank).
size3 = 0x5000 - ML_RESERVE
lo3 = 0x4000 - ML_RESERVE  # 16187 bytes up to BFFF
for slot, bank in (("s1", 0), ("s2", 2)):
    tag = f"T3{slot.upper()}"
    ml(f"t3_{slot}.bin", tag, bank, 0x8000 + ML_RESERVE, size3)             # one file across BFFF
    ml(f"t3_{slot}_lo.bin", tag, bank, 0x8000 + ML_RESERVE, lo3)            # leading bank only
    ml(f"t3_{slot}_hi.bin", tag, bank + 1, 0x8000, size3 - lo3, first=lo3)  # rest, next bank
for area in ("S1", "S2"):
    basic(f"t3_{area.lower()}.bas", f"T3{area}", 10, 200, pad=40)

# Test 4 -- merged S0, ML area &A000 (40763 bytes). Where S0 starts depends on
# the fill order test 1 finds, so the big file comes in two header variants.
size4 = 0xA000 - ML_RESERVE
ml("t4_ml_b0.bin", "T4B0", 0, 0x8000 + ML_RESERVE, size4)
ml("t4_ml_b2.bin", "T4B2", 2, 0x8000 + ML_RESERVE, size4)
basic("t4_probe.bas", "T4", 10, 200, pad=40)

print("written to", OUT)
