# PC-1500 ROM Tokenizer Analysis

> Extracted from Part 1 of `SharpBasicShared/TokenizerAnalysis.md` (in the separate
> `SharpBasicShared` repository, left unchanged there). The remaining parts of that
> document compare Java tokenizer implementations across other projects and are not
> Sharp hardware/firmware research, so they were not copied here.

This section captures how the PC-1500 ROM tokenizes BASIC programs, reverse-engineered
from `PC-1500_ROM-A0x.lh5801.asm`.

## Where to find it in the ASM file

| Section | ROM address | ASM file lines | Label |
|---|---|---|---|
| Keyword table pointers (26 entries, A–Z) | `$C020` | 108–185 | `B_TBL_C000_A_KW` … `Z_KW` |
| Keyword table entries (linked list bodies) | `$C054` | 186–318 | `B_TBL_C000_CMD_LST` / `LET_A` … `LET_W` |
| Tokenizer routine | `$F957` | 13544–13805 | `TOK_INBUF` |

The comment at ASM line 13546–13550 is the best single-sentence description of what the routine does:

> *"Converts subsets of ASCII character strings into tokens… All Basic commands tokenized to 2 bytes, insert codes are deleted and **spaces outside of strings as well.**"*

## Keyword table structure (ASM lines 186–318)

Each letter A–Z has a pointer to the head of its own singly-linked list of keyword entries. The `CNIB` macro at each entry encodes: a link to the next entry, the keyword text as plain ASCII, the 2-byte token code, and the dispatch vector.

Example — all P-keywords, in table order (ASM lines 266–275):

```
PRINT   → token $F097   (listed first)
PI      → token $F15D
PEEK#   → token $F16E
PEEK    → token $F16F
POKE#   → token $F1A0
POKE    → token $F1A1
POINT   → token $F168
PAUSE   → token $F1A2
"P    " → token $F1A3   (fallback: P + 4 spaces, see below)
```

**The ordering is deliberate**: longer keywords with a common prefix always appear before shorter ones (`PEEK#` before `PEEK`, `POKE#` before `POKE`). The `"P    "` entry (P + four trailing spaces) at the end of the P-list acts as a single-character fallback; the trailing spaces become transparent because spaces are skipped during matching (see below).

## Tokenizer algorithm (ASM lines 13558–13805)

The routine is a **single-pass, character-by-character, first-match** scanner.

### Outer loop (lines 13568–13576)

For each character in the input buffer:
- Skip `'` (single-quote / cursor-control byte, 0x27)
- On CR (0x0D): end of line
- On `"` (0x22): toggle the *in-string* flag (`UH`) and store character as-is

### Non-string, non-letter characters (lines 13665–13673)

- **Space (0x20)**: silently discarded — line 13666. This is the global space removal the comment mentions.
- Characters outside `[A–Z]` and below `0xE0`: copied to output buffer unchanged.
- Bytes `>= 0xE0`: already a 2-byte token from a previous tokenize pass; second byte is read and both bytes are copied through.

### Keyword matching — setup (lines 13674–13702)

When an uppercase letter is found:
1. Save the first character, compute `(letter & 0x1F) × 2` to index into the pointer table at `$C020`, loading the head of that letter's linked list into register X.
2. `PSH Y` saves the current input stream position — so if no keyword matches, Y is restored and the letter is treated as a plain variable name.

### Keyword matching — inner loop (lines 13704–13728)

For each keyword candidate in the linked list:

1. **Save input position** (`PSH Y`, line 13705).
2. **Read the next input character** (`LIN Y`, line 13708), then:
   - **Skip if space (0x20)** — lines 13709–13710, loops back.
   - **Skip if single-quote (0x27)** — lines 13711–13712, loops back.
   - **If period (0x2E)**: abbreviation terminator — fall through to step 3a.
   - **Otherwise**: go to step 3b.
3a. **Period found — abbreviation path** (lines 13716–13721): Scan the keyword table forward until a byte `> 0xE0` (the end-of-entry marker) is found. Back up one byte and jump to **Match Found**. This means: *any prefix of a keyword followed by `.` is accepted as an abbreviation.* `"FO."` = `FOR`, `"P."` = `PRINT` (first P-keyword in the list).
3b. **Normal match** (lines 13723–13728): `CIN` compares the input character against the current table byte and advances the table pointer. If not equal → **try next keyword** (restore Y, advance X to next list entry). If equal → check whether the next table byte is the end-of-entry marker (`>= 0xE0`). If yes → **Match Found**. If no → loop back to step 2 (read more input).

**Try next keyword** (lines 13773–13786): Scan X past the remaining characters of the current table entry and past the token code bytes, read the next-entry link nibble, restore Y (input position), and iterate. If end-of-list → no keyword matched; the saved first letter is stored as a plain character.

**Match Found** (lines 13730–13744): Load the 2-byte token code from the table into `UH:UL`, pop saved registers, write the token to the output buffer.

### REM special case (lines 13745–13749)

After writing any token the code checks: if `UH == $F1` and `UL == $AB` (= the REM token), copy everything up to the next CR verbatim and skip further tokenization for that line.

## ROM tokenizer properties — summary table

| Property | ROM behaviour |
|---|---|
| Space removal | All spaces outside strings deleted globally (line 13666) |
| Space skipping *within* keyword match | YES — lines 13709–13710 during inner match loop |
| Single-quote skipping within match | YES — lines 13711–13712 (cursor-control bytes) |
| Matching strategy | **First-match** in linked-list order |
| Keyword ordering | Longer keywords listed before shorter same-prefix ones |
| Abbreviation (`P.`) | Native via `.` terminator in inner loop |
| REM handling | Consumes rest of line after token is written |
| Already-tokenized bytes | Passed through transparently |
