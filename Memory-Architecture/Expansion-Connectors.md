# Expansion Connector Reference: PC-1500, PC-1500A, PC-1600

## 1. Overview

This document consolidates the physical expansion-connector pinouts for the PC-1500, PC-1500A, and PC-1600 (Slot 1 and Slot 2) in one place, since understanding how any given module (period or modern) works starts with knowing exactly which physical wires it has to work with.

It covers: the PC-1500's 40-pin and 60-pin connectors (§2); the PC-1500A's pin reassignment relative to the PC-1500, and how far a fixed-wiring module can be pushed against that reassignment (§3); and the PC-1600's 60-pin system bus connector and two 40-pin slot connectors, CN-7 (Slot 1) and CN-8 (Slot 2) (§4).

For what happens *behind* these pins — the on-mainboard address decoders, chip populations, and bank-switching logic that give each pin its meaning — see `PC-1500-Address-Decoding.md` (PC-1500/1500A) and `PC-1600-Memory-Bank-Switching.md` (PC-1600). This document is the physical-pinout reference those documents assume; §3 here also hosts a worked example (a hypothetical wide module) that draws on both.

---

## 2. The PC-1500 Expansion Connectors

The PC-1500 exposes two distinct expansion connectors, both documented in TRM §4-3 ("Connector signals/LSI signals"): a 40-pin connector (§4-3-1) and a 60-pin connector (§4-3-2). The TRM's own introductory note to §4-3 states that "there may be a different kind of connector used for the 40 and 60 pin connector of the PC-1500 on account of product revision," and that "the 64-pin connector on the back of the CE-150 is compatible with the 60-pin connector of the PC-1500."

### 2.1 40-Pin Connector

The PC-1500 exposes its expansion bus on a 40-pin edge connector on the rear (confirmed by physical pin count on real hardware).

| Pin | Signal | Description |
|-----|--------|-------------|
| 1 | VCC | Power |
| 2 | **PV** | CPU flipflop output (chip select function) |
| 3 | **PU** | CPU flipflop output (chip select function) |
| 4 | YO | Address &0000–&3FFF chip select |
| 5 | S4 | Address &6000–&67FF select (may be NC depending on production month) |
| 6 | DME0 | Chip select with WAIT condition (ME0 area) |
| 7–14 | D7–D0 | Data bus |
| 15 | INHIBIT | Prohibits ROM select when connected to GND |
| 16 | S1 | Address &4800–&4FFF select |
| 17 | S2 | Address &5000–&57FF select |
| 18 | S3 | Address &5800–&5FFF select |
| 19 | Y2 | Address &8000–&BFFF select |
| 20 | VGG | Negative supply |
| 21 | GND | Ground |
| 22–37 | AD15–AD0 | Address bus (16 bits) |
| 38 | OD | Output disable |
| 39 | R/W | Memory read/write |
| 40 | GND | Ground |

*Source: Sharp PC-1500 Technical Reference Manual, section 4-3-1.*

**PU and PV** (pins 3, 2) are CPU flipflop outputs on the LH5801 (`SPU`/`RPU`/`SPV`/`RPV` instructions), described in the TRM as "chip select" signals — modules can use them as extra chip-select gating inputs, alongside their primary role of bank-selecting the system's own &8000–&BFFF ROM area (PC-1500 system ROM vs. CE-150/CE-158 peripheral ROM). See `PU-PV-Signals.md` for the full mechanism, including the CE-158/TRAMsoft PU conflict and why modern module recreations avoid PU/PV entirely in favor of address-range triggers.

**YO** (pin 4) is the sole chip select for the entire &0000–&3FFF module RAM/ROM region — a 16KB window with no further narrowing done by the mainboard. A module populating this window must do its own internal sub-decoding (see the CE-155 example in `PC-1500-Address-Decoding.md` §3.2).

There is no dedicated bank-select address register on the connector for any region — PU/PV (write-only CPU flipflops) and the address-range strobes (Y0, Y2, S1–S3, S4) are the only mechanisms available for a module to learn "which bank" or "which sub-region" the host is addressing.

### 2.2 60-Pin Connector

| Pin | Signal | Description |
|-----|--------|-------------|
| 1 | AD7 | Address bus |
| 2 | AD6 | Address bus |
| 3 | AD5 | Address bus |
| 4 | AD4 | Address bus |
| 5 | AD3 | Address bus |
| 6 | AD2 | Address bus |
| 7 | AD1 | Address bus |
| 8 | AD0 | Address bus |
| 9 | PB0 | Not used (may be NC depending on production month) |
| 10 | PC7 | Not used |
| 11 | VCC | Power |
| 12 | VCC | Power |
| 13 | NC | Not connected |
| 14 | NC | Not connected |
| 15 | **PV** | Chip select |
| 16 | **PU** | Chip select |
| 17–24 | D7–D0 | Data bus |
| 25 | INHIBIT | Prohibits ROM select of the PC-1500, when connected to GND |
| 26 | WEX | External WAIT signal |
| 27 | CMTIN | Cassette data input |
| 28 | W1 | WAIT condition input |
| 29 | CMTOUT | Cassette data output |
| 30 | INT | Interrupt request to CPU |
| 31–38 | AD8–AD15 | Address bus |
| 39 | PB1 | Not used (may be NC depending on production month) |
| 40 | NC | Not connected |
| 41 | VCC | Power |
| 42 | VCC | Power |
| 43 | F-GND | Frame GND |
| 44 | VBAT | Battery voltage |
| 45 | VBAT | Battery voltage |
| 46 | VBAT | Battery voltage |
| 47 | VBAT | Battery voltage |
| 48 | VBAT | Battery voltage |
| 49 | NC | Not connected |
| 50 | BFO | VCC output |
| 51 | φOS | Clock in the same phase as the LSI internal clock |
| 52 | GND | Ground |
| 53 | GND | Ground |
| 54 | GND | Ground |
| 55 | GND | Ground |
| 56 | DME0 | Chip select taking consideration of WAIT condition (ME0 area designation) |
| 57 | R/W | Memory read/write signal |
| 58 | DME1 | Chip select taking consideration of WAIT condition (ME1 area designation) |
| 59 | ME1 | ME1 area designation |
| 60 | OD | Output disable |

*Source: Sharp PC-1500 Technical Reference Manual, section 4-3-2. Note in source: "PB0 of No. 9 may be NC depending on production month. PB1 of No. 39 may be NC depending on production month."*

This is the PC-1500(A)'s side expansion connector: the CE-150 plugs into it via a 60-pin male connector, and per the TRM §4-3 note above, the CE-150's own 64-pin female connector at its rear is pin-compatible with it — letting a further peripheral (typically a CE-158) chain onto the CE-150 in turn. This connector is the PC-1500's I/O expansion bus, distinct in purpose from the 40-pin memory-expansion connector in §2.1: it carries the full 16-bit address and 8-bit data bus (like the 40-pin connector), but adds cassette I/O (CMTIN/CMTOUT), an interrupt line (INT), an external WAIT mechanism (WEX/W1), and a second WAIT-qualified chip-select/area pair (DME1/ME1) alongside DME0 — none of which appear on the 40-pin connector at all.

#### 2.2a Cross-validation against the PC-1600's 60-pin connector

The PC-1600's 60-pin system bus connector (§4.0 below) is a documented match in form factor and largely in pin assignment, confirming both scans are internally consistent (this document's original transcription source for §4.0 was the PC-1600 TRM's §10.3(1), a separate document from the PC-1500 TRM scanned here). Lining the two tables up pin-for-pin:

**Strong agreement** (same pin, equivalent signal, in both machines — good corroboration for both scans):
- Pins 1–8: address bus low byte, identical bit order (AD7→AD0 / A7→A0) on both.
- Pins 17–24: data bus, identical order (D7→D0) on both.
- Pins 25: INHIBIT (PC-1500) / INH (PC-1600) — same function, same pin.
- Pins 27, 29: CMTIN, CMTOUT — identical on both, same pins.
- Pins 31–38: address bus high byte, identical order (AD8→AD15 / A8→A15) on both.
- Pins 41, 52–54: VCC and GND land on the same pins on both machines.
- Pin 50–51: BFO, φOS — identical signals, same pins, on both.
- Pin 56: DME0 — identical signal, same pin, on both.

**Divergences** (real architectural differences between the LH5801-based PC-1500 and the Z-80/LH5803-based PC-1600, not transcription errors — the PC-1600 replaces the PC-1500's direct PU/PV CPU flipflops with a gate-array-buffered PT/PU/PVOUT triple, and its Z-80 core has separate RD/WR/IORQ/MREQ/INT/M1 lines where the LH5801 has a single R/W and a single INT):
- Pins 15–16: PC-1500 has PV then PU; PC-1600 has PU then PVOUT — the bank-select signals are present on both but in reversed pin order and with PV replaced by the gate-array's PVOUT.
- Pins 9–10, 13–14: PC-1500 has PB0/PC7 (unused)/NC/NC; PC-1600 has INT1̄/M1̄/RSTE/PT — the PC-1600 uses this range for Z-80-specific control and the sub-CPU's PT bank-select bit.
- Pins 26, 28, 30: PC-1500 WEX/W1/INT vs. PC-1600 IORQ/WAIT/IRQ — both pairs are WAIT- and interrupt-related, but the PC-1600 versions are genuine Z-80 bus signals rather than the PC-1500's simpler external-WAIT/interrupt lines.
- Pins 39, 42: PC-1500 has PB1 (unused)/VCC; PC-1600 has VGG/NC.
- Pins 43–49: PC-1500 runs F-GND (43) then five VBAT pins (44–48) then NC (49); PC-1600 runs FG (43–44) then two VBAT pins (45–46) then VP (47) and NC (48–49, with MREQ at 49). Both machines dedicate this range to frame ground + battery backup, but with different pin counts per signal.
- Pin 55: GND (PC-1500) vs. NC (PC-1600).
- Pins 57–60: PC-1500 has R/W, DME1, ME1, OD; PC-1600 has WR̄, ELH̄, IOE, RD̄ — the PC-1500's single-strobe LH5801 read/write and second-bank chip-select signals are replaced by the Z-80's split RD̄/WR̄ strobes and the PC-1600-specific ELH̄/IOE lines.

**Net assessment:** the two scans agree exactly, pin-for-pin, on every signal common to both CPU architectures (address bus, data bus, INHIBIT/INH, CMTIN/CMTOUT, VCC/GND placement, BFO/φOS, DME0) — strong evidence neither transcription has a shifted or misread pin in those ranges. The divergences are concentrated exactly where the two machines' CPUs and bus protocols genuinely differ (bank-select signal set, interrupt/WAIT signals, read/write strobes, ground/battery pin counts), which is what a real hardware difference should look like rather than an OCR error. The one place worth double-checking against a second PC-1500 TRM scan if one surfaces: pins 15–16 (PV/PU order) and 43–49 (F-GND/VBAT run), since those are the only divergent regions where a plausible alternative reading (e.g. an accidentally swapped row) would still land on named signals rather than obvious garbage.

---

## 3. The PC-1500A: Pin Reassignment and How Far It Reaches

### 3.1 What changed

Four pins carry a different signal depending on the model. This is a **connector pinout change, not a change to the decoder itself** — full explanation of the cause (built-in RAM growing from S0-only to S0+S1+S2) is in `PC-1500-Address-Decoding.md` §3.

| Pin | PC-1500 signal | PC-1500A signal |
|---|---|---|
| 5 | S4 (&6000–&67FF) | NC |
| 16 | S1 (&4800–&4FFF) | S3 (&5800–&5FFF) |
| 17 | S2 (&5000–&57FF) | S4 (&6000–&67FF) |
| 18 | S3 (&5800–&5FFF) | S5 (&6800–&6FFF) |

Every other pin — including YO (pin 4), Y2 (pin 19), PU/PV (pins 3/2), DME0 (pin 6), and the full address/data bus — is unchanged between models. A module's hardware never has to know which machine it's plugged into: it just reacts to whatever strobe physically arrives on its fixed pins.

### 3.2 The ceiling: S5 never reaches the connector on the PC-1500 at all

Only **four** pins in this range carry a strobe on the PC-1500: pins 5, 16, 17, 18 (S4, S1, S2, S3). S5, S6, and S7 never appear on any connector pin on the PC-1500 — only S1–S4, YO, and Y2 reach the expansion bus. This means:

- The largest fixed-wiring module obtainable via these four pins on the PC-1500 covers **S1+S2+S3+S4** (8KB), tiling exactly against built-in S0 (2KB) to fill &4000–&67FF. S5 (&6800–&6FFF) is permanently unreachable by any module — not because Sharp chose to leave it unpopulated, but because no physical wire for it exists. This is why the PC-1500's own decode table marks S5 "Not used" (`PC-1500-Address-Decoding.md` §2.2) rather than "optional."
- The same four pins on the PC-1500A decode to: pin 5 → **NC**, pin 16 → S3, pin 17 → S4, pin 18 → S5. So the identical module gets **S3+S4+S5** (6KB) there, with the pin-5-wired bank left floating/dead.

**Worked comparison — the maximal fixed-wiring module, Y0 fully populated on both models:**

| Model | Y0 (&0000–&3FFF) | Built-in | Module (S-blocks) | Total | Gaps |
|---|---|---|---|---|---|
| PC-1500 | 16KB (module) | S0, 2KB | S1+S2+S3+S4, 8KB | **26KB** | S5 (2KB) permanently unreachable |
| PC-1500A | 16KB (module) | S0+S1+S2, 6KB | S3+S4+S5, 6KB | **28KB** | none — &0000–&6FFF fully tiled |

The PC-1500A version of this module fills its entire available window (&0000–&3FFF plus &4000–&6FFF) with no gaps. The PC-1500 version is short exactly 2KB relative to that, because S5 was never wired to the connector on that model — a ceiling Sharp's four-pin design imposes structurally, independent of chip population or built-in RAM.

A *wider* hypothetical module — one wanting S1 through S5 on the PC-1500 (10KB) and S3–S5 on the PC-1500A (6KB) — is not just short by 2KB; it's unbuildable on the PC-1500 side outright, since there is no fifth pin to wire S5 to in the first place. Sharp's connector design covers the CE-155 case (3 pins, exact 4KB shift, no gaps on either model) and stretches to a 4-pin/8KB module (1500) vs. 3-pin/6KB module (1500A) with one dead bank on the 1500A — but goes no further. See `PC-1500-Address-Decoding.md` §3.3 for the independent, chip-count-based argument for why Sharp's own built-in RAM expansion stopped at the same S0–S2 boundary.

---

## 4. PC-1600 Expansion Slot Connectors

The PC-1600 has three expansion connectors in total: a 60-pin system bus connector (for peripherals that need the raw Z-80 bus, e.g. the CE-1600F floppy or CE-1600P plotter/printer units) and two 40-pin memory slot connectors, one per memory slot. Unlike the PC-1500/1500A's single connector, these carry Z-80 (not LH5801) bus signals, plus the gate-array-buffered bank-select lines described in `PC-1600-Memory-Bank-Switching.md` Part 3–4.

### 4.0 The 60-pin system bus connector

*Source: PC-1600 Technical Reference Manual §10.3(1).*

| Pin | Signal | Pin | Signal | Pin | Signal | Pin | Signal |
|---|---|---|---|---|---|---|---|
| 1 | A7 | 16 | PVOUT | 31 | A8 | 46 | VBAT |
| 2 | A6 | 17 | D7 | 32 | A9 | 47 | VP |
| 3 | A5 | 18 | D6 | 33 | A10 | 48 | NC |
| 4 | A4 | 19 | D5 | 34 | A11 | 49 | MREQ |
| 5 | A3 | 20 | D4 | 35 | A12 | 50 | BFO |
| 6 | A2 | 21 | D3 | 36 | A13 | 51 | φOS |
| 7 | A1 | 22 | D2 | 37 | A14 | 52 | GND |
| 8 | A0 | 23 | D1 | 38 | A15 | 53 | GND |
| 9 | INT1̄ | 24 | D0 | 39 | VGG | 54 | GND |
| 10 | M1̄ | 25 | INH | 40 | NC | 55 | NC |
| 11 | VCC | 26 | IORQ | 41 | VCC | 56 | DME0 |
| 12 | NC | 27 | CMTIN | 42 | NC | 57 | WR̄ |
| 13 | RSTE | 28 | WAIT | 43 | FG | 58 | ELH̄ |
| 14 | PT | 29 | CMTOUT | 44 | FG | 59 | IOE |
| 15 | PU | 30 | IRQ | 45 | VBAT | 60 | RD̄ |

This is a different, larger connector than the two memory slots — it exposes Z-80 control signals (M1̄, INT1̄, IORQ, WAIT, IRQ) that the memory slots don't, plus cassette I/O (CMTIN/CMTOUT), battery-backup (VBAT), and the sub-CPU timing signals (BFO, φOS) that never appear on a memory-only connector. PT and PU (pins 14, 15) appear here too, confirming they're broadcast machine-wide, not slot-specific.

### 4.1 Memory Slot 1 (S1) Connector, per TRM §10.3

*Source: PC-1600 Technical Reference Manual §10.3(2), "Memory slot 1 (S1) connector."*

| Pin | Signal | Pin | Signal | Pin | Signal | Pin | Signal |
|-----|--------|-----|--------|-----|--------|-----|--------|
| 1 | VCC | 11 | D3 | 21 | NC | 31 | A6 |
| 2 | PVIN | 12 | D2 | 22 | A15 | 32 | A5 |
| 3 | PU | 13 | D1 | 23 | A14 | 33 | A4 |
| 4 | **RAM1** | 14 | D0 | 24 | A13 | 34 | A3 |
| 5 | PVOUT | 15 | INH | 25 | A12 | 35 | A2 |
| 6 | MREQ | 16 | K0 | 26 | A11 | 36 | A1 |
| 7 | D7 | 17 | K1 | 27 | A10 | 37 | A0 |
| 8 | D6 | 18 | K2 | 28 | A9 | 38 | RD |
| 9 | D5 | 19 | PT | 29 | A8 | 39 | WR |
| 10 | D4 | 20 | VGG | 30 | A7 | 40 | GND |

### 4.2 Memory Slot 2 (S2) Connector, per TRM §10.3

*Source: PC-1600 Technical Reference Manual §10.3(3), "Memory slot 2 (S2) connector."*

Identical layout to §4.1 except:
- Pin 4 = **RAM2** (instead of RAM1)
- Pin 16 = **S1**, Pin 17 = **S2**, Pin 18 = **S3** (instead of K0/K1/K2)

### 4.2a Discrepancy: TRM connector tables vs. real module hardware

The TRM pin tables above (§4.1–4.2) put **K0/K1/K2 and RAM1 on the connector labeled "Memory slot 1"**, and **S1/S2/S3 and RAM2 on the connector labeled "Memory slot 2."** This is the **opposite** of what two independent pieces of real-hardware evidence say:

- The **CE-1601M**'s own manual (`PC-1600-Memory-Bank-Switching.md` Part 7a) states outright that the module "must be mounted in the PC-1600 memory slot S2" — and its own schematic shows its onboard decoder driven directly by pins labeled **K0** and **K2** on the module's edge connector.
- The ***superRAM*** modern module (Part 7b) likewise must go in Slot 2, and relies on the same Port 28H / K0–K2 mechanism.

Both modules require the K0–K2 signal set, and both are only usable in the physical bay marketed as **Slot 2** — directly contradicting the TRM table's own section header, which puts K0–K2 on "Memory slot 1." This isn't a new error introduced here: the pre-existing `PC-1600-Memory-Bank-Switching.md` (sourced from the Service Manual rather than the TRM) already had CN-8/"Slot 2" carrying RAM1/K0–K2, i.e. it already matched the module-hardware evidence rather than this TRM scan. Sharp's own TRM has documented transcription/labeling errors elsewhere in this project's PC-1500 material (see `PC-1500-Address-Decoding.md`'s "Appendix: PC-1500 Chip-Select Table" for two confirmed examples), so a swapped section header here — "Memory slot 1" and "Memory slot 2" simply mislabeled relative to the product's own physical/marketed slot numbering — is the most likely explanation, though not confirmed against a second TRM scan or the physical connector's own silkscreen.

**Practical resolution used throughout this project's documentation:** trust the module-hardware evidence. Wherever "Slot 2" is stated elsewhere in these documents (Port 28H, the CE-1601M, *superRAM*), it refers to the physical bay carrying RAM1 and K0–K2 — i.e., the connector the TRM's own table happens to head "Memory slot 1." If you have a way to check the physical PC-1600's own case silkscreen/labeling against a connector multimeter trace, that would settle this definitively.

### 4.3 Key signals, by function

Uses the module-hardware-confirmed assignment (§4.2a): RAM1/K0–K2 on the physical bay marketed as Slot 2, RAM2/S1–S3 on Slot 1.

| Pin | Signal | Function |
|---|---|---|
| 2 | PVIN | LH-5803 PV signal input (direct from LH-5803 pin 60) — PC-1500-compatibility CPU mode |
| 3 | PU | Bank select bit, from I/O port 31H |
| 4 | RAM2 (Slot 1) / RAM1 (Slot 2) | Chip select for the respective slot's RAM banks. Called **RAMSN** on the CE-1600M/CE-1620M schematics. Asserted (low) **only** for 8000–BFFF accesses when the Port 31H page-2 field selects this slot (banks 0/1 → Slot 1; banks 2/3 → Slot 2). Never asserts for 4000–7FFF or any other window — a memory-bay module cannot answer outside 8000–BFFF. |
| 5 | PVOUT | The selected module's **A14-equivalent** — which 16 KB half / which of the slot's two banks. **= Port 31H bit b4** (LSB of the 8000–BFFF bank field), i.e. the bit distinguishing bank 0 from 1 (Slot 1) or bank 2 from 3 (Slot 2). *Not* Port 31H bit b0: b0 is also nicknamed "PVOUT" but is the 0000–3FFF page / LH5803-PV bit and does not reach this pin. (Corrected here from an earlier "from I/O port 31H b0" — confirmed against the CE-1600M schematic, which uses pin 5 as one of the two `{A13, PVOUT}` select inputs to its 4-way SRAM decoder, and Part 7a's CE-1601M description of the same pin distinguishing "Z-80 Bank 2 vs. Bank 3".) |
| 6 | MREQ | Z-80 memory request |
| 15 | INH | Inhibit internal ROM (CS001/CS123), letting the module override internal memory. **Polarity note:** PC-1600 TRM §7.2.2 says the ROM is inhibited by driving INH **high** — on the PC-1600 INH *is* the ROM's active-low OE, tied to ground by default. This is opposite to the PC-1500's "connect to GND to inhibit". See `../PC-1600/PC-1600-Memory-Bank-Switching.md` Part 4; not yet reconciled against a second source. |
| 16–18 | S1/S2/S3 (Slot 1) or K0/K1/K2 (Slot 2) | Sub-select (Slot 1) / I/O-select (Slot 2) within the slot's address range |
| 19 | PT | Bank select bit, from I/O port 31H |
| 22–37 | A15–A0 | Full 16-bit Z-80 address bus |
| 7–14 | D7–D0 | Data bus |
| 38/39 | RD/WR | Z-80 read/write strobes |

PVOUT, PU, and PT are on the connector, but the **CE-1600M schematic shows Sharp's own 32KB RAM module wiring only PVOUT** (pin 5) as its bank input — plus RAMSN (pin 4) as enable and A0–A13 for the window. PU (pin 3) and PT (pin 19) go unconnected on that module; they are the Port 31H 4000–7FFF field bits (b1/b2), broadcast machine-wide but not needed by a memory module (which only ever lives in the 8000–BFFF window). So the practical selection a 32KB module gets from its pins is **one bit** (PVOUT = b4, the 16KB-half select), giving 2 banks × 16KB = 32KB. A module wanting more must instead be driven through **Port 28H** — a write-only "vertical bank" selector (values 0–7, one 32KB bank each, decoded on the module side from K0–K2) that reaches 256KB for Slot 2 with Sharp's own decoder hardware. See Part 2, Part 7 and Part 7a of `PC-1600-Memory-Bank-Switching.md`, and §5 below.

Compared to the PC-1500/1500A single connector, the PC-1600 slots expose: a full 16-bit address bus directly (vs. no address bus reaching a PC-1500 module beyond what's needed for its own local decode — actually the PC-1500 does expose the full AD15–AD0 bus, pins 22–37, so this is symmetric); three dedicated bank-select bits (PVOUT/PU/PT) instead of two flipflops (PU/PV) plus four narrow address-range strobes; and no equivalent of the PC-1500's YO/S1–S4 fixed 2KB/16KB strobes at all — PC-1600 modules are bank-selected, not address-range-selected.

---

## 5. PC-1600 Module Hardware: Status

`PC-1600-Memory-Bank-Switching.md` covers the bank-switching architecture (Port 31H truth tables, gate array pin assignments, firmware bank-call mechanism, and the CN-7/CN-8 pinout now consolidated above) in solid detail, confirmed against the Service Manual and Systemhandbuch.

**Resolved, now from two independent sources** (CE-1601M Service Manual, Part 7a; *superRAM* modern-module manual, Part 7b): Port 28H is a write-only "vertical bank" selector for Slot 2, values 0–7 natively, decoded entirely on the module side (via the K0–K2 I/O-select lines) rather than by the mainboard gate array. Each vertical bank is 32KB — confirmed both from the CE-1601M's chip layout (a 64KB module occupies exactly two vertical banks) and from *superRAM*'s own stated memory map. That makes **256KB the officially-supported ceiling for Slot 2** (8 banks × 32KB), and only vertical bank 0 is reachable as ordinary program/expansion memory — banks 1–7 are file-system-only. **512KB is directly confirmed** by *superRAM*, which extends the vertical-bank field to 4 bits (0–15) in hardware (a jumper-selected extra address line on its single large SRAM chip, replacing Sharp's one-chip-per-bank decoder approach) and patches the PC-1600's file-system header/capacity fields at runtime, since the stock `INIT` command has no notion of a disk that large. Sharp's own largest factory module was the 64KB CE-1601M — confirmed directly by the *superRAM* manual's own text.

**Still open:**
- **CE-1650M** (256KB, 8 vertical banks × 32KB, Slot 2, Japan-only). Shown in the CE-1601M Service Manual §5 map. No standalone schematic, but the CE-1601M schematic now largely explains it: that PWB carries a **`0M`/`1M` solder-jumper strap** on the `TC74HC131F`'s high select input — `0M` = 2 vertical banks (CE-1601M), `1M` = all 8 (CE-1650M) — so the CE-1650M is almost certainly the same board with all SRAM sites populated and the strap set. See `../PC-1600/PC-1600-Memory-Bank-Switching.md` Part 7a.
- **Slot 1's ceiling.** Slot 1 has no equivalent of Port 28H in the documentation so far (RAM2 chip select is unconditional on PVOUT/PU/PT alone, and *superRAM* itself states Slot 1 operation "would there behave like a 32KB RAM module") — worth confirming whether that's a hard architectural cap or just unimplemented.
