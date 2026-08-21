# Sharp PC-1500 Tape Format — Technical Reference

This document describes the FSK audio tape format used by the Sharp PC-1500 series pocket computers, as reverse-engineered from the C reference tool (`wav2bin_211c1d2.c`) and confirmed by successfully decoding a live recording (`advmath_sharp-pc-1500.wav`).

---

## WAV File Characteristics

The test recording (`advmath_sharp-pc-1500.wav`) has the following properties:

| Property     | Value        |
|--------------|--------------|
| Sample rate  | 5000 Hz      |
| Channels     | 1 (mono)     |
| Bit depth    | 8-bit PCM    |
| Data size    | 686,880 bytes |
| Format       | SuperTape (lead-in at 1250 Hz) |

> **Note:** The C reference tool (`wav2bin_ref`) identifies this recording as "SuperTape of PC-1500" and refuses to decode it. SuperTape uses a 1250 Hz lead-in tone rather than the standard 2500 Hz. The data encoding itself is identical to standard PC-1500 tape.

---

## FSK Encoding

The PC-1500 uses Frequency Shift Keying (FSK) with two frequencies:

| Signal       | Frequency | Period at 5000 Hz SR |
|--------------|-----------|----------------------|
| Sync / Bit 0 | 1250 Hz   | 4 samples            |
| Bit 1        | 2500 Hz   | 2 samples            |

**Detection threshold:** `sampleRate / 3.0` (≈ 1667 Hz at 5000 Hz).
- Period frequency **below** threshold → low frequency → Bit 0
- Period frequency **above** threshold → high frequency → Bit 1

### Period Detection

A "period" is measured as the number of samples for one full waveform cycle — i.e., from the current zero-crossing direction to the second subsequent zero-crossing (two half-cycles). The threshold is calculated dynamically from the min/max of the first 1000 samples.

---

## Nibble Frame Format

Data is transmitted as 4-bit nibbles. Each nibble is encoded as a serial frame:

```
[Start bit] [b0] [b1] [b2] [b3] [Stop bits...]
```

- **Start bit:** Low frequency (Bit 0 = 1250 Hz). Validates that a real frame is starting.
- **Data bits b0–b3:** LSB first. Each bit is confirmed by counting cycles in a window:
  - High-frequency bit: 8 transition cycles expected
  - Low-frequency bit: 4 transition cycles expected
  - Majority vote (ones vs zeros) determines the bit value.
- **Stop bits:** High frequency (Bit 1). One or more stop bits follow each nibble.

### Nibble Value Assembly

```
nibble = b0 * 1 + b1 * 2 + b2 * 4 + b3 * 8
```

---

## Byte Encoding: ORDER_INV

The PC-1500 uses **ORDER_INV** byte encoding (defined in the C reference as `ORDER_INV = 1`):

- The **low nibble (lsq)** of a byte is transmitted **first**.
- The **high nibble (msq)** of a byte is transmitted **second**.
- Reconstruction: `byte = (msq << 4) | lsq`

This is the inverse of the more common ORDER_STD (`byte = (msq << 4) | lsq` with msq first).

**Example — byte `0x10`:**

```
Tape transmission:  lsq=0x0 (first)  →  msq=0x1 (second)
Reconstruction:     (0x1 << 4) | 0x0  =  0x10  ✓
```

---

## Tape Structure

A complete PC-1500 BAS file on tape is laid out as follows:

```
┌─────────────────────────────────────────┐
│  Sync tone (1250 Hz, several seconds)   │
├─────────────────────────────────────────┤
│  Ident nibble: 0x0A  (1 nibble, 4 bits) │
├─────────────────────────────────────────┤
│  Header block: 40 bytes (ORDER_INV)     │
│  (block counter: 40 → 80 → checksum)    │
├─────────────────────────────────────────┤
│  Header checksum: 2 bytes (4 nibbles)   │
├─────────────────────────────────────────┤
│  Data block 1:   80 bytes (ORDER_INV)   │
│  Checksum 1:      2 bytes (4 nibbles)   │
├─────────────────────────────────────────┤
│  Data block 2:   80 bytes (ORDER_INV)   │
│  Checksum 2:      2 bytes (4 nibbles)   │
├─────────────────────────────────────────┤
│  ...                                    │
├─────────────────────────────────────────┤
│  Data block N:   ≤80 bytes (ORDER_INV)  │
│  (no checksum for the final partial     │
│   block — the block counter does not    │
│   reach the next multiple of 80)        │
└─────────────────────────────────────────┘
```

### Block Counter Mechanics (`BLK_OLD = 80`)

The C reference tool uses an internal byte counter (`ptrFile->count`) that starts at `BLK_OLD - 40 = 40` immediately after the ident nibble is read. Each header or data byte increments the counter. When the counter reaches a multiple of `BLK_OLD` (80), a 2-byte checksum is read from the tape and the checksum accumulator is reset. The counter itself is never reset.

```
After ident nibble:  count = 40
After 40 header bytes: count = 80  → checksum triggered (first checksum)
After 80 data bytes:   count = 160 → checksum triggered
After 80 data bytes:   count = 240 → checksum triggered
...
```

Checksum bytes are read with `ReadByteFromWav` (not `ReadByteSumFromWav`) and therefore do **not** increment the counter.

---

## Header Block Layout (40 bytes, ORDER_INV)

| Byte index | Count in C | Size  | Content                          | Notes                          |
|------------|------------|-------|----------------------------------|--------------------------------|
| —          | —          | 4 bits| **Ident nibble:** `0x0A`         | Not counted in block counter   |
| 0–7        | 40–47      | 8     | Fixed sync bytes: `0x10`–`0x17` | Verified by decoder            |
| 8          | 48         | 1     | Sub-type byte                    | `0x01` = BAS, `0x00` = BIN, `0x02` = RSV, `0x03` = DEF, `0x04` = DAT |
| 9–24       | 49–64      | 16    | Filename (ASCII, zero-padded)    |                                |
| 25–33      | 65–73      | 9     | Padding (zeros)                  |                                |
| 34–35      | 74–75      | 2     | Start address (hi, lo)           |                                |
| **36–37**  | **76–77**  | **2** | **Data length (hi, lo)**         | `dataLength = (hdr[36]<<8)\|hdr[37]` |
| 38–39      | 78–79      | 2     | Entry address (hi, lo)           |                                |

After reading all 40 header bytes the block counter reaches 80, triggering the first 2-byte checksum.

**Full ident word** (formed after reading sub-type):
```
ident = (0x0A << 4) | (subtype & 0x0F)
```
| Ident  | Value  | Meaning              |
|--------|--------|----------------------|
| `0xA0` | `0x0A` ident + `0x0` sub | BIN (binary image) |
| `0xA1` | `0x0A` ident + `0x1` sub | BAS (BASIC program)  |
| `0xA2` | `0x0A` ident + `0x2` sub | RSV (reserve)        |
| `0xA3` | `0x0A` ident + `0x3` sub | DEF (definable keys) |
| `0xA4` | `0x0A` ident + `0x4` sub | DAT (data)           |

---

## Checksums

Each 2-byte checksum is a running sum of all data bytes in the block, accumulated nibble by nibble (ORDER_INV). The checksum is transmitted as two bytes (high byte first, low byte second) using `ReadByteFromWav` with ORDER_INV:

```
checksum_word = (sumH << 8) | sum
```

The 2-byte checksum occupies **4 nibble frames** on the tape (2 bytes × 2 nibbles per byte). When decoding without checksum verification these 4 nibble positions are simply skipped.

---

## Decoding Algorithm (Java Implementation)

```
1. Parse WAV header → sampleRate, dataSize
2. Load PCM samples into byte array
3. Compute dynamic threshold = (min + max) / 2 from first 1000 samples

4. Collect nibbles:
   for each sample position:
     period = detectPeriod(samples, pos, threshold)
     if period <= 0: advance by 1, continue
     freq = sampleRate / period
     if freq < sampleRate / 3.0:        // possible nibble frame
       read 11 bits (start + 4 data + stop) via majority vote over cycles
       if bits[0] == 0:                 // valid start bit
         nibble = bits[1] + bits[2]*2 + bits[3]*4 + bits[4]*8
         append nibble to list
         advance pos to end of frame
       else: advance pos by period
     else: advance pos by period        // high-freq → skip (sync or bit 1)

5. Locate ident: scan nibble list for first value == 0x0A; skip it

6. Read 40 header bytes with ORDER_INV:
   for i in 0..39:
     lsq = nibbles[ni++]
     msq = nibbles[ni++]
     hdr[i] = (msq << 4) | lsq

7. Extract dataLength = (hdr[36] << 8) | hdr[37]

8. Skip first checksum: ni += 4  (2 bytes × 2 nibbles)

9. Read data:
   blockCount = 0
   for bytesRead in 0..<dataLength:
     lsq = nibbles[ni++]
     msq = nibbles[ni++]
     output.write((msq << 4) | lsq)
     blockCount++
     if blockCount == 80 and bytesRead+1 < dataLength:
       ni += 4           // skip 2-byte checksum
       blockCount = 0

10. Return output bytes
```

---

## Worked Example: `advmath_sharp-pc-1500.wav`

| Property          | Value                   |
|-------------------|-------------------------|
| File type         | PC-1500 BASIC (BAS)     |
| Filename on tape  | `ADVMATH`               |
| Sub-type byte     | `0x01`                  |
| Full ident        | `0xA1` (IDENT_PC15_BAS) |
| Start address     | `0x0000`                |
| Data length       | `0x071C` = **1820 bytes** |
| Entry address     | `0x1000`                |
| Data blocks       | 22 full (80 B) + 1 partial (60 B) = 23 total |
| Checksums skipped | 1 (header) + 22 (full blocks) = 23 × 2 bytes = 46 bytes |
| Reference BIN     | 1820 bytes, starts with `00 01 4D 22 20 22 F0 85 3A F1...` |

### Nibble stream accounting

```
1 nibble   — ident (0x0A)
80 nibbles — 40 header bytes
4 nibbles  — header checksum
3640 nibbles — 1820 data bytes
88 nibbles — 22 intermediate checksums (22 × 4)
─────────────────────────────────────
3813 nibbles total after sync tone
```

---

## Key Constants (from `wav2bin_211c1d2.c`)

```c
#define BLK_OLD         80      // block size for PC-1500
#define ORDER_INV        1      // lsq first, msq second
#define IDENT_PC1500  0x0A      // sync ident nibble
#define IDENT_PC15_BAS 0xA1     // BASIC file
#define EOF_15         0x55     // end-of-file marker (not present in BAS output)
#define BASE_FREQ2     2500     // standard PC-1500 base frequency (Hz)
#define BASE_FREQ5     1250     // SuperTape lead-in (unsupported by C tool)
#define BIT_0            8      // transitions per bit period (low)
#define BIT_1           16      // transitions per bit period (high)
```

---

## SuperTape vs. Standard PC-1500

| Property            | Standard PC-1500 | SuperTape          |
|---------------------|------------------|--------------------|
| Sync/lead-in tone   | 2500 Hz          | 1250 Hz            |
| Start bit           | 1250 Hz (low)    | 2500 Hz (high)     |
| Bit 0               | 1250 Hz          | 1250 Hz            |
| Bit 1               | 2500 Hz          | 2500 Hz            |
| Supported by C tool | Yes              | No                 |
| Supported by Java decoder | Yes        | Yes                |

The Java decoder is insensitive to the sync tone inversion because it only begins accumulating nibbles once the FSK signal falls below the `sampleRate / 3.0` frequency threshold, which correctly filters both sync types. The data bit encoding is identical in both formats.
