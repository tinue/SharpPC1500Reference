# PC-1600 Machine Overview

## Scope

The whole-machine picture the other PC-1600 documents assume: the chip complement and
how they interconnect, the clock tree, how the two main CPUs share one bus, what the
sub-CPU does and how the main CPU talks to it, the power rails, and reset/boot. Detail
that has its own home is cross-referenced, not repeated:

- Instruction set / CPU programmer's model → `PC-1600-CPU-SC7852-Z80.md`
- Bank switching, chip selects, the LR38041 gate-array pin table →
  `PC-1600-Memory-Bank-Switching.md`
- Bit-level I/O ports → `PC-1600-IO-Ports.md`
- LCD, keyboard → `PC-1600-Display-HD61202.md`, `PC-1600-Keyboard.md`

**Sources:** PC-1600 Technical Reference Manual §7.1 (block diagram, CPU specs, CPU↔CPU
and sub-CPU↔main-CPU interfaces) and §7.7 (power supply), read from the German
Systemhandbuch scan; §3.5 (system start-up) and §5.14 pending.

---

## 1. Chip complement

Per the TRM §7.1 block diagram, the PC-1600 is built around a gate array plus a
single-chip main CPU, with three processors in total.

| Ref | Part | Role | Clock |
|---|---|---|---|
| — | **SC-7852** | Main CPU 1 (native): Z-80A-equivalent core + on-chip clock gen, memory-select logic, interrupt control, LH-5810-style I/O port, LH-5803 interface. 100-pin LSI. | 3.58 MHz |
| — | **LH-5803** | Main CPU 2: executes PC-1500-compatible LH-5801 code. | 2.6 MHz crystal → 1.3 MHz internal |
| — | **LU-57813P** | Sub-CPU: 4-bit CMOS. Power management, real-time clock, wakeup/alarm timers, key-wake, BREAK/ON, low-battery detect, analog input, auto-power-off. | 307.2 kHz (from a 1.229 MHz input, CL2) |
| **LR38041** | Gate array | Bus routing, chip-select buffering to the slots, sub-CPU↔main-CPU data buffer, A13A/A14A–A16A address generation, PRIM (RS-232C/SIO) mux, low-battery gating. 64-pin. | — |
| **TC8576F** | UART | One async serial channel (ART) + baud-rate generator + Centronics parallel interface. Serves *either* RS-232C *or* SIO, not both at once. | fed CL2-derived clock |
| **HD61203** | LCD common driver | Row drive for the 156×32 panel + 16-symbol status line. | 217 kHz (CK0 from SC-7852) |
| **HD61102 ×2** | LCD column drivers | IC2, IC3. | — |
| **BX7269W** | RS-232C hybrid IC | Level-shifts EIA/JIS ±V line signals ↔ logic. | — |
| — | ROM | 3 × 27C256 (256 Kbit / 32 KB) = 96 KB: 80 KB Z-80 BASIC + 16 KB LH-5803. | — |
| — | RAM | 2 × 8 KB static = 16 KB internal, battery-backed. | — |

Memory sizing, bank layout and the ROM/RAM PWB wiring are in
`PC-1600-Memory-Bank-Switching.md` Parts 1 and 12.

## 2. Clock tree

| Clock | Source | Feeds |
|---|---|---|
| **3.58 MHz** | crystal on SC-7852 XIN/XOUT; on-chip CGC | the Z-80 core; buffered out on `CLK` (pin 86) |
| **1.3 MHz** (`φOS`) | LH-5803 side (2.6 MHz crystal ÷2) | LH-5803 core; fed *into* the SC-7852 on pin 4 as the sync for the LH-5810-style port and the source for the LCD clock |
| **217 kHz** | derived from φOS inside the SC-7852 | `CK0` (pin 56) → HD61203 LCD common driver; gated by bit 4 of I/O port 37H (0 at power-on, set when the boot routine turns the LCD on) |
| **1.229 MHz** (`CL2`) | oscillator into the gate array (pin 7) | the sub-CPU; also passed through the gate array as `CLK1` (pin 42) to become the TC8576F UART base clock while the system is on (low when off) |
| **307.2 kHz** | sub-CPU internal | LU-57813P |
| **64 Hz** (1/64 s) | sub-CPU `Z6` terminal | interrupts the SC-7852 every 1/64 s for the key scan (→ `INT4`, pin 83; tied to PB5) |

## 3. Dual main-CPU bus sharing (TRM §7.1.4)

The SC-7852 and LH-5803 are wired **directly to the same bus**. Only the running CPU
drives the system bus; the idle one is floated. They cannot run simultaneously — one is
always halted while the other runs.

Bus-signal correspondence:

| SC-7852 pin | Z-80 meaning | LH-5803 meaning |
|---|---|---|
| A15–A0 | A15–A0 | A15–A0 |
| DB7–DB0 | D7–D0 | D7–D0 |
| MREQ | (opposite polarity of Z-80 `MREQ#`) | ME0 |
| IORQ | (opposite polarity of Z-80 `IORQ#`) | ME1 |
| RD# | RD# | OD |
| WR# | WR# | R/W |

**Which CPU is running:** the `ELH#` signal (SC-7852 pin 77). `ELH#` low = LH-5803
running; high = SC-7852 running. A system reset drives `ELH#` high and the SC-7852
starts.

**Hand-off:**

- SC-7852 → LH-5803: `OUT (38H),A` (A value irrelevant), then `HALT`.
- LH-5803 → SC-7852: `STA #A038H` (the LH-5803-side alias of I/O port 38H, see
  `PC-1600-CPU-SC7852-Z80.md` §7.2 — LH-5803 I/O 38H shadows Z-80 I/O 38H).

The OS wraps this in the `CALLH` routine at 01C6H — its full parameter block (CMDZ mode
byte at F002H, PARA…PARUH register values at F005H–F00BH, LH-5803-view entry address at
F00CH–F00DH, bank/PV at F00EH) and the register write-back on return are in
`PC-1600-CPU-LH5803-Compat.md` §3 (TRM §5.14).

The extra wait states the SC-7852 inserts into *LH-5803* cycles (LHWAIT, IOE) for
accesses to certain regions are in `PC-1600-CPU-SC7852-Z80.md` §2.4.

## 4. Sub-CPU ↔ main-CPU interface (TRM §7.1.5)

The LU-57813P sub-CPU is reached through the **TC8576F UART's parallel side** plus a
data buffer **inside the LR38041 gate array**.

Wiring:

```
TC8576F (UART)                 LU-57813P (sub-CPU)
  DSTB  ───────────────────►  KI
  BUSY  ◄───────────────────  Z10
  ACK   ◄───────────────────  Z9
  DATA1..DATA8 ────────────►  R00..R13     (command byte in)
                    R20..R33 ────────────► [buffer in LR38041] ──► D7..D0
                                            ▲
                              IORP (from SC-7852) gates the buffer
```

**Command protocol:**

1. The SC-7852 checks the sub-CPU is ready (TC8576F `BUSY` high).
2. Within 500 µs of a 1/64 s-signal edge, the SC-7852 writes an 8-bit command byte to the
   UART parallel-data lines DATA1–DATA8, then asserts the UART's `DSTB`.
3. The sub-CPU receives the command on R00–R13 and executes it in an interrupt service
   routine. Two command classes:
   - **Type 1 (returns data):** on completion the sub-CPU places return data on R20–R33
     and pulses `Z9` to signal done. The SC-7852 reads the return byte with an
     **`IN` from I/O port 33H** — `IORP#` goes low and the buffer drives D0–D7.
   - **Type 2 (no return data):** the sub-CPU pulses `Z9` on receipt; the SC-7852 waits
     for `Z9` to go high.

Approximate timing from the TRM figure: `KI` pulse ≈ 13 µs / 26 µs; `Z9` (ACK) ≈ 19.5 µs;
`Z10` = Ready → Busy → Ready across the command.

The sub-CPU's interrupt into the main CPU is `INT6` (SC-7852 pin 84), carrying: the
0.5 s timer, low-battery check, analog-input interrupt, CI-signal interrupt, auto
power-off, RS-232C timeout, and the wakeup / alarm1 / alarm2 timers (TRM §3.4.1(2)).

## 5. Power supply (TRM §7.7)

Four rails:

| Rail | Voltage | On when | Powers |
|---|---|---|---|
| **VGG** | 4.0–4.7 V | **always** (even system-off) | the ICs that must retain state: internal 16 KB RAM (data retention); LU-57813P (RTC + wakeup timer); HD61102 (display-data retention across auto-power-off while the machine stays on); LR38041 (to hold select signals such as the memory-select lines inactive) |
| **VCC** | 4.0–4.7 V | system-on only | ROM (256 Kbit ×3); CPUs SC-7852 + LH-5803; HD61203 LCD driver; TC8576F UART |
| **VEE** | ≈ −8.5 V | — | negative bias for the LCD driver and RS-232C line signals |
| **VDD** | ≈ 6.0 V | only when `PRIM` high (RS-232C selected) | positive supply for RS-232C line signals; off when `PRIM` low (SIO selected) |

Power sources: (1) internal batteries, (2) AC adapter, (3) `VBAT` on the system bus.
If more than one is connected, the highest-voltage source is used.

Because RS-232C draws more than SIO (VDD generation), the TRM recommends switching back
to SIO after an RS-232C session to save battery (see also `PC-1600-Serial-Hardware-Notes.md`).

## 6. Reset and boot

- `RSTIN#` (SC-7852 pin 79) is forced low for **30 ms** by the sub-CPU on power-on, ACL,
  or RESET.
- On reset the gate array forces `A13A` high, `A15A` low, `A14A` high — establishing the
  initial bank configuration (`PC-1600-Memory-Bank-Switching.md` Part 3).
- `ELH#` goes high → the SC-7852 runs first.
- Standard Z-80 reset state, then the reset routine selects IM 2, sets the IRQ mask, and
  runs the boot search. Reset cause is stored at F1ABH.

### 6.1 Power-on process (TRM §3.5.1)

`Z80 RESET` (start at 0000H) → the **IOCS reset-handling routine**. If the machine was
woken by the auto-power-off wakeup, it checks whether the wake conditions are satisfied
(CF = 0 allowed / 1 not) and, if so, just runs `IOCS KEYGET`. Otherwise `A` holds the
power-on conditions → **Initialization** (with interrupts masked) → dispatch on the start
event: *ON key · ON from external bus · Wakeup event · CI turned on · ALL RESET · RESET ·
Reset from external bus* → per-event processing → the IOCS→BASIC handoff → **"Auto
program run?"** → *Command level* or *Program run state*.

### 6.2 Boot search order (TRM §3.5.2)

At the end of the power-on process the IOCS jumps to an entry point chosen in this order:

1. **Boot program on a data medium** — a RAM-disk memory file or a 2.5″ floppy whose
   boot sector holds a loader in the medium-specific format (`PC-1600-Filesystem.md`
   §5.1). The PC-1600 loads it into memory and jumps to its start address.
2. **A system-software module** — if a module with a system header is in a slot, jump to
   the entry address in its header (`PC-1600-Memory-Bank-Switching.md` Part 6 / TRM
   §3.13.3).
3. **The application pointer** — a work-area slot holding entry address + bank, written
   on Reset / All-Reset. **This is how the BASIC interpreter itself is entered.**

### 6.3 System state at the application entry point (TRM §3.5.2(1))

1. All registers and flags are undefined **except `A`, `I`, `SP` and the IRQ-mask flag**.
2. `SP` is at its reset value.
3. `I` and interrupt mode 2 are set; the Z-80 IRQ-mask flag is `DI` (0).
4. Exactly one bit of `A` is set, giving the **start cause**:

   | Bit | Started by |
   |---|---|
   | 0 | All-Reset |
   | 1 | Reset |
   | 2 | Reset from the external bus |
   | 3 | always 0 |
   | 4 | power-on via the ON key |
   | 5 | power-on via the external bus |
   | 6 | power-on via the wakeup function |
   | 7 | power-on via the SIO `CI` signal |

   (Same bitfield as the F1ABH reset-cause byte, `PC-1600-Memory-Bank-Switching.md`
   Part 6.)

## 7. Peripheral catalogue (TRM Chapter 1)

The system bus is "PC-1500-serial-compatible", so the PC-1600 can use most PC-1500/1500A
peripherals (with the MODE-1 restrictions in `PC-1600-CPU-LH5803-Compat.md` §6).

**PC-1600 peripherals:** CE-1600P (A4 4-colour plotter-printer with cassette interface —
also hosts the floppy), CE-1600F (2.5″ floppy drive), CE-1650F (2.5″ floppy 10-disk
pack), CE-1600M (32 KB RAM module), CE-1620M (32 KB EPROM module) + CE-1601E PROM
programmer, CE-1602T (SIO↔RS-232C converter), CE-1600L (optical-fibre cable),
CE-1601L (modem/acoustic-coupler cable), CE-1602L (RS-232C cable for MZ-5500/5600),
CE-1603L (for PC-5000 / CE-158), CE-1604L (for IBM-PC / PC-7000), CE-1605L (open-end
RS-232C cable), CE-1601N (bar-code pen reader), CE-1F01A (bar-code reader utility, on
floppy).

**PC-1500 peripherals usable on the PC-1600:** CE-150 (colour graphics printer/plotter),
CE-151 (4 KB RAM), CE-152 (cassette recorder), CE-155 (8 KB RAM), CE-158 (RS-232C /
parallel interface), CE-159 (8 KB program module), CE-161 (16 KB program module),
CE-162E (parallel / cassette interface).

Notes: CE-150 and CE-158 cannot be used together with the CE-1600P; connecting a CE-1600F
requires a CE-1600P; CE-158 and CE-162E cannot connect to the CE-1600P.

## Open items

- TRM §7.1.5 "Fig. b" exact timing numbers are read off a small scan; treat the µs
  figures as approximate.
- The relationship between the LH-5810-style port's MSK/IF interrupt latches (I/O
  1AH/1BH, `PC-1600-IO-Ports.md`) and the port-32H/35H interrupt aggregator
  (`PC-1600-CPU-SC7852-Z80.md` §5.2) is not spelled out by the TRM — both feed the Z-80
  INT line; needs the §3.4 work-area detail to reconcile.
