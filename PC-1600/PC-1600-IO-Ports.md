# PC-1600 I/O Port Map (bit level)

## Scope

Every Z-80 I/O port the PC-1600 decodes. The SC-7852 has a 256-byte I/O space (00H–FFH),
"similar to the Z-80A" (TRM §7.1.1(3)). This document carries the bit-level detail; the
range map and the SC-7852-internal control block at 30–3FH are also summarised in
`PC-1600-CPU-SC7852-Z80.md` §7 and the bank registers in
`PC-1600-Memory-Bank-Switching.md` Part 2/9 — those remain the primary homes for that
material and are cross-referenced rather than duplicated.

**Sources so far:** TRM §7.1.1(3) (range map), §7.9 (the LH-5810-compatible port,
10–1FH), §7.6 (TC8576F register select, 20–27H), §7.5 (buzzer), §7.3 (LCD, 50–5BH); plus
the Systemhandbuch's own port-by-port appendix (David von Oheimb, *Das Systemhandbuch für
den PC-1600*, Appendix 6 "I/O-Adressen (Ports)", PDF pp. 94–96), which independently
confirms and fills in detail for most of the ranges below — cited inline as "Appendix 6"
below.
Still pending: §3.4 (interrupt cause/mask bit detail for 32H/35H — partially filled by
Appendix 6, §4 below), §3.9 (timer / analog port), §3.6 (UART parameter/command register
contents).

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
| 70H–77H | CE-1600F (floppy), **second unit** — mirrors 78H–7FH (Appendix 6) | — |
| 78H–7FH | CE-1600F (floppy) — port-level detail in `PC-1600-Peripherals-Hardware.md` §2.6 | — |
| 80H–83H | CE-1600P — **dual-purpose**: plotter/printer mode *and* a Centronics parallel-printer mode (Appendix 6); detail in `PC-1600-Peripherals-Hardware.md` §1.2.2/§1.3 | — |
| 84H–FFH | Reserved for future extension | — |

## 2. The LH-5810-compatible port, 10H–1FH (TRM §7.9)

Seven read/write registers. Reading or writing one is accompanied by a read/write on the
matching Z-80 I/O address. These drive the SC-7852's PA0–PA7 (pins 62–70, keyboard
strobes), PB2/PB5/PB6/PB7 (pins 71–74), and the PC-port outputs PC6 (buzzer, pin 75) and
SD0 (cassette write, pin 76). Not synchronised to φOS.

Appendix 6 labels the whole block "compatible to the PC-1500's port chip **LH-5811**" (an
earlier draft of this doc, sourced from TRM §7.9 alone, called it LH-5810/LH-5811 —
kept as-is, not a contradiction: Sharp's port-compatible chip family covers both part
numbers across the PC-1500 line). It also adds two registers TRM §7.9 doesn't name here:

| Reg | I/O addr | Purpose |
|---|---|---|
| — | 14H write | divider reset (`Teiler-Reset`) |
| — | 15H read | `U` register — serial receive |
| — | 16H write | `L` register — serial transmit |
| — | 17H read/write | `F` register — serial-output modulation. Also a continuous tone on the buzzer: `OUT &17,65` on, `OUT &17,0` off (§2.7) |
| OPC | 18H | PC-port output buffer |
| — | 19H | `G` register — wait control / baud rate |
| MSK | 1AH | interrupt mask (LH-5810-style path) |
| IF | 1BH | interrupt flags |
| DDA | 1CH | PA port direction |
| DDB | 1DH | PB port direction |
| OPA | 1EH | PA port output buffer / input latch — used for the **keyboard strobe** (Appendix 6) |
| OPB | 1FH | PB port output buffer / input latch |

### 2.1 MSK register — 1AH

Write (mask; bit = 1 → interrupt enabled). **Corrected/completed against Appendix 6** —
the TRM excerpt previously transcribed here missed a bit (there is no "unused b2"; it's a
second serial flag):

| Bit | Mask for |
|---|---|
| b0 | **IRQ** (PC-1500-peripheral interrupt) |
| b1 | **PB7** (BREAK/ON key status from the sub-CPU) |
| b2 | **TD** — sender/transmit flag |
| b3 | **RD** — receiver flag |
| b4–b7 | unused |

Read layout (upper nibble = live signal states, lower nibble = the mask bits from 1Aw
above — Appendix 6 names the upper-nibble signals `RD`/`TD` where an earlier draft of
this doc, from the TRM alone, had the less-specific pin names `CL1`/`SD1`):

```
 b7    b6    b5    b4    b3     b2     b1     b0
 RD    TD    PB7   IRQ   MSKb3  MSKb2  MSKb1  MSKb0
(CL1)  (SD1)
```

So **bit 5 of a 1AH read is the ON key's live level** (PB7, 1 = pressed), readable any
time without the IF latch. Baum, *PC-1600 Systemhandbuch* (ISBN 3-924327-31-9) p.92: *"Sowohl Bit 5 der E/A Adresse &1A als auch
Bit 7 in &1F (PB7) werden bei gedrückter ON-Taste gesetzt"* — `INP &1A AND &20` or
`INP &1F AND &80`.

### 2.2 IF register — 1BH

A flip-flop per bit, retained until explicitly cleared — same bit assignment as the MSK
register above:

| Bit | Name | Meaning |
|---|---|---|
| b0 | IF0 | set to 1 on the **rising edge of IRQ** |
| b1 | IF1 | set to 1 on the **rising edge of PB7** |
| b2 | TD | serial-transmit-complete flag |
| b3 | RD | serial-receive flag; cleared when the CPU loads the received serial data — the earlier draft of this doc placed this "TD, read-only" at b3 instead, based on the TRM excerpt alone; Appendix 6 clarifies there are **two** independent flags (TD at b2, RD at b3), not one |
| b4–b7 | X | unused |

### 2.3 DDA / DDB — 1CH / 1DH (direction)

For each bit *i*: `0` → PAi / PBi is **input**; `1` → **output**, driving the content of
OPAi / OPBi. (DDB: the scan shows b5/b6 unmarked; the PB pins actually used are PB2 (b2),
PB5 (b5), PB6 (b6), PB7 (b7) — treat b0/b1/b3/b4 as don't-care.)

**OPB pin meanings (Appendix 6, register 1FH):**

| Bit | Signal |
|---|---|
| b7 | BREAK key — the ON key's **live level**, 1 = pressed. The same bit reads as MSK (1AH) bit 5. See Keyboard §8 |
| b6 | keyboard strobe #8 |
| b5 | 1/64-second pulse |
| b2 | cassette-receive input |

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

**Resolved: both readings are right.** Appendix 6 glosses 18H as "b7: buzzer line
(active = 0), b6: buzzer on". That looked like it contradicted the pin-level table above
(b7 = cassette write). Baum, *PC-1600 Systemhandbuch* (ISBN 3-924327-31-9), Anhang A p.93, settles it:
"&18 Port PC — Bit 6: 0 = BEEP OFF, 1 = BEEP ON; Bit 7: **Cassettenausgang und
Lautsprecher** (cassette output *and* loudspeaker), 0 = low, 1 = high". b7 is the SD0
cassette-write line, and that same line sounds the buzzer. That's the gate
`PC6 = NAND(…, SD0)`. b6 is the BEEP ON/OFF gate. The BEEP tone loop matches (P1-B3
`5EB9H`): it toggles b7 with b6 = 1. `BEEP OFF` clears b6 and silences everything on
this line.

### 2.6 Relationship to the 32H/35H interrupt system

The MSK/IF pair here latches **IRQ**, **PB7** and the **TD** serial flag. The separate
7-source cause/mask registers at I/O **32H / 35H** (`PC-1600-CPU-SC7852-Z80.md` §5.2)
aggregate the machine-wide interrupt causes. Both ultimately feed the Z-80 INT line; the
TRM does not spell out how the two layers combine. Needs TRM §3.4 (interrupt work area)
to reconcile — flagged open.

### 2.7 F register — 17H: the modulated output as a tone generator

The F register works as in the PC-1500's LH5810/5811 (PC-1500 TRM 3-2 D and 3-3-2 (9), pp.69/72):

| Bits | Meaning |
|---|---|
| F6 | SDO output mode: 0 = normal serial data, 1 = **modulated** |
| F3–F5 | FY: modulation clock for data 0 — φ ÷ 64 / 128 / 256 / 512 / 1024 (codes 0–4) |
| F0–F2 | FX: modulation clock for data 1 — same code table |

In modulated mode `SDO = SXO·FX + /SXO·FY`. With nothing being transmitted, SXO idles at
mark (1), so **SDO is a continuous FX square wave**.

Baum, *PC-1600 Systemhandbuch* (ISBN 3-924327-31-9), Anhang A p.93, lists port &17 as a *"Dauerton, Synchronisationssignal für
Cassettenaufnahmen. Einschalten: OUT &17,65 — Ausschalten: OUT &17,0"*: the cassette
leader tone. 65 = 41H: F6 = 1, FX = φ÷128, FY = φ÷64.

**φ = 1.3 MHz ÷ 4 = 325 kHz, measured (2026-09-23).** The dampflok program (Baum p.52)
whistles with exactly these writes. A real unit plays **2539 Hz**: 2533.24 Hz recorded,
less the recorder's −0.22 % established by the BEEP measurements
(`PC-1600-CPU-SC7852-Z80.md` §2.3). That is 1.3 MHz ÷ 512, i.e. FX = ÷128 of 325 kHz.
- Baum prints "2639 Hz". That is a typo: no power-of-two division of 1.3 MHz or 3.58 MHz
  gives 2639 Hz (1.3 MHz ÷ 492.6).
- The PC-1500 differs. Its LH5811 runs the dividers from 1.3 MHz directly: the CE-150
  tape code writes F = 63H (FX ÷512 = 2539 Hz, FY ÷1024 = 1270 Hz), the documented
  2500 / 1250 Hz tape tones (`../Data-Formats/PC-1500-Tape-Format.md`).

**Buzzer path.** SDO is an input to the same buzzer gate as OPC b7/b6, not a replacement
for b7. In the recording the whistle continues unchanged while a noise routine writes
random 00H/FFH to 18H, and both are heard. Treating all inputs as idle-high:
**buzzer drive = (OPC b6 ∧ OPC b7) ∧ SDO**. So `BEEP OFF` (b6 = 0) silences the tone as
well, consistent with `PC6 = NAND(…, SD0)` (§2.5).

The PC-1600's own ROM writes 17H only with 01H (normal mode), in the CE-1600P cassette
read code (P1-B5 `62BDH`).

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

**Port 21H dual use (Appendix 6).** Besides parallel data out, port 21H doubles as the
**command port for the sub-CPU timer/RTC/analog block** when not in use for parallel
I/O — i.e. this address is shared between the Centronics-parallel path and the timer
dispatcher (§7 below), not exclusive to one function. 24H–27H mirror 20H–23H but are
"incompletely decoded" (Appendix 6's own wording) — treat them as unreliable aliases,
not a second independent register block.

**Baud rate:** the IC's clock input is divided by a programmable 4-bit prescaler →
SYS-CLK, then by a programmable 12-bit divider (the baud-rate generator). In the PC-1600,
XCLK = 1.2288 MHz and the boot code sets the prescaler to ÷2, so **baud = 76800 / B**
(50–38400 baud). All the register and bit formats are in
[`PC-1600-CPC-TC8576.md`](PC-1600-CPC-TC8576.md), from the Toshiba data sheet: the port-23H
three-way write decode, PR0–PR7, serial status/command, parallel status/command. That
document also covers how the ROM programs the chip.

The BASIC-level view of these registers (`SETCOM`, `SNDSTAT`, etc.) is in
`PC-1600-Serial-Commands.md`; the line-signal hardware in `PC-1600-Serial-Hardware-Notes.md`.

## 4. SC-7852 internal control block, 30H–3FH

Full table with per-address `IOR`/`IOW` names in `PC-1600-CPU-SC7852-Z80.md` §7.2.
Summary: **31H** = primary bank-select register; **32H/35H** = interrupt cause / mask
(§5.2 there); **38H** = CPU-switch trigger; **39H** = IM2 vector low byte; **3CH** b6 =
LHS1–3 remap; **3DH** = hidden-ROM / extended-address latch; **37H** bit 4 = LCD-clock
(`CK0`) enable. Writing wrong values anywhere in 30H–3DH makes the machine malfunction
(TRM note).

**Appendix 6's own per-address gloss**, useful confirmation/completion of the summary
above (some entries not previously itemised in this corpus — reconcile fully against
`PC-1600-CPU-SC7852-Z80.md` §7.2 before treating as authoritative on its own):

| Addr | Op | Function |
|---|---|---|
| 31H | write | bank switching |
| 32H | read | interrupt cause |
| 33H | read | input from the timer |
| 34H | — | interrupt mask for the LH-5803 |
| 35H | — | interrupt mask for the Z-80 |
| 37H | write | b4 = LCD-processor clock on |
| 37H | read | input from the keyboard matrix |
| 38H | write | switch control between the two CPUs |
| 39H | write | low byte of the indirect interrupt address (IM2) |
| 3AH, 3BH | — | unused |
| 3CH | write | **SLOTMAP** (slot remapping); readback of the current value is kept at `F08DH` (`PC-1600-Work-Area-Map.md`) |
| 3DH | write | bank-select for BASIC-ROM vs. JAPAN-ROM: b2 = `4000H`–`7FFFH` is Bank 3 (normal ROM module) when set, else BASIC-ROM; b1 = `8000H`–`BFFFH` is Bank 4 (JAPAN-ROM) when set, else BASIC-ROM. Readback kept at `F07DH` |
| 3EH, 3FH | — | unused |

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
- The modulated serial output **SDO** of the 10H–1FH block (F register, §2.7) also drives
  the PC6 path. That's how the cassette sync tone (`OUT &17,65`) is heard.

### 6.1 BEEP IOCS routines (TRM §3.10)

Direct-call (`CALL <addr>`); both sound regardless of the BASIC `BEEP ON/OFF` setting.

| Name | Entry | Params | Return |
|---|---|---|---|
| **BOUT** | `01B4H` | A = pitch (00H–FFH), BC = duration (0000H–FEFFH), DE = repeat count | CF = 0 ok / CF = 1 stopped by BREAK. Clobbers AF. |
| **SOUT** | `01B7H` | A = pitch, BC = duration (no repeat) | as BOUT |

- **frequency = 1 300 000 / (166 + 22·A)** Hz
- **duration = BC · (166 + 22·A) / 1 300 000 = BC / frequency** seconds

**Measured on a real unit (2026-09-23, microphone recordings):**

- **Pitch.** `A`=200 → **287.13 Hz**, `A`=50 → **1038.15 Hz**, both 0.22 % below the
  exact loop count. At 3.58 MHz the tone loop (P1-B3 `5EB9H`) is **60·A + 441 T-states
  per period**: 52·A + 389 nominal plus one wait per M1 cycle
  (`PC-1600-CPU-SC7852-Z80.md` §2.3). The TRM formula above is a rounded form of this.
- **Duration.** Exactly `BC` periods. `BC` = 1 is silent: the loop sets the line high,
  counts down to zero and exits before it ever goes low.
- **Repeats** (`DE` > 1, BASIC `BEEP n,A,d`). Between tones the ROM (P1-B3 `5F12H`)
  counts **6 rising edges of PB5**, the sub-CPU's free-running 64 Hz square wave on port
  1FH bit 5 (§2). Tone and pause together therefore take
  **(⌈T / P⌉ + 5) · P**, with P = 1/64 s and T the tone length (`BC` periods).
  Confirmed on hardware for:

  | BEEP | Tone T | Period |
  |---|---|---|
  | 5,200,5 | 17.4 ms | 109.4 ms (7 P) |
  | 5,50,100 | 96.1 ms | 187.5 ms (12 P) |
  | 20,200,20 | 69.5 ms | 156.25 ms (10 P) |
  | 5,200,100 | 348 ms | 437.5 ms (28 P) |

  All periods are steady; a real unit never adds a tick. A long ISR during the pause,
  such as the slow sub-CPU path in §7.3, would eat PB5 edges and add a tick.
- **Acoustic response.** Relative to its 2–3 kHz peak, the buzzer reproduces a
  287 Hz fundamental at about −52 dB, 861 Hz at −21 dB and 1.4 kHz at −7 dB. It then
  falls to −10…−25 dB over 5–7 kHz. A low BEEP is heard through its 3rd–11th
  harmonics, not its fundamental. Mic recordings vary ±5 dB take to take. One point, a
  1038 Hz fundamental, came out ~12 dB above that curve, so 0.8–1.4 kHz is not pinned
  down.

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
| SWA1A | 24H | set the trigger thresholds for a software interrupt on the analog-input value — thresholds are stored at `F12DH` (lower) / `F12EH` (upper), `PC-1600-Work-Area-Map.md` §3.9 |
| *(undocumented)* | 25H | sub-CPU capability probe, run once at boot (P0-B0 `03B7H`); result ORed into `F0B8H`. See §7.3 |

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


### 7.2 Analog-input connector (CN6)

Physical 3-pin header, separate from the serial connectors, carrying the raw signal that
`SRA1` (§7 above) digitises:

| Pin | Signal |
|---|---|
| 1 | GND |
| 2 | NC |
| 3 | AIN (analog input) |

`AIN` reaches this connector directly from the gate array (`AIN(CN2-10)` on the main
board) — it does not pass through the TC8576F UART or the BX7269W RS-232C level shifter
(`PC-1600-Serial-Hardware-Notes.md` §1). Source: PC-1600 main-board wiring diagram scan
(2026-09-04); pin labels 2/3 are legible, exact silkscreen names not cross-checked
against the TRM.

### 7.3 Command-byte pacing: IOCS 25H and `F0B8H` bit 0 (ROM disassembly)

Every command byte the Z-80 sends to the sub-CPU goes out through one routine
(P2-B6 `A9FBH`). It writes the byte to port 21H, the TC8576F parallel port wired to the
LU-57813P. It has two modes, chosen by **`F0B8H` bit 0**:

- **bit 0 = 1:** `OUT (21H),A` immediately.
- **bit 0 = 0:** first wait for the next **PB5 transition** (port 1FH bit 5, the 64 Hz
  signal), polling the TC8576F status (`AA33H`) meanwhile, then send. Each byte then costs
  up to one 64 Hz half period, **7.8 ms**.

Boot clears bit 0 and then ORs in the result of timer **IOCS 25H** (P0-B0 `03B7H`,
handler P2-B6 `A951H`). It isn't in the TRM's IOCS list; it is a handshake:

1. send `B0H` (written to port 21H as `4FH`: the routine complements every byte, and the
   CPC's inverted `/DATA1–8` outputs turn it back into `B0H` at the sub-CPU —
   `PC-1600-CPC-TC8576.md` §9.4). If the answer
   read from port 33H is `AAH`,
2. send `B1H` (`4EH`). If the answer is `55H`, return A = 1, otherwise A = 0.

So a sub-CPU that answers `AAH` / `55H` gets unpaced command transfer, and one that
doesn't is driven in lock-step with its 64 Hz tick. It looks like provision for two
sub-CPU revisions (an assumption; no source names them). The 0.5 s-timer ISR sends two
bytes (requests 5DH and 5CH). In paced mode it therefore runs ~8–16 ms and always
spans a PB5 edge, which would make BEEP repeats slip a tick (§6.1). The unit measured
for §6.1 never slips, so **it answers the probe**.

## TODO

- §3.4: exact edge/level behaviour of 32H (cause) / 35H (mask) — reconcile the two
  interrupt layers (port 35H bit 6 ↔ §7.1 sub-CPU bitfield). **Bit 4 resolved
  (2026-08-30, Systemhandbuch §7.3/§7.4):** a plain free-running 64 Hz, 50%-duty square
  wave from the sub-CPU's Z6 pin (INT4/PB5), not edge-latched — see
  `PC-1600-CPU-SC7852-Z80.md` §5.2. Bits 0-3/5-7 still open. Baum, Anhang A p.94, names the
  bits for users as 0 = serial receive, 1 = peripherals (printer and floppy), 4 = 1/64 s
  timer, 6 = 1/2 s timer, and says a 35H bit of 0 disables that cause. That agrees with
  the TRM table; it doesn't settle edge/level behaviour.
- §3.9: the SWRT/SRRT RTC param-block byte layout; the ADC value range/scaling for
  SRA0/SRA1/SRA2; the SWPON power-on-condition mask bits.
- ~~§3.6.2 / §7.6: TC8576F parameter-register and command-byte formats~~ — **resolved**
  (2026-09-26, Toshiba TC8576AF data sheet): `PC-1600-CPC-TC8576.md`.
- ~~§3.7 / §3.8: CE-1600P (80–83H) and CE-1600F (78–7FH) port detail~~ — **resolved**
  (2026-09-18, Systemhandbuch Appendix 6): full detail now in
  `PC-1600-Peripherals-Hardware.md` §1.2.2/§1.3 (plotter/Centronics dual-mode) and §2.6
  (floppy port-level command/status registers).
- Confirm the 50–5FH LCD per-port decode against real hardware.
- ~~OPC (18H) buzzer-bit discrepancy between Appendix 6's gloss and the gate-logic-derived
  table (§2.5)~~ — **resolved** by Baum, Anhang A p.93: b7 = cassette output *and*
  loudspeaker, b6 = BEEP ON/OFF.
- F register (17H): the SXO → FY path (tone while serial data is actually being sent
  through L, 16H), and whether G (19H) affects the modulation clocks, are unmeasured.
