# PC-1600 Display (HD61203 + HD61102 ×2)

## Scope

The PC-1600 LCD hardware: panel, controller topology, the I/O interface, and the
frame-buffer addressing model. The BASIC/IOCS drawing path (character font, `GPRINT`,
cursor, graphics primitives) comes from TRM §3.1 and §10.1 and is **not yet
transcribed** — see "TODO" below.

**Sources:** PC-1600 Technical Reference Manual §7.3 (LCD hardware), read from the German
Systemhandbuch scan. §3.1 (IOCS routines for LCD, work area, character font) and §10.1
(character-code table) pending. §3's port/command decode additionally sourced from a
headless trace of the genuine PC-1600 boot ROM (`romI-0.bin`/`romIV-6.bin`) executing
against a from-scratch SC-7852 emulation, 2026-08-30 — the real firmware's own I/O
behavior, not a description of it, so treated as primary alongside the TRM.
Chip-level behavior (instruction set, status bits, read pipeline, duty/clock options) from
the **Hitachi HD61102 and HD61203 datasheets (1989 data book)**, §9 below.

---

## 1. Panel

- Module: **LF7204E**.
- **Graphics area: 156 × 32 dots.** Plus a **status-symbol line of 16 symbols** above it.
- Drive: **1/64 duty**.
- LCD base clock: **217 kHz**, supplied from the SC-7852 `CK0` pin (pin 56). `CK0` is
  emitted only while **bit 4 of Z-80 I/O port 37H = 1** — 0 at power-on, set by the boot
  routine when it enables the LCD (`PC-1600-CPU-SC7852-Z80.md` §6, pin 56).
- Negative bias from the **VEE** rail (≈ −8.5 V, `PC-1600-Machine-Overview.md` §5).
- `VGG` keeps the HD61102s' display data alive across auto-power-off while the machine
  stays on.

### 1.1 The status-symbol line is fixed-legend segments, not dot-matrix text

**Confirmed 2026-08-30 from a photo of a genuine PC-1600 unit** (the physical hardware
itself — as primary a source as the TRM). The 16 status positions are **printed legend
text permanently etched on the LCD glass**, each with its own small individually-drivable
segment, the same style as a scientific calculator's fixed "DEG/RAD/GRAD" mode strip —
**not** glyphs the firmware draws into the 156×32 dot-matrix graphics area the way
character/graphics mode does. Left to right, the printed legend reads:

```
BUSY  SHIFT  S[ローマ字→カナ]  SMALL  DEGRAD  RUNPRO  RESERVE  DEF  I II III  CTRL  BATT
```

("ローマ字→カナ" = "romaji→kana", a Japanese input-mode toggle, printed as part of the
combined **S** legend.) Several printed labels appear to be single fixed captions with
**two selectable positions each** rather than sixteen independent icons (matching
"DEGRAD" being one legend that shows either DEG or RAD is active, "RUNPRO" showing
either RUN or PRO, and "I II III" being three positions sharing one concept — likely a
memory-area indicator): this is consistent with a "16 symbols" count without there being
sixteen visually-separate icons. **This resolves why the DEG/PRO/I indicators an actual
boot shows never appear in an emulation that only ever draws into the 156×32 dot-matrix
area**: they are architecturally a completely separate display region from that area,
driven by whatever discrete segment lines the HD61203/gate array expose for this strip —
not more page/column-addressed HD61102 writes. **Still needed**: the actual per-segment
port/bit mapping (which `SMBLSET` bit lights which named position) — TRM §3.1 p28's own
bit map, not yet transcribed (see this doc's TODO).

## 2. Controller topology (TRM §7.3)

- **1 × HD61203** — common (row) driver. Provides the X (common) outputs across the
  panel: the 32 graphics rows on each side plus the status line.
- **2 × HD61102** — segment (column) drivers, labelled **IC2** and **IC3** on the board.

The 156-dot width is split into three column blocks: **64 + 64 + 28 = 156**, confirmed
2026-08-30 from the TRM's own LCD block diagram (Systemhandbuch, LCD: LF7204E), which
gives the exact internal Y/X wiring, not just the block sizes:

- **Left 64-dot block** (screen columns 0–63): driven by **IC2**'s `Y1–Y64` outputs.
- **Centre 64-dot block** (columns 64–127): driven by **IC3**'s own `Y1–Y64` outputs,
  labelled independently in the diagram.
- **Right 28-dot block** (columns 128–155): driven by `Y1–Y28`. IC2's label in the
  diagram reads `Y1–Y66`. The right block shares physical segment pins with the left
  block's first 28 columns, but it is **not** a duplicate of them. At 1/64 duty every
  HD61102 scans all 64 of its RAM lines, one per HD61203 common (datasheets, §9.4). The
  right block sits on commons `X33–X64`, so its 28 columns show RAM lines 32–63
  (pages 4–7) of IC2. The left block shows lines 0–31 (pages 0–3) of the same outputs on
  `X1–X32`. The right block's pixels are therefore separate and individually
  addressable, and no chip needs extra output pins.

Row (common) driving: **1 × HD61203** supplies the panel's X (common) outputs — `X1–X32`
into the left block, `X1–X32` into the centre block (IC3's own, a second/independent
32-line group despite the same numbering), and `X33–X64` into the right block. Two
further connections feed the **status-symbol line specifically**, distinct from the main
32-row screen's own addressing: IC3's `Y6f` pin, and HD61203's `X49–X64` common-line
group — both drawn in the diagram entering the panel at the status-line row, not the
32-dot screen body. This is consistent with (though doesn't fully resolve) `PC1600StatusLine`
being a separate mechanism from the graphics-area HD61102 ports — see §1.1 above; the
status line's own *software-side* port/bit protocol (which `SMBLSET` value lights which
segment) is still not given by this diagram and remains open (§6.3/TODO).

## 3. I/O interface

The HD61102s sit in the Z-80 I/O space at **50H–5BH** (6800-family bus via the SC-7852
`E` strobe, pin 60, which fires on any I/O access to 40H–5FH — issued a half-cycle after
`IORQ`). Each HD61102 has three chip-select inputs **CS1#, CS2#, CS3**, and is selected
only when **all three** are asserted. The gate array wires each CS to a different low
address bit so the two controllers (and the register-select within each) decode from the
port number:

| HD61102 CS pin | driven from, IC2 | driven from, IC3 |
|---|---|---|
| CS1# | A2 | A3 |
| CS2# | A5 | A5 |
| CS3 | A4 | A4 |
| I/O port range that selects it | 50H–53H and 58H–5BH | 50H–53H and 54H–57H |

(The 50H–53H overlap in the source table is as printed; the SC-7852 I/O-map page renders
the split as "50H = HD61102 (IC2)+(IC3), 58H = IC3, 5BH = IC2" — i.e. within 50–5FH the
A2/A3/A4/A5 combination picks controller + instruction/data + which half.)

**Command/data/status port assignment within each 4-port block, confirmed 2026-08-30 by
a headless trace of the genuine PC-1600 boot ROM (`romI-0.bin`/`romIV-6.bin`) executing
against a from-scratch SC-7852 emulation** (a primary source: the actual Sharp firmware
running, not a secondary description of it): within a controller's 4-port block (IC3 =
54H–57H, IC2 = 58H–5BH, "both" = 50H–53H), the **command register and the data register
are two different ports, not one port with a D/I-selecting bit as this doc previously
guessed**. The boot ROM was observed writing exclusively to the block's first and third
port (offset 0 and offset 2 from the block's base — e.g. 54H and 56H for IC3) and reading
exclusively from the block's second port (offset 1 — e.g. 55H for IC3, matching the
already-documented busy-wait at `IN A,(55H)`/`IN A,(59H)`, §7 below and
`PC-1600-CPU-SC7852-Z80.md` §5.2's cause list is unrelated to this): never a write to
offset 1/3, never a read of offset 0/2. So:

| Offset from block base | Direction | Register |
|---|---|---|
| +0 | write | command |
| +1 | read | status |
| +2 | write | data |
| +3 | read | data (not in the boot trace, but confirmed from ROM code: bank 6 `81E8H`/`8AA2H` read with `IN r,(C)` at C = 57H/5BH, §9.3) |

Within the command register, three command-byte ranges were directly observed being
written by the real ROM and, once decoded this way, produced a genuinely-lit real pixel
in a from-scratch emulation running that same ROM (also a primary-source result — the
effect of running the actual firmware, not a guess): **0x3E = display off / 0x3F =
display on** (bit 0 selects — the ROM's very first-ever display write in a cold-boot
trace is `0x3E` to the "both controllers" port, an ordinary display-off init step),
**0xB8–0xBF = set page address** (low 3 bits = page 0–7, e.g. `0xBC`/`0xBE`/`0xBF`
observed = pages 4/6/7), and **0x40–0x7F = set column address** (low 6 bits = column
0–63, e.g. `0x7F`/`0x40` observed = columns 63/0). A fourth range, **0xC0–0xFF = set
display start line**, was also written by the ROM (`0xC0` observed) but its effect was
not independently exercised/confirmed by this trace.

## 4. Frame-buffer / addressing model

Standard HD61102: 64 columns × 8 pages of 8 bits per controller; a byte written to a
(page, column) cell is a vertical run of 8 pixels, LSB at the top. The PC-1600's
156×32 graphics area is 4 pages tall (32 rows) spread across the three column blocks /
two controllers as in §2. A pixel at (x, y) maps to: controller = block(x); page =
y >> 3; column = x within its block; bit = y & 7.

## 5. PC-1500-compatibility (MODE 1)

In MODE 1 the display is restricted to **26 × 1** (only the bottom text line used) and
character codes `&27` / `&5B` / `&5D` are remapped to their PC-1500 meanings. The
mechanism and the open question of how an LH-5803 PC-1500 program's writes to the
literal `&7600–&774F` display-buffer addresses reach these I/O-port-mapped controllers
are in `PC-1600-Memory-Architecture.md` §5 (unresolved: hardware shim vs. software shim).
Note the SC-7852 `LHA90` exception (pin 38): an LH-5803 access to 7400H–744FH / 7500H–754FH
physically lands on 7600H–764FH / 7700H–774FH.

## 6. LCD IOCS routines (TRM §3.1)

Call `CALL <entry>`. All addresses are in Bank 0. The character-mode routines operate on
**one text line at a time** — output never wraps to another line. Character mode is
26 columns wide (X 0–25) × 4 lines (Y 0–3); graphics mode uses dot coordinates
**0 ≤ X ≤ 155, 0 ≤ Y ≤ 31**. See `PC-1600-IOCS.md` §1 for the field conventions.

### 6.1 Character output & cursor

| Name | Entry | Function | Params | Return | Clobbers |
|---|---|---|---|---|---|
| **PRTANK** | 0100H | show one char at cursor, advance right | A = char code | CF=1 if it landed in the rightmost column (X=25) → cursor display turned off, cursor not advanced | AF, CRSRX, CRSRST |
| **PRTASTR** | 00EBH | show a string from memory at cursor until a terminator byte is met (terminator not shown) | DE = start addr; A = terminator code | DE = addr of last-shown byte + 1; CF=1 if a char landed in the rightmost column | AF, DE, CRSRX, CRSRST |
| **ERSSTR** | 013FH | show a run of blanks | (count) | — | — |
| **RVSCHR** | 011BH | flip the currently-shown characters to reverse video | — | — | — |
| **SETANK** | 0109H | switch the display to character mode | — | — | — |
| **CGMODE** | 0133H | switch the character-generator between PC-1500 and PC-1600 sets (also reachable via LCDWK1 b2) | — | — | — |
| **CRSRSET** | 0115H | set cursor position (char mode) | D = X, E = Y | CF=1 if outside the displayable area | AF, CRSRX (F060H), CRSRY (F05FH) |
| **CRSRPOS** | 0118H | read cursor position (char mode) | — | D = X, E = Y | DE |
| **CRSRSTAT** | 011EH | set cursor type | A = 00 off / 01 underline / 02 blinking block / 03 blinking blank | — | CRSRST (F067H) |

### 6.2 Line / scroll

| Name | Entry | Function | Params |
|---|---|---|---|
| **UPSCRL** | 012DH | scroll the display up one line; bottom line cleared; cursor display off | — |
| **DWNSCRL** | 0130H | scroll down one line; top line cleared; cursor display off | — |
| **INS1LN** | 0142H | insert a blank line at line A; that line and those below scroll down; cursor display off | A = line 0–3 · clobbers AF |
| **ERS1LN** | 0145H | clear an entire line (stays blank) | A = line position |

### 6.3 Status (symbol) line

| Name | Entry | Function | Params |
|---|---|---|---|
| **SMBLSET** | 013CH | set a symbol set into the state given by A | B = symbol-set number 0–2; A = 8-bit mask, 1 = ON (bit map below) |
| **SMBLREAD** | 0139H | read the status-line state | — |

**SMBLSET's bit map, confirmed 2026-08-30** from the TRM's own SMBLSET reference page
(§3.1 p28; primary source, a photo of the manual page supplied by the project owner) —
resolving the "not fully transcribed" gap this table previously carried. `A`'s 8 bits,
MSB → LSB, per `B`:

| B | b7 | b6 | b5 | b4 | b3 | b2 | b1 | b0 |
|---|---|---|---|---|---|---|---|---|
| 00H | DEF | I | II | III | SMALL | — | SHIFT | BUSY |
| 01H | — | RUN | PRO | RESERVE | — | RAD | G | DE |
| 02H | KBII | — | — | — | S | — | CTRL | Low battery |

(`—` = unused/undefined in the TRM's own table.) TRM's own note: *"Wenn entweder KBII
oder S auf 1 gesetzt ist, so wird das S Symbol angezeigt"* — "if either KBII or S is set
to 1, the S symbol is shown": on real hardware there is exactly one printed "S" position,
lit by either underlying cause; the "ローマ字→カナ" caption text this project's own
photo measurement (§1.1) found next to it is most likely a static, permanently-printed
explanation of what S means when lit, not a second independently-driven segment.

**Storage location, confirmed from ROM code (2026-09-26).** The symbol writer in
bank 6 (`8220H`, called with the page in A, e.g. `LD A,07H / CALL 8220H` at `82FCH`)
selects IC3 (C = 54H) and sets page **(A + DSPLPTR F05CH) & 7** (`81F0H`: `OR B8H`).
It sets column **3FH = 63** (`81FCH`: `OR 40H`) and writes the byte with `OUT (56H),A`,
waiting on both chips' busy bits (`817FH`) before each access. So the three sets live in
**IC3 column 63: B=00H → page 7, B=01H → page 6, B=02H → page 4**. Page 5 is unused.
The display start line rotates them along with the main screen. For page 4 the writer
folds KBII into S (`AND 77H`, then `OR 08H` if bit 3 or 7 was set) before the write.
The RAM shadows, read back by `8208H`, are **F64EH** (page 7), **F64FH** (page 6) and
**F3C6H** (page 4, pre-fold, so it still carries KBII in b7).

### 6.4 Graphics

| Name | Entry | Function | Params / notes |
|---|---|---|---|
| **DOTSET** | 0127H | plot one dot | dot at (X,Y); raster-op from **DOTSOP** (F096H): 00 = set, 01 = OR / clear, 02 = XOR / invert |
| **DOTREAD** | 012AH | read one dot's state | — |
| **LINE** | 0121H | draw a line between (X1,Y1) and (X2,Y2) with pattern LINPTN | params in the F08EH block (§6.5); on return X1POS←X2POS, Y1POS←Y2POS (endpoint becomes the next start) and LINPTN is rotated one dot right for a continuation; clobbers AF, BC, DE, HL, X1POS, Y1POS, LINPTN |
| **BOX** | 0124H | draw a rectangle with (X1,Y1)/(X2,Y2) as opposite corners | same F08EH param block · *(the TRM §3.1 worked example draws a line but ends `CALL &0124`; treat the `0121`/`0124` split as LINE/BOX per the routine table and verify against ROM)* |
| **GCRSRSET** | 014BH | set the graphics-cursor position | DE = X, BC = Y (2's-complement, −32768…32767) · clobbers GCRSRX, GCRSRY |
| **GCRSRPOS** | 0148H | read the graphics-cursor position | — |
| **PRTGCHR** | 014EH | show one char at the graphics-cursor position | 6×8 raster; DOTSOP framing (00 = draw new & clear old 6×8, 01 = OR with old) |
| **PRTGSTR** | 00EEH | show a string from memory at the graphics-cursor position | DE = start; A = terminator |
| **PRTGPTN** | 0154H | show a 1×8-dot pattern at the graphics-cursor position | DOTSOP framing (00 = new & clear old 1×8, 01 = OR) |
| **GPTNREAD** | 015AH | read a 1×8-dot pattern at the graphics-cursor position | — |

**Worked example (TRM §3.1):** `LINE(-5,-3)-(100,50),,&ADA9,BF` in BASIC ≡

```
POKE &F08E,&FB,&FF,&FD,&FF,&64,&00,&32,&00   ; X1=-5, Y1=-3, X2=100, Y2=50 (LE, 2's-comp)
POKE &F096,&00,&A9,&AD                       ; DOTSOP=0 ; LINPTN = &ADA9
CALL &0124
```

### 6.5 Whole-screen / raw

| Name | Entry | Function |
|---|---|---|
| **CLS** | 0112H | clear the whole display (no params, no return) |
| **BSPCTR** | 00E5H | enable / disable the LCD |
| **SAVELCD** | 015DH | save one line's 156×8-dot bitmap to RAM |
| **LOADLCD** | 0160H | load one line's 156×8-dot bitmap from RAM |
| **CPY1500LCD** | 0157H | copy the 4th display line (156-byte bitmap) into the PC-1500-mode LCD RAM at 7600H–764FH or 7700H–774FH — the compatibility bridge for `PC-1600-Memory-Architecture.md` §5 |

## 7. LCD work area (TRM §3.1.2)

SC-7852-view addresses; 2-byte fields are little-endian (L then H) unless noted.

| Name | Addr | Bytes | Meaning |
|---|---|---|---|
| LCDWK1 | F05DH | 1 | b0: LCD mode (0); **b2**: character set (0 = PC-1600, 1 = PC-1500); **b3**: codes 00H–1FH (0 → shown as blanks, 1FH as the "insert" symbol; 1 → shown from the user CG table at CTRCGA/CTRCGB); **b4**: cursor-blink frequency (0 = normal, 1 = double) |
| LCDWK2 | F05EH | 1 | b0: cursor-blink work; b1: LCD interrupt-request mask |
| CRSRX | F060H | 1 | cursor X (0–25) |
| CRSRY | F05FH | 1 | cursor Y (0–3) |
| CRSRT | F067H | 1 | cursor type (00 off / 01 underline / 02 blink block / 03 blink blank) |
| CTRCGA | F061/F062H | 2 | start address of the CG table for codes **00H–1FH** (must be > 8000H) |
| CTRCGB | F063H | 1 | bank (0–7) of that table |
| UPAGGA | F064/F065H | 2 | start address of the CG table for codes **80H–FFH** (must be > 8000H) |
| UPAGGB | F066H | 1 | bank (0–7) of that table |
| X1POS | F08E/F08FH | 2 | LINE/BOX corner 1 X (2's-complement) |
| Y1POS | F090/F091H | 2 | LINE/BOX corner 1 Y |
| X2POS | F092/F093H | 2 | LINE/BOX corner 2 X |
| Y2POS | F094/F095H | 2 | LINE/BOX corner 2 Y |
| DOTSOP | F096H | 1 | dot / pattern raster-op (see §6.4) |
| LINPTN | F097/F098H | 2 | line pattern (same encoding as the BASIC `LINE` pattern argument) |
| GCRSRX | F099/F09AH | 2 | graphics-cursor X |
| GCRSRY | F09B/F09CH | 2 | graphics-cursor Y |

(These overlap the `PC-1600-Work-Area-Map.md` §3.2 LCD entries; the addresses here from
§3.1.2 are the authoritative set for the graphics params, which §6.3 of that doc did not
list.)

## 8. Character generator (TRM §3.1.3)

- A PC-1600 character cell is **6 × 8 dots**. In the CG table each of the 6 columns is one
  byte (an 8-dot vertical slice), stored **left column first**; within a byte **LSB = top
  dot, MSB = bottom dot**. Example — "G" = `3E 41 41 49 39 00`.
- Three CG tables:
  1. **codes 20H–7FH** — in ROM, fixed.
  2. **codes 80H–FFH** — in ROM; the user can point at an alternate RAM table via
     **UPAGGA/UPAGGB**. The whole table is swapped, so all codes must be defined.
  3. **codes 00H–1FH** — no ROM table. To use them the user builds a RAM table, sets
     **CTRCGA/CTRCGB**, and sets **LCDWK1 bit 3 = 1**.

## 9. Controller datasheet facts (Hitachi HD61102 / HD61203, 1989)

**Sources:** Hitachi *HD61102 Dot Matrix LCD Graphic Display Column Driver* (data book
pp. 261–290) and *HD61203 Dot Matrix LCD Graphic Display Common Driver* (pp. 361–387),
scans at `~/SynologyDrive/Dokumente/PDF/Vintage/Sharp/PC-1600/Hitachi_HD61102_1989.pdf`
and `…/Hitachi_HD61203_1989.pdf`. The HD61102 sheet names the **HD61103A** as its common
driver. The HD61203 sheet names the **HD61202** as its column driver. Both use the same
FRM/CL/M/φ1/φ2 interface, and the PC-1600 uses the HD61102 + HD61203 pair (§2). Anything
marked *inferred* combines a datasheet fact with the PC-1600 wiring. The datasheets do not
state it directly.

### 9.1 HD61102 register selection

The chip is selected only when **CS1 = L, CS2 = L, CS3 = H** (active levels as §3 already
lists them). D/I and R/W then pick one of four operations (datasheet Table 1):

| D/I | R/W | Operation | PC-1600 port offset (§3) |
|---|---|---|---|
| 0 | 0 | write instruction | +0 (ROM-trace confirmed) |
| 0 | 1 | read status | +1 (ROM-trace confirmed) |
| 1 | 0 | write display data | +2 (ROM-trace confirmed) |
| 1 | 1 | read display data | +3 (*inferred*: it is the only operation left) |

This matches D/I following port-address bit 1 and R/W following bit 0 or the Z-80's
read/write direction. The datasheet makes +3 = data read the only consistent choice,
and ROM code confirms it (bank 6 `81E8H`/`8AA2H` read 57H/5BH, §9.3).

On a write, data is latched at the **falling edge of E**. On a read, data is driven while
E = H. RST and ADC act whether or not the chip is selected.

**Inferred:** a *read* from the "both controllers" block (50H–53H) would make IC2 and IC3
drive DB0–7 at the same time. Only writes (broadcast instructions such as the ROM's first
`3EH` display-off) make sense there.

### 9.2 Instruction set (datasheet Table 2)

| Instruction | Code (D/I=0, R/W=0) | Effect |
|---|---|---|
| Display ON/OFF | `0011111D` = **3EH / 3FH** | D=1 on, D=0 off. RAM and registers are unchanged. |
| Display start line | `11AAAAAA` = **C0H–FFH** | Sets the RAM line (0–63) shown on the top common line (COM1). Used for scrolling. |
| Set page (X address) | `10111AAA` = **B8H–BFH** | Page 0–7. The X counter does **not** auto-increment. |
| Set Y address | `01AAAAAA` = **40H–7FH** | Column 0–63. Auto-increments after each data read or write and wraps 63 → 0. |

Hitachi's naming is the reverse of the screen's: **"X" = page (vertical, 8-dot bands)**
and **"Y" = column**. The address counter is 9 bits: 3 page bits and 6 column bits.
512 bytes = 64 columns × 8 pages.

**Status byte** (D/I=0, R/W=1):

| Bit | Meaning |
|---|---|
| DB7 | **BUSY**: 1 = executing, and only Status Read is accepted |
| DB6 | 0 |
| DB5 | **ON/OFF**: 1 = display **off**, 0 = on (reverse of the instruction's D bit) |
| DB4 | **RESET**: 1 = still initialising after RST |
| DB3–DB0 | 0 |

The ROM's busy-wait at `IN A,(55H)` / `IN A,(59H)` is this read. The datasheet says to
wait for DB7 = 0 before every instruction, and for DB4 = 0 as well after a reset. The
ROM tests **DB7 only**, on both chips in one loop (bank 0 `0807H`, bank 6 `817FH`):
`IN A,(59H) / RLA / IN A,(55H) / RRA / AND C0H / JP NZ,loop`. DB5 and DB4 are never
looked at.

**Busy time:** 1/f_CLK ≤ T_BUSY ≤ 3/f_CLK, where f_CLK is the φ1/φ2 frequency.

### 9.3 Read pipeline: one dummy read after setting an address

A data read returns the **output register**. The RAM cell at the current address is
latched into that register at the falling edge of E, and then Y increments. After a
Set-page or Set-Y instruction, the **first data read returns stale data**. The byte at
the new address arrives on the *second* read (datasheet Fig. 5: set address → dummy read
→ data N → data N+1 …). An emulator of offset +3 must model this. Writes need no dummy
access.

**ROM confirmation:** bank 6 `81E8H` is `PUSH AF / CALL 817FH (busy-wait) / IN A,(C) /
POP AF / RET`, a busy-wait plus a discarded read. The block reader at `8AA2H` calls it
and then reads four bytes (`IN E/D/L/H,(C)`) with a busy-wait before each one. The
scroll/copy routines at `8A2CH` (IC2, C = 5BH) and `8A66H` (IC3, C = 57H) read four bytes
that way and write them back one page further on (`8ABAH`).

### 9.4 Display scan, duty and why the right block works (HD61203)

- The HD61203 has **64 common outputs X1–X64** and an internal timing generator. In
  **master mode** (M/S = Vcc) it supplies **φ1, φ2, FRM, CL (via CL2) and M** to the
  column drivers. The HD61102 has no timing source of its own. **Confirmed** as the
  PC-1600's mode: the Service Manual key circuit diagram (printed p. 43) ties M/S to VCC.
- Duty is set by pins DS1/DS2: 1/48 (L,L), **1/64 (L,H)**, 1/96 (H,L), 1/128 (H,H). The
  TRM's 1/64 duty (§1) is **DS1 = GND, DS2 = Vcc**, which the key circuit diagram
  shows. So there is one HD61203 and all 64 commons are in use.
- At 1/64 duty each HD61102's 6-bit **Z counter** steps through RAM lines 0–63, one per
  common. FRM reloads it from the display-start-line register. Common X*n* therefore shows
  RAM line (start + *n* − 1) mod 64 on every segment output.
- **Consequence for §2** (*inferred* from the scan rule plus the TRM block diagram): with
  start line 0, commons X1–X32 show lines 0–31 (pages 0–3) and X33–X64 show lines 32–63
  (pages 4–7). The right 28-dot block is wired to X33–X64 and to 28 of IC2's segment
  outputs. So it displays **pages 4–7 of 28 IC2 columns**. These are separate RAM bits
  from the left block's pages 0–3, on shared physical Y pins. That removes the need for
  92 outputs on one chip, which the `Y1–Y66` label seemed to imply. Which 28 of IC2's 64
  column addresses are used depends on its ADC pin (§9.5), which the TRM does not give.
- The same rule places the status symbols. Commons X49–X64 are RAM lines 48–63, which is
  **pages 6 and 7 = 16 bits of one column** on the segment line that feeds the status row
  (IC3, the TRM's `Y6f`, probably Y64). That is exactly the "16 symbols" of §1.
  **Resolved from ROM code (§6.3):** the ROM does not pack. B=02H is a third byte, at
  **page 4** of the same column 63. Page 4 is RAM lines 32–39, i.e. commons X33–X40, not
  X49–X64, so the TRM diagram's "X49–X64 into the status row" is incomplete. §9.4.1 has
  the full wiring from the Service Manual.

#### 9.4.1 Status-row wiring (Service Manual key circuit diagram)

**Source:** PC-1600 Service Manual, key circuit diagram, printed pp. 43–44 (PDF pp. 46–47).
It shows the LF7204E glass pinout with the status legend printed under the pins. The
legend strip starts with a **Y64** segment pin, followed by the commons listed below. Pins
between them that belong to the dot matrix (Y16–Y20, Y36–Y45, Y56–Y64, IC3's Y′11–Y′60)
only pass through the connector. The ROM writes the symbols to **IC3** (C = 54H, §6.3), so
that Y64 is IC3's column 63. The sheet uses Y′ for IC3 elsewhere, and the prime is
missing on this pin.

Common X*n* scans RAM line *n* − 1 (start line 0), so each common is one bit of column 63:

| Common | Page | Bit | Legend | SMBLSET |
|---|---|---|---|---|
| X57 | 7 | 0 | BUSY | B=00H b0 |
| X58 | 7 | 1 | SHIFT | B=00H b1 |
| X59 | 7 | 2 | ローマ字→カナ (part) | B=00H b2, "—" in the TRM |
| X60 | 7 | 3 | SMALL | B=00H b3 |
| X61 | 7 | 4 | III | B=00H b4 |
| X62 | 7 | 5 | II | B=00H b5 |
| X63 | 7 | 6 | I | B=00H b6 |
| X64 | 7 | 7 | DEF | B=00H b7 |
| X49 | 6 | 0 | DE(G) | B=01H b0 |
| X50 | 6 | 1 | G(RAD) | B=01H b1 |
| X51 | 6 | 2 | RAD | B=01H b2 |
| X53 | 6 | 4 | RESERVE | B=01H b4 |
| X54 | 6 | 5 | PRO | B=01H b5 |
| X55 | 6 | 6 | RUN | B=01H b6 |
| X33 | 4 | 0 | BATT | B=02H b0 |
| X34 | 4 | 1 | CTRL | B=02H b1 |
| X35 | 4 | 2 | ローマ字→カナ (part) | B=02H b2, "—" in the TRM |
| X36 | 4 | 3 | S | B=02H b3 |

So there are 18 electrodes. Every TRM symbol sits on the common its bit predicts. The
diagram shows no status pin for X52, X56 (page 6 b3, b7) or X37–X40 (page 4 b4–b7).
**KBII (B=02H b7, X40) therefore has no electrode of its own**, which fits the ROM
folding it into S. The "ローマ字→カナ" caption is instead two electrodes on **X35 and
X59**, placed after S in pin order. The diagram doesn't say which part of the caption
each one lights.

With the western "new" ROM, a probe through boot, KBII, SHIFT, CTRL and MODE never set
bit 2 of the page-4 shadow (F3C6H) or the page-7 shadow (F64EH). The romaji→kana
electrodes stay dark on that machine unless a program writes those bits (SMBLSET B=02H
keeps bit 2: `AND 77H`).
- **Start line moves everything together.** A non-zero start line rotates the whole
  64-line scan, including the status symbols and the right block. The ROM sets start
  line 0 (`C0H`, §3).

### 9.5 ADC pin (column direction)

The ADC pin is tied to Vcc or GND and must never change while running (changing it
corrupts registers and RAM).

- **ADC = H:** Y address 0 → pin Y1, 63 → Y64.
- **ADC = L:** Y address 0 → pin Y64, 63 → Y1.

The TRM does not show IC2's or IC3's ADC level. §4's "column = x within its block"
assumes ADC = H on both.

### 9.6 Reset

RST = L sets **display OFF** and **start line 0**. While RST is low only Status Read is
accepted. According to the datasheet, a reset *during operation* may destroy all RAM and
registers except the ON/OFF register. That fits the TRM's VGG note (§1): the HD61102s
stay powered and keep their RAM across auto-power-off, so they must not be reset on
wake-up.

### 9.7 Clocking and timing

- **HD61203 oscillator:** fosc = 2 × f(φ1/φ2). For a **70 Hz frame** the sheet gives
  fosc = **430 kHz** or **215 kHz**, selected by the FS pin. (The printed text says
  "FCS" in the FS row, apparently a typo.) An external clock goes into **CR** with R and C
  left open (range 50–600 kHz, duty 45–55 %).
- **PC-1600** (**confirmed**, Service Manual key circuit diagram, printed p. 43 / PDF
  p. 46): CK0 (CN1-40) drives the HD61203's **CR** pin with **R and C open**, which is
  the external-clock setup. The other pins are M/S, FCS, STB, SHL and DS2 = VCC, and FS,
  DS1, CL1 and TH = GND. So CK0 = **217 kHz** (§1) is the 215 kHz case, which gives
  **φ1/φ2 ≈ 108.5 kHz** and a frame rate of about **70 Hz**. It is inside the HD61102's φ limits (cycle 2.5–20 µs; 108.5 kHz ≈ 9.2 µs).
  It follows that the HD61102s get **no clock while port 37H bit 4 = 0**, so busy never
  clears and the display does not refresh. The boot ROM must enable CK0 before it
  polls busy.
- **HD61102 busy time** at 108.5 kHz is about **9.2–27.6 µs** per instruction or data
  access (§9.2's formula at the confirmed φ).
- **MPU bus (HD61102):** E cycle ≥ 1000 ns, E high ≥ 450 ns, E low ≥ 450 ns, address
  setup ≥ 140 ns, write data setup ≥ 200 ns, read data delay ≤ 320 ns. These are the
  limits the SC-7852's delayed `E` strobe (§3) has to meet.

### 9.8 Power (for context)

| | HD61102 | HD61203 |
|---|---|---|
| Logic VCC | 5 V ± 10 % | 5 V ± 10 % |
| VEE | 0 to −10 V; LCD drive span ≤ 15.5 V | VCC − VEE = 8–17 V |
| Drive levels | V1/V2 select, V3/V4 non-select | V1/V2 select, V5/V6 non-select |
| Power | ≤ 2 mW, ≤ 100 µA at 1/64 duty with φ = 250 kHz | ≈ 5 mW |

The PC-1600's VEE of about −8.5 V gives VCC − VEE ≈ 13.5 V, inside both ranges. The
contrast control sets the V1…V6 bias resistor chain; for 1/9 bias the sheet uses
4R1 + R2 : R1 = 9 : 1 (e.g. R1 = 3 kΩ, R2 = 15 kΩ). The PC-1600's actual values are not
known.

## TODO

- ~~SMBLSET's per-symbol-set bit map~~ — resolved 2026-08-30 from the TRM's own SMBLSET
  page (§3.1 p28), see §6.3 above.
- The character-*code* table (glyph assignments) — TRM §10.1. **Not needed by an emulator** (the ROM's own font tables, §8, do the rendering); useful for the program-writing agent.
- Reconcile the `LINE`/`BOX` entry-address vs. the §3.1 example's `CALL &0124`.
- ~~§3's offset 3 (data read)~~ — confirmed 2026-09-26 from ROM code: bank 6
  `81E8H` (busy-wait + discarded dummy read) and `8AA2H` (four reads) at C = 57H/5BH
  (§9.3).
- ~~Status-line RAM mapping~~ — resolved 2026-09-26 from the ROM's symbol writer
  (bank 6 `8220H`): IC3 column 63, pages 7/6/4 + DSPLPTR (§6.3, §9.4). ~~How commons
  X33–X40 reach the status row~~ — Service Manual glass pinout, §9.4.1.
- Which part of "ローマ字→カナ" X35 and X59 each light, and whether a Japanese ROM
  drives them (§9.4.1).
- IC2/IC3 ADC pin levels, and which 28 IC2 column addresses feed the right block (§9.5).
- ~~§2's three-column-block (64+64+28) sizes and the right block's wiring~~ — sizes
  from the TRM block diagram (2026-08-30). The right block is IC2 pages 4–7 on commons
  X33–X64, from the datasheets' 1/64-duty scan (2026-09-26, §9.4).
- The status-symbol line's Y6f/X49-X64 wiring (§2 above) is now confirmed as physically
  separate from the main screen, but its *software* side — which port/value actually
  drives Y6f or selects X49-X64 — is not given by the block diagram and remains open;
  still needs TRM §3.1 p28's own bit map (see the first TODO item above).
