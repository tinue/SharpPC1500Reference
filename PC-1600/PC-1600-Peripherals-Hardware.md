# PC-1600 Peripheral Devices — IOCS and Hardware

## Scope

The printer/plotter (CE-1600P) and floppy (CE-1600F) IOCS routines and hardware, plus
the peripheral-device hardware chapter (TRM Ch 8) as it is processed. Memory modules have
their own document (`PC-1600-Memory-Modules.md`); the serial interface has
`PC-1600-Serial-Commands.md` / `PC-1600-Serial-Hardware-Notes.md`.

**Sources:** PC-1600 Technical Reference Manual §3.7 (printer IOCS), §3.8 (disk IOCS),
Ch 8 (peripheral hardware) — read from the German Systemhandbuch scan. Processed so far:
**§3.7**. Pending: §3.8, Ch 8.

---

## 1. Printer / plotter — CE-1600P (TRM §3.7)

The CE-1600P is an A4 4-colour pen plotter-printer with a built-in cassette interface
(and it hosts the CE-1600F floppy). Its ROM lives in **Bank 4** (`EXROM4`,
`PC-1600-Memory-Bank-Switching.md` Part 6); its work-area state is in
`PC-1600-Work-Area-Map.md` §3.4 (F182H–F194H) and §3.7 (F9E0H–F9F8H).

### 1.1 Two call mechanisms

**§3.7.1 — direct-call routines** (`CALL <Bank 4, address>`):

| Name | Address | Function | Params | Return |
|---|---|---|---|---|
| **PCHEK** | Bank 4, `4020H` | is the printer ready? | — | A: b3 = not initialised, b6 = pen-change status, b7 = printer battery low (b4, b5 always 0). Clobbers all registers. |
| **POUT** | Bank 4, `4023H` | send one character code | E = char code | CF=0 ok; CF=1 = error or BREAK; A = 00H (BREAK pressed) or an error code (same codes as BASIC). Clobbers all registers. |
| **PKOUT** | Bank 4, `4026H` | send one character code (kana variant) | E = char code | as POUT |

> **Mandatory cleanup.** Immediately after *any* printer IOCS routine you **must** call
> **Bank 4, `4029H`** and then **Bank 4, `6777H`**. These do the post-processing (turn
> off the printer-motor power and the interrupt control). Skip them and the motor stays
> powered and the keyboard stops accepting input.

**§3.7.2 — dispatched routines**: put the **IOCS number in `C`** and `CALL Bank 4,
`4008H``. All registers are destroyed. Error code as in BASIC. Routines marked **(G)**
work only in graphics mode.

| # | Name | Function |
|---|---|---|
| 00H | PINIT | initialise the printer |
| 01H | PTEXT | select text mode |
| 02H | PGRAPH | select graphics mode |
| 03H | PCSIZE | set character size |
| 04H | PCOLOR | set pen colour |
| 06H | PWIDTH | set characters per line |
| 07H | PLEFTM | set the left margin |
| 08H | PPITCH | set character pitch + line height |
| 09H | PPAPER | set paper type |
| 0AH | PSCRL | set the Y-direction print area on the paper |
| 0BH | PEOL | set the action taken on a CR code (0DH) |
| 0CH | PZONE | set the print-zone length for `LPRINT` |
| 0DH | PPENUP | raise / lower the pen |
| 0EH | PROTATE | set print direction |
| 0FH | PLTYPE (G) | set line type |
| 10H | PHOME (G) | pen up → origin |
| 11H | PSORGN (G) | define the current pen position as the origin |
| 12H / 13H | PAMVUP / PRMVUP (G) | move pen up, absolute / relative coords |
| 14H / 15H | PAMVDN / PRMVDN (G) | move pen down, absolute / relative coords |
| 16H | PTEST | run the print test |
| 17H | PTAB | move pen to a tab position |
| 18H | ALLOFF | turn off the printer-motor power |
| 1AH–1DH | PCUP / PCDOWN / PCLEFT / PCRIGHT | move pen up, one character step, up/down/left/right |
| 1EH–21H | PGUP / PGDOWN / PGLEFT / PGRIGHT | move pen up, one graphics-dot step, up/down/left/right |
| 22H | PCHGPEN | change pen |
| 28H | PRESET | reset the printer-IOCS work area to its All-Reset state |
| 29H | PCR | pen → left end (carriage return) |
| 2AH | PDIRC | set the character print direction (graphics mode) |
| 2BH | PCRLF | pen → left end of the next line (CR + LF) |
| 2CH | PMYFD | how many lines can the pen move in −Y? |
| 2DH | PPYFD | how many lines can the pen move in +Y? |
| 2FH / 30H | PBOXA / PBOXR | draw a box, absolute / relative coords |
| 31H | HARESET | initialise the printer hardware |

The `LPRINT` / `LLINE` / `GLCURSOR` / `COLOR` / `LF` / `ROTATE` / `CSIZE` / `PZONE` BASIC
commands are the high-level face of these; the work-area bytes they set
(`PC-1600-Work-Area-Map.md` §3.4) are the same state.

## 2. Floppy — CE-1600F / CE-1650F (TRM §3.8)

A 2.5″ floppy drive that connects **through the CE-1600P** (it cannot run standalone).
Its ROM is `EXROM5` (Bank 5); its disk format is the same FAT family as the RAM-disk
memory file (`PC-1600-Filesystem.md`).

### 2.1 Disk geometry (§3.8.2)

| Property | Value |
|---|---|
| Tracks per side | 16 |
| Sectors per track | 8 |
| Bytes per sector | 512 |
| Capacity per side | 64 KB |
| Sectors per FAT | 1 |
| Number of FATs | 2 |
| Logical sectors per cluster | 1 |
| Max files per side | 48 |

### 2.2 Logical-sector layout (§3.8.3(1))

| Logical sector | Area |
|---|---|
| 0 | Boot sector (`PC-1600-Filesystem.md` §5.1) |
| 1 | FAT |
| 2 | FAT (backup) |
| 3–5 | Directory (3 sectors × 512 B ÷ 32 B = 48 entries) |
| 6–127 | Data (122 clusters) |

### 2.3 FAT (§3.8.3(3))

Byte 0 = format ID = **F2H** (for this floppy). Bytes 1–122 = one entry per cluster
(clusters 1–122, mapped to logical sectors 6–127):

- `00H` — free
- `01H`–`7AH` — in use; value = next cluster in the chain
- **`F0H` — last cluster of the file** *(note: the RAM-disk uses `FFH` for "last
  cluster", `PC-1600-Filesystem.md` §5.3 — the floppy uses `F0H`)*

### 2.4 IOCS routines (§3.8.4)

**Dispatch:** (1) set parameters; (2) IOCS number → **C**; (3) `CALL Bank 5, 4008H`. The
IOCS work area must be reserved first. **Drive number**: `01H` = X drive, `02H` = Y drive
(two drives supported).

**Error code in `A`** (bit set = that error):

| Bit | Meaning |
|---|---|
| 0 | drive not ready / timeout |
| 1, 2 | read/write error |
| 3 | sector not found |
| 4 | head-seek error |
| 5 | disk write-protected |
| 6 | battery voltage too low |
| 7 | other (e.g. no disk in the drive) |

| Name | # | Function |
|---|---|---|
| DSKINIT | 80H | initialise the drive (A = drive number) |
| CNCTDRV | 81H | how many drives are connected |
| RESTORE | 82H | seek the head to track 0 |
| FORMAT | 83H | format the disk |
| DREAD | 84H | read one sector |
| DWRITE | 85H | write one sector |
| DVERIFY | 86H | compare a sector against memory |
| GETDRVST | 87H | read the drive status |
| HFREAD | 88H | read the first half (256 B) of a sector |
| HFVERIFY | 89H | compare the first half of a sector against memory |

### 2.5 Power-on (§3.8.5)

When a drive is attached, the drive runs its own initialisation sequence at power-on
(details not transcribed).

## 3. Peripheral hardware (TRM Ch 8)

**Pending.** CE-1600P block diagram / port map (I/O 80–83H), CE-1600F / CE-1650F,
CE-1620M / CE-1601E PROM programmer, CE-1600L / CE-1601T, CE-1601L–CE-1605L, CE-160CA.
