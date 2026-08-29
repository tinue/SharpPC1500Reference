# PC-1600 Assembly Programming Guide (SC-7852 / Z-80)

## Scope

The practical guide to writing machine-language programs for the PC-1600's Z-80 side —
the counterpart to `../Assembly-Programming/LH5801_Guide.md` for the PC-1500. The pure
instruction-set reference is in `PC-1600-CPU-SC7852-Z80.md`; this document is
conventions, the BASIC-interpreter interface, ROM entry points, and idioms.

**Sources so far:** PC-1600 Technical Reference Manual **Chapter 4** ("BASIC
Interpreter") §4.1.3–§4.1.4, §4.2.1–§4.2.2 (number/string representation, function
subroutines, conversion routines), read from the German Systemhandbuch scan; plus the
IOCS material already documented (`PC-1600-IOCS.md` and the subsystem docs). Still
outline-only: toolchain, `NEW` allocation mechanics, worked examples.

The BASIC intermediate-code (token) tables of §4.2.5 are **out of scope here** — they
will be covered for the PC-1500 and PC-1600 together in the shared token-code guide (see
`../README.md`).

---

## 1. Internal data representation (TRM §4.1.3)

The PC-1600 BASIC interpreter's working values are the **X, Y, Z arithmetic registers**,
memory-mapped 8 bytes each in the arithmetic-operations area (`PC-1600-Work-Area-Map.md`
§1.1):

| Register | Address |
|---|---|
| **X** | FA00H–FA07H |
| **Y** | FA10H–FA17H |
| **Z** | FA20H–FA27H (by extension) |

Every value — number or string — is one 8-byte cell in one of three encodings,
discriminated by **byte 4**:

### 1.1 BCD floating point (byte 4 ∈ digits, not B2H/D0H)

Range ±9.999999999 × 10⁹⁹. Bytes, low address → high:

| Byte | Content |
|---|---|
| 0 | **exponent** — signed binary (negative = two's complement) |
| 1 | **mantissa sign** — `00H` = +, `80H` = − |
| 2–6 | **mantissa** — 5 bytes packed BCD = 10 digits, implied decimal point after the first digit |
| 7 | `00H` |

Examples (`123` = 1.23 × 10² in X; `−0.0123` = −1.23 × 10⁻² in Y):

```
FA00: 02 00 12 30 00 00 00 00      ; +1.23 x 10^2
FA10: FE 80 12 30 00 00 00 00      ; -1.23 x 10^-2   (exponent FE = -2)
```

This is **the same BCD float as the PC-1500** — see `../Data-Formats/Binary-Exchange-Formats.md`
§6.3 (which was sourced from PC-1500 hardware); the earlier "confirm whether it matches"
question is now settled: it matches.

### 1.2 Binary integer (byte 4 = `B2H`)

Range −32768…32767. Only 3 bytes carry data:

| Byte | Content |
|---|---|
| 0–3 | don't care |
| 4 | **`B2H`** (marker) |
| 5 | integer **high** byte |
| 6 | integer **low** byte |
| 7 | don't care |

Examples: `123` (`007BH`) → `.. .. .. .. B2 00 7B ..`; `−123` (`FF85H`) →
`.. .. .. .. B2 FF 85 ..`. (Note bytes 5–6 are **big-endian** here, unlike the Z-80's
usual little-endian.) The PC-1500 has the identical `B2H` integer form
(`Binary-Exchange-Formats.md` §6.3).

### 1.3 String descriptor (byte 4 = `D0H`)

A string value is a *descriptor* pointing at the actual characters (which live in the
string buffer FB10H–FB5FH, or elsewhere):

| Byte | Content |
|---|---|
| 0–3 | don't care |
| 4 | **`D0H`** (marker) |
| 5 | `ADDH` — start-address high byte, **with its MSB inverted** (LH-5803-view address; e.g. `FB10H` → `7B`) |
| 6 | `ADDL` — start-address low byte (`FB10H` → `10`) |
| 7 | `LENGTH` — character count, `01H`–`50H` (1–80) |

Example — `"PC-1600"` in the string buffer, descriptor into X:

```
FA00: .. .. .. .. D0 7B 10 07
FB10: 50 43 2D 31 36 30 30              ; "PC-1600"
```

The MSB-inverted high byte is the same convention Block C uses throughout
(`PC-1600-Work-Area-Map.md` §1.1) — invert bit 15 to convert between the SC-7852 view
(`Fxxx`) and the stored form (`7xxx`).

## 2. Calling BASIC's math functions from ML (TRM §4.1.4)

### 2.1 Single-argument numeric function

1. Put the argument (BCD, §1.1) in the **X register** (FA00H).
2. Put the function's **intermediate code** in `DE` (from the token guide).
3. Store `01H` at **F88CH** (the "argument count" work byte).
4. `CALL 0202H` (the Z-80 call gateway).

Return: `CF = 0` → result in X; `CF = 1` → error, code in `A` (same codes as BASIC).
Clobbers `HL, BC, DE, AF, AF'`.

Available single-argument functions (all `f(X) → X`): `SQR`, `LN`, `LOG`, `EXP`, `SIN`,
`COS`, `TAN`, `ASN`, `ACS`, `ATN`, `DEG`, `DMS`, `ABS`, `SGN`, `INT`, `NOT`, `RND`,
`XPEEK(n)`, `PEEK`, `STATUS`, `POINT`.

### 2.2 Two-argument numeric function

Arguments in X and Y (BCD); the left operand goes in X. Otherwise as §2.1.

### 2.3 String functions

The string descriptor (§1.3) is passed in X; single-argument string functions that take
a numeric argument take it as BCD in X and build the result string in the string buffer,
writing the descriptor back to X (details: TRM §4.1.4(2), §4.2 p156–157 — not yet fully
transcribed).

## 3. Number / string conversion routines (TRM §4.2.1–§4.2.2)

| Name | Entry | Function | In | Out | Clobbers |
|---|---|---|---|---|---|
| **BI2BCD** | `024AH` | 2-byte binary → BCD | `DE` = binary value | `X` = BCD | all |
| **BCDASC** | `0244H` | BCD → ASCII string | (X) | ASCII string | (TRM §4.2.1 — not transcribed) |
| **EXPRESS** | `0277H` | evaluate an expression from BASIC text | (HL → text) | value in X | (§4.2.1) |
| **EXPREX** | `0277H`* | as EXPRESS but does not … (variant) | | | (*address per §4.2.1 p161 — verify) |
| **USGCNT** | `029EH` | internal number → `USING`-formatted string | | | (§4.2.1) |
| **HTOA** | `0283H` | 2-byte binary → ASCII decimal string | `HL` = value (0000H–FFFFH), `DE` = dest addr | `DE` = addr of last char, `B` = char count | `HL, DE, BC, IX, AF` |

Example — `HTOA` with `HL = 2374H` (9076): writes `39 30 37 36` (`"9076"`) at `(DE)`,
returns `B = 04H`.

## 4. Bank-aware coding

- **Bank 0 (0000H–3FFFH) is never switched out** — all the gateway routines
  (`PC-1600-Memory-Bank-Switching.md` Part 6) and the interpreter entry points above are
  always reachable.
- User ML lives in the machine-program area from **C0C5H** up, sized with
  `NEW "S0:"/"S1:"/"S2:",&<bytes + C5H>` (`PC-1600-Memory-Architecture.md` §3–4).
- Cross-bank calls: `BANKCALL` (019FH) / `BANKJUMP` (019CH) / the `RST 18H` / `RST 20H`
  shortcuts. Save/restore bank state around anything that repoints a page.
- Working memory for a resident routine: `CALL 02DFH` (`DE` = size, `C` = Creg) or the
  BASIC-callable `CALL &02DD,A` for EXROM3's area (`PC-1600-Work-Area-Map.md` §2.4).

## 5. Reaching the LH-5803 side

`CALL`/`XCALL` (Z-80 vs. LH-5803 code), `PEEK`/`XPEEK`, `POKE`/`XPOKE`. The OS bridge is
`CALLH` at **01C6H**; its full parameter block (CMDZ mode byte at F002H, PARA…PARUH at
F005H–F00BH, entry address at F00CH–F00DH in LH-5803 view, bank/PV at F00EH) and the
register write-back on return are in `PC-1600-CPU-LH5803-Compat.md` §3.

## 6a. Precautions for ML programs (TRM §5.16)

- **Use IOCS calls, not raw `IN`/`OUT`.** The IOCS routine entry addresses are contractually
  stable across BASIC-ROM revisions; there are several slightly-different interpreter
  versions and only IOCS is guaranteed portable across them.
- **§5.16(7):** if a `CALL`ed ML routine returns a **null string** to BASIC through a
  string variable, represent it as a `00H` byte with length 1 (not length 0).
- **§5.16(8):** to pass a parameter to `XCALL` through a variable, use only a **standard
  or simple** variable — not an array element.

## 6. IOCS

Everything a program needs to touch hardware goes through IOCS, not raw `IN`/`OUT` —
`PC-1600-IOCS.md` is the index; the per-subsystem detail is in
`PC-1600-Display-HD61202.md` §6, `PC-1600-Keyboard.md` §4, `PC-1600-Filesystem.md` §3,
`PC-1600-Serial-Commands.md` Part 2, `PC-1600-Peripherals-Hardware.md` §1–2,
`PC-1600-IO-Ports.md` §6.1/§7.

## Still to write

- Toolchain: Z-80 assembler choice, byte-exact round-trip, getting a `.bin` onto a
  PC-1600 (serial `LOAD`, `CLOADM`, cassette, or an emulator).
- The file/transfer header for an ML program (`PC-1600-Filesystem.md` §1 /
  `Binary-Exchange-Formats.md` §3).
- Worked examples in the style of `LH5801_Guide.md` "Common Patterns".
- Full transcription of §4.2.1 (BCDASC, EXPRESS/EXPREX, USGCNT) and §4.2.4 (GETCD1,
  `NXTADR` 02EEH, label lookup) parameter details.
- Confirm the `EXPRESS`/`EXPREX` entry addresses (§4.2.1 p161).
