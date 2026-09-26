#!/usr/bin/env python3
"""Map the test markers in a Calc-U-1600 Debug panel log to banks/addresses.

Paste the output of  Dump Card YAML  (both slots) and  Dump Mem  into one
text file, then:

    python3 analyze_dump.py log.txt

For every memory segment -- Slot 1 bank 0/1, Slot 2 bank 2/3 (8000-BFFF
each) and internal RAM (C000-FFFF) -- it lists the BASIC marker lines
(<TAG>:<line>) and ML records (<TAG>@<file offset>) found there. For ML it
also prints address - offset per run, which stays constant while a file
lands linearly and changes wherever it was split or wrapped.
"""
import re
import sys
from collections import defaultdict

CARD_SIZE = 0x8000
ROW = re.compile(r"^\s*\$([0-9A-F]{4}):\s+(.*?)\s*$")
BASIC = re.compile(rb"(T[0-9A-Z]{1,3}):(\d{5})")
ML = re.compile(rb"(T[0-9A-Z]{3})@([0-9A-F]{5})")


def parse_card(rows):
    """addressed-hex rows (module offset -> bytes); 'XX...' fills to the next row."""
    img = bytearray(CARD_SIZE)
    for k, (off, text) in enumerate(rows):
        if text.endswith("..."):
            end = rows[k + 1][0] if k + 1 < len(rows) else CARD_SIZE
            img[off:end] = bytes([int(text[:2], 16)]) * (end - off)
        else:
            data = bytes.fromhex(text.replace(" ", ""))
            img[off:off + len(data)] = data
    return img


def parse_log(path):
    cards, internal = {}, None
    section, rows = None, []

    def close():
        nonlocal internal
        if section and rows:
            if section == "internal":
                img = bytearray(0x4000)
                for off, text in rows:
                    data = bytes.fromhex(text.replace(" ", ""))
                    img[off - 0xC000:off - 0xC000 + len(data)] = data
                internal = img
            else:
                cards[section] = parse_card(rows)

    for line in open(path, encoding="utf-8", errors="replace"):
        if "Module card dump:" in line:
            close()
            m = re.search(r"\(Slot (\d)\)", line)
            section, rows = (int(m.group(1)) if m else 1), []
        elif line.startswith("internal RAM"):
            close()
            section, rows = "internal", []
        elif line.startswith("──") and section == "internal":
            close()
            section, rows = None, []
        else:
            m = ROW.match(line)
            if m and section is not None:
                rows.append((int(m.group(1), 16), m.group(2)))
    close()
    return cards, internal


def segments(cards, internal):
    """(name, z80 base address, bytes)"""
    for slot in sorted(cards):
        img = cards[slot]
        for half in (0, 1):
            bank = (slot - 1) * 2 + half
            yield f"Slot {slot} bank {bank}", 0x8000, img[half * 0x4000:(half + 1) * 0x4000]
    if internal is not None:
        yield "internal RAM", 0xC000, internal


def report(name, base, data):
    basic = defaultdict(list)
    for m in BASIC.finditer(data):
        basic[m.group(1).decode()].append((int(m.group(2)), base + m.start()))
    ml = defaultdict(list)
    for m in ML.finditer(data):
        ml[m.group(1).decode()].append((int(m.group(2), 16), base + m.start()))
    print(f"== {name}  ({base:04X}-{base + len(data) - 1:04X})")
    if not basic and not ml:
        print("   no markers")
    for tag, hits in sorted(basic.items()):
        (l0, a0), (l1, a1) = hits[0], hits[-1]
        print(f"   BASIC {tag}: lines {l0}..{l1} ({len(hits)} lines), first at {a0:04X}, last at {a1:04X}")
    for tag, hits in sorted(ml.items()):
        runs, cur = [], [hits[0]]
        for h in hits[1:]:
            (o, a), (po, pa) = h, cur[-1]
            if a - o == pa - po:
                cur.append(h)
            else:
                runs.append(cur)
                cur = [h]
        runs.append(cur)
        for r in runs:
            (o0, a0), (o1, a1) = r[0], r[-1]
            print(f"   ML    {tag}: offsets {o0:05X}..{o1 + 15:05X} at {a0:04X}..{a1 + 15:04X}"
                  f"  (address - offset = {a0 - o0:+06X})")


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    cards, internal = parse_log(sys.argv[1])
    if not cards and internal is None:
        sys.exit("no card dump or internal RAM section found")
    for seg in segments(cards, internal):
        report(*seg)


if __name__ == "__main__":
    main()
