# PC-1600 File System (FCB, RAM-disk / floppy FAT)

## Scope

How the PC-1600 stores and accesses files: the file-type header, the File Control Block
(FCB), the file IOCS routines, and the FAT-style on-medium layout used by both RAM-disk
memory files and CE-1600F floppies.

**Sources:** PC-1600 Technical Reference Manual §3.3 ("Files") — §3.3.1 file types &
management, §3.3.2 file IOCS routines, §3.3.3 memory-file structure — read from the
German Systemhandbuch scan. TRM §3.8.3 (floppy geometry, directory-entry format) and the
RAM-disk-specific IOCS/work-area material in §6–§7 below are from the same Systemhandbuch
(David von Oheimb, *Das Systemhandbuch für den PC-1600*), ch. **13 "Diskettenlaufwerk"**
and ch. **14 "Dateien"** (PDF pp. 46–53, printed pp. 45–52).

---

## 1. File types and the 16-byte file header (§3.3.1(1))

The PC-1600 handles three file types:

1. **ASCII files** — no header. Lines are separated by **CR+LF** (`0DH 0AH`); end of file
   is marked by an **EOF byte, `1AH`**.
2. **BASIC program files** — tokenized ("intermediate code").
3. **Machine-language program files.**

Non-ASCII files carry a **16-byte header** at the start of the file:

| Off | Value | Field | Notes |
|---|---|---|---|
| +00H | `FFH` | header present | `FFH` = not ASCII (header follows); ≠ `FFH` = ASCII file (no header) |
| +01H | `10H` | ID code | |
| +02H | `00H` | reserved | |
| +03H | `00H` | reserved | |
| +04H | — | **mode** | `10H` = machine-language program; `21H` = BASIC program (intermediate code) |
| +05H..+07H | low, mid, high | **size** of the data area (3-byte LE) | |
| +08H..+0AH | low, high, bank | **load address** (3-byte) | machine-language only |
| +0BH..+0DH | low, high, bank | **execution address** (3-byte) | machine-language only |
| +0EH | `00H` | reserved | |
| +0FH | `0FH` | reserved | |
| +10H.. | | data | |

This is the **same 16-byte header** documented for the PC-1600 serial transfer format in
`../Data-Formats/Binary-Exchange-Formats.md` §3 (`FF 10 00 00`, type byte, 3-byte LE
length, 3-byte LE load/exec addresses, `00 0F` end marker) — §3.3 confirms it and adds
that offset +00H doubles as the "is this ASCII?" discriminator.

## 2. File Control Block (§3.3.1(2))

BASIC manages an open file through a **57-byte FCB** followed by a **256-byte buffer** —
**313 bytes** per file, allocated according to the `MAXFILES` command. (The 313-byte
figure also appears as the preset-FCB reserve in `PC-1600-Work-Area-Map.md` §1 and the
`Creg 10` file-buffer allocation in `PC-1600-Memory-Bank-Switching.md` Part 6; the
Systemhandbuch's own text reads "im Abstand von 139 Bytes", almost certainly an OCR/scan
digit-order slip for "313" — the FCB's own byte layout below runs `+00H`..`+138H`
inclusive, which *is* 313 (`139H`) bytes, so the two sources agree once read correctly.)

**Preset FCB.** The standard FCB used internally by `(B)LOAD`/`(B)SAVE` lives at a fixed
address, **`F3C7H`–`F4FFH`**. All other FCBs must be reserved via `MAXFILES` and are laid
out back-to-back, 313 bytes apart, starting at the address held in **`F04EH`**.

| Off | Name | Field | Notes |
|---|---|---|---|
| +00H | FLNO | file number | from the `OPEN` command |
| +01H..+04H | FDVN0 | device name (channel) | 4 bytes, `00`-padded if shorter; **must be set before calling a file IOCS routine** |
| +05H | FLMD | mode | input / output / append |
| +06H | FBP | file-buffer pointer | length of valid data currently in the buffer |
| +07H | FBRP | file-buffer read pointer | offset from buffer start of the next byte to read (input mode) |
| +08H | FSTATUS | status | set to `1` when EOF is hit reading the buffer in input mode |
| +09H..+10H | FNAM | file name | 8 bytes |
| +11H..+13H | FEXT | extension | 3 bytes, space-padded if none |
| +14H | FATT | attribute | |
| +15H..+1EH | — | reserved | 10 bytes |
| +1FH..+20H | FTIM | time of creation | packed `[hour][minute][second/2]` (FAT-style) |
| +21H..+22H | FDAT | date of creation | packed `[year][month][day]`; **year = offset from 1980** (FAT-style) |
| +23H..+24H | FCLUS | first cluster number | |
| +25H..+28H | FSIZE | file size in bytes | 4 bytes, low → high |
| +29H..+38H | FFRE | per-device work area | 16 bytes — see the precise sub-fields below |
| +39H.. | — | file buffer | 256 bytes |

`+09H..+28H` (32 bytes) is literally a **copy of the file's directory entry** (name,
extension, attribute, time, date, first cluster, size — same byte layout as §5.4 below),
not independently-named FNAM/FEXT/etc. fields — the names above are this doc's own gloss,
kept for readability.

**`FFRE` (+29H..+38H) sub-fields**, precise reading from the Systemhandbuch (ch. 14,
"Struktur des FCB") — supersedes the vaguer "holds current record/block" note previously
here:

| Off | Field | Notes |
|---|---|---|
| +29H | current cluster number | the cluster currently being processed during sequential access |
| +2BH | clusters-processed count | how many clusters of this file have already been walked |
| +2DH | cluster number in FAT | — |
| +2EH | bytes per logical block | constant `0100H` (256) |
| +30H..+32H | logical-block counter | — |
| +33H..+35H | — | unused |
| +36H | flags | b0 = FCB modified; b1 = file content modified |
| +37H..+38H | — | `00H` |

## 3. File IOCS routines (§3.3.2)

**Calling convention:** (1) set parameters in the FCB and registers; (2) put the IOCS
number in the **C register**; (3) `CALL 01DEH`. On return **every register is destroyed
except A**:

- `A = 00H` — normal completion.
- otherwise `A` is an **error bitfield** (Systemhandbuch ch. 14 wording, more precise
  than the earlier TRM-paraphrase kept in parens):

| Bit | Meaning |
|---|---|
| 7 | wrong/nonexistent device |
| 6 | device error |
| 5 | no floppy inserted (media error on the addressed device) |
| 4 | wrong function code (routine not supported by that I/O) |
| 3 | hardware error / other |
| 2 | file-end exceeded (no more data to read) |
| 1 | disk full (no space left to write) |
| 0 | file not found, or directory full |

`SEARCH FIRST`/`SEARCH NEXT`/`DELETE FILE` (`11H`–`13H`) and the `GET ALLOC`/`GET LENGTH`
pair (`1BH`, `23H`) are **not available for `COM:`/`CAS:`** devices — sequential-access
serial and cassette channels have no directory to search or size to report.

| Routine | IOCS # | Function |
|---|---|---|
| OPEN FILE | `0FH` | open a file |
| CLOSE FILE | `10H` | close a file |
| SEARCH FIRST | `11H` | find the first directory entry (wildcards allowed in the name, `?` per character) |
| SEARCH NEXT | `12H` | find the next directory entry matching the pattern set by `SEARCH FIRST` |
| DELETE FILE | `13H` | delete a file (wildcards allowed) |
| SEQUENTIAL RD | `14H` | sequential read of one logical block (256 bytes) |
| SEQUENTIAL WR | `15H` | sequential write of one logical block |
| CREATE FILE | `16H` | create a file (for writing) |
| RENAME FILE | `17H` | rename a file — replaces `DE+09H..+13H` with `DE+29H..+33H`; wildcards allowed |
| SET DMA | `1AH` | set the transfer (DMA) address |
| GET ALLOC | `1BH` | medium/file allocation info: `DSKF` in bytes = `BC × E × HL` (`BC` = bytes/sector, `E` = sectors/cluster, `HL` = number of free clusters); also sets file attributes from `DE+14H` |
| SET ATTRB | `1EH` | set file attributes |
| GET LENGTH | `23H` | logical block count of the file → `DE` = high word, `HL` = low word |

## 4. Memory files (RAM-disk) — physical structure (§3.3.3(1))

A memory file occupies **16 KB segments**. Usable modules: **CE-161** (16 KB),
**CE-1600M** / **CE-1620M** (32 KB; CE-1620M is the EPROM version, otherwise identical).

Slot / bank mapping (in the Z-80 8000H–BFFFH window):

| Module | In Slot 1 | In Slot 2 |
|---|---|---|
| 16 KB (CE-161) | Bank 0 | Bank 2 |
| 32 KB (CE-1600M/1620M) | Bank 0 + Bank 1 | Bank 2 + Bank 3 |

Larger capacities are reached through the Port 28H vertical-bank mechanism
(`PC-1600-Memory-Bank-Switching.md` Part 2) — "for future extension". The ROM
geometry table (§5.2) actually carries rows up to 320 KB (`F9H`), and the
boot-sector header can be hand-patched past `INIT`'s 256 KB ceiling (§5.5).

Geometry: each module → **4 KB tracks** → **512-byte sectors**. A 16 KB module has
32 sectors (0–31) in 4 tracks; a 32 KB module has 64 sectors (0–63) in 8 tracks. Because
it is addressed by track+sector it is "logically like a 2.5-inch floppy disk" — the same
IOCS and on-medium format serve both.

## 5. Logical structure (§3.3.3(2))

Four areas, in order: **Boot sector · FAT · Directory · Data.**

### 5.1 Boot sector

Offsets within the (512-byte) boot sector:

| Off | Contents |
|---|---|
| 00H | `55H` — file-module header ID code |
| 01H | `80H` |
| 02H | checksum — set so the 8-bit sum of boot-sector bytes `00H..1FH` is `00H` (ROM-verified across F1/F3/F7 disks) |
| 03H | boot flag — `C3H` or `1BH` ⇒ the program is booted |
| 04H..05H | jump address (low, high) |
| 06H | `00H` |
| 08H | **Medium ID** (see §5.2) |
| 09H..0AH | sector length, bytes/sector (low, high) — `0200H` = 512 |
| 0BH | (sector length / 32) − 1 — `0FH` |
| 0CH | `DIRSFT` (directory shift) |
| 0DH | (sectors per cluster) − 1 |
| 0EH | `CLSSFT` (cluster shift) |
| 0FH..10H | first logical sector number of the **FAT** area (low, high) |
| 11H | `FATCNT` — number of FAT copies |
| 12H | `MAXDIR` — max directory entries |
| 13H..14H | first logical sector number of the **data** area (low, high) |
| 15H..16H | `MAXCLS` — max clusters (low, high) |
| 17H | `FATSIZ` — FAT size in sectors |
| 18H..19H | first logical sector number of the **directory** area (low, high) |
| 1AH | sectors per track — `08H` for the RAM modules |
| 1BH..1CH | `00H`, `00H` |
| 1DH..1EH | boot-program load start address (low, high) |
| 1FH | `00H` = boot program was loaded into memory and executed; `FFH` = executed in place without loading |
| 20H..FFH | boot loader code |

### 5.2 Medium ID and geometry table (§3.3.3(2), p66)

`Media ID` runs `F0H`…`FFH` by module capacity (KB): 16→`F0H`, 32→`F1H`, 64→`F2H`,
96→`F3H`, 128→`F4H`, 160→`F5H`, 192→`F6H`, 224→`F7H`, 256→`F8H`, 320→`F9H`, 384→`FAH`,
512→`FBH`, 640→`FCH`, 768→`FDH`, 896→`FEH`, 1024→`FFH`.

Constant across all sizes: sector size `0200H`; (sector size/32)−1 = `0FH`;
`DIRSFT` = `04H`; first FAT sector = `0001H`; `FATSIZ` = `01H`; 8 sectors/track.

#### The geometry table in ROM

`romIII-3.bin` carries this table at **Z-80 address `5006H + (MediaID − F0H)·19`**
— one **19-byte row per Media ID**, byte-for-byte the boot sector's `08H..1AH`
fields (Media ID, bytes/sector, `0FH`, `DIRSFT`, (sec/clus)−1, `CLSSFT`,
first-FAT-sector, `FATCNT`, `MAXDIR`, first-data-sector, `MAXCLS`, `FATSIZ`,
first-dir-sector, sectors/track). The setup routine at `4F5F` indexes it by
`MediaID & 0x0F`. **The table in this ROM image ends at F9H (320 KB)** — bytes
past that row are code, so `FAH`–`FFH` from the Media-ID list above are the
TRM's documented ID *range*, not shipping-ROM geometry. `INIT` never formats
above **F8H (256 KB)** anyway.

Rows transcribed directly from the ROM (all: sector size `0200H`, `0BH`=`0FH`,
`DIRSFT`=`04H`, first FAT sector `0001H`, `FATSIZ`=`01H`, 8 sectors/track):

| KB | Media ID | (sec/clus)−1 | CLSSFT | FATCNT | MAXDIR | first data sector | MAXCLS | first dir sector |
|---|---|---|---|---|---|---|---|---|
| 16 | F0H | 00H | 01H | 1 | 20H | 0004H | 001DH | 0002H |
| 32 | F1H | 00H | 01H | 1 | 30H | 0005H | 003CH | 0002H |
| 64 | F2H | 00H | 01H | 2 | 30H | 0006H | 007BH | 0003H |
| 96 | F3H | 00H | 01H | 2 | 60H | 0009H | 00B8H | 0003H |
| 128 | F4H | 00H | 01H | 2 | 80H | 000BH | 00F6H | 0003H |
| 160 | F5H | 01H | 02H | 2 | 90H | 000CH | 009BH | 0003H |
| 192 | F6H | 01H | 02H | 2 | 90H | 000CH | 00BBH | 0003H |
| 224 | F7H | 01H | 02H | 2 | F0H | 0012H | 00D8H | 0003H |
| 256 | F8H | 01H | 02H | 2 | FEH | 0014H | 00F7H | 0003H |
| 320 | F9H | 03H | 03H | 2 | D0H | 0010H | 009DH | 0003H |

(The "first dir sector" column supersedes the earlier hand-transcribed
`0002H` for the `FATCNT`=2 rows: with two FAT copies the FAT occupies
sectors 1–2 and the directory starts at 3.)

From the TRM scan (not in this ROM's table — spec only): the 1024 KB
row would be `FFH | 07H | 04H | 2 | FEH | 0018H | 00FEH | 0003H`.

**Possible discrepancy, 128 KB (F4H) row.** The Systemhandbuch's own printed geometry
table (ch. 14, covering 16/32/64/128 KB) agrees with the ROM-derived table above for
every field of every row it lists — **except** first-data-sector for F4H, which it gives
as `0008H` against the ROM's `000BH`. Not resolved here (the floppy drive itself only
ever uses the F2H/64KB row per §2.1, so this only matters for larger RAM-disk modules);
flagged for a future cross-check against real 128 KB RAM-disk hardware or another ROM
dump.

**Media ID table pointer.** Distinct from the `5006H`-based per-row table above, the
Systemhandbuch also describes a **pointer** to the media-ID/geometry data, factory-set to
`4242H`, held in the disk buffer (§7 below) and changeable by software — this may be an
indirection layer in front of the fixed ROM table rather than a second copy of it; not
yet reconciled with the `5006H` addressing.

#### The table is INIT-only

Mount and `DSKF` do **not** re-consult this table for a formatted medium.
For any Media ID ≥ F2H the setup routine (`4F93`→`4F9A`) copies the boot
sector's own `08H..1AH` bytes into a RAM work area (`FC77H`) and the driver
runs from that copy. So a **hand-written boot sector with a Media ID this
ROM's table doesn't contain still mounts** — the basis of the third-party
superRAM 512 KB patch (§5.5).

`DSKF "d:"` returns **`(MAXCLS − 1) × sectors_per_cluster × 512`** bytes,
computed from the mounted volume's boot sector. Verified: F1H → 30208,
F3H → 93696, F7H → 220160.

### 5.3 FAT (§3.3.3(2)(b))

- The data area is split into **clusters**, up to **254** of them, each described by one
  FAT byte.
- **FAT byte 0** = the format ID code (= the Medium ID for the module's capacity, §5.2).
- **FAT bytes 1…254** = one entry per cluster (cluster 1 … cluster 254):
  - `00H` — cluster free
  - `01H`–`FEH` — cluster in use; the value is the **next** cluster number in the file's
    chain
  - `FFH` — last cluster of the file

This is a single-byte-entry FAT (like FAT12 truncated to 8-bit cluster numbers), and the
FCB's FAT-style packed date/time (§2) confirms the family resemblance to MS-DOS FAT.

### 5.4 Directory (TRM §3.8.3(4))

**32 bytes per entry** — an MS-DOS-FAT-style entry:

| Off | Size | Field |
|---|---|---|
| 00H–07H | 8 | file name (space-padded, `20H`); `E5H` = deleted entry |
| 08H–0AH | 3 | extension (space-padded) |
| 0BH | 1 | attribute/"Set-Code" — see below; default `20H` |
| 0CH–15H | 10 | reserved (always `00H`) |
| 16H–17H | 2 | update time — bit-packed, see below |
| 18H–19H | 2 | update date — bit-packed, see below |
| 1AH–1BH | 2 | first cluster number — `1AH` = the number, `1BH` = always `00H` |
| 1CH–1FH | 4 | file size in bytes, low → high |

(On a floppy the directory is logical sectors 3–5 = 48 entries per side. The RAM-disk
directory area is located by the boot sector's directory-area pointer, §5.2 — e.g. on a
2×32KB-module `S2:` example in the Systemhandbuch, the directory sits at absolute address
`8600H`.)

**Attribute/"Set-Code" byte (`+0BH`), normal value `20H`:**

| Bit | Meaning |
|---|---|
| b0 (`"P"`) | write-protected |
| b1 (`"I"`) | meaning not confirmed by the source (marked `?`) |
| b2 | hidden from the `FILES` command's listing |
| b5 | always set (part of the `20H` default) |

**Update time+date (`+16H`–`+19H`).** The Systemhandbuch gives each byte
left-to-right from b7 to b0, with `/` separating the high-bit field from the low-bit
field:

| Byte | Source text | b7…b0 |
|---|---|---|
| `+16H` | Minute (b2–b0) / 0 0 0 0 0 | minute b2–b0 in b7–b5; b4–b0 = `0` |
| `+17H` | Stunde (b4–b0) / Minute (b5–b3) | hour b4–b0 in b7–b3; minute b5–b3 in b2–b0 |
| `+18H` | Monat (b2–b0) / Tag (b4–b0) | month b2–b0 in b7–b5; day in b4–b0 |
| `+19H` | 0 0 0 0 0 0 0 Monat (b3) | b7–b1 = `0`; month b3 in b0 |

Read as two little-endian 16-bit words, this is exactly the conventional MS-DOS FAT
packing — the same as the FCB's `FTIM`/`FDAT` (§2) — with the fields the PC-1600 clock
doesn't have left at zero:

- **time** (`+16H/+17H`) = `hour << 11 | minute << 5 | 0` (seconds/2 field = `0`)
- **date** (`+18H/+19H`) = `0 << 9 | month << 5 | day` (year field = `0`; `TIME` has no year)

Example: 22 September, 14:37 → `A0 74 36 01`.

The scan prints the extension offset as `+0B-0A` (a typo for `08H–0AH`) and gives the
file size as two words, `+1CH` = size mod 65536 and `+1EH` = size \ 65536 — i.e. the
single 32-bit little-endian value in the table above.

(An earlier transcription of this section, made from a low-resolution scan, misplaced
the minute bits into the low bits of `+16H` and concluded the packing was non-standard;
the clean text above supersedes it.)

### 5.5 Patching the header past INIT's 256 KB ceiling

`INIT` only builds volumes up to `F8H` (256 KB), but §5.2 shows mount/`DSKF`
trust the boot sector, not the ROM table — so a bigger volume can be reached
by **formatting small, then rewriting the header in place**. This is what the
third-party *superRAM* module's `SUPERRAM.BIN` does; the same edit lives baked
into `Calc-U-1600`'s `superram.card.yaml` (commit `abdb369`).

Observed split-format layout (from CE-1601M-class dumps at 2/4/8 vertical
banks): **vbank 0** holds a bare geometry block (bytes `00H..07H` = `FF`, no
`55H`) with the Media ID for the *whole module*; **vbank 1** holds the mounted
volume's real boot sector with the Media ID for *(module − 32 KB)* — the 32 KB
reserved as `S0:` program memory — using that ID's standard table row. Logical
sector 0 of the volume is vbank 1 offset 0; the data area runs on linearly
through vbanks 2, 3, …

**512 KB example.** There is no Media ID for 480 KB (the steps are
256→320→384→512 = F8→F9→FA→FB), so the volume is described as `FBH` (512 KB)
with `MAXCLS` reduced by the carve:

- FBH row, extrapolated on the F9H pattern (2 KB clusters) and checked against
  the superRAM manual's `DSKF` figures 514048 (pure) / 481280 (32 KB carved):
  (sec/clus)−1 `03H`, `CLSSFT` `03H`, `FATCNT` 2, `MAXDIR` `FEH`,
  first-data-sector `0014H`, `MAXCLS` `00FCH` (252), first-dir-sector `0003H`.
- With a 32 KB `S0:` carve: `MAXCLS` `00FCH` − 16 (= 32 KB / 2 KB clusters) =
  `00ECH` (236) → `DSKF "S2:"` = (236 − 1) × 2048 = **481280**.
- vbank 0's block gets the pure FBH row (`MAXCLS` `00FCH`); FAT byte 0 (the
  format-ID copy) in both vbanks → `FBH`; boot-sector checksum at `02H`
  recomputed per §5.1.

## 6. RAM-disk IOCS routines (Bank 3) — Systemhandbuch ch. 14

A separate routine table from the file-IOCS one in §3 — these are the **RAM-disk's own
low-level driver routines** (parallel to the CE-1600F's disk-IOCS table in
`PC-1600-Peripherals-Hardware.md` §2.4, but for the built-in RAM-disk modules instead of
the floppy). **Dispatch:** IOCS number → `C`, slot number → `A` (`01H` = `S1:`, `02H` =
`S2:`), `CALL Bank 3, 4008H`.

| Name | # | Function |
|---|---|---|
| SET ID | `80H`–`87H` | same meaning as the corresponding CE-1600F routine (`PC-1600-Peripherals-Hardware.md` §2.4) |
| SET ID | `88H` | set the Media ID block, `(HL)+00H`..`(HL)+12H` |
| SECTSET | `89H` | bank-select by logical sector number; `DE` = logical sector number, → address in `HL` |
| LOGREAD | `8AH` | read sectors (count in `B`, `200H` bytes each) into `(HL)`; `DE` = number of the first **logical** sector (not track/sector) |
| LOGWRITE | `8BH` | write sectors from `(HL)`; params as `LOGREAD` |
| GET DISKSIZ | `8CH` | RAM-disk size in 16 KB units → `C` |
| GET RAMSIZ | `8DH` | installed RAM size in the slot given in `A` → `D` (16 KB units), `E` (remainder, 4 KB units) |
| SEARCH BOOT | `8EH` | search for a bootable program; found → `NC` (carry clear) and slot number written to `FC16H` |
| START BOOT | `8FH` | start (run) the boot program |
| SET DISKSIZ | `90H` | set the RAM-disk size, in 2 KB units, written to `F055H` (`S1:`) or `F05BH` (`S2:`) |

(The line "`c80–c87` sinngemäß wie bei der Diskettenstation" in the source means these
share the same function-code meanings as CE-1600F's `80H`–`87H` block — `DSKINIT`
through `HFVERIFY` — just addressed to Bank 3/RAM-disk instead of Bank 5/floppy; `88H`
onward is where the RAM-disk table diverges with its own routines.)

## 7. Disk buffer and IY-register work area — Systemhandbuch ch. 14

**Disk buffer.** Reserved at `CALL 4002H` (with `A` = `00H`/`01H`) reset time; its start
address is held at **`F038H`** (a generic 2-byte pointer slot per
`PC-1600-Work-Area-Map.md` §1 — this is its disk-specific use). Layout:

| Off | Size | Field |
|---|---|---|
| +000H–+1FFH | 512 B | buffer for one data or directory sector |
| +200H | 1 | which drive's sector is buffered: `01H` = "X", `02H` = "Y" |
| +201H–+20BH | 11 | name of the file currently present in the buffer |
| +20CH | 1 | `00H` = buffer contents not yet modified |
| +20DH | 1+ | logical number of the currently-buffered sector |
| +20FH–+30FH | — | FAT copy, drive "Y" |
| +310H–+410H | — | FAT copy, drive "X" |

**IY-register work area.** During disk routines, `IY` points at a fixed work block
(location relative to the buffer above, at offset `+411H` from its start) with connected-
drive bookkeeping distinct from the per-sector buffer:

| Off (from `IY`) | Field |
|---|---|
| +00H | start address of media-ID block, drive X |
| +02H | start address of FAT, drive X |
| +04H | `00H` |
| +05H | FAT checksum, drive X |
| +06H | start address of media-ID block, drive Y |
| +08H | start address of FAT, drive Y |
| +0AH | `00H` |
| +0BH | FAT checksum, drive Y |
| +0CH | number of connected drives |
| +0DH | last-used drive (`01H` = X, `02H` = Y) |
| +0EH | `00H` |
| +0FH | b2 = port `70H`–`73H`, b1 = port `78H`–`7BH`, b0 = abort on error |
| +10H | attribute mask for the `SET` command (default `D8H`) |
| +11H | retry count on read/write error |
| +12H | jump address for an invalid function code in `C` |
| +14H | stack pointer to restore on abort-by-error |
| +16H | port address in use (`70H` or `78H`) |
| +17H | `00H` |

**Low-level RAM-disk driver work area.** Byte-level driver state (`LOGFORM`/FAT
addresses, cluster/sector counters, error codes, etc.) at `FC00H`–`FCAFH` is documented in
`PC-1600-Work-Area-Map.md` §3.18, not repeated here — that file remains the home for all
F000H–FFFFH addresses.

## Open items

- `DIRSFT` / `CLSSFT` exact meaning (bit-shift counts for directory-entry-size and
  cluster-size arithmetic — infer from §3.8 or the ROM).
- `SET DMA` semantics — is it a real DMA address or just a transfer buffer pointer?
- 128 KB (F4H) geometry-table first-data-sector discrepancy (§5.2): Systemhandbuch
  says `0008H`, ROM dump says `000BH`.
- Media-ID table pointer at `4242H` (§5.2) vs. the ROM table's own `5006H` base —
  not yet reconciled.
- Attribute-byte b1 (`"I"`) meaning (§5.4) — the source itself marks it `?`.
