# PC-1600 Memory Modules — Catalogue

> **STATUS: STUB.** Structure placeholder from the PC-1600 corpus restructuring
> (2026-08-29). Much of the content already exists in
> `PC-1600-Memory-Bank-Switching.md` Parts 7/7a/7b/10 — this document is where it will be
> consolidated into a per-module catalogue, leaving that document to cover the *mechanism*.

## Scope

Every memory module for the PC-1600 (Sharp and modern), one entry each: capacity, slot,
internal hardware, enable condition, bank-select mechanism, `INIT` modes, `MEM` impact.
Plus the PC-1500-module-in-PC-1600 adaptation path.

## Planned outline

- **CE-1600M** — 32 KB, either slot, fits in native two-bank capacity, no Port 28H.
  (`PC-1600-Memory-Bank-Switching.md` Part 7.)
- **CE-1601M** — 64 KB, Slot 2 only, first module needing Port 28H vertical banking
  (2 vertical banks); `INIT` modes A–D. (Part 7a.)
- **CE-1620M** — 32 KB EPROM, either slot, CE-1601E programmer, VPP 21 V.
  (`../Memory-Architecture/Software-Defined-Memory-Extension.md` §3.)
- **CE-1650M** — larger Japan-only module shown using the same vertical-bank scheme in the
  CE-1601M manual's memory map; no schematic-level source yet. (Part 7b footnote.)
- **superRAM** — modern 256 KB / 2×256 KB / 512 KB Slot-2 module; 4-bit vertical-bank
  field; runtime file-system patch for >256 KB. (Part 7b.)
- **Adapting a PC-1500 8×16 KB module** — adapter board, bank-signal mapping, driver
  approaches. (Part 10.)
- Cross-cutting rules: only vertical bank 0 is live program/expansion memory; Slot 1 caps
  at 32 KB toward `MEM`, Slot 2 at one vertical bank; the ~77 KB theoretical `MEM` ceiling.
  (Part 2's "Why Slot 1 and Slot 2 contribute so differently" + "theoretical maximum".)

## What partially exists elsewhere

- `PC-1600-Memory-Bank-Switching.md` Parts 2, 7, 7a, 7b, 10 — the authoritative content
  today; keep the mechanism there, move the per-product catalogue here.
- `../Memory-Architecture/Software-Defined-Memory-Extension.md` §3 — module emulation table
  (enable / bank-select conditions), stays as the cross-machine speculative doc.
- `../Memory-Architecture/PC-1500-Bank-Switching.md` §9–10 — CE-163 in PC-1600 slots.

## Sources needed

- CE-1650M schematic / service manual (open gap).
- Confirmation of Slot 1's ceiling: hard architectural cap or just unimplemented?
  (`Expansion-Connectors.md` §5 "Still open".)
