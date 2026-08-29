# PC-1600 BASIC / IOCS Work Area (F000H–FFFFH)

## Scope

The system RAM the BASIC interpreter and IOCS use: its block structure, how it extends
downward when peripherals are attached, and the named work variables inside it. This is
the reference the IOCS-routine documentation (TRM §3, still pending) builds on.

**Sources:** PC-1600 Technical Reference Manual **Chapter 6** ("Work Area Used for
BASIC") — §6.1 overview, §6.2 work-area/buffer expansion, §6.3 work-area map — read from
the German Systemhandbuch scan.

**Companion:** the slot / boot / bank-management addresses in this same F000H–FFFFH range
(F0AEH/F0AFH module bitmaps, F0DCH/F0DDH boot bank, F07DH Port-3D mirror, F123H–F126H
config, F1ABH reset cause, F015H–F05BH slot descriptors) are in
`PC-1600-Memory-Bank-Switching.md` Part 6, not repeated here. Chapter 6 §6.3 covers the
interpreter / editor / LCD / keyboard / plotter work variables; Part 6 covers the
slot/bank plumbing. Together they map the region.

---

## 1. Overview (§6.1)

The work area is **4 KB at F000H–FFFFH in bank 0** as seen from the SC-7852 — or
**7000H–7FFFH** as seen from the LH-5803 (`PC-1600-CPU-LH5803-Compat.md`; the LH-5803
sees bank 0's C000H–FFFFH at its own 4000H–7FFFH, and this work area is the top quarter
of that). It splits into five blocks:

| Block | SC-7852 | LH-5803 | Contents |
|---|---|---|---|
| **A** | F000H–F5FFH | 7000H–75FFH | IOCS work area (F000H–); Interpreter area I (F05CH–); Editor buffer, 256 B (F1B2H–); Interpreter area II (F21DH–); preset FCB, 313 B (F31DH–); Z-80 stack, 256 B (F500H–F5FFH) |
| **B** | F600H–F7FFH | 7600H–77FFH | PC-1500/1500A display area I (F600H–); standard variable area E$–O$ (F650H–); PC-1500/1500A display area II (F700H–); standard variable area P$–Z$ (F750H–) |
| **C** | F800H–FBFFH | 7800H–7BFFH | **Used exactly as on the PC-1500/1500A** — see §1.1 |
| **D** | FC00H–FF20H | 7C00H–… | RAM-disk area (FC00H–); Interpreter area III (FCB0H–). Expanded for the PC-1600. |
| **E** | FF21H–FFFFH | …–7FFFH | Reserved by the PC-1600 system; used by CE-1F01A (bar-code reader software) |

Block A is IOCS + interpreter + preset FCB + Z-80 stack (the stack is enlarged relative
to the PC-1500). Block B is used as on the PC-1500/1500A: display-refresh area + standard
string variables E$–Z$. Block D handles RAM-disks and is PC-1600-specific.

The (L)/(H) sub-address labels above are read off the §6.1 figure and are approximate at
the byte level; §3 below is the authoritative address list for the named variables.

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
| F05EH | LCDWK2 | LCD work 2 — b0: cursor-blink work; b1: LCD interrupt-request mask |
| F05FH | CRSRY | cursor X coordinate *(sic — the manual labels it "X-Koordinate")* |
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
| F079H | KEYWK1 | key work 1 — b1: click tone (0=off,1=on); b2: repeat (0=off,1=on); b3: which keys repeat (0=non-special, 1=all); b4: repeat delay (0=1 s, 1=0.8 s); b7: key-code conversion (0=on, 1=off) |
| F07AH | KEYWK2 | key work 2 |
| F07BH | KEYWK3 | key work 3 |

### 3.4 Plotter / printer command state

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

### 3.8 Misc

| Addr | Name | Contents |
|---|---|---|
| F9FFH | LOCK | `LOCK`/`UNLOCK` state |
| FB00H–FB07H | RND NUMBER | 8-byte random-number seed / state |

## Open items

- Exact byte boundaries of the Block A sub-regions (§1) — derive from the IOCS work-area
  detail in TRM §3.1.2 / §3.2.2 / §3.4.2 / §3.12.2.
- The F9E0H–F9EFH overload (§3.7) — which alias is live in which printer mode.
- CG-table pointers (CTRCGA/CTRCGB, UPACGA/UPACGB) tie into the "changing the display
  character font" feature (TRM §5.2) — cross-reference when §5 is processed.
- Whether the `CRSRY = X` / `CRSRX = Y` labelling in §3.2 is a manual typo or a genuine
  axis-naming quirk — check against the LCD IOCS routines (§3.1).
