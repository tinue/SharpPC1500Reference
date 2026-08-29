# PC-1600 IOCS — Overview and Routine Index

## Scope

The PC-1600's IOCS (Input/Output Control System) — the ROM routine library an assembly
program calls instead of touching I/O ports directly. This document holds the **calling
conventions** and a **master index** of every IOCS routine; the detailed per-routine
specs live in the relevant subsystem document (display, keyboard, files, …) and are
linked from the index.

**Sources:** PC-1600 Technical Reference Manual **Chapter 3** ("IOCS"), read from the
German Systemhandbuch scan. Processed so far: §3.1–§3.13 (Chapter 3 complete).

---

## 1. Calling conventions (TRM §3 preamble)

Every routine's spec is given as up to six fields:

| Field | Meaning |
|---|---|
| **Entry address** (`Einsprungadresse`) | Most routines: `CALL <address>` directly. |
| **IOCS number** (`IOCS-Nummer`) | Some routines instead: put the IOCS number in the **C register** and `CALL` a fixed dispatch address. (The dispatch address is per subsystem — e.g. printer routines via `POUT` at Bank 4 4023H, files/disk/serial via their own dispatchers — noted per routine.) |
| **Function** | What it does. |
| **Parameters** | Set in registers and/or fixed work-area addresses **before** the call. |
| **Return** | Results in registers and/or work-area addresses. |
| **Clobbered** (`Veränderte Register`) | Registers **and work-area locations** the routine may change. |

Notes:

- **Entry addresses are contractually stable** across future PC-1600 BASIC-ROM
  revisions. Sharp's explicit guidance: use IOCS, not raw `IN`/`OUT`, or your program
  may break on a later machine.
- Entry addresses below 4000H are in **Bank 0**, which is never switched out
  (`PC-1600-Memory-Bank-Switching.md` Part 6) — always reachable. Routines given as
  "Bank n, addr" need that bank paged in (or a `BANKCALL`).
- Carry flag (`CF`) is the usual success/error or boundary indicator; `A` often carries
  an error code on `CF=1`. Per routine.
- Work-area addresses are in the F000H–FFFFH map — see `PC-1600-Work-Area-Map.md`.

## 2. Master routine index

### §3.1 Display / LCD — detail in [`PC-1600-Display-HD61202.md`](PC-1600-Display-HD61202.md) §6

Text/char output: `PRTANK` 0100H · `PRTASTR` 00EBH · `PRTGSTR` 00EEH · `ERSSTR` 013FH ·
`RVSCHR` 011BH · `SETANK` 0109H · `CGMODE` 0133H
Cursor: `CRSRSET` 0115H · `CRSRPOS` 0118H · `CRSRSTAT` 011EH
Line/scroll: `UPSCRL` 012DH · `DWNSCRL` 0130H · `INS1LN` 0142H · `ERS1LN` 0145H
Status line: `SMBLSET` 013CH · `SMBLREAD` 0139H
Graphics: `DOTSET` 0127H · `DOTREAD` 012AH · `LINE` 0121H · `BOX` 0124H ·
`GCRSRSET` 014BH · `GCRSRPOS` 0148H · `PRTGCHR` 014EH · `PRTGPTN` 0154H ·
`GPTNREAD` 015AH
Whole screen: `CLS` 0112H · `BSPCTR` 00E5H · `SAVELCD` 015DH · `LOADLCD` 0160H ·
`CPY1500LCD` 0157H

### §3.2 Key input — detail in [`PC-1600-Keyboard.md`](PC-1600-Keyboard.md) §4

`KEYGET` 0166H · `KEYGETR` 0169H · `KBUFSET` 016CH · `BREAKCHK` 016FH · `CURUDCHK` 0172H ·
`KEYDIRECT` 0175H · `KEYSTRB` 0178H · `KEYAUX` 017BH · `KEYSTATSET` 017EH ·
`KEYSTATREAD` 0181H · `OFFCHK` 0184H · `KEYGETND` 0187H · `BREAKRESET` 018AH

### §3.3 Files — detail in [`PC-1600-Filesystem.md`](PC-1600-Filesystem.md) §3

Dispatched via **C = IOCS number, then `CALL 01DEH`** (returns error bitfield in A):
`OPEN FILE` 0FH · `CLOSE FILE` 10H · `SEARCH FIRST` 11H · `SEARCH NEXT` 12H ·
`DELETE FILE` 13H · `SEQUENTIAL RD` 14H · `SEQUENTIAL WR` 15H · `CREATE FILE` 16H ·
`RENAME FILE` 17H · `SET DMA` 1AH · `GET ALLOC` 1BH · `SET ATTRB` 1EH

### §3.4 Interrupt handling — detail in [`PC-1600-CPU-SC7852-Z80.md`](PC-1600-CPU-SC7852-Z80.md) §5 (+ §5.2a user hooks)

IM 2; cause/mask ports 32H/35H; user handler slots F0BCH–F0CAH for the 1/64 s / 0.5 s /
alarm1 / alarm2 / wakeup timers.

### §3.5 System start-up — detail in [`PC-1600-Machine-Overview.md`](PC-1600-Machine-Overview.md) §6

Power-on process, boot search order (medium → system module → application pointer), and
the A-register start-cause bitfield at the application entry point.

### §3.6 RS-232C / SIO — detail in [`PC-1600-Serial-Commands.md`](PC-1600-Serial-Commands.md) Part 2

Dispatched via **C = IOCS number, D = channel (00/01/02 = COM:/COM1:/COM2:), `CALL 01D8H`**:
`CWCOM` 01H · `CRCOM` 02H · `CSNDA` 03H · `CRCVA` 04H · `CRCV1` 07H · `CSETHS` 0EH ·
`CRESHS` 0FH · `CWOUTS` 10H · `CRCTRL` 11H · `CWDEV` 12H · `CRDEV` 13H · `CESND` 14H ·
`CERCV` 15H · `CSBRK` 16H · `CSRCVB` 17H · `CCLRSB` 1BH · `CCLRRB` 1CH

### §3.7 Printer — detail in [`PC-1600-Peripherals-Hardware.md`](PC-1600-Peripherals-Hardware.md) §1

Two mechanisms: direct-call `PCHEK`/`POUT`/`PKOUT` at Bank 4 `4020H`/`4023H`/`4026H`
(with the **mandatory** `CALL Bank4,4029H` + `CALL Bank4,6777H` cleanup after), and
**C = IOCS number, `CALL Bank 4, 4008H`** for `PINIT` 00H … `HARESET` 31H (full table
there).

### §3.8 Disk (CE-1600F) — detail in [`PC-1600-Peripherals-Hardware.md`](PC-1600-Peripherals-Hardware.md) §2

Dispatched via **C = IOCS number, `CALL Bank 5, 4008H`** (drive: 01H = X, 02H = Y;
8-bit error code in A): `DSKINIT` 80H · `CNCTDRV` 81H · `RESTORE` 82H · `FORMAT` 83H ·
`DREAD` 84H · `DWRITE` 85H · `DVERIFY` 86H · `GETDRVST` 87H · `HFREAD` 88H · `HFVERIFY` 89H

### §3.9 Timer / RTC / analog port — detail in [`PC-1600-IO-Ports.md`](PC-1600-IO-Ports.md) §7

Dispatched via **C = IOCS number, `CALL 01D5H`**: `SINIT` 00H · `SBEEP` 01H · `SWRT` 02H ·
`SRRT` 03H · `SWWT` 04H · `SRWT` 05H · `SWA1T` 06H · `SRA1T` 07H · `SWA2T` 08H ·
`SRA2T` 09H · `SWMSK` 10H · `SRMSK` 11H · `SRIRQ` 12H · `SRINP` 13H · `SWPON` 14H ·
`SRA0` 18H · `SRA1` 19H · `SRA2` 1AH · `SRPON` 21H · `SWAB` 22H · `SRAB` 23H · `SWA1A` 24H

### §3.10 Beep — detail in [`PC-1600-IO-Ports.md`](PC-1600-IO-Ports.md) §6.1

Direct-call `BOUT` 01B4H (A = pitch, BC = duration, DE = repeats) / `SOUT` 01B7H;
frequency = 1300000 / (166 + 22·A) Hz. Sound regardless of `BEEP ON/OFF`.

### §3.11 Tape recorder — detail in [`../Data-Formats/WAV-Cassette-Format-1500-1600.md`](../Data-Formats/WAV-Cassette-Format-1500-1600.md)

Mode 0 (native) vs. Mode 1 (PC-1500-compatible) recording layouts, the 48-byte Mode-0
header field semantics, and the F197H–F1A6H tunable-timing work area (TRM §3.11).

### §3.12 Memory control — *done* → `PC-1600-Memory-Bank-Switching.md` Part 6

`BANKSET` 0190H · `BANKREAD` 0193H · `MEMORYCHK` 018DH · `BANKJUMP` 019CH ·
`BANKCALL` 019FH · `SLOT1MAP` 0196H · `SLOT2MAP` 0199H · `SLOTST` 00E8H

### §3.13 Memory module headers — *done* → `PC-1600-Memory-Bank-Switching.md` Part 6
