# PC-1600 BASIC / IOCS Work Area (F000H–FFFFH)

## Scope

The system RAM the BASIC interpreter and IOCS use: its block structure, how it extends
downward when peripherals are attached, and the named work variables inside it. This is
the reference the IOCS-routine documentation (TRM §3, still pending) builds on.

**Sources:** PC-1600 Technical Reference Manual **Chapter 6** ("Work Area Used for
BASIC") — §6.1 overview, §6.2 work-area/buffer expansion, §6.3 work-area map. Originally
from the German Systemhandbuch scan; cross-checked against the **English TRM, PDF
pp.203–213** (§6.1 fig = p.204, §6.2 fig(a) = p.205, fig(b) = p.206, §6.3 map =
pp.207–213). The English figures confirm §2 and §3 verbatim; they **correct** the Block A
sub-addresses in §1 (the German scan was shifted by one slot — see §1).

§3.9 onward is from a second, independent Systemhandbuch source: David von Oheimb, *Das
Systemhandbuch für den PC-1600*, Appendix 7 "System-RAM (Memory-Map)" (PDF pp. 97–114) —
its own address-by-address dump of F000H–FFFFH. It fills gaps the English-TRM-sourced §3
table above leaves blank, and in a few places disagrees with it outright (flagged in
place, not silently merged/resolved).

**Companion:** the slot / boot / bank-management addresses in this same F000H–FFFFH range
(F0AEH/F0AFH module bitmaps, F0DCH/F0DDH boot bank, F07DH Port-3D mirror, F123H–F126H
config, FA1BH reset cause, F015H–F05BH slot descriptors) are in
`PC-1600-Memory-Bank-Switching.md` Part 6, not repeated here. Chapter 6 §6.3 covers the
interpreter / editor / LCD / keyboard / plotter work variables; Part 6 covers the
slot/bank plumbing. Together they map the region. §4 below adds the `ADTBL`/`SxMTb`
BASIC-program bank-distribution bytes (TRM §3.12.2), and
[`PC-1600-BASIC-Program-Placement.md`](PC-1600-BASIC-Program-Placement.md) turns them
into an injection algorithm for an emulator.

---

## 1. Overview (§6.1)

The work area is **4 KB at F000H–FFFFH in bank 0** as seen from the SC-7852 — or
**7000H–7FFFH** as seen from the LH-5803 (`PC-1600-CPU-LH5803-Compat.md`; the LH-5803
sees bank 0's C000H–FFFFH at its own 4000H–7FFFH, and this work area is the top quarter
of that). It splits into five blocks:

| Block | SC-7852 | LH-5803 | Contents |
|---|---|---|---|
| **A** | F000H–F5FFH | 7000H–75FFH | system pointers / slot descriptors (F000H–F05BH); then the sub-blocks in the table below |
| **B** | F600H–F7FFH | 7600H–77FFH | PC-1500/1500A display area I (F600H–); fixed variable area E$–O$ (F650H–); PC-1500/1500A display area II (F700H–); fixed variable area P$–Z$ (F750H–) |
| **C** | F800H–FBFFH | 7800H–7BFFH | **Used exactly as on the PC-1500/1500A** — see §1.1 |
| **D** | FC00H–FF20H | 7C00H–… | RAM-file work (FC00H–); Interpreter work III (FCB0H–). Expanded for the PC-1600. |
| **E** | FF21H–FFFFH | 7FFFH | Reserved by the PC-1600 system; used by CE-1F01A (bar-code reader software) |

**Block A sub-blocks (English TRM §6.1 figure, PDF p.204 — this replaces the earlier
German-scan values, which had every label one slot too low):**

| SC-7852 range | Sub-block |
|---|---|
| F000H–F05BH | system pointers / slot descriptors (`PTR1`–`PTRG` at F030–F04F, `FBNO`/`FBBP`/`FCBPTR`; slot descriptors F015H–F05BH per `PC-1600-Memory-Bank-Switching.md` Part 6) — not sub-labelled in the figure |
| F05CH–F1B1H | **IOCS work** |
| F1B2H–F21CH | **Interpreter work I** |
| F21DH–F31CH | **Edit buffer** (256 bytes = F21D…F31C exactly) |
| F31DH–F3C6H | **Interpreter work II** |
| F3C7H–F4FFH | **Default FCB** (313 bytes; F3C7H + 139H = F500H exactly) |
| F500H–F5FFH | **Z-80 stack area** (256 bytes; enlarged relative to the PC-1500) |

The 313-byte-FCB and 256-byte-stack sums both land exactly on F500H, which is the
arithmetic check that this slot assignment (not the German scan's `…FCB @ F31DH, stack
@ F500H`) is the correct one.

Block B is used as on the PC-1500/1500A: display-refresh area + fixed string variables
E$–Z$. Block D handles RAM-files and is PC-1600-specific.

The (L)/(H) sub-address labels below are read off the §6.1 figure; §3 is the authoritative
address list for the named variables.

### 1.1 Block C sub-structure (§6.1)

| Region | Address |
|---|---|
| LH-5803 stack area | F800H–F84FH |
| Standard variables A–Z | F900H–F9CFH |
| Standard variables A$–D$ | F8C0H–F8FFH |
| Arithmetic-operations area | FA00H–FA37H |
| String buffer | FB10H–FB5FH |
| Output buffer | FB60H–FBAFH |
| Input buffer | FBB0H–FBFFH |
| Interpreter area | (remainder) |

**Because Block C follows the PC-1500/1500A conventions (§6.1 note):**

- A 2-byte datum is stored **high byte first, then low byte** (big-endian — the LH-5803
  convention).
- Addresses in this block are given **as the LH-5803 sees them** (MSB ≈ 0, i.e. 7xxxH).
  To use them from the SC-7852, **invert the MSB** — `7xxxH` ↔ `FxxxH`.

*(Contrast: the §6.3 table below and the pointer table in §2 give SC-7852-view `Fxxx`
addresses, and the pointer entries there are stored **low byte then high byte** — the
Z-80 convention. Watch the mixed conventions.)*

## 2. Downward extension for peripherals (§6.2)

The standard work area (F000H–FFFFH) can grow **downward, toward C000H**, when:

1. a peripheral device is attached, or
2. a buffer is explicitly enlarged by a command.

### 2.1 Peripheral ROM work areas

A peripheral's control ROM occupies one of **14 memory blocks of 8 KB** in banks 1–7 at
4000H–7FFFH (two 8 KB rows per bank — the `EXROM1`–`EXROME` / `EXDEV1`,`EXDEV8` layout,
matching the `Creg` table in `PC-1600-Memory-Bank-Switching.md` Part 6: Creg 01–07 =
start 4000H, 08–0E = start 6000H). Its work area is carved out of the top of the
extended region, one slice per active ROM, in the order (highest address first):
communication buffer, file buffer, then `EXROME`…`EXROM1` work areas, then the standard
work area at F000H.

Sizes/uses called out by the TRM:

| ROM slot | Used by | Work-area note |
|---|---|---|
| EXROM3 | CE-1F01A (bar-code reader) | if no CE-1F01A: free for machine-language use — see §2.4 |
| EXROM5 | CE-1600F (floppy) | 1065 bytes |
| EXROM4 / EXROMB / EXROMC | CE-1600P (plotter/printer) | **no** work-area extension — the CE-1600P uses the standard work area |
| others (9 blocks) | reserved for future peripherals | — |

### 2.2 Pointer table PTR1–PTRG (§6.2(3))

Each work-area / buffer slice has a 2-byte pointer to its start address, stored in the
**standard** work area, **low byte then high byte**:

| Ptr | Location | Ptr | Location | Ptr | Location |
|---|---|---|---|---|---|
| PTR1 | F030/F031H | PTR8 | F03E/F03FH | PTRE | F04A/F04BH |
| PTR2 | F032/F033H | PTR9 | F040/F041H | PTRF | F04C/F04DH |
| PTR3 | F034/F035H | PTRA | F042/F043H | PTRG | F04E/F04FH |
| PTR4 | F036/F037H | PTRB | F044/F045H | | |
| PTR5 | F038/F039H | PTRC | F046/F047H | | |
| PTR6 | F03A/F03BH | PTRD | F048/F049H | | |
| PTR7 | F03C/F03DH | | | | |

PTR1–PTRE point at the EXROM1–EXROME work areas; PTRF = communication buffer start;
PTRG = FCB (file) buffer start. (See also the named entries `FBBP` at F04C/F04DH and
`FCBPTR` at F04E/F04FH in §3 — same addresses.)

**Detecting whether a slice is reserved:** read the pointer for the slice, then read the
pointer at the *next higher* address (the reserved slice's pointer); if they differ, the
slice is reserved, if equal it is not. (To test EXDEV1 use F000H as the "previous" value.)

### 2.3 Buffer expand / release commands (§6.2(2))

| Buffer | Expand | Release | ALL RESET | RESET | Power-on |
|---|---|---|---|---|---|
| Communication buffer | `INIT "COMn:",m` (m>1) | `INIT "COMn:",0` | freed | freed | freed |
| File buffer | `MAXFILES=m` (m>1) | `MAXFILES=0` | freed | retained | retained |

Work areas for peripherals are reserved automatically at ALL RESET / RESET / power-on
when the device is attached, and freed when the machine is powered off, the device
detached, and the machine powered on again. **EXROM3 and EXROMA** work areas are also
freed on ALL RESET or by their explicit release command.

### 2.4 Reserving EXROM3 for machine-language use (§6.2(4))

When no CE-1F01A is attached, EXROM3's work area is available for ML programs:

| | |
|---|---|
| reserve | `A = <size to reserve>`, then `CALL &02DD,A` |
| release | `A = 0`, then `CALL &02DD,A` |

(This is the BASIC-callable form of the working-memory allocator `CALL 02DFH` /
parameters `DE`=size, `C`=Creg in `PC-1600-Memory-Bank-Switching.md` Part 6 — the entry
here is 02DDH, taking the size in `A`.)

### 2.5 Variable area (§6.2(5))

The variable area is reserved just **below `xx00H`**, next to the file buffer; the gap
between `xx00H` and the start of the file buffer is unused. It is reserved in 256-byte
chunks, but enlarging it does **not** shrink the program+variable area by the full chunk.

## 3. Work-area map (§6.3) — named variables

SC-7852-view addresses. `(L)`/`(H)` = low / high byte of a 2-byte value (stored L then H
unless noted). Multi-byte variable slots are 8 bytes (numeric BCD) or 16 bytes (string),
as on the PC-1500.

### 3.1 File / buffer pointers

| Addr | Name | Contents |
|---|---|---|
| F02DH | FBNO | `MAXFILES` value |
| F04C/F04DH | FBBP | Communication-buffer start address (L/H) |
| F04E/F04FH | FCBPTR | FCB (file) buffer start address (L/H) |

### 3.2 LCD / display work

| Addr | Name | Contents |
|---|---|---|
| F05CH | DSPLPTR | LCD display start line |
| F05DH | LCDWK1 | LCD work 1 — b0: LCD mode (set to 0); b2: char-generator mode (0=PC-1600, 1=PC-1500); b3: control-char display (0=no, 1=yes); b4: cursor-blink speed (0=slow, 1=fast) |
| F05EH | LCDWK2 | LCD work 2 — b0: cursor-blink work; b1: LCD interrupt-request mask *(Systemhandbuch Appendix 7 disagrees: b0 = cursor currently visible, b1 = LCD access flag — not resolved, see §3.13)* |
| F05FH | CRSRY | cursor X coordinate *(sic — the manual labels it "X-Koordinate")* — but Appendix 7 independently labels F05FH "cursor position **y**" and F060H "cursor position **x**", i.e. the plain, unswapped reading; the two sources disagree on which byte holds which axis, not resolved |
| F060H | CRSRX | cursor Y coordinate *(sic)* |
| F061/F062H | CTRCGA | start address (L/H) of the CG table for control characters |
| F063H | CTRCGB | bank number of the CG table for control characters |
| F064/F065H | UPACGA | start address (L/H) of the CG table for char codes 80H–FFH |
| F066H | UPACGB | bank number of that CG table |
| F067H | CRSRST | cursor type: 00H=off, 01H=underline, 02H=block, 03H=blank-char |
| F068H | CBLCTR | cursor-blink counter |

### 3.3 Keyboard work

| Addr | Name | Contents |
|---|---|---|
| F079H | KEYWK1 | key work 1 — b1: click tone (0=off,1=on); b2: repeat (0=off,1=on); b3: which keys repeat (0=non-special, 1=all); b4: repeat delay (0=1 s, 1=0.8 s); b7: key-code conversion (0=on, 1=off) *(Appendix 7 agrees on b1–b3 but reads b4 as "first repeat" and b7 as "SHIFT/SML off" instead — not resolved, see §3.14)* |
| F07AH | KEYWK2 | key work 2 — full bit breakdown in §3.14 |
| F07BH | KEYWK3 | key work 3 — full bit breakdown in §3.14 |

### 3.4 Plotter / printer command state

*(Appendix 7 gives an independent, partially-conflicting reading of several bytes in
this range — see §3.13 below; not merged into this table since the conflicts aren't
resolved.)*

| Addr | Name | Contents |
|---|---|---|
| F182H | PITCHX | character-density value of `PITCH` |
| F183H | PITCHY | line-spacing value of `PITCH` |
| F184H | COLORP | b0–3: plotter/printer pen colour; b4–7: don't change |
| F185H | WIDTH | characters per line |
| F187H | FLAGA | b0: fixed 1; b1–4: don't change; b5–6: line-feed code (b6=1,b5=1 → LF; b6=1,b5=0 → CR+LF; b6=0,b5=1 → CR) |
| F188/F189H | CUSZL/CUSZH | clipping counter (L/H) |
| F18F/F190H | SZXRL/SZXRH | right clipping bound, X (L/H) |
| F191/F192H | SZXL/SZXH | left clipping bound, X (L/H) |
| F194H | INZONE | pen position (character count from left) |
| F9E0/F9E1H | ABSXL/ABSXH | physical pen position X (L/H) *(alias — see §3.7 for the F9Ex overload)* |
| F9F0H | GRAPH/TEXT | printer mode: 255 = graphics, 0 = text |
| F9F2H | ROTATE | print direction |
| F9F3H | COLOR | colour |
| F9F4H | CSIZE | character size |
| F9EFH | MODE | plotter/printer mode — b0: 0=text,1=graphics; b1: 0=cut-sheet,1=roll; b2–4: don't change; b5: 0=ready,1=not ready; b6: 1=pen in exchange state; b7: 1=printer hardware initialised |
| F9F4H | CHR | value set by `ROTATE` — b4–7: ROTATE 0–3; b0–3: DIRECTION 0–3 (pen movement) |
| F9F5H | CSIZEP | value set by `CSIZE` — b0–3: CSIZE 1–9; b4–5: don't change; b6–7: fixed 0 |
| F9F6H | LINE | line type — b0–3: 0–9; b4–7: don't change |
| F9F7H | ZONE | value set by `PZONE` |
| F9F8H | PWORK | special work — b0: 1 = `LLIST` prints in special size; b1: 1 = pen not raised after `LLINE`/`RLINE` (line type 20); b2/b4/b7: fixed/don't-change; b5: 1 = pen not moved on manual paper feed; b6: 1 = −Y clip disabled in graphics+roll-paper mode |

### 3.5 Interpreter run-state, error/break capture

| Addr | Name | Contents |
|---|---|---|
| F865/F866H | PROGRAM START H/L | start address of the BASIC program, **high byte first** (bank in `F02BH`) *(see note)* |
| F867/F868H | PROGRAM END H/L | end address of the BASIC program, high byte first (bank in `F02CH`). Start = end (and `F02B` = `F02C`) ⇒ no program *(see note)* |
| F869/F86AH | EDIT / MERGE HEAD H/L | head address of the program being edited or merged *(see note)* |
| F88FH | OUTPUT BUFFER POINTER | pointer into the output buffer |
| F890H | FOR POINTER | stack pointer for `FOR…NEXT` |
| F891H | GOSUB POINTER | stack pointer for `GOSUB` |
| F894H | STRING BUFFER POINTER | pointer into the string buffer |
| F895H | USING F/F | `USING` format (decimal-point / comma control) |
| F896H | USING M | integer part of `USING` |
| F897H | USING & | `USING` for strings |
| F898H | USING m | `USING` decimal-point |
| F899/F89AH | VARIABLE POINTER H/L | pointer to variables |
| F89BH | ERL | error number of the error that occurred |
| F89C/F89DH | CURRENT LINE H/L | current program line number |
| F89E/F89FH | CURRENT TOP H/L | start address of the current line's program block |
| F8A6/F8A7H | SEARCH ADDRESS H/L | address of the line found by a SEARCH |
| F8A8/F8A9H | SEARCH LINE H/L | line number of the line after the one found by SEARCH |
| F8AA/F8ABH | SEARCH TOP H/L | start address of the searched program block |
| F8AC/F8ADH | BREAK ADDRESS H/L | address where a `BREAK` occurred |
| F8AE/F8AFH | BREAK LINE H/L | line number where a `BREAK` occurred |
| F8B0/F8B1H | BREAK TOP H/L | start address of the program block where `BREAK` occurred |
| F8B2/F8B3H | ERROR ADDRESS H/L | address where an error occurred |
| F8B4/F8B5H | ERROR LINE H/L | line number where an error occurred |
| F8B6/F8B7H | ERROR TOP H/L | start address of the program block where the error occurred |
| F8B8/F8B9H | ON ERROR ADDRESS H/L | address control jumps to on error |
| F8BA/F8BBH | ON ERROR LINE H/L | line number control jumps to on error |
| F8BC/F8BDH | ON ERROR TOP H/L | start address of that program block |

*(Note the H-then-L labelling here: these follow the Block-C / PC-1500 big-endian
convention, §1.1.)*

**Note on F865–F86A.** These three pointers are not in the Systemhandbuch table. They are the PC-1500's `7865`/`7867`/`7869` (`BASPRG_ST`/`END`/`EDT`) at the same offset in the relocated work area, and big-endian like them. Confirmed in the ROM disassembly (`~/Development/sharp/pc1600/disasm/z80/`):
- The `NEW` path (`rom3b.asm`, `65C8H`) sets start = end = `(F029H AND 7FH)`:`C5H`, i.e. the first byte after the 197-byte reserve, and copies the program's bank index from `F02AH` into both `F02BH` and `F02CH`.
- The emptiness test (`romce1600-2.asm`, `3970H`) compares `F865`/`F867` and `F02B`/`F02C`.

Klaus Ditze's disk-MERGE routine (*Programme, Tips & Tricks für den PC-1600*, 1987, pp. 9–12) relies on the same fields. It saves `(F865)`/`(F02B)`, moves the start to `(F867)`+1 so that `LOAD` appends, then restores them, puts the merged block's head in `F869` and `F89E` (`CURRENT TOP`), and copies the bank from `F1C4` (`MERGED`) to `F1C1` (`CURRENT`).

### 3.6 BASIC variable storage

| Addr range | Name | Variable |
|---|---|---|
| F8C0H–F8CFH | ADOLAR | A$ |
| F8D0H–F8DFH | BDOLAR | B$ |
| F8E0H–F8EFH | CDOLAR | C$ |
| F8F0H–F8FFH | DDOLAR | D$ |
| F900H–F907H | AVAR | A |
| F908H–F90FH | BVAR | B |
| … 8 bytes each, in order … | | C … Z |
| F9C0H–F9C7H | YVAR | Y |
| F9C8H–F9CFH | ZVAR | Z |

(E$–Z$ live in Block B, F650H–F7FFH, §1.) Full letter sequence A–Z at
F900H + 8·(letter−A).

### 3.7 Plotter position/clipping counters (F9Ex — overloaded)

The F9E0H–F9EDH bytes carry different meanings depending on printer mode; the §6.3 table
lists two overlapping sets:

| Addr | Names | Contents |
|---|---|---|
| F9D1H | OPN DV | attached-peripheral designation |
| F9E0/F9E1H | USER COUNTER XH/XL — or — ABSXL/ABSXH | pen X coordinate counter / physical pen X (L/H) |
| F9E2/F9E3H | USER COUNTER YH/YL — or — OVRXL/OVRXH | pen Y coordinate counter / X clip counter (L/H) |
| F9E4/F9E5H | SCISSORING COUNTER YH/YL — or — OVRYL/OVRYH | Y-direction clip counter |
| F9E6H | ABSOLUTE POSITION X — or — SZMYL | absolute X position counter / −Y clip bound (L) |
| F9E7/F9E8H | SCISSORING COUNTER XL/XH — or — SZMYH/SZPYL | X-direction clip counter / −Y and +Y clip bounds |
| F9E9H | SZPYH | +Y clip bound (H) |
| F9EAH | LINE TYPE — or — SRXL | line type / graphics-mode pen X relative to `SORGN` origin, −4096…+4096 two's-complement (L) |
| F9EBH | DOT LINE COUNTER — or — SRXH | dot-line counter / (H) of the above |
| F9ECH | UP/DOWN — or — SRYL | pen up/down status / graphics-mode pen Y (L) |
| F9EDH | X MOTOR HOLD COUNTER — or — SRYH | X-motor hold counter / (H) |
| F9EEH | PORT C | current motor phase |
| F9EFH | Y MOTOR HOLD COUNTER | Y-motor hold counter *(and `MODE`, §3.4 — another overload)* |

This region is clearly reused between the plotter driver's absolute-position tracking and
its scissoring (clipping) logic; treat the two column sets as mode-dependent aliases and
verify against the CE-1600P IOCS routines (TRM §3.7) before relying on a specific meaning.
Appendix 7 gives a third, internally-coherent (non-overloaded) reading for this same
range under the heading "Plotter 2" — see §3.13 below.

### 3.8 Misc

| Addr | Name | Contents |
|---|---|---|
| F9FFH | LOCK | `LOCK`/`UNLOCK` state |
| FB00H–FB07H | RND NUMBER | 8-byte random-number seed / state |

## 3.9 Timer / interrupt work area (F127H–F12EH)

From the Systemhandbuch's Appendix 7 ("System-RAM", PDF pp. 97–114) — the manual's own
address-by-address dump of F000H–FFFFH, complementing the named-variable table above
(sourced from the English TRM's Chapter 6 figures). Ties into the sub-CPU timer IOCS in
`PC-1600-IO-Ports.md` §7.

| Addr | Contents |
|---|---|
| F127H | pending BASIC timer interrupt request — b7: `WAKE$(0)`, b6: `ON TIME$`, b5: `ALARM$` |
| F12AH | which interrupts are *enabled* — b7: `WAKE$(0)`, b3: `ON TIME$`, b5: `ALARM$`, b1: `Keystat 1` (bit layout as transcribed, some bit positions repeat across the two bytes in the source and may be a transcription slip). The ROM passes this byte to SWMSK as-is (P2-B6 `A8E7H`), so it follows the sub-CPU mask layout: b7 wake-up, **b6** alarm 1 (`ON TIME$`), b5 alarm 2, b1 0.5 s, b0 (`PC-1600-IO-Ports.md` §7.1) |
| F12BH | signal flags — b3: hour signal, b2: wake-beep, b1: wake, b0: `WAKE$(1)` |
| F12CH | b0: `ON ADIN` interrupt set |
| F12DH | `ON ADIN` lower threshold — referenced from `PC-1600-IO-Ports.md` §7 (`SWA1A`) |
| F12EH | `ON ADIN` upper threshold |

## 3.10 Serial (COM1/COM2) work area (F12FH–F1B1H)

Not previously mapped in this corpus. Cross-reference `PC-1600-Serial-Commands.md` (the
BASIC-level view) and `PC-1600-Serial-Hardware-Notes.md` (the UART/line hardware).

| Addr | Contents |
|---|---|
| F12FH–F131H | `Setcom` parameters, COM1 |
| F132H–F134H | `Setcom` parameters, COM2 |
| F135H–F137H | `INIT` string I |
| F138H–F13AH | `INIT` string II |
| F13BH / F13CH | `Pconsole` line length, COM1 / COM2 |
| F13DH / F13EH | `Pzone`, COM1 / COM2 |
| F140H | receive-buffer start address |
| F142H | receive-buffer end address |
| F144H | read pointer |
| F146H | write pointer |
| F148H | send status, COM1 |
| F149H / F14AH | send timeout, COM1 / COM2 |
| F14BH | receive status, COM1 |
| F14CH / F14DH | receive timeout, COM1 / COM2 |
| F14EH | b6: `Setdev` COM2, b2: PO, b0: KI |
| F14FH | b5: RTS on, b3: `SNDBRK`, b1: DTR on |
| F150H | receive-error flags — b7: BRK, b2: buffer full, b1: timeout |
| F151H | b3: word length 7 + SHIFT-IN, b0: XOFF received |
| F152H | b7: XON sent, b6: SHIFT-OUT received, b3: XOFF sent |
| F156H | timeout counter, counts up in 0.5-second steps |
| F158H–F17FH | default receive buffer |

## 3.11 Plotter/Centronics work area, first block (F180H–F195H)

Appendix 7's own reading of this range — presented separately from the named-variable
table in §3.4 above because the two sources disagree on several bytes (flagged, not
merged):

| Addr | Contents |
|---|---|
| F182H | pitch X |
| F183H | pitch Y |
| F184H | b4: `LLINE` type 20d; b3–b0: colour |
| F185H | `Pconsole` line length |
| F186H | `Lcursor`/tab |
| F187H | `Pconsole` EOL code — b7: LF, b6: no CR |
| F188H | paper position, 0.1 mm units, Y direction |
| F18AH–F18CH | jump vector for system routines |
| F18BH | `LLINE` X difference |
| F18DH | `LLINE` Y difference |
| F18FH | max. X position |
| F191H | min. X position |
| F193H | value read from port 80H |
| F194H | relative position within the `Pzone` |
| F195H | scratch for the X position across a pen change |

## 3.12 BASIC interpreter work I (F1B2H–F21CH)

This block was previously an opaque, unlabelled "Interpreter work I" region in §1's Block
A layout — Appendix 7 gives it real content:

| Addr | Contents |
|---|---|
| F1B2H | processing pointer for ROM-module commands |
| F1B5H | `AUTO` current line |
| F1B7H | `AUTO` increment |
| F1BCH | mode — b7: set when port 1FH bit 3 is set (normal case); b6: `Mode 1`; b1: `BREAK OFF`; b0: error-handling routine running |
| F1BDH | slot where the line search happens |
| F1BEH | bank of the found peripheral command |
| F1BFH | "ROM-bit" for the peripheral token table; b7 of F1C0H | PC-1500 token table |
| F1C1H–F1CEH | **logical banks**: `CURRENT`, `SEARCH START`, `SEARCH FOUND`, `MERGED`, `PREVIOUS I`, `PREVIOUS II`, `BREAK I`, `BREAK II`, `ERROR I`, `ERROR II`, `ON ERROR I`, `ON ERROR II`, `RESTORE`, `INTERPRET` (one byte each, in that order) |
| F1CFH–F1D4H | BASIC interrupts — `STOP`/`ON` state, request-pending flags |
| F1D5H | `TITLE` — currently selected program area: 0 = S0 (internal), 1 = S1, 2 = S2; the value `TITLE ?` returns (`PC-1600-Memory-Architecture.md` §4.1) |
| F1D6H–F1DAH | one info byte per logical bank — b7: program/AEIM module; b5–b4: physical port address (value for port 31H); b1: slot 2; b0: slot 1 — this is `ADTBL+1`…`ADTBL+5`, see §4 below |
| F1DBH–F21CH | BASIC stack II |

## 3.13 Editor / display extras (F069H–F09CH)

| Addr | Contents |
|---|---|
| F069H–F078H | display area currently hidden behind the cursor |
| F08DH | mirror of port 3CH (`SLOTMAP`) — `PC-1600-IO-Ports.md` §4 |
| F08EH/F08FH | Line/Pset/Gprint X1 |
| F090H/F091H | Y1 |
| F092H/F093H | X2 |
| F094H/F095H | Y2 |
| F096H | draw mode ("Set-Code") — `00`=Set, `01`=Or, `02`=Xor |
| F097H | line dot-pattern code |
| F099H/F09AH | Gcursor X |
| F09BH | Gcursor Y |
| F09DH–F0A1H | jump vector, display routines |
| F0A2H–F0A6H | jump vector, print routines |
| F0A7H–F0ABH | jump vector, keyboard routines |
| F0ACH | Auto-Power-Off counter |

**Appendix 7's alternate reading of the plotter-2 region (F9E0H–F9F9H)**, presented as a
third, internally-consistent set alongside the two overloaded readings already in §3.7 —
not merged with them (address offsets between the two sources may differ by a byte or
two; this needs checking against the CE-1600P IOCS before relying on any single reading):

| Addr | Contents |
|---|---|
| F9E0H/F9E1H | pen position X, 0.1 mm units |
| F9E2H/F9E3H | X overrun count |
| F9E4H/F9E5H | Y overrun count |
| F9E6H/F9E7H | paper limit 2 |
| F9E8H/F9E9H | paper limit 1 |
| F9EAH/F9EBH | graphics-mode pen position X |
| F9ECH/F9EDH | graphics-mode pen position Y |
| F9EEH | pen status — b7: pen down, b5: key-lock, b3: `LLINE` raises the pen, b2: Y overrun, b1: X overrun, b0: lower the pen |
| F9EFH | status 1 — b7: hardware reset, b6: pen change, b5: battery empty, b3: BREAK key forbidden, b1: paper "R", b0: graph mode |
| F9F0H | b7–b4: Y follow-counter, b3–b0: X follow-counter |
| F9F1H | b7–b4: X motor state, b3–b0: Y motor state |
| F9F2H | value written to port 83H |
| F9F3H | pen motor — b7–b4: follow-counter, b3–b0: motor state |
| F9F4H | b7–b4: `ROTATE`, b3–b0: write direction |
| F9F5H | b3–b0: `CSIZE` |
| F9F6H | `LLINE` — b7–b4: type, b3–b0: type (as transcribed; likely two sub-fields the source doesn't distinguish clearly) |
| F9F7H | `Pzone` |
| F9F8H | status 2 — b6: paper feeds forward unrestricted, b5: no re-centring on paper-feed key, b3: no hardware reset after power-off, b2: value at "Point 35" retained, b1: `LLINE` type 20d, b0: `CSIZE` retained |
| F9F9H | value read from port 35H |

## 3.14 Keyboard work, full detail (F079H–F08CH, F0DFH–F126H)

Supersedes the brief `KEYWK1`/`KEYWK2`/`KEYWK3` stubs in §3.3 with Appendix 7's full
breakdown. **Conflicts with §3.3 on F079H bits 4 and 7** (flagged there, not resolved
here either — kept as two independent readings):

| Addr | Contents |
|---|---|
| F079H | status 1 — b7: SHIFT/SML off, b6: fast repeat, b4: first repeat, b3: all keys repeat, b2: repeat on, b1: click on, b0: key-interrupt lock |
| F07AH | status 2 — b4: `ALARM$` interrupt while waiting for a key, b3: keyboard-buffer access, b2: waiting for a key, b1: key code ≥80H, b0: not the same key (as last time) |
| F07BH | status 3 — b3: `Keystat 2`, b2: Power-Off off, b1: Power-Auto-Off 1, b0: `Keystat 1` |
| F07CH | keys from Keystat 1/2 — b7: PF-U, b6: PF-0, b0: OFF |
| F07DH | mirror of port 3DH — `PC-1600-IO-Ports.md` §4 |
| F07EH | mask for the timer interrupt |
| F07FH | keyboard-buffer write pointer (00H–3FH); b7 = buffer full |
| F080H | keyboard-buffer read pointer |
| F081H | last key pressed |
| F082H | repeat counter |
| F083H | last key including shift function (for repeat) |
| F084H/F085H | SHIFT key-code table start address; F086H = bank |
| F087H/F088H | KBII table start address; F089H = bank |
| F08AH/F08BH | SHIFT-KBII table start address; F08CH = bank |
| F0DFH–F11EH | keyboard buffer |
| F11FH/F120H | bank / address of the normal-key key-code table |

## 3.15 LH-5803 register-save area (F001H–F012H)

The sub-CPU's register-save block, used across `CALLH` and interrupt handoffs between the
two CPUs (`PC-1600-CPU-LH5803-Compat.md`):

| Addr | Register |
|---|---|
| F002H | Mode — b4: parameter handoff |
| F004H | Flags — b4: H, b3: V, b2: Z, b1: IE, b0: C |
| F005H | A (error code) |
| F006H/F007H | X (HL) |
| F008H/F009H | Y (DE) |
| F00AH/F00BH | U (BC) |
| F00CH | PC |
| F00EH | b0: PV |
| F00FH | IX (uncertain — source marks this "?") |
| F011H | IY (uncertain — source marks this "?") |

## 3.16 Arithmetic-register names (FA00H–FA37H)

The English-TRM figure only labels this range "Arithmetic-operations area" (§1.1);
Appendix 7 names the individual registers, matching the `XX` register referenced by
`PC-1600-ROM-Jump-Table.md` (e.g. `USGCNT`, `USCNVL`):

| Addr | Name |
|---|---|
| FA00H | XX |
| FA08H | ZZ. Also the power-off signature `A5H`×4 (FA08H–FA0BH) that a power-on reset checks before it resumes (`PC-1600-SubCpu-LU57813P.md` §4.1; SP is saved at F0DAH) |
| FA10H | YY |
| FA18H | UU |
| FA20H | VV |
| FA28H | WW |
| FA30H | SS |
| FA38H–FAFFH | BASIC stack |

## 3.17 Cassette-interface header buffer (FB60H–FBAFH)

| Addr | Contents |
|---|---|
| FB60H–FB8FH | header buffer |
| FB90H/FB91H | start address |
| FB92H | bank |
| FB93H/FB94H | end address |
| FB95H | bank |
| FB96H/FB97H | pointer into the address/length block |
| FB98H–FBAFH | address/length block (value for port 31H, b7 = last block: start address, length) |

Relevant to the serial/cassette binary formats in `../Data-Formats/Binary-Exchange-Formats.md`
and `../Data-Formats/WAV-Cassette-Format-1500-1600.md`.

## 3.18 RAM-disk work area (FC00H–FCAFH)

Detailed low-level RAM-disk driver state, complementing the FCB/directory structures in
`PC-1600-Filesystem.md`. Not merged there — this file remains the home for all
F000H–FFFFH addresses; Filesystem.md cross-references this section.

| Addr | Contents |
|---|---|
| FC00H–FC07H | RAM-disk S1 — `LOGFORM` address, FAT address, FAT checksum, Media ID, count of open files |
| FC08H–FC0FH | RAM-disk S2 — same layout |
| FC10H | byte count of the old sector |
| FC12H | count of the new sectors |
| FC14H | byte count of the new sector |
| FC16H | device name — `01`=X, `02`=Y, `00`=S1, `01`=S2, `04`=COM, `05`=COM1, `06`=COM2 (also the `SEARCH BOOT` result slot, `PC-1600-Filesystem.md` §6) |
| FC17H–FC21H | filename + extension |
| FC22H | cluster counter while searching |
| FC23H | first free cluster |
| FC24H | disk-buffer-control address; RAM: dir-block address |
| FC27H | dir-block number |
| FC28H | logical block count per read/write operation |
| FC2AH–FC2DH | logical sector number (low/high), byte number (low/high) |
| FC30H–FC34H | physical sector count, remainder bytes |
| FC36H | current cluster number |
| FC38H | remaining sectors |
| FC39H | current read/write address |
| FC3BH | RAM-disk error code |
| FC3CH | count of clusters processed so far |
| FC3EH | FCB address |
| FC40H | X/Y control address |
| FC42H | `LOGFORM` address |
| FC44H | read/write-FCB address |
| FC4BH | `00`=read, `01`=write, `02`=compare |
| FC4EH | current sector count of the file |
| FC50H | b7: new sector needed |
| FC51H | disk full |
| FC52H | sector complete |
| FC56H | value in port 31H |
| FC57H | FAT write counter |
| FC58H | device name for the file search |
| FC5AH | current dir-block during the file search |
| FC9AH–FCA4H | new name |
| FCA5H–FCAFH | old name |

## 3.19a BASIC interpreter work II (F31DH–F3C6H)

The counterpart to §3.12 for the second "Interpreter work II" block in §1's layout:

| Addr | Contents |
|---|---|
| F31DH–F35EH | stacks for BASIC interrupts |
| F32DH–F334H | max. 8 active interrupts |
| F335H | stack pointer for interrupt masks |
| F337H–F35EH | 5 bytes per active interrupt |
| F35FH | command token |
| F3BFH | last "ROM-bit" (for reset) |
| F3C1H–F3C3H | COM-command entry point |
| F3C6H | status 2 — b7: KBII, b3: `S`, b1: CTRL, b0: BATT |

## 3.19 WAKE$ storage (FF00H–FF3FH)

| Addr | Contents |
|---|---|
| FF00H–FF1FH | `WAKE$(0)` |
| FF20H–FF3FH | `WAKE$(1)` |
| FF40H–FFFFH | unused |

## 4. BASIC-program bank distribution — `ADTBL` / `SxMTb` (TRM §3.12.2)

When the S0 work area spans more than one 16 KB bank (a module used as expansion memory, or a program module), the interpreter stores the tokenised BASIC program **linearised across a list of banks** and records that list in the work area. `LOAD` consumes this list; it does not build it (the boot memory-config routine and `NEW`/`INIT` build it).

### 4.1 The bytes

| Addr | Name | Meaning |
|---|---|---|
| F029H / F015H / F01FH | — | b6–b0: high byte (page) of the program-area base of S0 / S1 / S2. `NEW` masks the byte with `7FH`, so b7 is a separate flag. The reserve-key area is at page:08H–page:C4H, the same 189-byte layout as the PC-1500's `4008`–`40C4` (e.g. `C008H` on a stock S0). Source: Ditze's reserve-save program (1987, pp. 26–27), which computes `PEEK(S−1)*256+8` from the `SxMTb` address `S` |
| F02AH | `S0MTb` | 1-based `ADTBL` index where **S0**'s bank list starts; S0 runs from there through entry 5. Value not in 1..5 ⇒ S0 has no module banks (internal RAM only). |
| F016H / F018H | `S1MTb` / `S1MBb` | first / last `ADTBL` index of **S1**'s bank list *when S1 is a program module*. `FEH` (anything not 1..5) ⇒ S1 is not a program module. |
| F020H / F022H | `S2MTb` / `S2MBb` | same for **S2**. |
| F1D6H–F1DAH | `ADTBL+1` … `ADTBL+5` | five 1-byte bank descriptors. |

### 4.2 `ADTBL+n` byte encoding

The bank field is stated by TRM §3.12.2 ("bank information is stored in bits 4 and 5"); the rest is **reverse-engineered from that section's two worked examples** — sample bytes `01 22 32` (Example 1) and `81 11 A2` (Example 2). Bits 3 and 6 are never set in those samples; treat them as unknown / assume 0.

```
byte == 0x00        entry unused
otherwise:
  bit 7            1 = LEADING bank of a program-module region
                       (the bank carrying the 8-byte module header + 189-byte reserve)
  bits 5-4         global bank number 0..3        bank = (byte >> 4) & 3
  bits 3-0         physical slot the bank routes to: 1 = Slot 1, 2 = Slot 2
```

`bank` alone is enough to drive Port 31H's page-2 field; the slot nibble is redundant with the fixed bank↔slot map (banks 0/1 → Slot 1, banks 2/3 → Slot 2) and serves as a validity/consistency tag.

### 4.3 Decoded examples

**Example 1** — CE-159 in S1, CE-1600M in S2, **both extension memory**:
`S0MTb=03`, `S1MTb=S2MTb=FEH`, `ADTBL = 00 00 01 22 32`.
S0 bank list = entries 3..5 = `[bank 0/slot 1, bank 2/slot 2, bank 3/slot 2]`. The TRM: *"the program is loaded into bank 0, bank 2, bank 3, and the main memory in that order"* — **`ADTBL` slice order = fill order**, and internal RAM (`C000–FFFF`) is appended as the final segment.

**Example 2** — CE-1600M in S1, CE-161 in S2, **both program modules**:
`S1MTb=02,S1MBb=03` → S1 owns `ADTBL[2..3] = 81,11` (bank 0 *leading* + bank 1); `S2MTb=S2MBb=04` → S2 owns `ADTBL[4] = A2` (bank 2 leading); `S0MTb=05`, `ADTBL[5]=00` → S0 internal-only. Here the three regions are **independent** text streams, one per region, each `ADTBL[xMTb..xMBb]`.

### 4.4 Reconstructing the placement (for an emulator injecting a tokenised image)

The full, implementation-ready procedure — build the ordered S0 segment list from `S0MTb`/`ADTBL`, linearise, translate each logical offset to `(physical bank, Z-80 address)`, write, and fix up the text-end / variable pointers — is in **[`PC-1600-BASIC-Program-Placement.md`](PC-1600-BASIC-Program-Placement.md)**, together with the direct-copy-vs-simulated-store question and why `SLOT1MAP`/`SLOT2MAP` need no accounting. `PC-1600-Memory-Architecture.md` §4b.5/§4b.7 give the address-space geometry the segment list sits in.

## Open items

- ~~Exact byte boundaries of the Block A sub-regions (§1)~~ — **resolved** from the
  English TRM §6.1 figure (PDF p.204); see the sub-block table in §1. What F000H–F05BH
  contains beyond `PTR1`–`PTRG` and the slot descriptors is still not itemised by §6.1.
- The F9E0H–F9EFH overload (§3.7) — which alias is live in which printer mode.
- CG-table pointers (CTRCGA/CTRCGB, UPACGA/UPACGB) tie into the "changing the display
  character font" feature (TRM §5.2) — cross-reference when §5 is processed.
- Whether the `CRSRY = X` / `CRSRX = Y` labelling in §3.2 is a manual typo or a genuine
  axis-naming quirk — check against the LCD IOCS routines (§3.1). Appendix 7 (§3.13
  note under §3.2) gives yet another reading, still unresolved.
- Real-hardware conflicts between the English-TRM-sourced §3 table and the
  Systemhandbuch-Appendix-7 material in §3.9–§3.19a: `F05EH` (LCD access/cursor-visible
  bits), `F05FH`/`F060H` (X/Y axis swap), `F079H` bits 4/7 (keyboard status), and the
  whole F180H–F195H / F9E0H–F9F9H plotter ranges (three different, only-partially-
  reconcilable readings across the two sources plus the aliasing already noted in §3.7).
  None of these are resolved — treat both readings as provisional until checked against
  real hardware or a ROM disassembly.
- ~~Appendix 7's own note that "on some ROM versions, 4 more jumps follow" past the fixed
  jump table (see `PC-1600-ROM-Jump-Table.md`) — not itemised by the source, not yet
  investigated.~~ **Resolved:** itemised from the ROM dump in
  `PC-1600-ROM-Versions.md` §4; "some ROM versions" is the OLD/NEW BASIC ROM split that
  document describes.
