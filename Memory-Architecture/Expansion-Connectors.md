# Expansion Connector Reference: PC-1500, PC-1500A, PC-1600

## 1. Overview

This document consolidates the physical expansion-connector pinouts for the PC-1500, PC-1500A, and PC-1600 (Slot 1 and Slot 2) in one place, since understanding how any given module (period or modern) works starts with knowing exactly which physical wires it has to work with.

It covers: the PC-1500's 40-pin connector (§2); the PC-1500A's pin reassignment relative to the PC-1500, and how far a fixed-wiring module can be pushed against that reassignment (§3); and the PC-1600's two 40-pin slot connectors, CN-7 (Slot 1) and CN-8 (Slot 2) (§4).

For what happens *behind* these pins — the on-mainboard address decoders, chip populations, and bank-switching logic that give each pin its meaning — see `PC-1500-Address-Decoding.md` (PC-1500/1500A) and `PC-1600-Memory-Bank-Switching.md` (PC-1600). This document is the physical-pinout reference those documents assume; §3 here also hosts a worked example (a hypothetical wide module) that draws on both.

---

## 2. The PC-1500 40-Pin Expansion Connector

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
| 4 | RAM2 (Slot 1) / RAM1 (Slot 2) | Chip select for the respective slot's RAM banks |
| 5 | PVOUT | Current PVOUT bank state (0 or 1), from I/O port 31H b0 |
| 6 | MREQ | Z-80 memory request |
| 15 | INH | Pull low to inhibit internal ROM (CS001/CS123), letting the module override internal memory |
| 16–18 | S1/S2/S3 (Slot 1) or K0/K1/K2 (Slot 2) | Sub-select (Slot 1) / I/O-select (Slot 2) within the slot's address range |
| 19 | PT | Bank select bit, from I/O port 31H |
| 22–37 | A15–A0 | Full 16-bit Z-80 address bus |
| 7–14 | D7–D0 | Data bus |
| 38/39 | RD/WR | Z-80 read/write strobes |

PVOUT, PU, and PT together are the three raw bank-select bits a slot module sees directly on its connector pins — they're the same bits Z-80 I/O port 31H writes (see `PC-1600-Memory-Bank-Switching.md` Part 2 for the full per-page truth tables). A module wanting more than the 32KB (2-bank, PVOUT-only) selection these pins alone provide must instead be driven through **Port 28H** — a write-only "vertical bank" selector (values 0–7, one 32KB bank each, decoded on the module side) that reaches 256KB for Slot 2 with Sharp's own decoder hardware. See Part 2 and Part 7a of that document, and §5 below.

Compared to the PC-1500/1500A single connector, the PC-1600 slots expose: a full 16-bit address bus directly (vs. no address bus reaching a PC-1500 module beyond what's needed for its own local decode — actually the PC-1500 does expose the full AD15–AD0 bus, pins 22–37, so this is symmetric); three dedicated bank-select bits (PVOUT/PU/PT) instead of two flipflops (PU/PV) plus four narrow address-range strobes; and no equivalent of the PC-1500's YO/S1–S4 fixed 2KB/16KB strobes at all — PC-1600 modules are bank-selected, not address-range-selected.

---

## 5. PC-1600 Module Hardware: Status

`PC-1600-Memory-Bank-Switching.md` covers the bank-switching architecture (Port 31H truth tables, gate array pin assignments, firmware bank-call mechanism, and the CN-7/CN-8 pinout now consolidated above) in solid detail, confirmed against the Service Manual and Systemhandbuch.

**Resolved, now from two independent sources** (CE-1601M Service Manual, Part 7a; *superRAM* modern-module manual, Part 7b): Port 28H is a write-only "vertical bank" selector for Slot 2, values 0–7 natively, decoded entirely on the module side (via the K0–K2 I/O-select lines) rather than by the mainboard gate array. Each vertical bank is 32KB — confirmed both from the CE-1601M's chip layout (a 64KB module occupies exactly two vertical banks) and from *superRAM*'s own stated memory map. That makes **256KB the officially-supported ceiling for Slot 2** (8 banks × 32KB), and only vertical bank 0 is reachable as ordinary program/expansion memory — banks 1–7 are file-system-only. **512KB is directly confirmed** by *superRAM*, which extends the vertical-bank field to 4 bits (0–15) in hardware (a jumper-selected extra address line on its single large SRAM chip, replacing Sharp's one-chip-per-bank decoder approach) and patches the PC-1600's file-system header/capacity fields at runtime, since the stock `INIT` command has no notion of a disk that large. Sharp's own largest factory module was the 64KB CE-1601M — confirmed directly by the *superRAM* manual's own text.

**Still open:**
- **CE-1650M.** Named and shown using the same vertical-bank scheme in the CE-1601M's own memory-map diagram (Japan-only per that source's footnote), but no schematic-level source for it has turned up yet — the only real Sharp module documented here in circuit detail remains the CE-1601M (64KB).
- **Slot 1's ceiling.** Slot 1 has no equivalent of Port 28H in the documentation so far (RAM2 chip select is unconditional on PVOUT/PU/PT alone, and *superRAM* itself states Slot 1 operation "would there behave like a 32KB RAM module") — worth confirming whether that's a hard architectural cap or just unimplemented.
