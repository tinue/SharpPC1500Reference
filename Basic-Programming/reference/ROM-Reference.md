# PC-1500 ROM Reference

Quick reference guide to the PC-1500 ROM disassembly structure.

## ROM File Location

`reference/PC-1500_ROM-A0x.lh5801.asm` (327,562 bytes)

## Key ROM Sections

### Token Table (Lines 192-315)

The token table defines all BASIC commands and their token values.

**Format:**
```
CN#: EQU $XX \ CNIB(...) \ .TEXT "COMMAND" \ .WORD $F0XX, $XXXX
```

**Token Value Range:** $F080 - $F1FF (commands and functions)

**Example Entries:**
- Line 193: `AREAD` → Token $F180
- Line 203: `BEEP` → Token $F182
- Line 267: `PRINT` → Token $F097
- Line 227: `FOR` → Token $F1A5

### Command Categories

**Commands (Lines 192-315):**
- Control flow: FOR, NEXT, IF, GOTO, GOSUB, RETURN
- I/O: PRINT, INPUT, BEEP, CLS, CURSOR
- Program: NEW, LIST, RUN, CLEAR, CONT
- Data: DIM, DATA, READ, RESTORE

**Functions (Lines 192-315):**
- Math: ABS, SIN, COS, TAN, ATN, SQR, EXP, LOG, LN
- String: LEFT$, RIGHT$, MID$, CHR$, STR$, LEN, VAL, ASC
- System: MEM, PEEK, POKE, STATUS, TIME

### Operator Precedence Table (Lines 407-425)

Located at ROM address $C3A8, defines operator precedence for expression evaluation.

**Precedence Levels (highest to lowest):**
1. `^` (power) - Level $84
2. `*` `/` (multiply/divide) - Level $82
3. `+` `-` (add/subtract) - Level $81
4. `=` `<` `>` (comparison) - Level $80

**Format:**
```
.BYTE $char, $precedence, $flags, $addr_low, $addr_high
```

**Examples:**
- Line 412: `^ (power)` → Precedence $84
- Line 410: `* (multiply)` → Precedence $82
- Line 411: `/ (divide)` → Precedence $82
- Line 408: `+ (plus)` → Precedence $81
- Line 409: `- (minus)` → Precedence $81

### BASIC Interpreter Entry Point (Line 431)

ROM address $C400: Main BASIC interpreter loop

### System Messages (Lines 325-337)

- Line 325: "NEW0? :CHECK"
- Line 330: "BREAK"
- Line 333: "IN"
- Line 336: "ERROR"

## Token Value Mapping

### Commands ($F080-$F1FF)

| Token | Command | Line | Implementation Address |
|-------|---------|------|------------------------|
| $F180 | AREAD   | 193  | $C684 |
| $F181 | ARUN    | 200  | $C684 |
| $F182 | BEEP    | 203  | $E5C1 |
| $F183 | CONT    | 206  | $C8C7 |
| $F084 | CURSOR  | 207  | $E846 |
| $F187 | CLEAR   | 208  | $C85F |
| $F088 | CLS     | 209  | $E865 |
| $F18B | DIM     | 215  | $C988 |
| $F18E | END     | 222  | $C50D |
| $F1A5 | FOR     | 227  | $C711 |
| $F192 | GOTO    | 230  | $C515 |
| $F194 | GOSUB   | 231  | $C64E |
| $F091 | INPUT   | 237  | $C8FA |
| $F196 | IF      | 238  | $C5B4 |
| $F090 | LIST    | 243  | $C96E |
| $F198 | LET     | 246  | $C458 |
| $F19A | NEXT    | 256  | $C705 |
| $F19B | NEW     | 258  | $C80A |
| $F19C | ON      | 261  | $C5E0 |
| $F097 | PRINT   | 267  | $E4EB |
| $F1A6 | READ    | 280  | $C7B8 |
| $F1AB | REM     | 286  | $C676 |
| $F1A7 | RESTORE | 281  | $C7A2 |
| $F199 | RETURN  | 279  | $C6AC |
| $F1A4 | RUN     | 278  | $C8B4 |
| $F1AC | STOP    | 289  | $C4B6 |
| $F1AE | THEN    | 298  | $CD89 |
| $F1B1 | TO      | 303  | $CD89 |
| $F1AD | STEP    | 295  | $CD89 |

### Functions ($F150-$F17F)

| Token | Function | Line | Implementation Address |
|-------|----------|------|------------------------|
| $F170 | ABS      | 195  | $F597 |
| $F174 | ACS      | 198  | $F492 |
| $F173 | ASN      | 197  | $F49A |
| $F160 | ASC      | 199  | $D9DD |
| $F175 | ATN      | 196  | $F496 |
| $F163 | CHR$     | 211  | $D9B1 |
| $F17E | COS      | 210  | $F391 |
| $F165 | DEG      | 217  | $F531 |
| $F178 | EXP      | 223  | $F1CB |
| $F171 | INT      | 239  | $F5BE |
| $F17A | LEFT$    | 248  | $D9F3 |
| $F164 | LEN      | 247  | $D9DD |
| $F176 | LN       | 245  | $F161 |
| $F177 | LOG      | 244  | $F165 |
| $F17B | MID$     | 253  | $D9F3 |
| $F15D | PI       | 268  | $F5B5 |
| $F172 | RIGHT$   | 284  | $D9F3 |
| $F17C | RND      | 282  | $F5DD |
| $F179 | SGN      | 292  | $F59D |
| $F17D | SIN      | 291  | $F3A2 |
| $F16B | SQR      | 290  | $F0E9 |
| $F161 | STR$     | 293  | $D9CE |
| $F17F | TAN      | 299  | $F39E |
| $F162 | VAL      | 310  | $D9D7 |

### Logical Operators

| Token | Operator | Line | Implementation Address |
|-------|----------|------|------------------------|
| $F150 | AND      | 194  | $CD89 |
| $F151 | OR       | 262  | $CD89 |
| $F16D | NOT      | 257  | $599E |

## Important Memory Addresses

From the ROM comments:

- **$C001-$C01C**: Two small OS functions
- **$C020-$C053**: Token table pointers for built-in commands
- **$C054-$C34E**: Token table for built-in commands
- **$C34F**: System messages
- **$C3A8**: Operator table for formula evaluation
- **$C400**: BASIC interpreter entry point

## Variable Naming Convention

Based on ROM analysis:
- **Simple variables**: A-Z (single letter)
- **Array variables**: A0-Z9 (letter + digit)
- **String variables**: Suffix with `$` (e.g., A$, B0$)

## Data Types

1. **Numeric**: 10-digit BCD floating-point (8 bytes in ROM)
2. **String**: Variable length up to 80 characters

## Special Characters

- **0x0D**: NEWLINE token
- **$**: String variable suffix
- **#**: Used in PEEK# and POKE# commands
- **&**: Hexadecimal prefix
- **^**: Power operator

## Using This Reference

When implementing commands:
1. Find the command in the token table (lines 192-315)
2. Note its token value ($F0XX)
3. Find the implementation address
4. Study the ROM code at that address for behavior
5. Implement equivalent Java code

For expression evaluation:
1. Use precedence table at lines 407-425
2. Implement Shunting Yard algorithm
3. Match operator precedence levels

## Quick Line Number Reference

- **Token Table Start**: Line 192
- **Token Table End**: Line 315
- **Operator Table Start**: Line 407
- **Operator Table End**: Line 425
- **BASIC Interpreter**: Line 431
- **System Messages**: Line 325

## Notes

- All ROM addresses are for the PC-1500 ROM versions A01, A03, and A04
- Token values are consistent across all versions
- Some commands share implementation addresses (e.g., THEN, TO, STEP all use $CD89)
- The ROM uses a linked-list structure for the token table (CNIB macro links entries)
