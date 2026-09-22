# PC-1600 — BASIC ROM Versions and How to Identify Them

**Source for this document:** *SHARP SOFTWARE-INFO* bulletin **No. 1600-010E**, "Tips,
Tricks, and Supplementations to the Manual PC-1600", D. Korhon, 22 July 1987, Sharp
Electronics (Europe) GmbH — Software Center, Hamburg; page 3/9, section **BASIC ROM
VERSION**. (Local scan: `~/SynologyDrive/Dokumente/PDF/Vintage/Sharp/PC-1600/Sharp-Soft-Info.pdf`,
PDF page 7.) Revision-linked hardware remark from bulletin **No. 1600-011** (page 4 of the
same scan). Cross-checked against the real-hardware ROM dumps in
`~/Development/sharp/pc1600/tools/rom-dumper/` and against PockEmul's PC-1600 ROM set.

This is the only source in the corpus that documents PC-1600 firmware revisions at all.
It resolves the standing "on some ROM versions…" caveat in
[`PC-1600-ROM-Jump-Table.md`](PC-1600-ROM-Jump-Table.md) into a concrete, testable
distinction.

---

## 1. There are two revisions, not three

The bulletin's heading is easy to misread. Sharp's table has three columns labelled
"ROM 1", "ROM 2", "ROM 3", but those are the **three internal ROM chips**, not three
firmware versions. The rows are the versions, and there are exactly two:

> *"The PC-1600 was supplied with a new, subsequently improved BASIC-ROM."*

| Version | ROM 1 — `PEEK #(0,&7FFF)` | ROM 2 — `PEEK #(6,&BFFF)` | ROM 3 — `PEEK #(3,&7FFF)` |
|---|---|---|---|
| **NEW** | **4** or **5** | **163** (`A3H`) | **195** (`C3H`) |
| **OLD** | **130** (`82H`) | **161** (`A1H`) | **193** (`C1H`) |

(Table transcribed verbatim from the bulletin; hex equivalents added here. The bulletin
prints the ROM 2 probe as `PEEK #(6&BFFF)` — a typo for `PEEK #(6,&BFFF)`, matching the
comma-separated form used in the other two columns and in the single-command version it
gives in the body text.)

The bulletin's short form, for users who only want a yes/no answer:

```basic
PRINT PEEK # (0,&7FFF)
```

> *"The value indicates whether it is the old version (130) or the new version (4) or (5)."*

**The `4`-or-`5` split is Sharp's own wording and is not explained.** The most economical
reading is that the "new" ROM itself came in two sub-revisions distinguished only by that
byte, both counted as NEW for the purposes of the bulletin's errata — but the source does
not say so, and nothing else in the corpus speaks to it. Treat it as an open question
(§5). Note that ROM 2 and ROM 3 have a *single* NEW value each, so if there really are two
new sub-revisions, they differ in the ROM 1 chip only.

The `PEEK #(bank,address)` form is the banked peek — the first argument is the Port 31H
bank number for the page containing the address, exactly as in
[`PC-1600-Memory-Bank-Switching.md`](PC-1600-Memory-Bank-Switching.md) Part 2.

## 2. Which physical chip each probe reads

Each of the three probes reads the **last byte of one of the three internal 32 KB ROM
chips**, via the Z-80 window where that chip's top is visible. Resolved against the chip
selects in `PC-1600-Memory-Bank-Switching.md` Parts 4/12 and the bank map in
[`PC-1600-Memory-Architecture.md`](PC-1600-Memory-Architecture.md) §2:

| Bulletin name | Probe | Z-80 page / bank | Chip select | Physical chip | What the byte is |
|---|---|---|---|---|---|
| **ROM 1** | `PEEK #(0,&7FFF)` | page 1 (4000–7FFF), bank 0 | **CS001** | main system ROM, 32 KB | last byte of the chip |
| **ROM 2** | `PEEK #(6,&BFFF)` | page 2 (8000–BFFF), bank 6 | **CS123** | 32 KB; only this 16 KB half is Z-80-visible, the other half is the LH-5803's private ROM | last byte of the Z-80-visible half |
| **ROM 3** | `PEEK #(3,&7FFF)` | page 1 (4000–7FFF), bank 3 | **CS24** | Memory-PWB ROM (IC5), 32 KB, sub-banked | last byte of the bank-3 aperture |

So the three probes together fingerprint **all 96 KB of internal ROM silicon** — Sharp's
own parts inventory's *"32KB ROM × 3"* (CS001 + CS123 + CS24). That is why there are three
columns: a unit could in principle have been reworked chip-by-chip, and the bulletin lets
a dealer check each one.

> **Naming collision — do not conflate.** Sharp's Service Manual *also* uses the names
> ROM1/ROM2/ROM3, for the Memory-PWB parts **IC3/IC4/IC5**, where ROM1 and ROM2 both sit
> behind **CS001** and ROM3 is **CS24** (`PC-1600-Memory-Bank-Switching.md` Part 12,
> "ROM Wiring"). That numbering is *not* the bulletin's. In the bulletin, "ROM 2" is the
> CS123 chip, which is not on that PWB list at all. Always disambiguate by the chip select
> or by the probe address, never by the number alone.

The bulletin's ROM 3 probe reads **bank 3 proper**, not the hidden bank 3b reachable via
Port 3DH bit b2 (`PC-1600-Memory-Bank-Switching.md` Part 1). Bank 3b's last byte is `00`
in the confirmed hardware dump, so it carries no version stamp and cannot be substituted.

## 3. Confirmed on real hardware, and on the only available ROM set

The last byte of each dump in `~/Development/sharp/pc1600/tools/rom-dumper/` (captured
from real hardware):

| Dump file | Bulletin column | Last byte | Verdict |
|---|---|---|---|
| `PC1600-P1-B0.BIN` | ROM 1 | `05` = **5** | **NEW** |
| `PC1600-P2-B6.BIN` | ROM 2 | `A3` = **163** | **NEW** |
| `PC1600-P1-B3.BIN` | ROM 3 | `C3` = **195** | **NEW** |

All three match the NEW row exactly, and the ROM 1 byte settles this unit's side of the
`4`-or-`5` ambiguity at **5**.

PockEmul's PC-1600 ROM images give the same three values, and are **byte-for-byte
identical** (MD5) to the hardware dumps:

| PockEmul image | Hardware dump | MD5 |
|---|---|---|
| `romII-0.bin` | `PC1600-P1-B0.BIN` | `bddbb8bbf0b2bd2d95038f67b8d002ac` |
| `romIV-6.bin` | `PC1600-P2-B6.BIN` | `86cb9036da284de2b04c7946d140a9fd` |
| `romIII-3.bin` | `PC1600-P1-B3.BIN` | `6f6e1a9d46db7dc91d4322c93583ac81` |

**Consequence for this corpus: every PC-1600 fact derived from a ROM image or from real
hardware here describes the NEW revision.** The OLD ROM (130 / 161 / 193) is not dumped,
not present in PockEmul, and — as far as this corpus can see — undocumented beyond this
one bulletin. Nothing written here has been checked against it.

**The stamp looks deliberate, not incidental.** In all three chips the identifying byte
sits in the padding *after* the last real instruction, not inside code:

```
ROM 1 (…7FF0–7FFF):  … cd 0c 01 d8 cb d6 3e 13 18 e3 | 68 05
ROM 2 (…BFF0–BFFF):  00 00 00 00 00 00 00 00 00 00 … | a3     ← lone byte in a long 00 run
ROM 3 (…7FF0–7FFF):  … 3e 02 32 7d f0 d3 3d c9 3e 05 18 f6 | 00 00 c3
```

That the bytes are `C1`/`C3` and `A1`/`A3` across the two revisions — differing by 2 in
the same low bits — reinforces that these are version identifiers Sharp incremented, not
opcodes that happened to land last. (The byte preceding ROM 1's stamp is `68`; whether
`68 05` is a two-byte marker cannot be decided without an OLD dump.)

## 4. What actually differs between OLD and NEW

The bulletin says only *"subsequently improved"* and does not enumerate the changes. Two
things elsewhere in the corpus and in the same bulletin family are plausibly revision-linked:

- **The jump table's tail — the four extra entries are present in the NEW ROM, and are
  now enumerated.** `PC-1600-ROM-Jump-Table.md` carried its source's unresolved note that
  *"on some ROM versions, 4 more jumps follow [after `0312H`], used only by the reset
  routine."* "Some ROM versions" is almost certainly this OLD/NEW split. Inspecting
  `PC1600-P0-B0.BIN` — a NEW dump — at `0315H` shows exactly four further entries of the
  same `RST 18` (`BANKJP`) shape as the rest of the table, after which real code resumes
  at `0321H`:

  ```
  0312: df 79 1c   BANKJP 1C79H   ← BASPARES, the last entry the source documents
  0315: df e1 40   BANKJP 40E1H   ┐
  0318: df e4 40   BANKJP 40E4H   │ the four "extra" reset-only entries
  031B: df e7 40   BANKJP 40E7H   │
  031E: df ea 40   BANKJP 40EAH   ┘
  0321: 2c         (code resumes — table ends here)
  ```

  Per the `BANKJP` address-implies-bank rule (`PC-1600-Memory-Bank-Switching.md` Part 6),
  a `4000–7FFF` operand selects **bank 3**, and bank 3 does hold a matching secondary jump
  table at exactly those addresses (`PC1600-P1-B3.BIN`):

  ```
  40E1: c3 af 6b   JP 6BAFH
  40E4: c3 d0 6b   JP 6BD0H
  40E7: c3 f0 6b   JP 6BF0H
  40EA: c3 0b 6c   JP 6C0BH
  ```

  So the entries are real, well-formed, and land in bank-3 code. **What they do is still
  unknown** — the source says only "used only by the reset routine", and `6BAFH`/`6BD0H`/
  `6BF0H`/`6C0BH` in bank 3 have not been disassembled. **Which revision has them is an
  inference:** the NEW ROM demonstrably does, so the natural reading of "some ROM versions"
  is that the OLD ROM lacks them — but with no OLD dump, the opposite direction (NEW
  dropping four entries that the source's own reference ROM had) cannot be excluded.
- **The `TAB` / serial-printing bug.** Bulletin No. 1600-011 (same scan, page 4) reports
  that *"PC-1600 units with serial end-number 8"* execute `TAB` correctly over the
  CE-1600P but incorrectly over the V24/RS-232C port, with `PZONE "COM1:",0` as the
  workaround (accepted despite the manual's documented minimum of 8). Sharp keys this to
  the **serial number**, not to a ROM probe, so it is not established that it is the same
  OLD/NEW boundary — it may be a narrower production-batch issue. Recorded here because
  it is the only other revision-linked behaviour difference in the bulletin set.

Everything else in bulletin 1600-010E is documented as applying to the PC-1600 generally,
with no version qualifier.

## 5. Open items

- **What `4` versus `5` at `(0,&7FFF)` distinguishes.** Sharp gives both as NEW without
  comment. Two new sub-revisions of the CS001 chip is the natural reading but is not
  stated. Only a second NEW-ROM unit reading `4` would settle it.
- **No OLD ROM has been dumped**, so the actual code differences are unverified and the
  "improvements" the bulletin alludes to are unidentified.
- **What the four extra reset-only jump entries past `0312H` actually do** — they are
  enumerated in §4 and resolve into bank 3 at `6BAFH`/`6BD0H`/`6BF0H`/`6C0BH`, but that
  code is undisassembled; and it is inferred rather than shown that their presence is the
  OLD/NEW difference (§4).
- **Whether the serial-end-number-8 `TAB` bug tracks the OLD/NEW ROM split** or is an
  independent batch issue (§4).
- **Where in the hardware the version is recorded besides these three bytes** — no
  service-manual part number, label, or date code has been tied to the split.

## 6. Related

- [`PC-1600-ROM-Jump-Table.md`](PC-1600-ROM-Jump-Table.md) — the "some ROM versions" caveat this document explains.
- [`PC-1600-Memory-Bank-Switching.md`](PC-1600-Memory-Bank-Switching.md) — Part 2 (`PEEK #` banks / Port 31H), Part 4 (CS001/CS123/CS24), Part 12 (Memory-PWB ROM1/2/3 = IC3/IC4/IC5 — the *other* numbering).
- [`PC-1600-Memory-Architecture.md`](PC-1600-Memory-Architecture.md) — §2, the bank map that locates each probe address.
- [`PC-1600-ROM-Disassembly.md`](PC-1600-ROM-Disassembly.md) — the byte-level ROM project; its dumps are the NEW revision.
