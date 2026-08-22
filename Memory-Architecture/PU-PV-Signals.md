# PU and PV Signals on the Sharp PC-1500 / PC-1500A

## Overview

PU and PV are two single-bit general-purpose flipflop outputs built directly into the LH5801 CPU. They are not software flags, not memory-mapped registers, and not part of the standard status register — they are physical output pins on the CPU chip, directly accessible from software via dedicated instructions and directly wired to the expansion connector.

---

## 1. Hardware: Inside the LH5801 CPU

The LH5801 CPU (a Sharp/SANYO CMOS 8-bit processor) contains the following internal flipflops beyond the standard status register flags:

| Symbol | Name | Bits | Description |
|--------|------|------|-------------|
| PU | General Purpose Flipflop | 1 | Output pin, set/reset by instruction |
| PV | General Purpose Flipflop | 1 | Output pin, set/reset by instruction |
| DISP | LCD on/off control | 1 | Controls LCD backplane signal generation |
| BF | Battery/power flipflop | 1 | Set by BFI input; reset by OFF instruction |
| TM | Timer control | 9 | Timer counter |

PU and PV are classed together with DISP in the CPU's internal register diagram, shown as separate 1-bit cells alongside the accumulator, index registers (X, Y, U), program counter (P), stack pointer (S), and status register.

**Key property**: PU and PV are *output-only* flipflops. They drive physical pins on the CPU package and cannot be read back — there is no "read PU" instruction. A program must track the current state of PU/PV in software if it needs to know what was last written.

---

## 2. CPU Instructions

Four dedicated instructions control PU and PV. None of them affect any status flags.

| Instruction | Operation | Opcode | Effect |
|---|---|---|---|
| SPU — Set PU | 1 → PU | FD D5 | Drives the PU pin high |
| RPU — Reset PU | 0 → PU | FD D4 | Drives the PU pin low |
| SPV — Set PV | 1 → PV | FD D7 | Drives the PV pin high |
| RPV — Reset PV | 0 → PV | FD D6 | Drives the PV pin low |

These are among the CPU control instructions, alongside `SDP`/`RDP` (LCD on/off), `SIE`/`RIE` (interrupt enable), `HALT`, and `OFF`.

---

## 3. The 40-Pin Expansion Connector

The PC-1500 exposes the expansion bus on a 40-pin edge connector on the rear (confirmed by physical pin count on real hardware). PU and PV appear directly on this connector, at pins 2 and 3, as output signals from the CPU.

For the full 40-pin table (and the PC-1500A's pin reassignment, and the PC-1600's CN-7/CN-8 slot connectors), see `Expansion-Connectors.md`.

PV and PU appear at pins 2 and 3, described in the TRM as "chip select" signals — modules can use them as additional gating inputs for chip-select logic, alongside their role as CPU flipflop outputs. YO (pin 4) is the primary chip select for the &0000–&3FFF module RAM region. There is no dedicated bank-select address register on the connector for that region — the PU and PV pins are the only CPU-flipflop mechanism for communicating a state change to a module beyond the address and data buses.

---

## 4. Role of PU and PV in the Memory Map

The Technical Reference Manual states:

> *"Memory bank is assigned by PV and PU for the MEO area of 8000H thru BFFFH. PU and PV are used to assign the area of 8000H thru 9FFFH."*

> *"PV and PU are bank select signals."*

The system ROM is in &C000–&FFFF (Y3 select); the expansion ROM/peripheral area is &8000–&BFFF (Y2 select). This is where PU and PV perform their primary architectural role:

| PV | PU | Selects |
|----|----|---------|
| 0 | 0 | (default / no option) |
| 0 | 1 | &8000–&9FFF sub-bank 1 |
| 1 | 0 | &8000–&BFFF alternate bank |
| 1 | 1 | &8000–&BFFF alternate bank + sub |

The exact meaning of each combination depends on what hardware is attached. The system firmware uses PV to switch between different token tables (BASIC command tables) stored in ROM expansions — the CE-150 plotter and CE-158 RS-232 interface both place their own system ROM and I/O tables in &8000–&BFFF, and PV selects which is visible when both are connected.

**PU** is used for a sub-division of &8000–&9FFF (the first half of the optional ROM area), allowing two 8KB ROM images to coexist there, selected by PU alone.

**Practical use by the system ROM**: the ROM disassembly (`PC-1500_Intern.pdf`) documents a "PV-Byte" at address &79D0, whose bit 0 determines whether PV should be 0 or 1. A `PV-Banking` routine at &E234 reads that bit and calls RPV or SPV accordingly, ensuring PV is correctly set before any access to a ROM table in &8000–&BFFF. The system ROM makes dozens of such calls around accesses to BASIC extension token tables, character set data, and I/O routines.

---

## 5. CE-158 and PU

The CE-158 RS-232/Centronics interface contains a 16KB system ROM mapped into &8000–&BFFF (Y2 select). This ROM provides RS-232 command tables, BASIC extensions (`LPRINT`, `INPUT#`, `PRINT#`), and I/O driver code. When connected, the system ROM uses PV to switch between the base PC-1500 ROM tables and the CE-158's — the CE-158's ROM responds to the Y2 chip-select and is additionally gated by PV.

**This is why the TRAMsoft 32kB-RAM/ROM module conflicts with the CE-158.** TRAMsoft uses PU to switch its two 16KB RAM banks in &0000–&3FFF; the CE-158 uses PU to gate access to its internal ROM in &8000–&BFFF. Different address ranges, but the same physical PU line on the connector.

Consequence, with both connected:
- Every SPU/RPU call from the TRAMsoft banking software simultaneously changes which CE-158 sub-bank is visible at &8000–&9FFF.
- On power-on, if the CE-158 initializes the PU line, TRAMsoft's bank state is set unexpectedly, leaving BASIC pointers pointing to wrong data.
- The TRAMsoft manual warns that its banking software must be called immediately after power-on to restore correct system pointers, and that all CE-158-related code must exist at identical addresses in both TRAMsoft banks.

Modern recreations avoid this entirely by using a different trigger mechanism — writing to &5800–&580F / &6800–&680F rather than SPU/RPU. This uses ordinary address decode logic, with no involvement of the PU pin (see `PC-1500-Bank-Switching.md` §2.2 and §4 for the mechanism).

---

## 6. PU/PV vs. the &5800/&6800 Address-Range Method

Two fundamentally different hardware mechanisms for controlling a module:

| Aspect | PU / PV | &5800 / &6800 write |
|--------|---------|---------------------|
| Trigger | Dedicated CPU instructions (SPU/RPU/SPV/RPV) | Memory write to a specific address |
| Signal path | CPU pin → connector pin directly | CPU address bus → PC-1500 address decoder → connector chip-select line |
| Number of states | 2 bits = 4 combinations | Up to 4 bits (module-specific; modern recreations offer up to 16 banks) |
| Address range controlled | Primarily &8000–&BFFF (system ROM area) | &0000–&3FFF (module RAM area) |
| Shared with system firmware | Yes — the system ROM uses PV heavily | No — not used by the system ROM |
| CE-158 conflict | Yes (both use PU) | No |
| Module detects which bank is requested | Reads PU/PV pin state | Latches the low address bits A0–A3 on write |

The address-range method is architecturally cleaner for user expansion RAM: it doesn't interfere with the system ROM's PV-banking, it encodes up to 4 bits of bank selection (16 banks) instead of PU+PV's 2 bits (4 combinations), and it shares no signal with the CE-158.

---

## 7. Software Pattern: Saving PV State

Because the system ROM uses PV to select ROM banks for BASIC extension tables, any machine-code program using SPV/RPV must save and restore PV state around its own use. The system ROM does this via the "PV-Byte" at &79D0:

```
; Save and restore PV around a section that uses PV for a different purpose:
LD A,(79D0H)    ; load PV-byte (bit 0 = desired PV state)
PUSH A          ; save it
RPV             ; set PV=0 for our use
... (access something at 8000-BFFF with PV=0) ...
POP A           ; restore PV-byte
BIT (N),n       ; test bit 0
JR Z, done      ; if 0, PV stays 0 (RPV already done)
SPV             ; if 1, restore PV=1
done:
```

This pattern appears dozens of times in the PC-1500 ROM disassembly. Any third-party module using PV for its own banking must account for the system ROM calling SPV/RPV at any time during BASIC execution, overriding the module's bank selection.

---

## 8. PC-1500A Differences

**Connector pins.** Pin 4 (YO), the &0000–&3FFF module chip-select on the PC-1500, is NC on the PC-1500A — the low-module-RAM select logic differs between models. This is why modern recreations use different bank-select addresses on each machine (&5800–&580F vs. &6800–&680F) — but the module's own hardware never has to know which host it's in. Its bank-select latch just reacts to whichever strobe physically arrives on its fixed connector pin (§3 above); that pin carries a different named signal on each model purely because of the mainboard's pin reassignment, not anything the module detects. The burden of picking the right address falls entirely on whoever issues the POKE — a user typing it directly, or software running on the host. (See `PC-1500-Address-Decoding.md` §3 for the full pin-reassignment table covering pins 5, 16, 17, and 18.)

**PU/PV role unchanged.** The role of PV and PU in &8000–&BFFF is identical between the two models — the system ROM at &C000–&FFFF handles PV-banking the same way on both.

**RAM figures.** The PC-1500A has more built-in RAM than the PC-1500, in two senses that are worth keeping distinct (full derivation in `PC-1500-Address-Decoding.md` §2–4):

- **Contiguous, BASIC-countable "standard user memory"**: 6KB on the PC-1500A (S0+S1+S2, &4000–&57FF) vs. 2KB (S0 alone) on the PC-1500 — confirmed against a stock unit's `MEM` value of 5946.
- **Total physical RAM on the mainboard**: ~8.5KB on the PC-1500A (four HM6116 chips covering S0–S2 and S7, plus 512B unchanged display-driver RAM) vs. exactly 3.5KB on the PC-1500 (one HM6116 + two TC5514 + 512B display-driver RAM).

The machine-language area at &7C01–&7FFF is part of the second figure, not the first — it sits behind the module-window/inhibited/display blocks (S3–S6) and isn't part of the contiguous pool `MEM` reports.

---

## 9. Summary

| Property | PU | PV |
|----------|----|----|
| Type | 1-bit CPU flipflop output | 1-bit CPU flipflop output |
| Set instruction | SPU (FD D5) | SPV (FD D7) |
| Reset instruction | RPU (FD D4) | RPV (FD D6) |
| 40-pin connector pin | Pin 3 | Pin 2 |
| Primary hardware use | Sub-bank select for &8000–&9FFF; TRAMsoft module bank switch | Bank select for &8000–&BFFF (peripheral ROM: CE-150, CE-158) |
| Used by system ROM | Occasionally (PU sub-banking) | Heavily (every BASIC extension table access) |
| Readable by CPU | No (write-only) | No (write-only) |
| Number of states | 1 bit | 1 bit |
| Conflict risk | CE-158 shares PU | Any module using PV conflicts with system BASIC extension access |
| Used by CE-163? | No | No — CE-163 uses S3/S5 (pin 18) instead |
