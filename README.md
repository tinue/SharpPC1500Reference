# Sharp PC-1500 Agent Instructions

This repository serves two purposes:

1. Two **self-contained prompt documents** that give an AI agent the knowledge to write programs for the **Sharp PC-1500** pocket computer (1981) — a machine no AI model has enough built-in knowledge to target reliably on its own.
2. A **consolidated research corpus** on the Sharp PC-1500, PC-1500A, and PC-1600 — reverse-engineered hardware/firmware facts, memory maps, BASIC token tables, peripheral protocols, and data-exchange formats, gathered from several independent projects into one place.

---

## Part 1 — How to use the prompt documents

Copy the relevant file into a new chat session or attach it as a system prompt / context document. Then describe what you want the program to do.

The files are self-contained. The AI does not need internet access, tool use, or any other files. Just the document and your request.

### BASIC programs

**File:** `Basic-Programming/sharp-basic-prompt.md`

Paste the file into the AI's context, then ask for a BASIC program. Example prompts:

```
Write a program that asks for a number and prints its prime factors.
```

```
Write a Mandelbrot set renderer that draws the result on the CE-150 plotter.
```

The document defines the AI's role, device constraints (RAM, display, tokenisation), output format (`.bas` source + `.md` companion guide), coding conventions (line numbering, comment strategy, variable naming, subroutine layout), and the full BASIC keyword reference. Outputs are immediately ready to transmit to a real PC-1500.

### Assembly programs

**File:** `Assembly-Programming/LH5801_Guide.md`

Paste the file into the AI's context, then ask for an assembly routine. Example prompts:

```
Write a routine that copies 64 bytes from address $4100 to $4200.
```

```
Write a subroutine callable from BASIC via CALL that measures the amount of free RAM and returns it in the floating-point accumulator ARX so BASIC can print it.
```

```
Test how much memory is unused and store a data block there.
```

The document covers the LH5801 instruction set, addressing modes, `sdaslh5801` (sdas) assembler syntax and macros, the `pc1500emu`/`pc1500preset` toolchain (assembling, disassembling with `pc1500disasm`, and loading into the emulator), PC-1500 memory layout, system variable addresses, ROM subroutine calling conventions, BCD floating-point format, and common idioms. An AI given this guide can produce correct, assembler-ready `.asm` files for the PC-1500.

---

## Part 2 — Research corpus

Everything below is **derived research data** about the real hardware/firmware/software of the PC-1500, PC-1500A, and PC-1600 — reverse-engineered facts, not tutorials. It was gathered from several sibling projects in the same workspace (each its own git repository) into this one location so any agent working on Sharp pocket-computer material has a single place to look.

Documents that were **moved** here leave a one-line stub at their old location pointing back here. Documents that were **extracted** (only part of a larger tool-doc was relevant) leave the original file completely untouched elsewhere, with a note at the top of the copy here saying what was left out and why.

### PC-1600/

Machine-specific consolidation for the **Sharp PC-1600** (dual-CPU: Z-80-compatible SC7852 + LH5803 co-processor), aimed at building an emulator and at letting an agent write Z-80 machine-language programs and design expansion hardware for it. Its own [`PC-1600/README.md`](PC-1600/README.md) is the sub-index and tracks which documents are written vs. still stubs. **PC-1600 BASIC is *not* here** — it is a near-superset of PC-1500 BASIC and will be covered for both machines together in `SharpBasicReference/`, the BASIC prompt guide, and a shared token-code guide.

| Document | Summary |
|---|---|
| `PC-1600-Memory-Bank-Switching.md` | Mechanism-level: chips, Port 31H/28H/3DH bank registers + truth tables, LR38041 gate array, chip selects, firmware transparent-banking calls, module headers, boot sequence, CE-1600M/1601M/superRAM, dual-CPU bridge, I/O range map, PC-1500-module adaptation, internal wiring. *(moved here from `Memory-Architecture/`)* |
| `PC-1600-Memory-Architecture.md` | Narrative/comparison: Z-80 8-bank view, internal-RAM/`NEW`-offset layout, the LH5803 compatibility memory map, address-by-address comparison to PC-1500/1500A, MODE0/MODE1. *(moved here from `Memory-Architecture/`)* |
| `PC-1600-Serial-Commands.md` | BASIC serial command reference: `INIT`, `SETCOM`, `OUTSTAT`, `INSTAT`, `SNDSTAT`, `RCVSTAT`, `SETDEV`, `PCONSOLE`, `SAVE`/`LOAD`. *(moved here from `Peripherals/`)* |
| `PC-1600-Serial-Hardware-Notes.md` | RS-232C/SIO share one TC8576F UART (PRIM select, BX7269W level shifter, VDD/VEE, TC8576F pinout — TRM §7.6); plus the FTDI USB/UART wiring how-to and Apple-Silicon driver gotcha. *(moved here from `Peripherals/`)* |
| `PC-1600-Machine-Overview.md` | *(first pass)* Chip complement, clock tree, dual main-CPU bus sharing, sub-CPU command protocol, power rails, power-on/boot (§3.5), peripheral catalogue (Ch 1). From TRM §7.1/§7.7/§3.5/Ch 1. |
| `PC-1600-Work-Area-Map.md` | *(first pass)* The F000H–FFFFH BASIC/IOCS work area: 5-block structure, downward extension for peripheral ROM work areas + PTR1–PTRG, and the §6.3 named-variable map. From TRM Chapter 6. Complements `PC-1600-Memory-Bank-Switching.md` Part 6. |
| `PC-1600-CPU-SC7852-Z80.md` | *(first pass)* The SC-7852 as a CPU: programmer's model, instruction set (= verbatim Zilog Z-80A), timing + the documented wait-state deviation, fixed-IM2 interrupts, RST vector map, the 100-pin terminal table, the 30–3FH control-register block, dual-CPU bus mapping. From TRM §7.1/§3.4/§5.13 + Systemhandbuch §10.4. |
| `PC-1600-CPU-LH5803-Compat.md` | *(first pass)* LH-5803 memory map, LH-5801 deltas, full `CALLH` parameter block (TRM §5.14), MODE0/MODE1, PC-1500 compatibility rules (TRM §5.15). |
| `PC-1600-IO-Ports.md` | *(first pass)* Range map + the LH-5810-compatible port block 10–1FH, TC8576F register select 20–27H, buzzer; BEEP + timer/RTC/analog IOCS (§3.9/§3.10). From TRM §7.9/§7.6/§7.5/§3.9. |
| `PC-1600-Display-HD61202.md` | *(first pass)* Panel LF7204E (156×32 + 16 symbols), HD61203 + 2×HD61102, 217 kHz clock, CS→A2–A5 decode, frame-buffer model (TRM §7.3); plus the full §3.1 LCD IOCS routine set, work area, and 6×8 CG format. |
| `PC-1600-IOCS.md` | *(in progress)* IOCS calling conventions (TRM §3 preamble) + master routine index for §3.1–§3.13. **Chapter 3 complete** (§3.1–§3.13). |
| `PC-1600-Filesystem.md` | *(first pass)* File system (TRM §3.3): 16-byte file header, 57-byte FCB + 256-byte buffer, file IOCS routines (C = IOCS #, `CALL 01DEH`), and the FAT-style RAM-disk / floppy layout (boot sector, media-ID geometry, single-byte FAT). |
| `PC-1600-Peripherals-Hardware.md` | *(in progress)* CE-1600P printer/plotter + CE-1600F floppy IOCS + peripheral hardware (TRM §3.7/§3.8/Ch 8). §3.7 printer + §3.8 floppy routines filled. |
| `PC-1600-Keyboard.md` | *(hw complete)* Scan mechanism, strobe/sense wiring (TRM §7.4/§7.9); plus the full §3.2 key IOCS routines, the 9-strobe scan matrix, the §3.2.2 work area, and key-code translation/redefinition. Emulator-ready; §10.2 key-code table (agent-facing) pending. |
| `PC-1600-Expansion-Bus.md` | *(stub)* Designing hardware for the 60-pin system bus + 40-pin memory slots: electrical, bus-cycle timing, IRQ/WAIT protocol, ROM-module header/autostart, worked example. |
| `PC-1600-Memory-Modules.md` | *(stub)* Per-module catalogue: CE-1600M/1601M/1620M/1650M/superRAM + PC-1500-module adaptation. |
| `PC-1600-Assembly-Guide.md` | *(stub)* Writing SC7852 machine-language programs: BASIC calling conventions, bank-aware code, ROM entry points, toolchain. |
| `PC-1600-ROM-Disassembly.md` | Pointer to the external PC-1600 ROM reverse-engineering project |

### Memory-Architecture/

| Document | Summary |
|---|---|
| `PC-1500-BASIC-Pointers.md` | ROM pointer and system-variable table for the PC-1500/1500A BASIC interpreter. |
| `PC-1500-Address-Decoding.md` | Address-decoder architecture and physical memory map for the PC-1500/1500A: Y0–Y3/S0–S7 blocks, physical RAM chips, the PC-1500→PC-1500A connector rewiring, the machine-language area, and RAM-sizing/`NEW`-offset calculations. |
| `PC-1500-Bank-Switching.md` | How 16KB memory-expansion modules bank-switch into the PC-1500/1500A's low 16KB address window, built on top of `PC-1500-Address-Decoding.md`; also touches PC-1600 compatibility. |
| `PU-PV-Signals.md` | PU/PV flip-flop pins on the LH5801 and their role in the PC-1500/1500A expansion connector. |
| `Expansion-Connectors.md` | Consolidated connector reference: the PC-1500's 40-pin and 60-pin connectors (the latter cross-validated pin-for-pin against the PC-1600's 60-pin connector), the PC-1500A's pin reassignment (and how far a fixed-wiring module can be pushed against it), and the PC-1600's 60-pin system bus and two memory-slot connectors. Raw pinouts the `PC-1600/` bus docs build on. |
| `Software-Defined-Memory-Extension.md` | Hypothetical: what a microcontroller-based universal module would need to do on the wire to emulate every real PC-1500/1500A/1600 memory module (plus a few "maxed out" hypotheticals) — an enable-condition/bank-select reference table per module, with the four 40-pin slot layouts underneath. |

### Assembly-Programming/

| Document | Summary |
|---|---|
| `LH5801_Guide.md` | The prompt document described in Part 1 above — also a solid LH5801 reference in its own right. |

### Basic-Programming/

| Document | Summary |
|---|---|
| `sharp-basic-prompt.md` | The prompt document described in Part 1 above. |
| `reference/ROM-Reference.md` | Guide to the structure of the PC-1500 ROM disassembly. |
| `reference/Peripheral-Commands.md` | CE-150/CE-158 peripheral command token table, from the SharpBasicInterpreter project's own research. Overlaps with `SharpBasicReference/reference/Token-Mapping-Analysis.md` (see External References below) — kept separate because that repo's contents were left untouched. |
| `reference/Tokenizer-Analysis.md` | How the PC-1500 ROM tokenizes BASIC input at `$F957`, reverse-engineered from the ROM disassembly (keyword linked lists, first-match scanning, abbreviation handling). |

### Peripherals/

| Document | Summary |
|---|---|
| `CE-150-Plotter-Links.md` | Pointers to third-party replacement parts for the CE-150 plotter's pen mechanism. |

The PC-1600 serial documents (`PC-1600-Serial-Commands.md`, `PC-1600-Serial-Hardware-Notes.md`) moved to `PC-1600/`.

### Data-Formats/

| Document | Summary |
|---|---|
| `Binary-Exchange-Formats.md` | Full serial binary format spec for both device families: CE-158 header (PC-1500/1500A) and PC-1600 header, plus BASIC/Machine/Reserve-Area/Variables payload encodings. Sourced from the PC-1500 Technical Reference Manual and real hardware dumps. |
| `PC-1500-Tape-Format.md` | FSK audio cassette-tape format for the PC-1500 series, reverse-engineered from a reference encoder and confirmed against a live recording. |
| `WAV-Cassette-Format-1500-1600.md` | WAV/PCM cassette encoding details (signal parameters, sync preambles, checksums) specifically for the PC-1500 and PC-1600; extracted from a broader spec that also covers unrelated models. |

---

## External references (not moved — kept intact at their source)

**`SharpBasicReference/`** is a separate public repository ([github.com/tinue/SharpBasicReference](https://github.com/tinue/SharpBasicReference)) whose entire purpose *is* being this exact set of reference documents, so nothing was moved out of it. It sits alongside this repository in the same workspace:

| Document | Summary |
|---|---|
| `SharpBasicReference/PC-1500-BASIC-Reference.md` | Full PC-1500 BASIC language reference. |
| `SharpBasicReference/CE-150-Reference.md` | CE-150 printer/plotter/cassette BASIC command reference. |
| `SharpBasicReference/CE-158-Reference.md` | CE-158 RS-232C/parallel interface BASIC command reference. |
| `SharpBasicReference/Command-Index.md` | Cross-index of all BASIC commands. |
| `SharpBasicReference/Error-Codes.md` | BASIC error code table. |
| `SharpBasicReference/reference/Token-Mapping-Analysis.md` | BASIC token value map (`0xE680`–`0xF1B6`) and device token allocation. Overlaps with `Basic-Programming/reference/Peripheral-Commands.md` above — both describe the same CE-150/CE-158 token space from different angles; consult both if one seems incomplete. |

---

## Sibling repositories referenced throughout this corpus

Several documents in this repo mention tools or sibling projects by their local path in the author's own workspace (e.g. `pc1500emu/`, `SharpDataExchange`), since that's how the docs are used day-to-day. Those local-path mentions are left in place, but **none of those sibling projects' contents are included in this repository** — this table is the canonical map of what's public and what isn't, so a reader arriving at this repo alone knows what they can and can't reach.

| Local path used in these docs | Status | Public URL |
|---|---|---|
| `pc1500emu/` | Public (independent fork, not this user's own project) | [github.com/tinue/pc1500emu](https://github.com/tinue/pc1500emu) |
| `pc1500preset/` | Public | [github.com/tinue/pc1500preset](https://github.com/tinue/pc1500preset) |
| `SharpDataExchange` | Public | [github.com/tinue/SharpDataExchange](https://github.com/tinue/SharpDataExchange) |
| `sdcc-pc1500/` | Public (external project, not this user's own) | [github.com/pchambre/sdcc-pc1500](https://github.com/pchambre/sdcc-pc1500) |
| `sharp-pocket-computer/` | Public | [github.com/tinue/sharp-pocket-computer](https://github.com/tinue/sharp-pocket-computer) |
| `SharpBasicReference/` | Public | [github.com/tinue/SharpBasicReference](https://github.com/tinue/SharpBasicReference) (see above) |
| `SharpBasicPlugin/` | Public | [github.com/tinue/SharpBasicPlugin](https://github.com/tinue/SharpBasicPlugin) |
| `pc1500/` (CE-1638, CE-163F, CE-163X material) | **Private — not published, no public URL** | — |
| `tasm/`, `tasm-35/`, `lh5801_asm/reference/` | **Private local project — not published, no public URL** | — |

---

## Adjacent / out-of-scope resources (not consolidated here)

These contain genuine Sharp research but were deliberately **not** copied or moved:

- **`pc1500emu/`** — has its own hardware reference (`docs/pc1500_hardware_reference.md`), LH5801 opcode reference (`docs/lh5801_opcode_reference.md`), a real-hardware keyboard-matrix probing writeup (`docs/pc1500_keyscan_probe.md`), and a "confirmed hardware facts" section inside `.claude/skills/pc1500-dev/SKILL.md`. Consult that repository directly for emulator-verified hardware facts.
- **CE-1638 / CE-163F / CE-163X materials** (`pc1500/CE-1638/`, `pc1500/CE-163F/`) — these document a **modern** (hobbyist-built) memory-expansion module and its firmware, not original 1980s Sharp hardware, so they're out of scope for this corpus and live in a **private, unpublished** repository (`pc1500/`, see table above) — not this repo and not `pc1500preset/`. `pc1500preset/docs/MEMTEST-MANUAL.md` (a memory-test utility for these modules) lives in the public `pc1500preset/` repo; `pc1500/CE-1638/BANKSWRM-Firmware-Notes.md` (a suspected firmware defect writeup) stays in the private `pc1500/` repo.
- **Generic TASM assembler manuals** (`tasm/`, `tasm-35/`, `lh5801_asm/reference/`) — the Telemark TASM user manual and opcode tables are generic to the assembler, not specific to the LH5801 or Sharp hardware, and are duplicated across three locations in a **private, unpublished** part of the workspace (see table above).

---

## Limitations

- The BASIC prompt targets the PC-1500 specifically. Other Sharp pocket computers (PC-1245, PC-1350, PC-G850) have different BASIC dialects and are not covered.
- The assembly guide targets the LH5801 CPU and the `sdaslh5801` (sdas) assembler. It assumes programs run on a PC-1500 or PC-1500A; memory addresses may differ on other LH5801-based systems.
- The research corpus above is scoped to the PC-1500, PC-1500A, and PC-1600 only. Other Sharp pocket computers (PC-1211, PC-1261, PC-1350, PC-1401, PC-1403, etc.) are out of scope, even where source documents mention them in passing.
