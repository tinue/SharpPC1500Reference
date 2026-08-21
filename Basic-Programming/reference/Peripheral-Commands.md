# PC-1500 Peripheral Commands

This document describes the peripheral commands added to the PC-1500 BASIC interpreter from the CE-150 and CE-158 expansion modules.

## Overview

The Sharp PC-1500 supported two major peripheral expansions:

1. **CE-150**: 4-color plotter/printer with graphics capabilities
2. **CE-158**: RS-232C serial and parallel printer interface

These peripherals added approximately 40 new BASIC commands and functions to extend the PC-1500's capabilities.

## Implementation Status

Currently, all peripheral commands are **recognized by the lexer** but are **not yet implemented** (no-ops). This allows programs using these commands to be parsed without syntax errors, while the actual peripheral emulation will be implemented in future phases.

---

## CE-150 Commands (4-Color Plotter/Printer)

### Graphics Mode Commands

| Command | Token | Abbreviation | Description |
|---------|-------|--------------|-------------|
| GRAPH | 0xE681 | GRAP | Switch to graphics mode |
| TEXT | 0xE686 | TEX | Switch to text mode |
| GLCURSOR | 0xE682 | GL | Set graphics cursor position |
| LCURSOR | 0xE683 | LCU | Set line cursor |
| LINE | 0xF0B7 | LIN | Draw absolute line |
| RLINE | 0xF0BA | RL | Draw relative line |
| SORGN | 0xE684 | SO | Set origin point |

### Display Control Commands

| Command | Token | Abbreviation | Description |
|---------|-------|--------------|-------------|
| COLOR | 0xF0B5 | COL | Select pen color (0-3: Black, Red, Blue, Green) |
| CSIZE | 0xE680 | CSI | Set character size (0-3) |
| ROTATE | 0xE685 | RO | Set rotation angle (0-3: 0°, 90°, 180°, 270°) |

### Printing Commands

| Command | Token | Abbreviation | Description |
|---------|-------|--------------|-------------|
| LPRINT | 0xF0B9 | LP | Print to plotter/printer |
| LLIST | 0xF0B8 | LL | List program to printer |
| LF | 0xF0B6 | - | Line feed |
| FEED | 0xF0B0 | - | Paper feed |

### Cassette Control

| Command | Token | Abbreviation | Description |
|---------|-------|--------------|-------------|
| RMT | 0xE7A9 | RM | Remote cassette motor control |
| CHAIN | 0xF0B2 | CHA | Load and execute from tape |

### Other

| Command | Token | Abbreviation | Description |
|---------|-------|--------------|-------------|
| TEST | 0xF0BC | TE | Graphics test function |

---

## CE-158 Commands (RS-232C/Parallel Interface)

### Configuration Commands

| Command | Token | Abbreviation | Description |
|---------|-------|--------------|-------------|
| SETCOM | 0xE882 | - | Configure serial parameters (baud, parity, data, stop) |
| SETDEV | 0xE886 | - | Select device (0=Console, 1=RS232C, 2=Parallel) |
| CONSOLE | 0xF0B1 | - | Set console device |
| PROTOCOL | 0xE881 | - | Set protocol type (0=None, 1=XON/XOFF, 2=RTS/CTS) |
| DTE | 0xE884 | - | Set DTE/DCE mode |

### Status and Information Functions

| Function | Token | Type | Description |
|----------|-------|------|-------------|
| DEV$ | 0xE857 | String | Return current device ("CON", "RS232C", "PARALLEL") |
| COM$ | 0xE858 | String | Return comm parameters ("BBBB,P,D,S") |
| INSTAT | 0xE859 | Numeric | Input buffer status (0 if empty) |
| OUTSTAT | 0xE880 | Numeric | Output buffer status (0=busy, non-zero=ready) |

### Data Transfer Commands

| Command | Token | Abbreviation | Description |
|---------|-------|--------------|-------------|
| TRANSMIT | 0xE885 | - | Transmit data immediately |
| TERMINAL | 0xE883 | - | Enter terminal mode |

### Data Transfer Functions

| Function | Token | Type | Description |
|----------|-------|------|-------------|
| RINKEY$ | 0xE85A | String | Read serial char (non-blocking, like INKEY$ but for serial) |

---

## Core PC-1500 Commands (Previously Missing)

These core commands were also added to complete the command set:

| Command | Token | Description |
|---------|-------|-------------|
| CLOAD | 0xF089 | Load program from tape |
| CSAVE | 0xF095 | Save program to tape |
| MERGE | 0xF08F | Merge program from tape |
| BREAK | 0xF0B3 | Break statement |
| TAB | 0xF0BB | Tab function |
| ZONE | 0xF0B4 | Set zone width |

### Error Handling Functions

| Function | Token | Type | Description |
|----------|-------|------|-------------|
| ERL | 0xF053 | Numeric | Error line number |
| ERN | 0xF052 | Numeric | Error number |

### String Functions

| Function | Token | Type | Description |
|----------|-------|------|-------------|
| SPACE$ | 0xF061 | String | Generate spaces |

---

## Token Value Ranges

- **Core PC-1500 commands**: 0xF080-0xF1FF
- **CE-150 specific commands**: 0xE680-0xE686, 0xE7A9
- **CE-158 specific commands**: 0xE857-0xE85A, 0xE880-0xE886

## Example Programs

### CE-150 Graphics Example

```basic
10 REM Circle drawing
20 GRAPH
30 SORGN 500, 500
40 COLOR 0
50 FOR A=0 TO 360 STEP 10
60 X=COS(A)*200
70 Y=SIN(A)*200
80 LINE X, Y
90 NEXT A
100 TEXT
```

### CE-158 Serial Communication Example

```basic
10 REM Simple terminal
20 SETCOM 4,0,8,1
30 SETDEV 1
40 PRINT "Connected at 1200 baud"
50 IF INSTAT THEN A$=RINKEY$: PRINT A$;
60 A$=INKEY$
70 IF A$<>"" THEN TRANSMIT A$
80 GOTO 50
```

---

## Implementation Notes

1. All commands are currently **no-ops** (not implemented)
2. The lexer recognizes all commands correctly
3. Programs using these commands will **parse without syntax errors**
4. Actual peripheral emulation will be added in future phases
5. All token values match the original ROM token table

## References

The paths below are relative to the author's local workspace, not to this repository. All three sibling projects are public but are **not part of this repository**:

- CE-150 Reference: `../SharpBasicReference/docs/CE-150-Reference.md` ([github.com/tinue/SharpBasicReference](https://github.com/tinue/SharpBasicReference))
- CE-158 Reference: `../SharpBasicReference/docs/CE-158-Reference.md` ([github.com/tinue/SharpBasicReference](https://github.com/tinue/SharpBasicReference))
- Plugin Keywords: `../SharpBasicPlugin/src/main/java/ch/erzberger/sharpbasic/keywords/` ([github.com/tinue/SharpBasicPlugin](https://github.com/tinue/SharpBasicPlugin))

---

*Last updated: February 15, 2026*
