# PC-1600 Expansion Bus — Hardware Design Reference

> **STATUS: STUB.** Structure placeholder from the PC-1600 corpus restructuring
> (2026-08-29).

## Scope

Everything needed to **design hardware** for the PC-1600's expansion connectors: the
60-pin system bus and the two 40-pin memory-slot connectors. Raw pinouts already live in
`../Memory-Architecture/Expansion-Connectors.md` §4 — this document builds on them with
the electrical, timing, and protocol detail a peripheral designer needs, plus worked
examples.

Memory modules specifically (CE-1600M etc.) get their own catalogue in
`PC-1600-Memory-Modules.md`; this document is about the bus, not the modules.

## Planned outline

- The three connectors and what each is for: 60-pin system bus (raw Z-80 bus + control:
  M1̄, INT1̄, IORQ, WAIT, IRQ, RD̄/WR̄, MREQ, ELH̄, IOE; cassette; VBAT; φOS/BFO) vs. the two
  40-pin memory slots (address/data + RAM1/RAM2 chip select + PVOUT/PU/PT bank bits +
  K0–K2 / S1–S3). Cross-ref `Expansion-Connectors.md` §4.0–4.3.
- **Electrical:** logic levels (5 V CMOS), drive strength / fan-out per line, which lines
  are inputs vs. outputs vs. bidirectional from the machine's side, pull-ups, INH usage,
  power budget available to a peripheral (VCC pins, VBAT).
- **Bus-cycle timing:** memory read/write and I/O read/write cycle diagrams, setup/hold
  vs. the SC7852 clock, WAIT-line insertion, the gate-array buffering delay on slot
  signals, LH5803-cycle differences when ELH̄ is asserted.
- **Interrupts from a peripheral:** IRQ / INT1̄ lines, IM2 vector mechanism (Port 39H),
  acknowledge cycle, sharing/priority (Port 32H/35H).
- **Address decoding for a peripheral:** how to claim an I/O range (28–2FH, 60–6FH,
  78–83H precedents), how INH lets a module override internal ROM.
- **ROM-module integration:** the 8-byte header, jump table at 4000H, boot-time detection
  (`SLOTST`, F0AE/F0AF bitmaps), autostart — consolidate from
  `PC-1600-Memory-Bank-Switching.md` Part 6.
- **Worked example:** a minimal I/O peripheral on the 60-pin bus (address decode + one
  readable/writable register + optional interrupt), end to end.
- **Unresolved:** the Slot 1 / Slot 2 ↔ K0–K2 / S1–S3 connector-label discrepancy
  (`Expansion-Connectors.md` §4.2a) — needs a continuity check on real hardware.

## What partially exists elsewhere

- `../Memory-Architecture/Expansion-Connectors.md` §4–5 — raw pinouts, signal-by-function
  summary, label discrepancy.
- `PC-1600-Memory-Bank-Switching.md` Part 3 (gate array), Part 5, Part 6 (module headers/
  boot), Part 10 (adapting a PC-1500 module), Part 11 (signal summary).
- An emulator with CE-1600F / CE-1600P device models is a behavioural cross-reference for this bus (see `README.md` — Sources & validation).

## Sources needed

- PC-1600 Service Manual — bus timing diagrams, gate-array (LR38041) AC characteristics.
- PC-1600 Technical Reference Manual §10 — connector chapter (already partly transcribed).
- CE-1600F / CE-1600P service manuals — as concrete peripheral-design references.
