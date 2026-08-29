# PC-1600 ROM Disassembly — Pointer

> **STATUS: POINTER DOC.** Brief index into the external reverse-engineering project;
> created during the PC-1600 corpus restructuring (2026-08-29).

## The project

`~/Development/sharp/pc1600/` — an active effort to produce a symbol-annotated,
reassembleable disassembly of the PC-1600 firmware, both CPUs (Z-80-compatible SC7852 and
LH5803). Its own `README.md` is the index. Modeled on the sibling PC-1500 ROM
disassembly project (TASM-based, fully reassembleable).

Key files there:

| File | What |
|---|---|
| `README.md` | Provenance, status, roadmap. |
| `notes/ROM-Bank-Map.md` | Which ROM image maps to which bank, and confidence per file. |
| `notes/Emulator-Cross-Check.md` | the Port 31H/28H/38H model diffed against an independent emulator implementation; the origin of the few "not confirmed against the service manual" notes in `PC-1600-Memory-Bank-Switching.md`. (See this sub-corpus's `README.md` — *Sources & validation*.) |
| `notes/LH5803-A04-Crosscheck.md` | `rom1500.bin` vs. real PC-1500 A04 ROM — 68–71 % identical; 1892 symbols harvested; consolidated-dispatcher architectural change. |
| `disasm/z80/`, `disasm/lh5803/` | Raw auto-disassembly output. |
| `tools/regenerate-disasm.sh` | Redo the raw passes from scratch. |

## Provenance caveat

The disassembly project's ROM images did **not** come from a real PC-1600 or a physical
EPROM dump — they were taken from an emulator's source tree and have not been
cross-checked against hardware or a second independent dump. That project's own
`README.md` documents the exact origin. Treat the disassembly as "what a long-running
emulation effort believes the ROM contains" until spot-checked against hardware.

## Relationship to this corpus

This sub-corpus explains *why* the address space is shaped the way it is (bank switching,
chip selects, dual-CPU bus) — the disassembly project is where the bytes become readable
code. They are complementary; neither duplicates the other.

## Open items relevant here

- `romce1600-1.bin` / `romce1600-2.bin` — purpose unknown; possibly CE-1600F/CE-1600P
  peripheral ROMs rather than CPU firmware. Identifying them would also help
  `PC-1600-Expansion-Bus.md` and a future peripherals document.
- Real-hardware validation of the ROM images (e.g. a PEEK-based partial dump).
