# PC-1500 / PC-1600 WAV Cassette Format

> Extracted from `SharpWavAnalysis/spec.md` (in the separate `SharpWavAnalysis`
> repository, left unchanged there). That document also covers the PC-1261, PC-1401,
> and PC-1403 cassette formats, which are out of scope here and were not copied.
> Derived from analysis of the `bin2wav` C reference encoder (version 2.1.1 c1d) and
> verified against real WAV/img pairs.

**Scope:** The `.img` file is the raw binary body of the program (no headers). This
spec covers what is prepended (binary header) and how the combined stream is encoded
to PCM audio. Parsing BASIC tokens and generating the `.img` content itself are out of
scope.

## Common WAV Container

All models use a standard RIFF/WAV file with 8-bit unsigned PCM, mono.

| Field            | Value                             |
|------------------|-----------------------------------|
| Format           | PCM (type 1)                      |
| Channels         | 1 (mono)                          |
| Bit depth        | 8 bits/sample                     |
| Sample rate      | model-specific (see each section) |
| Byte rate        | = sample rate (8-bit mono)        |

**Amplitude constants** (sample values, 0 = min, 255 = max):

| Name       | Value | Meaning                    |
|------------|-------|----------------------------|
| `AMP_MID`  | 0x80  | DC offset / silence level  |
| `AMP_HIGH` | 0xDA  | Peak positive (PC-1500) |
| `AMP_LOW`  | 0x26  | Peak negative (PC-1500) |
| `AMP_HIGH_E` | 0xFC | Peak positive (PC-1600)    |
| `AMP_LOW_E`  | 0x04 | Peak negative (PC-1600)    |

Silence regions are filled with `AMP_MID` (0x80).

---

## PC-1500

### A) Binary header prepended to raw `.img` data

```
[Sync] [TAP nibble] [Header block: 40 bytes + 2-byte checksum]
[75 sync bits]
[Body: img bytes + checksum every 80 bytes]
[Footer]
```

#### TAP nibble

Before the header, a single nibble `0x0A` (`IDENT_PC1500`) is written with
**6 stop bits** (using `WriteQuaterToWav`):

```
[start=Bit0] [1,0,1,0] [6 × Bit1 stop]   = 11 signal bits
```

This nibble is transmitted with ORDER_INV rules (LSN first), so it is the
first nibble in the stream.

#### Header block (42 bytes total)

Written with ORDER_INV (LSN first, then MSN per byte), MODE_B22 (stopb1=6,
stopb2=6).  The 40 data bytes are followed by a 2-byte checksum:

| Offset | Size | Content |
|--------|------|---------|
| 0–7    | 8    | Preamble bytes 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17 |
| 8      | 1    | Sub-ident: `0x01` (BASIC image), `0x00` (binary), `0x02` (RSV), `0x03` (DEF), `0x04` (DAT) |
| 9–24   | 16   | Filename, NUL-padded to 16 characters |
| 25–33  | 9    | Reserved / null bytes |
| 34–35  | 2    | Load address, big-endian (default 0x00C5 for BASIC IMG) |
| 36–37  | 2    | Buffer size = body byte count, big-endian |
| 38–39  | 2    | Entry address, big-endian |
| 40–41  | 2    | Checksum of bytes 0–39 (2-byte simple sum, big-endian) |

**Header checksum** (simple byte sum):
```
sum = 0
for b in bytes[0..39]: sum += b
checksum = sum & 0xFFFF
```
Written big-endian: `[sum >> 8, sum & 0xFF]` using `WriteByteTo15Wav`
(not via `WriteByteSumTo15Wav`, so these bytes do NOT reset the running sum).

**Filename:** Names up to 16 characters, NUL-padded, stored in plain ASCII
(no reversal or nibble-swapping).

#### Body

Written with ORDER_INV, MODE_B22.  A 2-byte simple-sum checksum is appended
after every 80 bytes (`BLK_OLD = 80`).  Checksum is big-endian; running sum
resets to zero after each checksum.

**Body checksum algorithm:**
```
sum = 0
for b in block_bytes: sum += b
checksum = sum & 0xFFFF  # written as [sum>>8, sum&0xFF]
```

#### Footer

Written with `WriteFooterTo15Wav`:

| Element      | Value / Notes |
|--------------|---------------|
| `BAS_1500_EOF` | `0xFF` — written via `WriteByteSumTo156Wav`, included in running body checksum |
| Final checksum | 2-byte simple sum over the current (partial) block including the 0xFF; written if `count > 0` |
| Sync          | 72 Bit1 sync bits |
| `EOF_15`      | `0x55` — raw byte (not checksummed) |
| Sync          | 70 Bit1 sync bits |
| Shutdown      | Signal ramp-down |

### B) WAV encoding

#### Signal parameters

| Parameter      | Value              |
|----------------|--------------------|
| Sample rate    | 44 100 Hz          |
| Bit duration   | 144 samples        |
| Bit0 frequency | ≈ 1 225 Hz (4 cycles / bit) |
| Bit1 frequency | ≈ 2 450 Hz (8 cycles / bit) |
| Polarity       | **inverted** (`bitMirroring = true`: `+` → AMP_LOW, `-` → AMP_HIGH) |
| Waveform       | near-sinusoidal (bit3_15 table) |

Due to `bitMirroring = true`, the amplitude labels in the waveform table are
swapped compared to the GRP_NEW models (PC-1261/1401/1403). Zero-crossing
frequency detection is identical regardless of polarity.

#### Sync preamble

Default minimum ≈ 1.875 seconds at 44.1 kHz ≈ 82 000 Bit1 symbols.
Between header and body: 75 Bit1 sync bits.

#### Nibble framing (PC-1500)

ORDER_INV: **LSN is transmitted first**, then MSN.

| Mode     | Use      | stopb1 (first nibble) | stopb2 (second nibble) | Bits/byte |
|----------|----------|-----------------------|------------------------|-----------|
| MODE_B22 | All data | 6                     | 6                      | 22        |

Each nibble frame: 1 start + 4 data + 6 stop = 11 bits.  Byte total = 22 bits.

---

## PC-1600

### A) Binary header prepended to raw `.img` data

```
[Sync] [Header block: 48 bytes + 2-byte checksum]
[Inter-block sync]
[Body: img bytes + checksum every 256 bytes]
[Footer]
```

#### Header block (50 bytes total)

Written with ORDER_E (byte-level MSB-first, no nibbles), MODE_B9.  The 48
data bytes are followed by a 2-byte bit-count checksum.

| Offset | Size | Content |
|--------|------|---------|
| 0      | 1    | File ID: `0x02` (`IDENT_E_BAS` — BASIC image) |
| 1–16   | 16   | Filename, NUL-padded to 16 bytes (plain ASCII, no swapping) |
| 17     | 1    | `0x0D` separator |
| 18–19  | 2    | Data block length (= body byte count), little-endian |
| 20–21  | 2    | Load address, little-endian |
| 22–23  | 2    | Entry address, little-endian |
| 24     | 1    | Sub-ident: `0x01` (BASIC), `0x00` (BIN) |
| 25–28  | 4    | Date/time: Month, Day, Hour, Minute (Month=1, Day=1, Hour=0, Min=0) |
| 29     | 1    | Extended data length (bits 16–23) |
| 30     | 1    | Extended load address (bits 16–23) |
| 31     | 1    | Extended entry address (bits 16–23) |
| 32–47  | 16   | Reserved (null bytes) |
| 48–49  | 2    | Bit-count checksum over bytes 0–47, big-endian |

**Filename note:** The encoder appends the `.BAS` extension for BASIC images,
e.g. a base name of `SIMPLE` is stored as `"SIMPLE.BAS\0\0\0\0\0\0"` (bytes
1–16 = `SIMPLE.BAS` followed by 6 NUL bytes).

**Bit-count checksum algorithm** (`CheckSumE`):
```
count = 0
for b in block_bytes:
    count += popcount(b)   # number of 1-bits in b
checksum = count & 0xFFFF  # written as [count>>8, count&0xFF]
```

#### Body

Written with ORDER_E (byte-level, MSB-first).  A 2-byte bit-count checksum
is appended after every 256 bytes (`BLK_E_DAT = 256`).  Running count resets
after each checksum.

#### Footer

Written by `WriteFooterToEWav`:

| Element            | Notes |
|--------------------|-------|
| Final checksum     | 2-byte bit-count sum over remaining body bytes (if non-empty partial block) |
| Stop bit           | One Bit1 (shutdown ramp-down) |
| Silence            | AMP_MID samples |

### B) WAV encoding

#### Signal parameters

| Parameter      | Value              |
|----------------|--------------------|
| Sample rate    | 48 000 Hz          |
| Bit0 duration  | **16 samples** (1 cycle = 3 000 Hz) |
| Bit1 duration  | **40 samples** (1 cycle = 1 200 Hz) |
| Polarity       | normal (`+` → AMP_HIGH_E, `-` → AMP_LOW_E) |
| Waveform       | near-rectangular (bitE3 table) |

**Important:** Unlike the other models, each bit has a **different** number
of samples depending on its value (variable-length FSK).  There are no stop
bits; bytes are separated only by frame alignment.

#### Sync preamble

Before the header block, `WriteSyncToEWav` writes:

```
[space: silence bits (AMP_MID), minimum ≈ 3 seconds]
[nbSync × Bit0]              // leading sync: 10 000 bits (0x2710) before header
[SYNC_E_HEAD × Bit1]         // SYNC_E_HEAD = 40
[SYNC_E_HEAD × Bit0]         // SYNC_E_HEAD = 40
[1 × Bit1]                   // sync-end marker
```

Between header and data blocks, `WriteSyncToEWav` writes the same pattern
but with `SYNC_E_DATA = 20` instead of `SYNC_E_HEAD = 40`, and a longer
leading Bit0 run of **10 744 bits** (0x2AF8) instead of 10 000 (0x2710).
(Verified against Sharp PC-1600 Systemhandbuch, chapter 12.)

#### Byte framing (E-series)

`WriteByteToEWav` writes each byte as:

```
[start bit = Bit1 (40 samples)]
[data bit 7 = MSB]  ← Bit0 (16 s) for 0, Bit1 (40 s) for 1
[data bit 6]
[data bit 5]
[data bit 4]
[data bit 3]
[data bit 2]
[data bit 1]
[data bit 0 = LSB]
```

Total bits per byte: **9** (1 start + 8 data).  **No stop bits.**

Byte boundaries are determined by counting exactly 9 bit-durations from each
start bit.  The start bit is always Bit1 (1 200 Hz, long period).

---

## Summary Table (PC-1500 / PC-1600 rows)

| Model   | Sample rate | Bit0 freq | Bit1 freq | Bits/byte | Checksum period | Checksum type   |
|---------|-------------|-----------|-----------|-----------|-----------------|-----------------|
| PC-1500 | 44 100 Hz   | ≈1 225 Hz | ≈2 450 Hz | 22        | 80 bytes        | byte-sum (2B)   |
| PC-1600 | 48 000 Hz   | 3 000 Hz  | 1 200 Hz  | 9 (no stop) | 256 bytes (body) | bit-count (2B) |

### Byte-sum checksum detail (PC-1500, 2-byte)

```python
sum = 0
for b in data: sum += b
checksum_hi = (sum >> 8) & 0xFF
checksum_lo = sum & 0xFF
```

### Bit-count checksum detail (PC-1600, 2-byte)

```python
count = 0
for b in data: count += bin(b).count('1')
checksum_hi = (count >> 8) & 0xFF
checksum_lo = count & 0xFF
```

## Open Questions / Notes (PC-1500 / PC-1600 relevant)

1. **PC-1500 `BAS_1500_EOF` in checksum:** The footer byte 0xFF is passed
   through `WriteByteSumTo156Wav`, so it is **included** in the final
   body checksum.  The checksum that follows covers all body bytes plus
   this 0xFF.
2. **PC-1600 sync-end bit:** `WriteSyncToEWav` emits one extra Bit1 at the
   end of each sync section (before each block).  This is a "sync-end marker"
   that is separate from the start bit of the first byte frame.  A decoder
   must skip this extra Bit1 before parsing byte frames.
3. **PC-1600 data_len in header:** Header bytes 18–19 hold the body length
   (little-endian).  The decoder uses this value to read exactly that many
   body bytes.
4. **Filename encoding:** PC-1500 and PC-1600 store filenames in plain ASCII
   order (no nibble-swap, no reversal) — unlike the GRP_NEW models
   (PC-1261/1401/1403), which use `SwapByte`.
