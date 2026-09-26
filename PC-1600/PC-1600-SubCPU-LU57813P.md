# PC-1600 Sub-CPU — LU-57813P

The PC-1600's third processor is the **LU-57813P**, a Sharp 4-bit CMOS mask-ROM
microcontroller clocked at 307.2 kHz. It runs on the always-on `VGG` rail. It decides
when the machine is on, keeps the calendar clock and the wake-up/alarm timers, does the
A/D conversions (analog jack, battery levels), debounces the ON/BREAK key, generates the
64 Hz system tick and the key click, and drives the peripheral reset line.

**No datasheet has been found.** Nothing beyond the one-line "4-bit CMOS, 307.2 kHz"
turns up online, and its internal ROM has not been dumped. Everything here comes from:

- **PC-1600 Service Manual**: §4-2 "Sub CPU role" (p.5), §4-3 "Sub CPU operation" (p.6),
  §6-3 "System-on/system-off", §7-1 "System-off operation", §9-3 "Sub CPU (LU57813P)
  pin description" (pp.26–29). The TRM reprints §4-3 as §7.1.5 and has the same pin table.
- **The PC-1600 Z-80 ROM**, which is the only record of the command set. The TRM
  documents the IOCS layer (`PC-1600-IO-Ports.md` §7) but not the bytes that go to the
  chip. Addresses below are P2-B6 unless stated.

Related: the command transport through the TC8576F is in `PC-1600-CPC-TC8576.md` §9.4.
The timer/RTC/analog IOCS list and the sub-CPU interrupt bitfield are in
`PC-1600-IO-Ports.md` §7.

---

## 1. Roles (Service Manual §4-2)

1. **Main power on/off.** The system turns off on a "system-off" command from the Z-80,
   and turns on from the ON key (and the other wake sources, §4).
2. **Real-time clock.** Month, day, hours, minutes, seconds, "similar to the PC-1500",
   with no leap-year handling. It also keeps **one wake-up timer and two alarm timers**,
   stepped every 0.5 s.
3. **Low-battery detection** by its own A/D converter, on both the PC-1600 supply and the
   supply of an attached option (CE-1600P). Below threshold the `BATT` symbol is lit.
   The separate hardware low-battery signal (`Q3`) forces the system off.
4. **Analog input.** The level on the analog-input jack is A/D-converted and returned to
   the Z-80. The same jack can also carry an **external keyboard**, whose input the
   sub-CPU reads and returns.
5. **Click sound**, on a command from the Z-80, when key-click mode is on.
6. **Reset signal.** Resets arrive from the PC-1600's own RESET switch and from the
   CE-1600P's. The sub-CPU turns either into a 30 ms system reset.
7. **System-on from the RS-232C `CI` (ring) line**, checked every 0.5 s.
8. **1/64 s timer output**, the system tick.

## 2. Clocks

| Clock | Source | Use |
|---|---|---|
| 1.229 MHz (1 228 800 Hz) | ceramic resonator on `CL1`/`CL2` (pins 4/5) | the chip's system clock. The gate array also passes `CL2` on as the TC8576F baud clock. |
| **307.2 kHz** | internal, 1.2288 MHz ÷ 4 | instruction clock ("307.2 kHz" in every Sharp spec list) |
| 32.768 kHz | watch crystal on `OSCIN`/`OSCOUT` (pins 15/14) | real-time clock timebase, runs while the system is off |

§7-1 of the Service Manual adds that while the system is off, the crystal timer
interrupts the chip every 0.5 s to advance the clock. At each minute carry it compares
the time against the wake-up and alarm settings, and it emits its system clock (153.6
or 307.2 kHz) on `FOUT` during these wake-ups. The pin table itself lists `FOUT` as
"not used".

## 3. Pinout (Service Manual §9-3)

64 pins. "Reset" is the pin state while `ACL` is active. For the Z pins, the
"Out … In" pairs in the manual mean output in normal operation and input (Hi-Z) during
reset.

| Pin | Name | Dir | Active | Function in the PC-1600 |
|---|---|---|---|---|
| 1 | Q0 | in | low | **Power-off acknowledge.** Fed from the SC-7852's `PCTRL` (pin 85). On a system-off command the sub-CPU switches the system off once `Q0` goes low. |
| 2 | VDD | pwr | | `VGG` |
| 3 | ACL | in | high | **All-reset** (ALL RESET switch). Must be ≥ 1 µs wide. The chip starts running ≈ 80 µs later. |
| 4 / 5 | CL1 / CL2 | in / out | | 1.229 MHz resonator. `CL2` is also the RS-232C baud clock. |
| 6 | FOUT | out | | system-clock output (§2) |
| 7 | P0 | out | low | **Reset of the SC-7852**, held low for 30 ms at system-on and reset |
| 8 | P1 | out | low | low while the main CPU may access memory and I/O. Goes to the gate array as `SLCB`. |
| 9 | P2 | out | high | complement of P1, to `SLCT` of the SC-7852 |
| 10 | P3 | out | low | low during system-on; switches the system power on |
| 11 | KH | in | high | **ON key.** In standby, a high `KH` turns the system on. |
| 12 | KI | in | high | **command request** from the Z-80 (TC8576F `DSTB`). High → interrupt → command processed in the ISR. |
| 13 | T | | | test, NC |
| 14 / 15 | OSCOUT / OSCIN | | | 32.768 kHz crystal |
| 16 | KL | in | high | reset input from a peripheral. Held high longer than a set time → reset. |
| 17 | Z15 | out | high | wired to `KL` and pulled down. Driven high for 1 ms by the reset routine; becomes `RSTE` on the system bus (e.g. CE-1600P reset). So the `Z15`/`KL` pair is a two-way peripheral reset line. |
| 18 | Z14 | out | high | debounced ON/BREAK state → SC-7852 `PB7` |
| 19 | Z13 | out | low | ON/BREAK polling strobe. Pulled low at every 1/128 s time interrupt. If `KH` is then high, BREAK/ON is pressed (`PC-1600-Keyboard.md`). |
| 20 | Z12 | out | low | "normally high (at ON)" |
| 21 | Z11 | — | | NC |
| 22 | **Z10** | out | high | **ready (high) / busy (low)** → TC8576F `/BUSY` |
| 23 | **Z9** | out | high | **done pulse** at the end of a command → TC8576F `ACK` |
| 24 | Z8 | out | | analog-input mode: low = voltage (100 kΩ input, BASIC's mode), high = current (machine code only) |
| 25 | **Z7** | out | high | **interrupt request → SC-7852 `INT6`** (§5) |
| 26 | GND | | | |
| 27 | **Z6** | out | low | **1/64 s square wave, 50 % duty** → SC-7852 `INT4` and `PB5` |
| 28 | Z5 | out | high | high only during an A/D conversion, to power the `VRH` reference (accuracy and power saving) |
| 29 | Z4 | out | high | external-keyboard handshake on the analog jack; shorted to `KC1`, normally open-drain |
| 30–33 | Z3–Z0 | in | | not used |
| 34 | SOUT | out | | not used |
| 35 | SCLOCK | I/O | | not used |
| 36 | **F** | out | | **click and alarm tone** → buzzer (`PC-1600-IO-Ports.md` §6) |
| 37 | VRH | in | | A/D high reference, 2.475 V |
| 38 | KC3 | in | | not used |
| 39 | KC2 | in | | A/D: **CE-1600P supply** (`VPP` via the system bus) |
| 40 | KC1 | in | | A/D: **PC-1600 main supply** |
| 41 | KC0 | in | | analog-input jack: A/D-converted, or read as a logic level for the external keyboard |
| 42–49 | R33…R30, R23…R20 | out | | **return data** to the Z-80, MSB…LSB, through the gate-array buffer read at I/O 33H |
| 50 | VRL | | | NC |
| 51 | SIN | in | | NC |
| 52 | VDD | pwr | | `VGG` |
| 53–60 | R13…R10, R03…R00 | in | | **command byte** from the Z-80, MSB…LSB (TC8576F `/DATA8…/DATA1`) |
| 61 | Q3 | in | | **hardware low-battery.** Active forces the system off. Afterwards only ON or ALL RESET restarts it, the clock is not corrected, and the 0.5 s wake timer stays stopped even once the battery recovers. |
| 62 | Q2 | in | | not used, pulled down |
| 63 | Q1 | in | low | RS-232C `CI`, inverted. Low while off → system on (sampled every 0.5 s). |
| 64 | Q0 | — | | *(the manual gives pin 64 the same "Q0 / system-off" text as pin 1; one of the two labels is a misprint)* |

The pin names (R, Z, K, P, Q ports, `ACL`, `KI`, `F`) follow Sharp's 4-bit SM-series
convention, which is a hint to the chip's family. No source states it.

## 4. Power states (Service Manual §6-3, §7-1)

The sub-CPU alone decides whether the system is on. With the system off, only `VGG` is
present: the sub-CPU, the 16 KB internal RAM and the HD61202 LCD RAM keep power. `VCC`
and `VEE` are cut. The system is on when the `BFO` output of the power circuit is low.

**Off → on**, five ways:
1. the ON/BREAK key (`KH`), the normal way
2. the **wake-up timer** (maskable, IOCS SWPON)
3. RS-232C `CI` (`Q1`)
4. the ALL RESET switch (`ACL`)
5. a reset from the CE-1600P (`KL`)

**On → off**, two ways:
1. a **system-off command from the Z-80**, completed when the SC-7852 pulls `PCTRL` →
   `Q0` low
2. hardware **low-battery** (`Q3`)

At power-on the sub-CPU holds the SC-7852 in reset through `P0` for 30 ms.

### 4.1 How the ROM switches off and back on (ROM disassembly)

**Off.** The system-off command is operand **`EAH`** (timer IOCS 20H, P2-B6 `A88EH`). The
OFF key and auto power-off both end in the LH-5803's OFF routine (rom1500 `E527H`): it
loads `UH = 15H`, waits for parallel-status BUSY = 0, writes `15H` to port 21H **without
complementing it** (so the sub-CPU sees `~15H` = `EAH`), waits for XBUSY to clear, and
executes `HLT` at `E553H`. That HALT is where power goes; nothing after it runs on a real
unit. Before that, the Z-80 side (P0-B0 `0B66H`–`0BB2H`) saves its registers on the
stack, stores SP at **`F0DAH`**, and writes the signature **`A5H A5H A5H A5H`** at
**`FA08H`** (the `ZZ` arithmetic register, reused as scratch).

**On.** Every power-on is a Z-80 reset. The boot code (P0-B0 `0346H`) reads the cause with
IOCS **15H** (operand `A5H`, not in the TRM list), reorders the bits and stores the result
at **`FA1BH`**. (Older notes in this corpus give the address as F1ABH, but the ROM uses
FA1BH.) The reordering maps sub-CPU answer bits to the TRM's start-cause bits
(`PC-1600-Machine-Overview.md` §6.3):

| Answer bit | FA1BH bit | Cause |
|---|---|---|
| 7 | 1 | RESET switch |
| 6 | 2 | reset from the external bus (`KL`) |
| 5 | 0 | ALL RESET (FA1BH is then forced to 01H) |
| 4 | — | ignored |
| 3 | 4 | power-on by the ON key |
| 2 | 5 | power-on from the external bus |
| 1 | 6 | power-on by the wake-up timer (`WAKE$(0)`) |
| 0 | 7 | power-on by RS-232C `CI` (`WAKE$(1)`) |

An all-zero answer is also stored as 10H, the same as ON-key power-on. For any power-on
cause (FA1BH ≥ 10H), `07E6H` checks the `FA08H` signature. If it is valid, `SP` comes back
from `F0DAH` and the machine resumes where it was switched off. The BASIC start
(P0-B0 `0C04H`, `0D67H`) sends the command string at `FF00H` (`WAKE$(0)`) or `FF20H`
(`WAKE$(1)`) to the key buffer when FA1BH bit 6 or 7 is set.

The ROM also has a software shortcut: if the power-off call returns (P0-B0 `0BB6H`), it
jumps into the boot path with `A = 10H`, which is the same as an ON-key power-on without
the reset.

## 5. Interrupts to the Z-80

`Z7` → `INT6`, which is SC-7852 port-32H/35H bit 6 (`PC-1600-CPU-SC7852-Z80.md` §5.2).
The Service Manual lists four causes that raise `Z7`:

1. wake-up time equals the clock
2. alarm 1 or alarm 2 time equals the clock
3. input from the external keyboard
4. the 0.5 s tick of the clock

`Z7` drops when the Z-80 reads the interrupt cause (IOCS 12H SRIRQ) or when all
external-keyboard input has been read. The software view of this, with a cause and mask
bitfield (wake-up, alarm 1, alarm 2, 1 s, 0.5 s), is IOCS 10H–12H in
`PC-1600-IO-Ports.md` §7.1. The 64 Hz tick on `Z6` is a separate line (`INT4`).

**The ROM's INT6 handler** (P1-B3 `419FH`) reads SRIRQ, ORs it with `F07EH`, stores the
bits the SWMSK mask (`F12AH`) leaves disabled back into `F07EH`, and acts on the enabled
ones. The ROM keeping the disabled ones itself means **reading SRIRQ clears the pending
bits in the sub-CPU**. The handler tests these bits:

| Bit | Handler work |
|---|---|
| 1 (0.5 s) | battery check via SRA0 (`A8H`: < AFH sets low battery, ≥ BEH clears it), then SRINP (`A3H`: CI → `ON PHONE`), then the auto-power-off countdown (`F0ACH`, 4B0H half-seconds = 10 min) |
| 0 | `CALL 8075H`, probably the analog-input / external-keyboard event (not traced) |
| 7 | wake-up timer → hook `F0C8H` → sets `F127H` b7 |
| 6 | alarm 1 (`ON TIME$`) → hook `F0C2H` → `F127H` b6 |
| 5 | alarm 2 (`ALARM$`) → hook `F0C5H` → `F127H` b5 |

Bit 2 (the TRM's "1 s signal") is not tested by this handler. The boot enables bits 1
and 0 (SRMSK OR 03H → SWMSK, P0-B0 `05F1H`).

## 6. Command protocol (Service Manual §4-3, TRM §7.1.5)

```
TC8576F (UART)                  LU-57813P
  DSTB        ────────────────► KI
  /BUSY       ◄──────────────── Z10    (high = ready)
  ACK         ◄──────────────── Z9     (pulse = done)
  /DATA8…1    ════════════════► R13…R00   command byte
  D7…D0 ◄═ buffer (LR38041, opened by IORP#) ◄═ R33…R20   return byte
```

1. The Z-80 waits until the sub-CPU is ready (`Z10` high).
2. It sends the command byte and a strobe. The sub-CPU takes the `KI` interrupt and
   handles the command in its ISR.
3. **Type (i), with return data:** the sub-CPU puts the answer on R33–R20 and then
   pulses `Z9`. **Type (ii), no data:** it pulses `Z9` on receipt.
4. The `Z9` pulse is latched by the CPC (XBUSY clears) and the Z-80 polls that latch.
   "Unless ACK is returned within one second, the Z-80 proceeds to the next processing."
5. A type (i) answer is read with `IN A,(33H)`.

Timing from the Service Manual figure: `KI` ≈ 13 µs after the command, ≈ 26 µs wide
(but see `PC-1600-CPC-TC8576.md` §12); the `Z9` pulse ≈ 19.5 µs; `Z10` goes busy for the
duration of the command.

In the ROM all of this is two routines. **`A974H`** complements the byte and sends it
(waits for ready, `OUT (21H)`, waits for ACK). **`A9B6H`** reads one nibble: it writes
`6FH` to port 21H **without** complementing it, then reads `IN A,(33H)`. Commands are
optionally paced to the 64 Hz edge (`PC-1600-IO-Ports.md` §7.3).

## 7. Command set (reconstructed from the ROM)

### 7.1 Encoding

Byte values below are the **operand passed to `A974H`**, i.e. before its `CPL`. The byte
written to port 21H is the complement. The TC8576F's `/DATA` outputs are inverted, so
the operand is also the pin level on R13–R00. Whether the sub-CPU treats those inputs as
active-low is not known. `A9B6H`'s `6FH` is written raw, so in operand terms it is `90H`.

| Operand (port 21H value) | Meaning (from ROM usage) |
|---|---|
| `F0H`+n (`0FH`−n) | first data nibble n: resets the sub-CPU's parameter pointer and stores n |
| `80H`+n (`7FH`−n) | next data nibble n |
| **`90H`+c** (`6FH`−c) | **execute timer IOCS function c** (c = 01H…1FH, see §7.2) |
| `90H` (raw `6FH`, via `A9B6H`) | fetch the next result nibble; read it from port 33H |
| `6xH`, `3CH`, `53H`, `A3H`, `EAH`, `E5H`, `B0H`, `B1H` | individual functions, §7.2 |

Multi-byte data travels as nibbles: a byte `hl` becomes `…+h`, `80H+l`. The
`SETCOM`-style data blocks for the clock and timers go out as one `F0H`+n head nibble
followed by 8 more nibbles (4 bytes, `A9CFH`) before the `90H`+c execute. Reads run the
other way: the execute, then 7 or 9 nibble fetches.

### 7.2 Timer IOCS → sub-CPU commands

Dispatcher: `CALL 01D5H` with the IOCS number in C → `A798H` → a jump table at `A74AH`
(entries 00H–26H). IOCS names are the TRM's (`PC-1600-IO-Ports.md` §7). Numbers marked
"—" are not in the TRM list.

| IOCS | Name | Handler | Sub-CPU traffic |
|---|---|---|---|
| 00H | SINIT | `A7BE` | no command of its own. It loads defaults and calls 10H, 14H, 1EH, 24H, 1CH/1DH, 22H. |
| 01H | SBEEP | `A87B` | `91H` |
| 02H / 04H / 06H / 08H | SWRT / SWWT / SWA1T / SWA2T | `A84B` | `F0H`+n, 8 × `80H`+n, then `92H` / `94H` / `96H` / `98H` |
| 03H / 05H / 07H / 09H | SRRT / SRWT / SRA1T / SRA2T | `A881` | `93H` / `95H` / `97H` / `99H`, then 9 nibble fetches (clock) or 7 (timers) |
| 0AH–0EH | — | `A905` | `F0H`+n, 15 × `80H`+n (8 bytes), `9AH`–`9EH`, then `A3H` and a test of one bit of the answer → CF: bit 2 after 0AH/0BH, bit 3 after 0CH/0DH, bit 0 after 0EH. **0AH / 0BH are `PASS`**: store the password / clear it if the 8 bytes match; SRINP bit 2 then reports whether a password is set. 0CH–0EH: unknown 8-byte functions. |
| 0FH | — | `A92F` | `9FH`, then 8 nibble fetches (4 bytes) |
| 10H | SWMSK | `A8E7` | `F0H`+hi, `80H`+lo of the mask, then `A0H` |
| 11H / 12H / 13H | SRMSK / SRIRQ / SRINP | `A8F0` | `A1H` / `A2H` / `A3H`, one byte read from 33H |
| 14H | SWPON | `A893` | `F0H`+n, `A4H`. The nibble (kept at `F12BH`): b0 power-on by `CI` (`WAKE$(1)`), b1 power-on by the wake-up timer (`WAKE$(0)`), b2 wake-up beep, b3 hour signal |
| 15H | *(reset cause)* | `A8F0` | `A5H`, one byte read: the power-on / reset cause, §4.1. Read once by the boot code (P0-B0 `0346H`). |
| 17H, 1BH–1DH, 1FH | — | `A8F0` | `A7H`, `ABH`–`ADH`, `AFH`, one byte read |
| 16H | — | `A8F8` | if `F12CH` b1 = 1 and b0 = 0: `A6H`, one byte read. Otherwise returns CF = 1 with no traffic. |
| 18H / 19H / 1AH | SRA0 / SRA1 / SRA2 | `A8F0` | `A8H` / `A9H` / `AAH`, one byte read (A/D value) |
| 1EH | — | `A8C2` | `F0H`+n (n = 9, 5 or 3 from A), `AEH`, then `53H` |
| 20H | *(system off)* | `A88E` | `EAH`: switch the system off (§4.1). The LH-5803 OFF routine sends the same byte. |
| 21H | SRPON | `A89C` | `69H`, one nibble fetch: the SWPON nibble back |
| 22H / 23H | SWAB / SRAB | `A8A4` / `A8BE` | `6AH` then `80H`+n (write) or a nibble fetch (read) |
| 24H | SWA1A | `A93B` | `3CH`, then the two threshold bytes as nibbles |
| 25H | *(probe)* | `A951` | `B0H` → expect `AAH`; `B1H` → expect `55H` (`PC-1600-IO-Ports.md` §7.3) |
| 26H | — | `A96C` | `E5H` |

So SRA0/SRA1/SRA2 are type-(i) commands answered with one A/D byte. SRMSK/SRIRQ/SRINP
answer with a bitfield. The clock reads need the separate nibble-fetch command because
the answer is longer than one byte.

**Cross-reference.** `PC-1600-IO-Ports.md` §7.3 gives the 0.5 s ISR's two requests in
port-21H terms as `5DH` and `5CH`. Those are the complements of `A2H` and `A3H`, i.e.
IOCS 12H SRIRQ (read interrupt cause) and 13H SRINP. The ISR is traced in §5.

### 7.3 Clock and timer data (P2-B6 `A84BH` / `A881H`)

All four blocks (clock, wake-up timer, alarm 1, alarm 2) use the same layout. The write
sends 9 nibbles: first the **month** as one nibble (`F0H`+n, from the low nibble of the
parameter block's first byte), then **day, hour, minute and second** as BCD pairs, high
nibble first (`80H`+n each). The read returns 9 nibbles for the clock and 7 for a timer
(month, day, hour, minute; no seconds).

A field whose nibbles are all `F` is a **wildcard**. BASIC turns a `?` digit into nibble
`F` (rom3b `50D6H`/`510AH`), so `ALARM$="??/??/13/30"` goes out with month `F` and day
`FF`. The read-back display treats `0FH`/`FFH` as `??` (`50EAH`). For the clock write
(SWRT), the same all-`F` field means "leave this field unchanged". That is how a partial
`TIME$=` or `DATE$=` works.

Writing a timer also clears its pending bit in `F127H` (b7 wake-up, b6 alarm 1, b5
alarm 2). Writing the clock clears all three (mask table at `A868H`).

## 8. Open items

- **Chip identity.** Probably a mask-ROM member of Sharp's SM 4-bit family (pin naming,
  4-bit data paths, 1.2288 MHz ÷ 4), but no part cross-reference has been found. Its ROM
  is not dumped.
- **Still-unnamed commands:** IOCS 0CH–0FH, 17H, 1BH–1FH, 26H (`E5H`) and the
  follow-up byte `53H` after 1EH. 1EH/24H/16H/1CH/1DH belong to the analog-input
  interrupt / external-keyboard mode (`F12CH` bits 0–1, 4), but that path isn't traced.
  SWAB's two bits (the alarm-signal condition) aren't named yet either.
- **The LH-5803's other raw command, `23H`** (rom1500 `E523H`, operand `DCH`): its answer
  bit 2 is tested, but its meaning is unknown.
- **The F-pin tones** (key click, alarm, wake-up beep, hour signal): frequency and length
  are unmeasured.
- **When exactly the pending bits are set**: the Service Manual says the timers are
  compared "at each minute carry", but whether a wildcard alarm fires once per matching
  minute or keeps repeating isn't documented.
- **External-keyboard protocol** on the analog jack (`KC0`, `Z4`): no documentation
  beyond the pin notes.
- **Pin 1 / pin 64** both labelled `Q0` in the manual.
