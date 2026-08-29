# PC-1600 Serial Hardware (RS-232C / SIO) + Wiring Notes

## 1. Serial hardware architecture (TRM §7.6)

The PC-1600 has **two serial ports — RS-232C and SIO** — but only **one** serial engine:
the **TC8576F** UART LSI (a single-chip CMOS device holding the RS-232C ART = async
receiver/transmitter, its baud-rate generator, and a Centronics parallel
transmit/receive interface). Because there is only one channel, **RS-232C and SIO cannot
be used at the same time.**

- **Port select:** the BASIC `OPEN` / `SETDEV` commands, or the hardware `PRIM` signal
  (LR38041 gate array pin 17). `PRIM` **high** → RS-232C; `PRIM` **low** → SIO. Power-on
  and reset pull `PRIM` low (SIO is the default).
- With `PRIM` high (RS-232C): the RS-232C interface supply `VDD` (≈ 6.0 V) is applied,
  `SDF`/`RDF` (SIO lines) go low, and the UART's `TXD`/`RXD` are placed **inverted** on
  the RS-232C `TXD`/`RXD` lines.
- With `PRIM` low (SIO): `VDD` is cut, and the UART's `TXD`/`RXD` are placed **inverted**
  on the SIO's `SDF`/`RDF` lines. RS-232C outputs are held high-impedance or low.
- **Gate-array routing table (LR38041):**

  | Line | PRIM = low (SIO) | PRIM = high (RS-232C) |
  |---|---|---|
  | output SDA | LOW | TXD# |
  | output SDF | TXD# | LOW |
  | input RXD | RDF | RDA |

- **RS-232C line levels:** conform to EIA/JIS, level-shifted by the hybrid IC **BX7269W**
  — incoming ±V shaped to 0/VCC logic, outgoing logic converted to VDD…VCC swing. `VEE`
  (≈ −8.5 V) provides the negative side.
- **Power note:** RS-232C draws more than SIO (it needs `VDD` generation). After an
  RS-232C session, switch back to SIO to save battery.

### TC8576F pinout (as wired in the PC-1600)

| Pin | Symbol | Dir | Active | Function |
|---|---|---|---|---|
| 1 | (NC) | — | — | not used |
| 2 | RD# | In | Low | CPU reads data/status from the TC8576F |
| 3 | WR# | In | Low | TC8576F takes data/control words from the CPU |
| 4 | CS# | In | Low | chip select; high tri-states the data bus and blocks RD/WR. Driven by `IOSU#` (SC-7852 pin 59, low on I/O 20H–27H). |
| 5, 6 | A1, A0 | In | — | register select (with RD#/WR#) — see the truth table in `PC-1600-IO-Ports.md` §3 |
| 7, 18 | GND | pwr | — | |
| 8 | INT | Out | High | logical OR of RXRDY, TXRDY, PRRDY, PTRDY → SC-7852 `INT0` (pin 81) |
| 9–16 | D7–D0 | I/O | — | data bus |
| 17 | VCC | pwr | — | |
| 42 | RESET# | In | Low | resets the IC; low suppresses all functions |
| 43 | P5V | I/O | — | parallel mode, tied to GND; `CDS`=1 → 1-bit output port, `CDS`=0 → input voltage supply for an external device |
| 44 | PE | I/O | — | parallel-mode paper-end; `CDS`=1 → 1-bit output port, `CDS`=0 → receives PE from an external device |

**Baud rate:** IC clock ÷ programmable 4-bit prescaler → SYS-CLK ÷ programmable 12-bit
divider → any rate **50–38400 baud**. The clock into the UART is `CLK1` from the gate
array (CL2 passed through while the system is on). Parameter/command byte formats: TRM
§3.6.2 — pending. BASIC-level control (`SETCOM`, `SNDSTAT`, …): `PC-1600-Serial-Commands.md`.

## 2. FTDI USB/UART wiring (practical)

> Extracted from the "PC-1600: USB Serial Adapter" section of
> `sharp-pocket-computer/SharpCommunicator/HardwareNotes.md` (in the separate, public
> `sharp-pocket-computer` repository — [github.com/tinue/sharp-pocket-computer](https://github.com/tinue/sharp-pocket-computer),
> not part of this repository — left unchanged there). That file's "PC-1500/A:
> CE-158X" section was not copied — it documents a modern third-party clone board, not
> original Sharp hardware. Referenced photos (`pictures/Pin_Adapter.jpg`,
> `pictures/Calculator.jpg`) remain in the original repository.

The Sharp PC-1600 has a serial device built in. It uses fairly standard 5V logic, and can be interfaced
with currently available FTDI adapters. When using an original (non-cloned) FTDI adapter, no additional
logic chips or inverters are required.

Components used:

- 1mm pins, bent 90 degrees
- A small board for soldering the pins. Search for "1.27mm 2.54mm Adapter Board" on the merchant site of your choice.
  While no 15 pin boards were found, 12 pins are enough for the signals that are required.
- USB/UART cable: "FTDI TTL-232R-5V-WE", i.e. 5V logic and wire ends.

Before the USB / UART adapter can be used, it needs to be reprogrammed using a Windows
machine. The signals of the RX, TX, RTS and CTS pins need to be inverted. This
can be done with a utility provided by FTDI. This is a one-time operation, because the
change is persistent even after unplugging the cable.

The wiring is as follows (pin 1 is the rightmost pin of the PC-1600's 15-pin serial connector):

| Pin | Signal PC-1600 | Connect this cable of the USB/UART | USB/UART wire color |
|-----|----------------|------------------------------------|---------------------|
| 2   | TX             | RX                                 | yellow              |
| 3   | RX             | TX                                 | orange              |
| 4   | RTS            | CTS                                | brown               |
| 5   | CTS            | RTS                                | green               |
| 7   | TX             | Ground                             | black               |

Note: Do not connect the red cable (5V) of the adapter.

## Problem with Apple Silicon Mac

On a Mac with the Apple Silicon chip, the USB UART Adapter does not work as it should,
probably due to a bug in the driver. The protocol that is used for flow control
is "RTS/CTS". In this, the sender (i.e. the Mac) requests to send a byte by raising
the RTS line ("request to send"). Then it is supposed to wait until the receiver
(the PC-1600) acknowledges readiness by raising the CTS line ("clear to send").
However, the Mac does not wait and starts to send right away, and the data
is lost. The other direction (PC-1600 to Mac) works fine.

As a workaround: build the transfer tool on the Mac and send it to a Raspberry Pi via `scp`.
The PC-1600 is connected to the Raspberry Pi, and sending / receiving happens
on the Raspberry Pi via a remote `ssh` session from the Mac.
