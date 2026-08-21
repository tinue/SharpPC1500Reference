# Sharp Pocket Computer — Serial Binary Format Specification

This document describes the binary file formats produced and consumed by the Sharp PC-1500
(with CE-158 interface) and PC-1600 pocket computers when transferring data over the serial
link.  It covers both header formats and all four payload types: BASIC, Machine Language,
Reserve Area, and Variables.

Sources: Sharp PC-1500 Technical Reference Manual (especially §5-3, §13); hardware dumps
captured from real PC-1500 hardware (see `src/test/resources/dumps/`).

---

## 1. File Structure

Every binary transfer file has the form:

```
[header] [payload]
```

There is **no checksum** appended to the file.  The header identifies the device, data
type, and (where meaningful) the payload length.  The payload immediately follows.

Two header formats exist, one per device family:

| Header | Used by | Size |
|---|---|---|
| CE-158 | PC-1500, PC-1500A | 27 bytes |
| PC-1600 | PC-1600 | 16 bytes |

---

## 2. CE-158 Header (PC-1500 / PC-1500A)

### 2.1 Layout

| Offset | Size | Field | Notes |
|---|---|---|---|
| 0x00 | 1 | Magic | Always `0x01` |
| 0x01 | 1 | Type byte | See §2.2 |
| 0x02 | 3 | `"COM"` | ASCII `0x43 0x4F 0x4D` — magic continuation |
| 0x05 | 16 | Filename | CP437, null-padded to 16 bytes; trailing nulls trimmed on read |
| 0x15 | 2 | Load start address | Big-endian; meaningful for MACHINE only; `0x0000` otherwise |
| 0x17 | 2 | Data length | Big-endian; **capacity − 1** encoding (see §2.3); not meaningful for VARIABLES |
| 0x19 | 2 | Auto-run address | Big-endian; meaningful for MACHINE only; `0x0000` otherwise |

**Total: 27 bytes.**

Detection: `data[0] == 0x01 && data[2..4] == "COM"`.

### 2.2 Type Byte

| Value | ASCII | Payload type |
|---|---|---|
| `0x40` | `@` | Tokenized BASIC program |
| `0x41` | `A` | Reserve Area |
| `0x42` | `B` | Machine language |
| `0x48` | `H` | Variables |

### 2.3 Length Field Encoding

The length field stores **capacity − 1**, i.e. `actual_payload_length − 1`.

- Reading: `payload_length = wire_value + 1`
- Writing: `wire_value = payload_length − 1`

Confirmed from hardware: the Reserve Area dump is 215 bytes total = 27-byte header +
188-byte payload; the wire length field is `0x00BB` = 187 = 188 − 1.

**Exception — VARIABLES:** the length field is always `0x0000` (parsed as 1, meaningless).
The true payload extent must be determined by reading records until EOF (see §6).

### 2.4 Address and Filename Notes

- **Filename**: The 16-byte field is null-padded (not space-padded).  Read with `trim()`.
  Maximum filename length is 16 characters.
- **Load start address** (RESERVE type): hardware stores `0x0008` here — the byte offset
  into the reserve area (base 4000H, data starts at 4008H skipping the ROM status block).
  This field is for hardware reference only; converters treat it as zero.
- **All addresses**: big-endian 2-byte unsigned integers.

---

## 3. PC-1600 Header

### 3.1 Layout

| Offset | Size | Field | Notes |
|---|---|---|---|
| 0x00 | 4 | Magic | `0xFF 0x10 0x00 0x00` |
| 0x04 | 1 | Type byte | See §3.2 |
| 0x05 | 3 | Data length | Little-endian, 3 bytes; actual payload length (no capacity−1 encoding) |
| 0x08 | 3 | Load start address | Little-endian, 3 bytes; MACHINE only; `0x000000` otherwise |
| 0x0B | 3 | Auto-run address | Little-endian, 3 bytes; MACHINE only; `0x000000` otherwise |
| 0x0E | 2 | End marker | Always `0x00 0x0F` |

**Total: 16 bytes.**

Detection: `data[0] == 0xFF && data[1] == 0x10 && data[2] == 0x00 && data[3] == 0x00`.

### 3.2 Type Byte

| Value | Payload type |
|---|---|
| `0x21` | Tokenized BASIC program |
| `0x10` | Machine language |
| others | RESERVE / VARIABLES — type bytes **not yet determined** (no hardware data available) |

### 3.3 Differences from CE-158

- **No filename**: the PC-1600 header carries no filename field.
- **3-byte addresses**: all addresses and the length are 3-byte little-endian (supporting
  the PC-1600's larger address space).
- **Length is direct**: no capacity−1 encoding; the length field holds the exact payload
  byte count.
- **End marker**: the two bytes `0x00 0x0F` terminate the header.

---

## 4. Payload: Tokenized BASIC

Source: Sharp PC-1500 Technical Reference Manual §5-3-5.

The BASIC payload is a linked list of tokenized program lines stored sequentially.  The
PC-1500 re-chains the lines into RAM at their actual load addresses after reception.

### 4.1 Line Structure

```
[next_addr: 2 bytes BE] [line_no: 2 bytes BE] [tokens...] [0x00]
```

| Field | Size | Content |
|---|---|---|
| Next address | 2 bytes, big-endian | RAM address of the next line (set by PC after load) |
| Line number | 2 bytes, big-endian | BASIC line number |
| Tokens | variable | Tokenized line content (see §4.2) |
| Line terminator | 1 byte | Always `0x00` |

### 4.2 Token Encoding

| Byte range | Meaning |
|---|---|
| `0x20`–`0x7F` | Literal character (ASCII / CP437) |
| `0xF0 xx` | BASIC keyword, first token table |
| `0xF1 xx` | BASIC keyword, second token table |

The full keyword-to-token mapping is maintained by the `KeywordRegistry` in the
SharpBasicShared library.

### 4.3 Program Terminator

The payload ends with a two-byte null next-address: `0x00 0x00`.  This signals end of
program to the PC.

---

## 5. Payload: Machine Language

The payload is **raw machine code bytes** with no framing or structure.

- **CE-158**: load address and optional auto-run address are in the header (§2.1).
- **PC-1600**: same, using the 3-byte header fields.
- The payload is loaded verbatim at the address given in the header's load start address
  field.  If the auto-run address is non-zero (CE-158: non-`0x0000`; PC-1600: non-`0x000000`)
  execution begins there after loading.

---

## 6. Payload: Variables

Source: Sharp PC-1500 Technical Reference Manual §5-3-1 through §5-3-3; confirmed from
four hardware dumps in `src/test/resources/dumps/`.

### 6.1 Overview

The Variables payload is a **positional** sequence of variable records — no variable names
are stored.  The PC-1500 loads values into variables in the order they were saved; the
program must have `INPUT#` preceded by the same variable **types** and **dimensions**
in the same order as the original `PRINT#` (variable names do not need to match).

If the incoming data contains fewer records than the `INPUT#` statement expects, the
PC-1500 fills the remaining variables with zeroes (numeric) or empty strings.  If the
incoming data contains more records than expected, the extra data is ignored.

Each record is preceded by a `0x00` separator byte, including the first:

```
[0x00] [4-byte prefix] [data]   ← repeated for each variable / array
```

The CE-158 length field is always `0x0000` for Variables files (meaningless).  Read until
EOF; there is no trailing terminator byte after the last record.

### 6.2 Record Prefix — Discriminator

**Prefix byte 1** distinguishes simple variables from DIM'd arrays; **prefix byte 3**
distinguishes numeric from string:

| byte 1 | byte 3 | Interpretation |
|---|---|---|
| `0x00` | `0x88` | Simple numeric scalar (or `DIM A(0)` — indistinguishable) |
| `0x00` | `0x10` | Simple string scalar, 16-byte slot (or `DIM A$(0)*16` — indistinguishable) |
| `0x00` | other | `DIM A$(0)*L` with max_len = byte 3 |
| non-zero | `0x88` | Numeric array: dim_max = byte 1, `(dim_max+1)` × 8-byte BCD values |
| non-zero | other | String array: dim_max = byte 1, max_len = byte 3 |

### 6.3 Simple Variable Prefix (byte 1 = `0x00`)

| Byte | Content |
|---|---|
| 0–1 | `len_minus_1`: total record length − 1, **little-endian** (record = prefix + data) |
| 2 | Always `0x00` |
| 3 | Type: `0x88` = numeric (BCD float), `0x10` = string |

Since simple-var records are at most 20 bytes, byte 1 of the LE16 length is always `0x00`,
making the discriminator unambiguous.

#### Numeric record

Prefix `0B 00 00 88` — total record 12 bytes (4 prefix + 8 data).

The 8-byte data field holds the numeric value; two encodings are possible (distinguished
by data byte 4):

**BCD float** (data byte 4 ≠ `0xB2`):

| Byte | Content |
|---|---|
| 0 | Exponent — signed 8-bit two's complement, range −99 to +99 |
| 1 | Mantissa sign — `0x00` = positive, `0x80` = negative |
| 2–6 | Mantissa — 5 bytes packed BCD, 10 digits; implicit decimal point after digit 1 |
| 7 | Always `0x00` |

Value = sign × mantissa\_as\_1.xxxxxxxxx × 10^exponent

Examples:

| Bytes (hex) | Value |
|---|---|
| `03 00 15 00 00 00 00 00` | 1500 |
| `FD 00 12 34 56 78 90 00` | 0.001234567890 |
| `08 80 12 34 00 00 00 00` | −1.234 × 10⁸ |
| `00 00 00 00 00 00 00 00` | 0 |

**Binary integer** (data byte 4 = `0xB2`):

| Byte | Content |
|---|---|
| 0–3 | Don't care |
| 4 | `0xB2` (type marker) |
| 5–6 | 16-bit two's complement integer, big-endian, range −32768 to +32767 |
| 7 | Don't care |

Not observed in any hardware dump.  Believed to be an in-RAM computation format that does
not appear in `PRINT#` output.  Decode support is retained for correctness.

#### String record (single-letter variables A$–Z$)

Prefix `13 00 00 10` — total record 20 bytes (4 prefix + 16 data).

The 16-byte data field contains the string value left-aligned, null-padded to exactly 16
bytes.  No length prefix; trailing nulls are stripped on read.  Maximum string length is
16 characters.

### 6.4 DIM'd Array Prefix (byte 1 ≠ `0x00`)

When byte 1 of the prefix is non-zero the record holds a DIM'd array.  Two array types
exist: string arrays (`DIM X$(N)*L`) and numeric arrays (`DIM X(N)`).  The prefix format
is the same for both; byte 3 carries the type-specific parameter.

`dim_max` of 0 is valid — a single-element array whose only element is at index 0
(e.g. `DIM A(0)` or `DIM A$(0)*16`).

#### DIM'd String Array

| Byte | Content |
|---|---|
| 0 | `len_minus_1`: total record length − 1 (single byte) |
| 1 | `dim_max`: N from `DIM X$(N)*L` — maximum subscript; elements are indexed 0 to N |
| 2 | Always `0x00` |
| 3 | `max_len`: L from `DIM X$(N)*L` — maximum string length per element in bytes |

Total record length = `4 + (dim_max + 1) × max_len`.

Verified examples:

| Array declaration | `dim_max` | `max_len` | Record length | `len_minus_1` |
|---|---|---|---|---|
| `DIM AA$(1)*80` | `0x01` | `0x50` (80) | 164 | `0xA3` (163) |
| `DIM BB$(2)*40` | `0x02` | `0x28` (40) | 124 | `0x7B` (123) |

Data layout: `(dim_max + 1)` sequential slots of exactly `max_len` bytes, from index 0
to `dim_max`.  Each slot contains the string value null-padded to `max_len` bytes.  If
the string value fills the slot exactly there is no null terminator.

```
[slot 0: max_len bytes] [slot 1: max_len bytes] … [slot dim_max: max_len bytes]
```

#### DIM'd Numeric Array

Confirmed from `pc1500-vars-mixed-arrays.bin` (two numeric array records).

| Byte | Content |
|---|---|
| 0 | `len_minus_1`: total record length − 1 |
| 1 | `dim_max`: N from `DIM X(N)` — maximum subscript; elements run from 0 to N |
| 2 | Always `0x00` |
| 3 | `0x88` — same numeric type marker as simple numeric scalar |

Data layout: `(dim_max + 1)` sequential 8-byte BCD values (same encoding as simple
numeric scalars), from index 0 to `dim_max`.

Verified examples:

| Array declaration | `dim_max` | Record length | `len_minus_1` |
|---|---|---|---|
| `DIM A(5)` | `0x05` | 52 | `0x33` (51) |
| `DIM A(0)` | `0x00` | 12 | `0x0B` (11) |

#### Special case: dim_max = 0

When `dim_max` is 0, byte 1 of the prefix is `0x00`.  The record becomes
**binary-identical** to the corresponding simple scalar:

| Declaration | Prefix | Indistinguishable from |
|---|---|---|
| `DIM A(0)` | `0B 00 00 88` | Simple numeric scalar |
| `DIM A$(0)*16` | `13 00 00 10` | Simple string scalar |

The converter cannot distinguish these cases from the binary alone.  On `get`, both are
emitted as scalars.  On `put`, a scalar line and a `DIM (0)` block with one element
produce identical binary output.

`DIM A$(0)*L` with L ≠ 16 is the one unambiguous dim_max=0 case: byte 1 = `0x00`,
byte 3 = L (not `0x88` and not `0x10`), so the converter can detect it as a
zero-dimension string array with max_len = byte 3.

---

## 7. Payload: Reserve Area

Source: Sharp PC-1500 Technical Reference Manual §5-3-6; confirmed from hardware dump
`src/test/resources/dumps/pc1500-reserve.bin` (215 bytes = 27-byte header + 188-byte payload).

The Reserve Area stores programmed content for the six reserve keys across three layers.

### 7.1 Layout

| Offset | Size | Content |
|---|---|---|
| 0x000 | 26 bytes | Key symbol label for layer I |
| 0x01A | 26 bytes | Key symbol label for layer II |
| 0x034 | 26 bytes | Key symbol label for layer III |
| 0x04E | 110 bytes | Key contents pool |

**Total: 188 bytes** (= 3 × 26 + 110).

### 7.2 Key Symbol Label (26 bytes per layer)

A human-readable label identifying the keys in that layer (e.g. `"ABS FOR SIN COS TAN ATN"`).
Stored as a 7-bit CP437 string, null-terminated and null-padded to fill the 26-byte field.
Read with `trim()`.

### 7.3 Key Contents Pool (110 bytes)

A flat byte stream of key entries followed by a `0x00` terminator:

```
[key_code] [content_bytes…]  [key_code] [content_bytes…]  …  [0x00]
```

Maximum usable content: 109 bytes (pool size 110, minus the mandatory `0x00` terminator).

#### Key code byte

Identifies the layer and key slot of the following content bytes:

| Key | Layer I | Layer II | Layer III |
|---|---|---|---|
| F1 | `0x01` | `0x11` | `0x09` |
| F2 | `0x02` | `0x12` | `0x0A` |
| F3 | `0x03` | `0x13` | `0x0B` |
| F4 | `0x04` | `0x14` | `0x0C` |
| F5 | `0x05` | `0x15` | `0x0D` |
| F6 | `0x06` | `0x16` | `0x0E` |

Key codes are in the range `0x01`–`0x16`.

#### Content bytes

| Byte(s) | Meaning |
|---|---|
| `0xF0 xx` | BASIC keyword, first token table |
| `0xF1 xx` | BASIC keyword, second token table |
| `0x20`–`0x7F` | Literal character (CP437) |

Content bytes are always ≥ `0x20` or start with `0xF0`/`0xF1` (all > `0x16`).  Key codes
are always ≤ `0x16`.  No ambiguity — the parser distinguishes them without lookahead.

#### Pool ordering

Entries appear in registration order, not sorted by key code.  On re-registration the old
entry is deleted and the new one appended at the end.  Unused bytes in the 110-byte pool
are `0x00`.

---

## 8. Summary Table

| Type | CE-158 type byte | Payload length source | Payload structure |
|---|---|---|---|
| BASIC | `0x40` (`@`) | Header length field (capacity−1) | Linked list of tokenized lines, `0x00 0x00` terminator |
| Machine | `0x42` (`B`) | Header length field (capacity−1) | Raw machine code bytes |
| Reserve Area | `0x41` (`A`) | Header length field (capacity−1) | 3 × 26-byte labels + 110-byte key pool |
| Variables | `0x48` (`H`) | EOF (header field meaningless) | Positional `[0x00][prefix][data]` records |
