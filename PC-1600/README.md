# PC-1600 sub-corpus

Consolidated hardware / firmware / machine-language reference for the **Sharp PC-1600**
(1986) — the dual-CPU (Z-80-compatible SC7852 + LH5803 compatibility co-processor)
successor to the PC-1500/1500A.

Serves two goals:

1. **Emulation** — enough detail to build a cycle-plausible PC-1600 emulator.
2. **Program & hardware development by an agent** — writing Z-80 machine-language
   programs for the platform, and designing hardware for the 60-pin system bus and the
   two 40-pin memory-slot connectors.

**BASIC is deliberately out of scope here.** The PC-1600's BASIC is a superset of the
PC-1500's (≈99 % shared token codes); it will be covered for both machines together in
`SharpBasicReference/`, the BASIC prompt guide, and a shared token-code guide — not in
this sub-corpus.

Sources — Sharp's own manuals, plus one independent emulator used for cross-validation —
are listed under **Sources & validation** below. Individual documents cite only the
primary sources.

---

## Documents

### Written

| Document | Status | Summary |
|---|---|---|
| [`PC-1600-Memory-Bank-Switching.md`](PC-1600-Memory-Bank-Switching.md) | **complete** | Mechanism-level reference: chip complement, Port 31H/28H/3DH bank registers + truth tables, LR38041 gate array, chip selects, firmware transparent-banking calls (BANKSET/BANKCALL/RST shortcuts), module headers, boot sequence, CE-1600M/1601M/superRAM, dual-CPU bridge, I/O port range map, PC-1500-module adaptation, CN-12 internal wiring. Service Manual + Systemhandbuch. |
| [`PC-1600-Memory-Architecture.md`](PC-1600-Memory-Architecture.md) | **complete** | Narrative / comparison layer: Z-80 8-bank view, internal-RAM layout (C5H reserve, work area, overhead), `NEW "S0:/S1:/S2:"`, the LH5803 compatibility memory map, address-by-address comparison to PC-1500/1500A, MODE0/MODE1. TRM §2.1/§2.2 + German *Bedienungsanleitung*. |
| [`PC-1600-Serial-Commands.md`](PC-1600-Serial-Commands.md) | **complete** | BASIC serial command reference: `INIT`, `SETCOM`, `OUTSTAT`, `INSTAT`, `SNDSTAT`, `RCVSTAT`, `SETDEV`, `PCONSOLE`, `SAVE`/`LOAD`. |
| [`PC-1600-CPU-SC7852-Z80.md`](PC-1600-CPU-SC7852-Z80.md) | **first pass** | The Z-80-compatible SC-7852 as a CPU: programmer's model, instruction set (= verbatim Zilog Z-80A per TRM §10.4), timing and the one documented wait-state deviation, interrupts (fixed IM2, ports 32H/35H/39H), RST vector map, the full 100-pin terminal table, the 30–3FH on-chip control-register block, dual-CPU bus mapping, ICE mode. TRM §7.1/§3.4/§5.13 + Systemhandbuch §10.4. Open items in §12. |
| [`PC-1600-Machine-Overview.md`](PC-1600-Machine-Overview.md) | **first pass** | Chip complement, clock tree, dual main-CPU bus sharing (TRM §7.1.4), sub-CPU command protocol (§7.1.5), power rails (§7.7), power-on/boot (§3.5), peripheral catalogue (Ch 1). |
| [`PC-1600-Work-Area-Map.md`](PC-1600-Work-Area-Map.md) | **first pass** | The F000H–FFFFH BASIC/IOCS work area: 5-block structure, downward extension for peripheral ROM work areas + the PTR1–PTRG pointer table, and the §6.3 named-variable map (LCD/keyboard/interpreter/error-capture/variable-storage/plotter state). TRM Chapter 6. Complements `PC-1600-Memory-Bank-Switching.md` Part 6 (slot/boot addresses). |
| [`PC-1600-IO-Ports.md`](PC-1600-IO-Ports.md) | **first pass** | Range map + the LH-5810-compatible port block 10–1FH (OPC/MSK/IF/DDA/DDB/OPA/OPB, TRM §7.9), TC8576F register-select 20–27H (§7.6), buzzer (§7.5), LCD ports, 30–3FH cross-ref. Timer/RTC/analog IOCS (§3.9) + BEEP (§3.10) added; §3.4 32H/35H edge detail pending. |
| [`PC-1600-Display-HD61202.md`](PC-1600-Display-HD61202.md) | **first pass** | Panel LF7204E (156×32 + 16 symbols, 1/64 duty), HD61203 + 2×HD61102, 217 kHz CK0 clock, CS1/CS2/CS3→A2–A5 decode, I/O 50–5BH, frame-buffer model (TRM §7.3); **plus the full §3.1 LCD IOCS routine set** (text/cursor/scroll/status-line/graphics/raw), the §3.1.2 work area, and the §3.1.3 6×8 character-generator format. Char-code table (§10.1) pending. |
| [`PC-1600-IOCS.md`](PC-1600-IOCS.md) | **in progress** | IOCS calling conventions + master routine index §3.1–§3.13. **Chapter 3 complete** (§3.1–§3.13); §3.12–§3.13 already covered in `PC-1600-Memory-Bank-Switching.md` Part 6. |
| [`PC-1600-Filesystem.md`](PC-1600-Filesystem.md) | **first pass** | The file system (TRM §3.3): the 16-byte file header, the 57-byte FCB + 256-byte buffer, the file IOCS routines (C = IOCS #, `CALL 01DEH`; error bitfield), and the FAT-style RAM-disk / floppy layout — boot sector, media-ID geometry table, single-byte-entry FAT. Directory-entry format (§3.8.3) pending. |
| [`PC-1600-Peripherals-Hardware.md`](PC-1600-Peripherals-Hardware.md) | **in progress** | Printer/plotter (CE-1600P) and floppy (CE-1600F) IOCS + peripheral hardware (TRM §3.7/§3.8/Ch 8). §3.7 printer + §3.8 floppy routine sets filled; Ch 8 pending. |
| [`PC-1600-Keyboard.md`](PC-1600-Keyboard.md) | **complete (hw)** | Scan mechanism (1/64 s via sub-CPU → INT4), strobe/sense wiring (TRM §7.4/§7.9); **plus the full §3.2 key IOCS routines**, the 9-strobe software scan matrix, the §3.2.2 work area (KEYWK1–3, buffer pointers, 64-byte buffer F0DF–F11E), the 4 translation-table pointers + redefinition, and the ON/BREAK path (I/O 1BH b1). Emulator-ready. Key-code value table (§10.2) — agent-facing, not emulator-critical — pending. |
| [`PC-1600-Serial-Hardware-Notes.md`](PC-1600-Serial-Hardware-Notes.md) | **first pass** | RS-232C/SIO share one TC8576F; PRIM select; BX7269W level shifter; VDD/VEE; TC8576F pinout (TRM §7.6). Plus the FTDI USB/UART wiring how-to. |

### Stubs — structure in place, content to be written

| Document | Covers |
|---|---|
| [`PC-1600-CPU-LH5803-Compat.md`](PC-1600-CPU-LH5803-Compat.md) | **first pass** | The LH-5803 side: memory map, LH-5801 deltas, the full `CALLH` (01C6H) parameter block (TRM §5.14), MODE0/MODE1, and the PC-1500/1500A program + peripheral compatibility rules (TRM §5.15). |
| [`PC-1600-Expansion-Bus.md`](PC-1600-Expansion-Bus.md) | Designing hardware for the 60-pin system bus + 40-pin memory slots: electrical levels, bus-cycle timing, IRQ / WAIT peripheral protocol, ROM-module header + autostart, worked minimal-peripheral example. |
| [`PC-1600-Memory-Modules.md`](PC-1600-Memory-Modules.md) | Consolidated module catalogue: CE-1600M / 1601M / 1620M / 1650M / superRAM, plus PC-1500-module-in-PC-1600 adaptation. |
| [`PC-1600-Assembly-Guide.md`](PC-1600-Assembly-Guide.md) | **first pass** | Writing SC-7852 ML: the X/Y/Z arithmetic registers and the BCD-float / B2H-integer / D0H-string 8-byte encodings (TRM §4.1.3, = PC-1500 format), calling BASIC math functions (X + code in DE + F88CH, `CALL 0202H`), the BI2BCD/HTOA/etc. conversion routines (§4.2), bank-aware coding, IOCS pointers. Toolchain + worked examples still to write. |
| [`PC-1600-ROM-Disassembly.md`](PC-1600-ROM-Disassembly.md) | Pointer/index to the active PC-1600 ROM reverse-engineering project |

---

## Shared cross-machine documents (not moved — they cover PC-1500 too)

- `../Memory-Architecture/Expansion-Connectors.md` — §4/§5: raw pinouts for the PC-1600
  60-pin system bus and both 40-pin memory slots. `PC-1600-Expansion-Bus.md` builds on this.
- `../Memory-Architecture/Software-Defined-Memory-Extension.md` — §3: PC-1600 module
  emulation table (enable / bank-select conditions per module).
- `../Memory-Architecture/PU-PV-Signals.md` — the PV signal path relayed from the LH5803
  into the PC-1600 gate array.
- `../Memory-Architecture/PC-1500-Bank-Switching.md` — §9–10: CE-163 behaviour in PC-1600
  Slot 1 vs. Slot 2, and the `OUT &28/&29` A0 quirk.
- `../Memory-Architecture/PC-1500-Address-Decoding.md` — PC-1600 rows in the `MEM` /
  `NEW`-offset tables (§5.1).
- `../Data-Formats/Binary-Exchange-Formats.md` — §3: PC-1600 16-byte serial transfer header.
- `../Data-Formats/WAV-Cassette-Format-1500-1600.md` — the PC-1600 cassette (E-series)
  encoding.
- `../Assembly-Programming/LH5801_Guide.md` — the LH5801 instruction set, shared with the
  PC-1600's LH5803 side.

## Sources & validation

### Primary sources

Every document in this sub-corpus is built from Sharp's own documentation, cited
per-section:

- **PC-1600 Technical Reference Manual** (English) and the **PC-1600 Systemhandbuch**
  (Holtkötter, German) — the same manual; the German scan is cleaner and is what most of
  the transcription was read from. Covers the memory map, IOCS, the BASIC interpreter,
  the work area, the hardware chapter, and the Z-80 mnemonic tables.
- **PC-1600 Service Manual** — hardware architecture, schematics, the LR38041 gate array,
  slot pinouts. (The bank-switching document is largely Service-Manual-sourced.)
- **PC-1600 Bedienungsanleitung** (German user manual) — memory map (App. D),
  machine-language commands and PC-1500 compatibility (App. E/H).
- **Module service manuals** — CE-1601M; and the third-party *superRAM* manual for the
  vertical-bank mechanism.

### Independent validation

`~/Development/PockEmul/` — a long-running multi-pocket-computer emulator whose source
tree includes a working PC-1600 implementation (`src/machine/sharp/pc1600.*`, the Z-80
and LH-5801 cores, the CE-1600F/CE-1600P device models). It is **not a primary source**
— it is one reverse-engineer's reading of the hardware — but it is an *executable*
reference, and it was used across this sub-corpus to:

- cross-check the memory / bank-switching model against the manuals;
- resolve a handful of points the manuals leave ambiguous or contradictory (e.g. the
  keyboard strobe/sense port binding, the LCD-controller port decode, the routing of
  `C000–FFFF` when `Port 31H b7 = 1`);
- provide a concrete answer where the manuals are silent (e.g. how much wait-state the
  SC-7852 inserts — modelled there as none, nominal Zilog timing).

Where the manuals and this implementation agree, the fact is stated plainly. Where a fact
rests on the implementation alone, the document says so ("not confirmed against the
service manual") — but the implementation is not named again outside this note.

## Related projects

- `~/Development/sharp/pc1600/` — active byte-level ROM reverse-engineering of the PC-1600
  firmware (both CPUs). Downstream of this sub-corpus; indexed by
  `PC-1600-ROM-Disassembly.md`.
- `Calc-U-1600` — the target PC-1600 emulator this sub-corpus is written to support.
