# PC-1600 File System (FCB, RAM-disk / floppy FAT)

## Scope

How the PC-1600 stores and accesses files: the file-type header, the File Control Block
(FCB), the file IOCS routines, and the FAT-style on-medium layout used by both RAM-disk
memory files and CE-1600F floppies.

**Sources:** PC-1600 Technical Reference Manual §3.3 ("Files") — §3.3.1 file types &
management, §3.3.2 file IOCS routines, §3.3.3 memory-file structure — read from the
German Systemhandbuch scan. §3.8.3 (floppy geometry, directory-entry format) is
**pending** and is cross-referenced where §3.3 defers to it.

---

## 1. File types and the 16-byte file header (§3.3.1(1))

The PC-1600 handles three file types:

1. **ASCII files** — no header.
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
`Creg 10` file-buffer allocation in `PC-1600-Memory-Bank-Switching.md` Part 6.)

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
| +29H..+38H | FFRE | per-device work area | 16 bytes; holds **current record** (≈ +30H) and **current block** (≈ +31H) — **128 records per block**; current record is set to `00H` by `OPEN`/`CREATE` and incremented by each `SEQUENTIAL RD`/`WR` (range `00H`–`7FH`) |
| +39H.. | — | file buffer | 256 bytes |

## 3. File IOCS routines (§3.3.2)

**Calling convention:** (1) set parameters in the FCB and registers; (2) put the IOCS
number in the **C register**; (3) `CALL 01DEH`. On return **every register is destroyed
except A**:

- `A = 00H` — normal completion.
- otherwise `A` is an **error bitfield**:

| Bit | Meaning |
|---|---|
| 7 | addressed device does not exist |
| 6 | device access failed |
| 5 | media error on the addressed device |
| 4 | this IOCS routine is not supported by that I/O |
| 3 | other |
| 2 | no more data to read |
| 1 | no space left to write on the medium |
| 0 | file not found, or directory full |

| Routine | IOCS # | Function |
|---|---|---|
| OPEN FILE | `0FH` | open a file |
| CLOSE FILE | `10H` | close a file |
| SEARCH FIRST | `11H` | find the first directory entry |
| SEARCH NEXT | `12H` | find the next directory entry |
| DELETE FILE | `13H` | delete a file |
| SEQUENTIAL RD | `14H` | sequential read |
| SEQUENTIAL WR | `15H` | sequential write |
| CREATE FILE | `16H` | create a file |
| RENAME FILE | `17H` | rename a file |
| SET DMA | `1AH` | set the transfer (DMA) address |
| GET ALLOC | `1BH` | read medium/file allocation info (e.g. free-cluster count) |
| SET ATTRB | `1EH` | set file attributes |

## 4. Memory files (RAM-disk) — physical structure (§3.3.3(1))

A memory file occupies **16 KB segments**. Usable modules: **CE-161** (16 KB),
**CE-1600M** / **CE-1620M** (32 KB; CE-1620M is the EPROM version, otherwise identical).

Slot / bank mapping (in the Z-80 8000H–BFFFH window):

| Module | In Slot 1 | In Slot 2 |
|---|---|---|
| 16 KB (CE-161) | Bank 0 | Bank 2 |
| 32 KB (CE-1600M/1620M) | Bank 0 + Bank 1 | Bank 2 + Bank 3 |

Larger capacities are reached through the Port 28H vertical-bank mechanism
(`PC-1600-Memory-Bank-Switching.md` Part 2) — "for future extension".

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
| 02H | checksum |
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

Per-size (selected rows):

| KB | Media ID | (sec/clus)−1 | CLSSFT | FATCNT | MAXDIR | first data sector | MAXCLS | first dir sector |
|---|---|---|---|---|---|---|---|---|
| 16 | F0H | 00H | 01H | 1 | 20H | 0004H | 001DH | 0002H |
| 32 | F1H | 00H | 01H | 1 | 30H | 0005H | 003CH | 0002H |
| 64 | F2H | 00H | 01H | 2 | 30H | 0006H | 007BH | 0002H |
| 128 | F4H | 00H | 01H | 2 | 80H | 000BH | 00F6H | 0002H |
| 256 | F8H | 01H | 02H | 2 | FEH | 0014H | 00F7H | 0003H |
| 1024 | FFH | 07H | 04H | 2 | FEH | 0018H | 00FEH | 0003H |

(The full 16-row table is in the scan; transcribe the rest if a specific capacity is
needed.)

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
| 00H–07H | 8 | file name (space-padded, `20H`) |
| 08H–0AH | 3 | extension (space-padded) |
| 0BH | 1 | attribute — b0: 0 = read/write, 1 = read-only; b1–7 reserved |
| 0CH–15H | 10 | reserved (always `00H`) |
| 16H–17H | 2 | update time — packed `[hour][minute][second/2]` |
| 18H–19H | 2 | update date — packed `[year][month][day]` (year from 1980) |
| 1AH–1BH | 2 | first cluster number — `1AH` = the number, `1BH` = always `00H` |
| 1CH–1FH | 4 | file size in bytes, low → high |

(On a floppy the directory is logical sectors 3–5 = 48 entries per side. The RAM-disk
directory area is located by the boot sector's directory-area pointer, §5.2.)

## Open items

- The full 16-row media-ID geometry table (§5.2).
- Directory-entry byte layout (§3.8.3(4)).
- `DIRSFT` / `CLSSFT` exact meaning (bit-shift counts for directory-entry-size and
  cluster-size arithmetic — infer from §3.8 or the ROM).
- `SET DMA` semantics — is it a real DMA address or just a transfer buffer pointer?
