# PC-1600 Keyboard

## Scope

How the PC-1600 keyboard is scanned and how key events reach software. The **hardware
model** (§2) and the **scan matrix** (§5) are complete and emulator-ready. The key-*code*
value table (§10.2 — matrix position → character/token, applied by ROM code, not needed
by an emulator) is still to transcribe.

**Sources:** PC-1600 Technical Reference Manual §7.4 (keyboard hardware), §7.9 (I/O port
controller) and §3.2 (key IOCS, the `KEYSTRB` matrix figure). The strobe/sense↔port
binding and a handful of glyph readings in the §3.2 scan were cross-checked against an
independent emulator implementation (`README.md` — *Sources & validation*). §10.2
(key-code table) pending.

---

## 1. Scan mechanism (TRM §7.4)

The keyboard is **scanned every 1/64 s** by interrupting the SC-7852 with the **64 Hz
pulse from the `Z6` terminal of the sub-CPU (LU-57813P)**. That pulse reaches the SC-7852
as **`INT4`** (pin 83, falling-edge triggered; externally tied to `PB5`, pin 72). The
1/64 s timer interrupt is one of the seven interrupt causes in the port-32H/35H system
(`PC-1600-CPU-SC7852-Z80.md` §5.2, bit 4) and its handler also blinks the cursor
(TRM §3.4.1(2)).

## 2. Port wiring — the emulator model

The keyboard hangs off the SC-7852's LH-5810-style I/O port (TRM §7.4, §7.9):

- **Strobe outputs = the LH-5810 `OPA` register (I/O port 1EH).** Its 8 bits are the
  keyboard strobe lines **KS0…KS7** (bit *n* → KS*n*), active-low. The firmware writes a
  bit pattern to OPA and the currently-low bits are the active strobe columns.
- **One extra strobe = `OPB` (port 1FH) bit 6** (PB6), active-low — for the three keys
  **CTRL / KBII / BS** only.
- **Sense input = a read of I/O port `37H`** (`IOR KB`). Returns the 8-bit sense byte,
  active-low: for every strobe line held low, the bits of the pressed keys on that line
  read 0.
- **BREAK/ON is *not* in the matrix.** It comes from the sub-CPU onto **`OPB` bit 7**
  (PB7); it also has its own interrupt latch (`IF` register b1, set on PB7's rising edge,
  maskable via `MSK` b1 — `PC-1600-IO-Ports.md` §2.1–2.2), and the gate array exposes it
  as `ON` (pin 5) / inverted `KH` (pin 43) to the sub-CPU, with `Z13` polling it during
  sub-CPU power-save. Model it as a separate one-bit input, like the PC-1500's ON key.
- The **1/64 s scan-tick pulse** arrives on **`OPB` bit 5** (PB5) — the same signal that
  raises the key-scan interrupt.

(The `OPA`-bit ↔ `KS`-line ordering, the `PB6` extra strobe, and the port-37H sense read
were pinned down by cross-check — `README.md`, *Sources & validation*.)

Pin-level detail (for a schematic-accurate model): the strobes physically leave the
SC-7852 on `PA0–PA7` (pins 62–70) and `PB6` (pin 73); the sense lines return on
`KIN0–KIN7` (pins 95–100, 1, 2), internally pulled to VCC (200–500 kΩ). Port directions
are set in `DDA` (1CH) / `DDB` (1DH), output latches in `OPA` (1EH) / `OPB` (1FH).

## 3. Wake / power

Key-wake from auto-power-off is handled by the sub-CPU (`WAKE$`, wakeup timer). The
sub-CPU stays powered on the `VGG` rail while the machine is off
(`PC-1600-Machine-Overview.md` §5).

## 4. IOCS routines (TRM §3.2.1)

`CALL <entry>`, all in Bank 0. See `PC-1600-IOCS.md` §1 for field conventions.

| Name | Entry | Function | Params | Return | Clobbers |
|---|---|---|---|---|---|
| **KEYGET** | 0166H | read one char from the 64-byte keyboard buffer; **waits** if empty | — | CF=0: A = key code. CF=1: 10-minute idle timeout — auto-power-off fired (BREAK/ON restarts it); the keyboard-wait-abort bit **KEYWK2 (F07AH) b4** is set | AF |
| **KEYGETR** | 0169H | like KEYGET but **does not wait** | — | CF=1 if the buffer is empty | AF |
| **KBUFSET** | 016CH | clear the buffer, then load A bytes from (DE) into it (key-scan interrupt suppressed during) | DE = source, A = count (1–63; A=0 just clears). Source must be within one bank. | — | DE |
| **BREAKCHK** | 016FH | read the BREAK-key status (clears the keyboard buffer if BREAK was pressed) | — | CF=1 pressed / CF=0 not | AF |
| **CURUDCHK** | 0172H | read the ↑ / ↓ key status | — | CF=0 neither; CF=1 one or both — A: b7=1 ↓ pressed, b6=1 ↑ pressed | AF |
| **KEYDIRECT** | 0175H | read the code of the key held at call time (scan interrupt suppressed; buffer cleared) | — | A = key code (0 = none) | AF |
| **KEYSTRB** | 0178H | read one strobe row's key state (pressed bits read as 0; scan interrupt suppressed) | A = strobe number 00H–08H | A = key-state byte | AF |
| **KEYAUX** | 017BH | set the input device (keyboard or RS-232C) | | | |
| **KEYSTATSET** | 017EH | set the key-repeat and key-click functions | | | |
| **KEYSTATREAD** | 0181H | read the repeat / click / input-device settings | — | A = settings bitfield (b0 device 0=keyboard/1=RS-232C; b1 all-keys-repeat=1 / all-except-special=0; b2 repeat ON=1; b4 key-click ON=1; b3/b5–b7 uncertain). "Special keys" = CTRL, SHIFT, function keys, KBII, MODE, SML, ON, OFF | AF |
| **OFFCHK** | 0184H | read the OFF-key status | — | CF=1 pressed / CF=0 not | AF |
| **KEYGETND** | 0187H | read the first buffer byte **without consuming it** | — | A = key code (buffer unchanged) | |
| **BREAKRESET** | 018AH | clear the BREAK-key latch (also clears the keyboard buffer) | — | — | |

## 5. Key-scan matrix

Strobe line (`KS`*n* = `OPA` bit *n*, plus `PB6`) × sense bit (the byte returned by an
`IN 37H`). A pressed key at (strobe, bit) pulls that sense bit to 0 while its strobe is
low. The table is the TRM §3.2.1 `KEYSTRB` figure with a handful of OCR misreads in the
scan corrected by cross-check (`$`→`F4`, `#`→`F3`, `+`/`*` ↔ `−`/`✻`, `ö`→`O`,
`•`/`—`/`⇕` → `.`/`-`/`RSV`; `README.md`, *Sources & validation*). `KEYSTRB`'s "strobe
number" 0–7 == the `KS` line index; its "strobe 8" == the `PB6` strobe.

| Strobe | bit0 (LSB) | bit1 | bit2 | bit3 | bit4 | bit5 | bit6 | bit7 (MSB) |
|---|---|---|---|---|---|---|---|---|
| **KS0** (OPA b0) | `2` | `5` | `8` | `H` | `SHIFT` | `Y` | `N` | `↑` |
| **KS1** (OPA b1) | `.` | `-` | `OFF` | `S` | `F1` | `W` | `X` | `RSV` |
| **KS2** (OPA b2) | `1` | `4` | `7` | `J` | `F5` | `U` | `M` | `0` |
| **KS3** (OPA b3) | `)` | `L` | `O` | `K` | `F6` | `I` | `(` | `ENTER` |
| **KS4** (OPA b4) | `+` | `*` | `/` | `D` | `F2` | `E` | `C` | `RCL` |
| **KS5** (OPA b5) | `=` | `←` | `P` | `F` | `F3` | `R` | `V` | `SPACE` |
| **KS6** (OPA b6) | `→` | `MODE` | `CLS` | `A` | `DEF` | `Q` | `Z` | `SML` |
| **KS7** (OPA b7) | `3` | `6` | `9` | `G` | `F4` | `T` | `B` | `↓` |
| **PB6** (OPB b6) | `CTRL` | `KBII` | `BS` | — | — | — | — | — |

`ON` is not in this matrix (§2). `SML` = small/kana lock, `RSV` = RESERVE, `KBII` = the
second keyboard (international) shift.

## 6. Keyboard work area (TRM §3.2.2)

| Addr | Name | Contents |
|---|---|---|
| F079H | KEYWK1 | b0 suppress key-scan interrupt · b1 key-click on · b2 key-repeat on · b3 repeat range (0 = all except special keys, 1 = all keys) · b4 repeat delay (0 = long, 1 = short) · b5 same-code repeat (0 = a repeated identical code is accepted only once, 1 = identical codes repeat) · b6 repeat rate (0 = slow, 1 = fast) · b7 suppress key-code translation in KEYGET |
| F07AH | KEYWK2 | b4 = keyboard-wait-abort (set by a KEYGET timeout) |
| F07BH | KEYWK3 | b1 suppress auto-power-off · b2 disable the OFF key |
| F07FH | — | keyboard-buffer **write** pointer (MSB = 1 when the buffer is full) |
| F080H | — | keyboard-buffer **read** pointer (write == read ⇒ empty) |
| F083H | — | last returned key code |
| F084H–F08CH | — | SHIFT / KBII / SHIFT-KBII translation-table pointers — see §7 |
| F0DFH–F11EH | — | the **keyboard buffer** (64 bytes) |
| F11FH | — | bank of the key-code (matrix→code) table |
| F120H–F121H | — | address of the key-code table (L then H) |

## 7. Key-code translation and redefinition (TRM §3.2.5 / §3.2.6)

**Data flow.** The 1/64-s interrupt handler reads the **key-scan matrix**, runs it
through the **key-code table** (pointer at F11FH / F120H–F121H), and pushes the resulting
**key code** into the keyboard buffer. `KEYGET` then pops a code and — depending on which
status-line symbol is active (Normal / SHIFT / KBII / SHIFT-KBII) — passes it through the
matching **code-translation table** to produce the final key data. §3.2.4: with the KBII
and/or SHIFT symbol shown, KEYGET/KEYGETR yield the international characters and symbols.

All four tables live in ROM but are reached through RAM pointers, so repointing them at
user tables in RAM redefines the keyboard. Each table must lie entirely within one bank.

| Table | Purpose | Address ptr | Bank ptr | ROM source label |
|---|---|---|---|---|
| Key-code | matrix → key code | F120H–F121H (2 B, L/H) | F11FH (1 B) | `KYCDTB` |
| SHIFT-code | key code → SHIFT code | F085H–F086H (2 B) | F084H (1 B) | `SFTCDT` |
| KBII-code | key code → KBII code | F088H–F089H (2 B) | F087H (1 B) | `KNCDT1` |
| SHIFT-KBII-code | key code → SHIFT-KBII code | F08BH–F08CH (2 B) | F08AH (1 B) | `KNCDT2` |

> The SHIFT/KBII/SHIFT-KBII pointer addresses above follow the **§3.2.2** work-area
> layout (bank byte first, then the 2-byte address, mirroring the key-code table's
> F11FH/F120H). The **§3.2.6** table instead labels F084H/F087H/F08AH as the *address*
> low byte and F086H/F089H as the *bank* — the two sections disagree on byte roles for
> these three tables (they agree on the key-code table). Trust §3.2.2 until checked
> against the ROM; §3.2.6 also prints F089H twice (KBII and SHIFT-KBII bank), an evident
> slip.

The `KEYSTAT` BASIC-command extension (TRM §5.3) is another route to these settings —
cross-reference when §5 is processed.

## 8. ON / BREAK (TRM §3.2.3)

BREAK/ON is **not** in the scan matrix. Its state is **bit 1 of I/O port 1BH** (the
LH-5810-style `IF` register — `PC-1600-IO-Ports.md` §2.2, `IF1`, set on the rising edge
of `PB7`): b1 = 1 ⇒ pressed, latched. Clear it with `BREAKRESET` (018AH), which also
clears the keyboard buffer. `BREAKCHK` (016FH) reads it via IOCS.

## TODO

- Key-*code* table values (§10.2): matrix position → character/token, plus the SHIFT /
  SML / `[MODE]` / `[DEF]` glyph assignments. **Not needed for an emulator** (ROM code at
  `KYCDTB` does this mapping); useful for the program-writing agent.
- Resolve the §3.2.2 vs. §3.2.6 translation-table pointer-byte-role discrepancy against
  the ROM.
