# PC-1600 I/O Port Map (bit level)

## Scope

Every Z-80 I/O port the PC-1600 decodes. The SC-7852 has a 256-byte I/O space (00H–FFH),
"similar to the Z-80A" (TRM §7.1.1(3)). This document carries the bit-level detail; the
range map and the SC-7852-internal control block at 30–3FH are also summarised in
`PC-1600-CPU-SC7852-Z80.md` §7 and the bank registers in
`PC-1600-Memory-Bank-Switching.md` Part 2/9 — those remain the primary homes for that
material and are cross-referenced rather than duplicated.

**Sources so far:** TRM §7.1.1(3) (range map), §7.9 (the LH-5810-compatible port,
10–1FH), §7.6 (TC8576F register select, 20–27H), §7.5 (buzzer), §7.3 (LCD, 50–5BH).
Still pending: §3.4 (interrupt cause/mask bit detail for 32H/35H), §3.9 (timer / analog
port), §3.6 (UART parameter/command register contents), §3.7–3.8 (78–83H peripheral
ports).

---

## 1. Range map (TRM §7.1.1(3))

| Range | Assignment | Strobe |
|---|---|---|
| 00H–0FH | **Use prohibited** | — |
| 10H–1FH | **LH-5810/LH-5811-compatible port** inside the SC-7852 (not φOS-synced) — §2 | — |
| 20H–27H | TC8576F UART register select — §3 | `IOSU#` (pin 59) |
| 28H–2FH | Slot 2 (S2) I/O — Port 28H vertical-bank select (`PC-1600-Memory-Bank-Switching.md` Part 2) | `KA1#`/`KA2#` (pins 53/54) |
| 30H–3FH | **SC-7852 internal control-register block** — §4 (detail in `PC-1600-CPU-SC7852-Z80.md` §7.2) | — |
| 40H–4FH | System reserve | `E` strobe covers 40H–5FH |
| 50H–57H | HD61102 LCD column driver — mostly IC2; §5 and `PC-1600-Display-HD61202.md` §3 | `E` (pin 60) |
| 58H–5BH | HD61102 LCD column driver — mostly IC3 | `E` |
| 60H–6FH | Slot 2 (S2) I/O, second window | `KA0#` (pin 55) |
| 78H–7FH | CE-1600F (floppy) | — |
| 80H–83H | CE-1600P (plotter/printer) | — |
| 84H–BFH | Reserved for future extension | — |

## 2. The LH-5810-compatible port, 10H–1FH (TRM §7.9)

Seven read/write registers. Reading or writing one is accompanied by a read/write on the
matching Z-80 I/O address. These drive the SC-7852's PA0–PA7 (pins 62–70, keyboard
strobes), PB2/PB5/PB6/PB7 (pins 71–74), and the PC-port outputs PC6 (buzzer, pin 75) and
SD0 (cassette write, pin 76). Not synchronised to φOS.

| Reg | I/O addr | Purpose |
|---|---|---|
| OPC | 18H | PC-port output buffer |
| MSK | 1AH | interrupt mask (LH-5810-style path) |
| IF | 1BH | interrupt flags |
| DDA | 1CH | PA port direction |
| DDB | 1DH | PB port direction |
| OPA | 1EH | PA port output buffer / input latch |
| OPB | 1FH | PB port output buffer / input latch |

### 2.1 MSK register — 1AH

Write (mask; bit = 1 → interrupt enabled):

| Bit | Mask for |
|---|---|
| b0 | **IRQ** |
| b1 | **PB7** (BREAK/ON key status from the sub-CPU) |
| b3 | **flag TD** (serial-transfer-complete) |
| b2, b4–b7 | unused |

Read layout (upper nibble = live signal states, lower nibble = the mask bits):

```
 b7    b6    b5    b4    b3     b2     b1     b0
 CL1   SD1   PB7   IRQ   MSKb3  MSKb2  MSKb1  MSKb0
```

### 2.2 IF register — 1BH (TD is read-only)

| Bit | Name | Meaning |
|---|---|---|
| b0 | IF0 | set to 1 on the **rising edge of IRQ** |
| b1 | IF1 | set to 1 on the **rising edge of PB7** |
| b3 | TD | 1 when a serial data transfer completes; cleared to 0 when the CPU loads the serial data into the register. Read-only. |
| b2, b4–b7 | X | unused |

### 2.3 DDA / DDB — 1CH / 1DH (direction)

For each bit *i*: `0` → PAi / PBi is **input**; `1` → **output**, driving the content of
OPAi / OPBi. (DDB: the scan shows b5/b6 unmarked; the PB pins actually used are PB2 (b2),
PB5 (b5), PB6 (b6), PB7 (b7) — treat b0/b1/b3/b4 as don't-care.)

### 2.4 OPA / OPB — 1EH / 1FH (buffer)

- **Output** (DDxi = 1): writing the port loads the bus byte into OPxi, driven out on
  PAi / PBi.
- **Input** (DDxi = 0): the OPxi→pin path is suppressed; the pin state is latched into
  OPxi and returned on the bus when the port is read.

### 2.5 OPC — 18H (PC-port buffer)

Buffer for data sent to the PC port. The data bus can also be latched into OPC on the
**falling edge of φOS** (from the SC-7852). Two meaningful bits:

| Bit | Routed to | Effect |
|---|---|---|
| b7 | `SD0` terminal (pin 76) | cassette write output |
| b6 | `PC6` terminal (pin 75), **inverted** | buzzer / BEEP drive |
| b0–b5 | X | — |

(Pin-level gate logic: `PC6 = NAND(PB2, PC6', PC7', SD0)`, `SD0 = OR(SD0', PC7')` —
`PC-1600-CPU-SC7852-Z80.md` §6, pins 75/76.)

### 2.6 Relationship to the 32H/35H interrupt system

The MSK/IF pair here latches **IRQ**, **PB7** and the **TD** serial flag. The separate
7-source cause/mask registers at I/O **32H / 35H** (`PC-1600-CPU-SC7852-Z80.md` §5.2)
aggregate the machine-wide interrupt causes. Both ultimately feed the Z-80 INT line; the
TRM does not spell out how the two layers combine. Needs TRM §3.4 (interrupt work area)
to reconcile — flagged open.

## 3. TC8576F UART register select, 20H–27H (TRM §7.6)

The UART decodes its `A1`,`A0` inputs from I/O-port bits 1 and 0, combined with the
read/write direction:

| A1 | A0 | dir | Function (port) |
|---|---|---|---|
| 0 | 0 | read | RXD → data bus (serial receive) — port 20H read |
| 0 | 0 | write | data bus → TXD (serial transmit) — port 20H write |
| 0 | 1 | read | PIN → data bus (parallel/Centronics data in) — port 21H read |
| 0 | 1 | write | data bus → PVOUT (parallel data out) — port 21H write |
| 1 | 0 | read | serial status → data bus — port 22H read |
| 1 | 0 | write | data bus → **parameter register** — port 22H write |
| 1 | 1 | read | parallel status → data bus — port 23H read |
| 1 | 1 | write | data bus → **command + parameter address** — port 23H write |

`CS#` high, or `RD#`=`WR#`=1, tri-states the data bus. `CS#` is `IOSU#` (SC-7852 pin 59),
low on any I/O access to 20H–27H. The UART's own `INT` output (logical OR of RXRDY,
TXRDY, PRRDY, PTRDY) reaches the SC-7852 on `INT0` (pin 81).

**Baud rate:** the IC's clock input is divided by a programmable 4-bit prescaler →
SYS-CLK, then by a programmable 12-bit divider (the baud-rate generator) → any rate
50–38400 baud. Programmed via the parameter register (port 22H write) and command
sequence (port 23H write). Exact byte formats: TRM §3.6.2 / §7.6 detail — pending.

The BASIC-level view of these registers (`SETCOM`, `SNDSTAT`, etc.) is in
`PC-1600-Serial-Commands.md`; the line-signal hardware in `PC-1600-Serial-Hardware-Notes.md`.

## 4. SC-7852 internal control block, 30H–3FH

Full table with per-address `IOR`/`IOW` names in `PC-1600-CPU-SC7852-Z80.md` §7.2.
Summary: **31H** = primary bank-select register; **32H/35H** = interrupt cause / mask
(§5.2 there); **38H** = CPU-switch trigger; **39H** = IM2 vector low byte; **3CH** b6 =
LHS1–3 remap; **3DH** = hidden-ROM / extended-address latch; **37H** bit 4 = LCD-clock
(`CK0`) enable. Writing wrong values anywhere in 30H–3DH makes the machine malfunction
(TRM note).

## 5. LCD ports, 50H–5BH

HD61102 IC2/IC3 select via CS1#/CS2#/CS3 wired to address bits A2/A3/A4/A5 — table and
caveats in `PC-1600-Display-HD61202.md` §3.

## 6. Buzzer (TRM §7.5)

No dedicated port. The buzzer is driven between two signals: **PC6** (SC-7852, via OPC
b6 inverted — §2.5) and **F** (LU-57813P). It sounds when either is asserted.

- **PC6** path OR-combines: cassette playback (PB2), cassette record, the BEEP-command
  ON signal (PC7), and the CE-150/CE-162 record signal (SD0'). `BEEP OFF` holds PC6 high
  (silent). Silent state = PC6 high.
- **F** path combines: click-ON, wakeup-ON, alarm-ON. Silent state = F low.

### 6.1 BEEP IOCS routines (TRM §3.10)

Direct-call (`CALL <addr>`); both sound regardless of the BASIC `BEEP ON/OFF` setting.

| Name | Entry | Params | Return |
|---|---|---|---|
| **BOUT** | `01B4H` | A = pitch (00H–FFH), BC = duration (0000H–FEFFH), DE = repeat count | CF = 0 ok / CF = 1 stopped by BREAK. Clobbers AF. |
| **SOUT** | `01B7H` | A = pitch, BC = duration (no repeat) | as BOUT |

- **frequency = 1 300 000 / (166 + 22·A)** Hz
- **duration = BC · (166 + 22·A) / 1 300 000 = BC / frequency** seconds

The keyboard-click routine is `SBEEP` (IOCS 01H via the timer dispatcher, §7).

## 7. Timer, RTC, and analog port (TRM §3.9)

The sub-CPU (LU-57813P) owns the real-time clock, the wakeup/alarm timers, and a
3-channel ADC. All of it is reached through IOCS routines, **not** raw ports:
**IOCS number → `C`, then `CALL 01D5H`.** Most clobber only `AF`.

| Name | # | Function |
|---|---|---|
| SINIT | 00H | initialise the timer + analog port. A = 00H All-Reset / 01H power-on after OFF key / 02H power-on after auto-power-off |
| SBEEP | 01H | generate a keyboard click |
| SWRT | 02H | set the calendar-clock (RTC) date/time — HL = param block |
| SRRT | 03H | read the RTC date/time |
| SWWT | 04H | set the wakeup-timer date/time |
| SRWT | 05H | read the wakeup-timer date/time |
| SWA1T | 06H | set alarm-timer 1 (like BASIC `ON TIME$`) |
| SRA1T | 07H | read alarm-timer 1 |
| SWA2T | 08H | set alarm-timer 2 (like BASIC `ALARM$`) |
| SRA2T | 09H | read alarm-timer 2 |
| SWMSK | 10H | set the **sub-CPU** interrupt mask (A-register bitfield, §7.1) |
| SRMSK | 11H | read the sub-CPU interrupt mask |
| SRIRQ | 12H | read which sub-CPU interrupts are pending (same bitfield) |
| SRINP | 13H | read the RS-232C `CI` signal status |
| SWPON | 14H | set the power-on-condition mask |
| SRPON | 21H | read the power-on-condition values |
| SRA0 | 18H | read the digitised **PC-1600 supply voltage** |
| SRA1 | 19H | read the digitised **analog-input voltage** |
| SRA2 | 1AH | read the digitised **battery voltage** |
| SWAB | 22H | set the alarm-signal-generation condition |
| SRAB | 23H | read the alarm-signal-generation condition (as set by SWAB) |
| SWA1A | 24H | set the trigger thresholds for a software interrupt on the analog-input value |

### 7.1 Sub-CPU interrupt bitfield (SWMSK / SRMSK / SRIRQ, in `A`)

This is a **separate, finer layer** from the port-32H/35H aggregator: these are the
events the sub-CPU itself raises, all of which funnel into port-32H/35H **bit 6**
("interrupt from the sub-CPU", `PC-1600-CPU-SC7852-Z80.md` §5.2).

| Bit | Event |
|---|---|
| 7 (MSB) | wakeup timer |
| 6 | alarm timer 1 |
| 5 | alarm timer 2 |
| 2 | 1 s signal |
| 1 | 0.5 s signal |

(mask: bit = 1 → enabled; SRIRQ: bit = 1 → that event is pending)

## TODO

- §3.4: exact edge/level behaviour of 32H (cause) / 35H (mask) — reconcile the two
  interrupt layers (port 35H bit 6 ↔ §7.1 sub-CPU bitfield).
- §3.9: the SWRT/SRRT RTC param-block byte layout; the ADC value range/scaling for
  SRA0/SRA1/SRA2; the SWPON power-on-condition mask bits.
- §3.6.2 / §7.6: TC8576F parameter-register and command-byte formats.
- §3.7 / §3.8: CE-1600P (80–83H) and CE-1600F (78–7FH) port detail.
- Confirm the 50–5FH LCD per-port decode against real hardware.
