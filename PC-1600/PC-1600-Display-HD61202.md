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
- **Right 28-dot block** (columns 128–155): driven by `Y1–Y28`. **IC2's own label in the
  diagram reads `Y1–Y66` total** (not `Y1–Y64 + 28 more`), which a first reading took to
  mean IC2 has only 66 physical Y outputs and the right block is a bare duplicate of the
  left block's own first 28 columns, sharing physical pins — **that reading is not
  reliable and is contradicted by an independent emulator's own working implementation**
  (PockEmul's `src/lcd/Lcdc_pc1600.cpp`, `disp()` — an emulator cross-check per this
  repo's own "Sources & validation" convention, not a TRM-confirmed fact): its renderer
  treats the right block as reading the *same* per-column storage as the left block but
  from an independent, otherwise-hidden set of pages/rows of that storage — genuinely
  separate, individually-addressable pixels, not a duplicate. A real HD61102's per-column
  storage is commonly taller than the visible window (a "display start line" register
  selects which window is shown), which would make room for exactly this without needing
  a 92nd physical output pin — but the TRM diagram's own `Y1–Y66` wording doesn't itself
  spell this mechanism out, so exactly how that number reconciles with an
  independently-addressable right block is still open, flagged here rather than resolved
  by the diagram alone.

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
| +3 | read | data (not yet directly observed in this trace — offset 1/read status is the only read this trace's boot path exercised; offset 3 is inferred by the write side's own +0/+2 symmetry, not independently confirmed) |

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
| **SMBLSET** | 013CH | set the status-line symbols | B = symbol-set number 0–2 (each set covers a different group of the 16 symbols: DEF / small / SHIFT / BUSY / RESERVE / … — exact bit map from TRM §3.1 p28, not fully transcribed) |
| **SMBLREAD** | 0139H | read the status-line state | — |

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

## TODO

- SMBLSET's per-symbol-set bit map (TRM §3.1 p28) — which bit lights which of the 16
  fixed-legend positions named in §1.1 (BUSY/SHIFT/S/SMALL/DEGRAD/RUNPRO/RESERVE/DEF/
  I·II·III/CTRL/BATT).
- The character-*code* table (glyph assignments) — TRM §10.1. **Not needed by an emulator** (the ROM's own font tables, §8, do the rendering); useful for the program-writing agent.
- Reconcile the `LINE`/`BOX` entry-address vs. the §3.1 example's `CALL &0124`.
- §3's command/data/status port split (offset 0/1/2 confirmed by ROM trace, 2026-08-30)
  still has one open cell: offset 3 (data *read*) was never exercised by the boot path
  traced so far — needs its own trace exercising `DOTREAD`/`GPTNREAD` or similar to
  confirm directly rather than by symmetry.
- ~~§2's three-column-block (64+64+28) sizes~~ — resolved 2026-08-30 from the TRM's own
  LCD block diagram, see §2 above. The right block's exact internal wiring is only
  partly resolved by that diagram, though: it behaves as independently-addressable pixels
  (confirmed against PockEmul's own working renderer, an emulator cross-check, not a TRM
  fact) rather than a duplicate of the left block, but the diagram's own `Y1-Y66` label
  doesn't itself explain the mechanism -- still open, see §2's own note.
- The status-symbol line's Y6f/X49-X64 wiring (§2 above) is now confirmed as physically
  separate from the main screen, but its *software* side — which port/value actually
  drives Y6f or selects X49-X64 — is not given by the block diagram and remains open;
  still needs TRM §3.1 p28's own bit map (see the first TODO item above).
