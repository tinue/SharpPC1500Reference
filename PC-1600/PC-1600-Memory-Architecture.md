# PC-1600 Memory Architecture: Bank Switching, Decoding, and the LH5803 View

## 1. Overview and Scope

This document is the narrative/comparison layer for the PC-1600's memory system: how the Z-80 sees its bank-switched address space, how the internal RAM at the top of that space is structured, and — the part not covered elsewhere in this project — how the *same physical memory* looks when the machine's second CPU, the LH5803, is running in PC-1500-compatibility mode, and how that compares to a real PC-1500/1500A.

For the exhaustive mechanism-level reference (Port 31H truth tables per address range, the LR38041 gate array's pin-by-pin function, firmware bank-call routines, module header formats, and real module hardware including the CE-1600M/CE-1601M/*superRAM*), see `PC-1600-Memory-Bank-Switching.md` — this document draws on it throughout rather than repeating it. For the PC-1500/1500A's own decoder architecture, see `PC-1500-Address-Decoding.md`. For raw connector pinouts across all three machines, see `Expansion-Connectors.md`.

**Sources for this document specifically:** the PC-1600 Technical Reference Manual §2.1 ("Memory Map"), the paragraph introducing 8 memory banks and internal-RAM layout that follows it, §2.2 ("BASIC Commands Related to Machine Language"), **§3.12** ("Memory": 3.12.1 Slots and Memory Modules, 3.12.2 Work Area used for Memory, 3.12.3 IOCS routines) and **§3.13** ("Memory Module": location / type / header) — the TRM figures behind §2–§4b, not previously transcribed into this project's PC-1600 material — plus **§5.15** and the Operation Manual Appendices **F** (error codes) and **H** (PC-1500 compatibility) for §8. Cross-checked against the existing Service-Manual-sourced content in `PC-1600-Memory-Bank-Switching.md`, and against the PC-1600's own German-language user manual (*Bedienungsanleitung*), whose Appendix D (memory map, in German) and Appendix E/H (machine-language commands, PC-1500 compatibility) independently confirm most of the TRM material and correct several claims this document made in earlier revisions — noted inline where that happened.

---

## 2. The Z-80 View: 64KB Sliced Into Four Bank-Switched Pages

The TRM states the mechanism plainly: the Z-80's 64KB address space is segmented into four fixed 16KB pages (0000–3FFF, 4000–7FFF, 8000–BFFF, C000–FFFF), and each page independently selects which physical 16KB block occupies it via the Port 31H bank-select bits (`PC-1600-Memory-Bank-Switching.md` Part 2). The TRM's own memory-map figure, reproduced structurally below, lays out which physical block sits in which page for banks 0–6:

| Address range | Bank 0 | Bank 1 | Bank 2 | Bank 3 | Bank 4 | Bank 5 | Bank 6 |
|---|---|---|---|---|---|---|---|
| 0000–3FFF | Internal ROM | — | — | — | — | — | — |
| 4000–7FFF | Internal ROM (cont.) | Module Slot 2 (C) | — | Internal ROM | CE-1600P Printer ROM | — | — |
| 8000–C000 | Module Slot 1 (A) | Module Slot 1 (B) | Module Slot 2 (C) | Module Slot 2 (D) | — | — | Internal ROM |
| C000–FFFF | Internal RAM | — | — | — | — | — | — |

This is consistent with, and confirms, the bank table already in `PC-1600-Memory-Bank-Switching.md` Part 1 — the TRM's (A)/(B)/(C)/(D) labels for the 8000–C000 row are exactly that document's "Slot 1a/Slot 1b/Slot 2a/Slot 2b," just drawn as a single unified table instead of split into a bank table plus two "additional banks" side-tables.

**One new fact from the TRM's own prose, not previously documented here:** *"The PC-1600 can address 8 memory banks (bank 0 to bank 7). The first four banks are allocated to RAM. Banks 4 to 6 hold internal system ROMs and peripheral memory. Bank 7 is unused, but is addressable."* Two things worth drawing out:

- "The first four banks are allocated to RAM" is a simplification — banks 0–3 are actually a mix (system/module ROM in their 0000–7FFF halves, RAM in their 8000–FFFF halves) — but it correctly identifies that all the *RAM* in the whole banked address space (module RAM in Slot 1/2, plus the internal 16KB) lives exclusively within banks 0–3.
- **Bank 7 exists, is addressable, and is simply unused** by anything Sharp shipped. This is new information: nothing in the existing bank table accounts for a 7th bank at all. It's a second piece of headroom in the architecture, parallel to (but distinct from) the Port 28H vertical-bank headroom documented in `PC-1600-Memory-Bank-Switching.md` Part 2/7a/7b — that headroom is *within* a Slot-2 module's own 32KB footprint; Bank 7 is a whole unused *global* bank slot, addressable by the same 3-bit b1–b3/b4–b6 fields Port 31H already uses for banks 0–6. Nothing in the sources reviewed for this project describes what, if anything, was ever mapped there. Independently confirmed word-for-word by the PC-1600's German user manual, Appendix D: *"Bank 7 ist zwar adressierbar, aber ungenutzt"* ("Bank 7 is indeed addressable, but unused").

---

## 2a. Reconciling the Two TRM Figures, the (A)/(B)/(C)/(D) Labels, and "Page B"

**The apparent page-16-vs-page-17 contradiction is a prose oversimplification, not a real conflict.** (Page numbers here are the Holtkötter PDF's page count, matching how this discussion was raised.) The TRM's memory-map *figure* (PDF p.16, reproduced structurally in §2) is authoritative and correct: Bank 0's 0000–7FFF is 32 KB of internal system ROM — the CS001 ROM, which `PC-1600-Memory-Bank-Switching.md` Part 4 flags *"NEVER SWITCHED OUT"* — not RAM. The paragraph on PDF p.17 that says *"Die ersten vier Bänke sind dem RAM zugeordnet"* ("the first four banks are allocated to RAM") is a loose paraphrase that only holds for the *upper* half of banks 0–3 (8000–FFFF): every bank that contains **any** RAM is one of banks 0–3, but banks 0–3 are not all RAM. The 0000–7FFF half of every bank is ROM or unused; RAM begins at 8000 (module RAM) and at C000 (the fixed internal 16 KB).

Concretely, for Bank 0: 0000–7FFF = internal ROM, 8000–BFFF = Slot 1 module RAM (if present), C000–FFFF = internal 16 KB RAM. The figure on p.16 has it right; the sentence on p.17 is imprecise and should not be read as "banks 0–3 are RAM".

**The (A)/(B)/(C)/(D) labels, and references like "Page B, bank 1" — two incompatible conventions are in circulation. Disambiguate before answering.**

1. **TRM p.16 figure convention** — A/B/C/D quarter the *8000–BFFF module-RAM window* (one label per bank × slot). Here "Page B" = Slot 1b RAM. Table below.
2. **CPU-page convention** (used by at least one emulator effort) — A/B/C/D name the four 16 KB *CPU pages*: A = 0000–3FFF (page 0), **B = 4000–7FFF (page 1)**, **C = 8000–BFFF (page 2)**, D = C000–FFFF (page 3). Here "Page B, bank 1" = the 4000–7FFF window with Port 31H's page-1 field = 1, which `PC-1600-Memory-Bank-Switching.md` Part 1's summary table *labels* "Slot 2 ROM"; "Page C" = Slot 2 RAM at 8000–BFFF.

   **Do not confirm a "route Page B through the Slot 2 connector, same as Page C" claim — it is wrong, now at schematic level.** The **CE-1600M** (Sharp's 32KB RAM module) and **CE-1620M** (Sharp's 32KB ROM cartridge) schematics both tie their chip-enable to connector **pin 4 (RAMSN)**, which the gate array asserts only for **8000–BFFF** accesses routed to that slot; neither module has any signal for a 4000–7FFF access, and neither even wires PU (pin 3) or PT (pin 19). The 4000–7FFF window is decoded internally by **CS24** → Memory-PWB ROM only (Part 4/Part 12). The firmware's EXROM / "Page-1 module at 4000H/6000H" concept (Part 6) is real but belongs to the **60-pin system bus**, not the memory slots — the one real 4000–7FFF ROM device (CE-1600P) is exactly such a 60-pin unit. Correct handling for an emulator: the memory-slot connector objects are consulted **only** for 8000–BFFF accesses; 4000–7FFF banks 1–7 are open bus unless internal ROM is mapped there. Resolved along the way: PU/PT are the 4000–7FFF field bits b1/b2 and simply go unused by the 32KB memory modules; connector-pin "PVOUT" is Port 31H **b4** (the 8000–BFFF field's LSB / 16KB-half select), a different net from the like-named bit b0 (`PC-1600-Memory-Bank-Switching.md` Part 7 connector table).

   **The one legitimate way Slot 2 content reaches 4000–7FFF** — Sharp's CE-1601M Service Manual §5 map shows a parenthesised `(S2:)` at Bank 1 / 4000–7FFF — is a **mainboard-side gate-array remap**: `SLOT2MAP` (0199H) plus the Port 3DH address-latch outputs let the firmware make the Slot 2 RAM select assert for a 4000–7FFF/Bank-1 access. Model this as an effective-address rewrite feeding the ordinary 8000–BFFF slot decode, driven by those registers — never as a connector pin, and never on by default. See `PC-1600-Memory-Bank-Switching.md` Part 1, "(S2:) at Bank 1 / 4000–7FFF".

The tell for which convention is in play: "Page C" used for Slot 2 RAM, or "b7" named ⇒ convention 2 (CPU pages). A bare reference with no such context ⇒ assume convention 1 (the TRM figure), below.

**Convention 1 — the TRM figure's 8000–BFFF quarters:**

| TRM label | This project's name | Physical slot | Z-80 window | Bank (Port 31H page-2 field b6:b5:b4) | Contents |
|---|---|---|---|---|---|
| (A) | Slot 1a | Slot 1 | 8000–BFFF | Bank 0 (`000`) | Lower 16 KB of a Slot 1 module |
| (B) | Slot 1b | Slot 1 | 8000–BFFF | Bank 1 (`001`) | Upper 16 KB of a full-size (32 KB) Slot 1 module |
| (C) | Slot 2a | Slot 2 | 8000–BFFF | Bank 2 (`010`) | Lower 16 KB of the Slot 2 module's currently-selected 32 KB vertical bank |
| (D) | Slot 2b | Slot 2 | 8000–BFFF | Bank 3 (`011`) | Upper 16 KB of that same vertical bank |

So **"Page B, bank 1" = Slot 1b**: the upper 16 KB aperture of a full-size Slot 1 RAM module, mapped at Z-80 8000–BFFF whenever Port 31H's page-2 field selects bank 1. It is not a memory region distinct from anything else discussed here — it is one of these four module sub-windows, and it is module RAM (Slot 1), directly usable as program/expansion memory (§4a). The letter and the bank number are redundant: the figure fixes (A)→bank 0, (B)→bank 1, (C)→bank 2, (D)→bank 3, so "Page B" alone already implies bank 1.

**Why the figure also shows a *(C)* at 4000–7FFF in bank 1.** The firmware has an EXROM / "Page-1 module at offset 4000H or 6000H, banks 1–7" concept (F0AEH/F0AFH bitmaps, EXROM1–EXROME, `CALL 02DFH` Creg 01–0E — `PC-1600-Memory-Bank-Switching.md` Part 6), and the p.16 figure's label reflects that firmware model. **It does not follow that a card in the CN-7/CN-8 memory bay drives the 4000–7FFF window** — see the Part 1 footnote †: the wiring decodes this window with CS24 (internal Memory-PWB ROM only), the slots' pin-4 select is 8000–BFFF only, and memory-bay module headers sit at 8000H/A000H/B000H (page 2). Where 4000–7FFF ROM genuinely exists (CE-1600P, bank 4) it arrives via the **60-pin system bus**, a different connector with its own decode. So, reliably: module **RAM** is page 2 (8000–BFFF), Slot 1 → banks 0/1, Slot 2 → banks 2/3 (× Port 28H vertical bank). Module **ROM** at page 1 is a firmware-level model whose physical path the corpus does not tie to the memory slots. "Modules occupy 4 slots, 8000–BFFF, banks 0–3" describes the RAM side — the four A/B/C/D blocks — and Slot 2's 32 KB of that is a single vertical bank of up to eight.

---

## 3. Internal RAM (Bank 0, C000–FFFF): Structure and the PC-1500(A) Parallel

The TRM's internal-RAM figure lays out Bank 0's C000–FFFF exactly as follows:

| Address | Region | Size |
|---|---|---|
| C000H | Header | 8 bytes |
| C008H | Reserve Program Area | 189 bytes |
| C0C5H | Machine Program Area (allocatable) | ⎫ |
| ↕ | BASIC Program Area | ⎬ User Area, 11834 bytes total |
| ↕ | Variables Area | ⎭ |
| (F000H) | Work Area | 4096 bytes, fixed |
| FFFFH | | |

Two figures here directly cross-check against numbers already established elsewhere in this project, from completely independent sources:

- **The 197-byte reserve.** C0C5H − C000H = C5H = **197 decimal**. This is the exact same offset, and the exact same hex constant, as the PC-1500/1500A's own `NEW 0` convention documented in `PC-1500-Address-Decoding.md` §5.4: *"`NEW 0` will set the start of Basic memory to `[RAM start] + C5`... the first 197 bytes are used by various Basic data structures."* The PC-1600 didn't just inherit a similar idea — it inherited the identical numeric constant, split the same way: an 8-byte header (matching the ROM/RAM module header format documented in `PC-1600-Memory-Bank-Switching.md` Part 6) plus a 189-byte reserve area, 8 + 189 = 197 = C5H. The CE-1601M service manual (`PC-1600-Memory-Bank-Switching.md` Part 7a) independently states "Reserve program area = 189 bytes" for its own program-memory mode, confirming the same 189 figure a third time.
- **The user-area byte count — 11834 confirmed, the manual's 12090 is very likely wrong.** This English-language TRM figure gives 11834 bytes, matching the `MEM` figures already tabulated in `PC-1500-Address-Decoding.md` §5.1 for an empty PC-1600. The PC-1600's own German-language user manual (*Bedienungsanleitung*, Appendix D) instead gives 12090 for the identical configuration, and that number is *arithmetically self-consistent* with its own header(8B)/reserve(189B)/work-area(4096B) breakdown alone (`16384 − 4293 = 12091 ≈ 12090`) — which is exactly why this was flagged as an open discrepancy in an earlier revision of this document. It's since been settled by two independent real-hardware tests, both landing on a fixed 4550-byte overhead rather than 4293: a 16KB-module test (`32768 − 4550 = 28218`, exact) and a Slot 1 (8KB) + Slot 2 (32KB, one vertical bank) test (`57344 − 4550 = 52794`, exact — matching the Sharp-documented CE-1600M+CE-159 combo figure precisely). The same 4550-byte overhead reproducing exactly across three different configurations on the same hardware is strong evidence it's the real figure; the manual's 12090 (implying 4293) is presented as most likely a documentation error, not a genuine ROM-revision difference, though that can't be fully ruled out without testing a second unit. The extra 257 bytes beyond header+reserve+work-area (4550 − 197 − 4096) is most plausibly a fixed system-variable table the TRM's simplified Appendix D diagram doesn't itemize — being present identically whether or not any module is attached rules out anything module-dependent (like a per-slot directory reserve) as the source.

The practical takeaway: **the PC-1600's `NEW &C5`-style reserve-area convention is not a new design for the Z-80 side — it's the PC-1500(A)'s own convention, reused verbatim**, right down to the hex constant. Given the PC-1600 also runs an LH5803 in PC-1500-compatibility mode (§5 below), and Sharp's PC-1500(A) BASIC interpreter and PC-1600's Z-80 BASIC interpreter are separate codebases targeting different CPUs, this is either a deliberate, explicit design choice to keep the convention portable across the product line, or (less likely, given the exact byte-for-byte match including the header/reserve split) a shared heritage in how Sharp's BASIC toolchain group specified the fixed-area layout across pocket computers generally.

---

## 4. The `NEW` Command Across S0/S1/S2, and Where Machine-Language Programs Land

The TRM generalizes the PC-1500(A)'s single-target `NEW <expr>` into a three-target form:

```
NEW {"S0:" | "S1:" | "S2:"}, <expression>
```

where `<expression>` is "(the desired machine language program area size in bytes) plus C5H" — the same C5H constant as §3, now explicitly parameterized per target: **S0:** (internal RAM), **S1:** (Slot 1 module), **S2:** (Slot 2 module). Executing it allocates from `[slot's own base address] + C5H` up to `[base + expression] − 1`.

**Worked example from the TRM**, with a CE-159 program module in Slot 1 and a CE-1600M program module in Slot 2:

```
NEW "S1:",&1000
NEW "S2:",&5000
NEW "S0:",&1000
```

yields these machine-language program areas:

| Command | Resulting area | Bank |
|---|---|---|
| `NEW "S1:",&1000` | A0C5H–AFFFH | Bank 0 |
| `NEW "S2:",&5000` | 80C5H–BFFFH | Bank 2 |
| (continuation) | 8000H–8FFFH | Bank 3 |
| `NEW "S0:",&1000` | C0C5H–CFFFH | Bank 0 |

Two things worth noting:

- **CE-159's program area starts at A0C5H, not 80C5H** — i.e. this particular Slot-1 module's own address window begins at &A000, not &8000 (a half-size, 8KB-class module footprint, distinct from a full 16KB Slot 1a/1b pairing). This is module-specific, not a general Slot-1 property — `PC-1600-Memory-Bank-Switching.md`'s own bank table shows Slot 1a/1b spanning the full 8000–BFFF across banks 0/1 for a full-size module.
- **CE-1600M's program area spans two banks** (Bank 2's 80C5H–BFFFH, continuing into Bank 3's 8000H–8FFFH with no further +C5H offset, since it's a continuation of the same allocation, not a new base) — directly confirming that a &5000-byte (~20KB) `NEW` allocation on a 32KB module can straddle the Slot 2a/Slot 2b bank boundary transparently from BASIC's perspective, exactly as the underlying two-bank Slot 2 hardware (`PC-1600-Memory-Bank-Switching.md` Part 1) would predict.

This C5H-offset convention is identical in spirit to the PC-1500/1500A's own module-`NEW`-offset practice (`PC-1500-Address-Decoding.md` §5.4, §5.5) — allocate the fixed reserve first, then give BASIC/ML the rest — just generalized here to name which of three physical targets (S0/S1/S2) the reserve applies to, since the PC-1600 (unlike the PC-1500/1500A) has two independent module slots plus internal RAM, all needing this same bookkeeping simultaneously.

---

## 4a. Program Memory, Expansion Memory, and the RAM File: the Firmware's Central Distinctions

The PC-1600 firmware draws a hard line between RAM the CPU addresses directly and RAM reached only through the file system; on the CPU-addressable side it further separates **program memory** from **expansion memory**, and almost every "why does `MEM` report *X*" question resolves to which of these three a byte falls in:

- **Work area / expansion memory** — the RAM that holds the *currently active* BASIC program, its variables, and the machine-language area: §3's internal 11,834-byte user area, plus any module RAM glued onto it. "Expansion memory" is the manual's term for that glued-on module part. Directly CPU-addressable: the OS points the page-2/page-3 bank registers at it and *leaves them there*, so BASIC and ML code touch it as ordinary memory with no per-access bank juggling. **This is the one and only thing `MEM` counts.** A flat module carrying an extension-module header (CE-1600M in either slot; Slot 1 modules generally) is folded in **automatically at boot**; otherwise the module part is set up by `NEW "S0:"/"S1:"/"S2:",expr` (§4) or `INIT "S2:","M"` (and by the (32−*n*) remainder of `INIT "S2:","P",n`) — see §4b.3(d). Its module-side bookkeeping lives in main-unit RAM, so a Slot 2 module's expansion-memory contribution does **not** survive a battery swap. **Ceiling ≈ 77 KB**: internal 16 KB + one 32 KB Slot 1 span + one 32 KB Slot 2 vertical bank (`PC-1600-Memory-Bank-Switching.md` Part 2, "the theoretical maximum").
- **Program memory** — a *separate, resident program-storage area*, set up by `INIT "S2:","P"` (or the *n* KB named in `INIT "S2:","P",n`). Also directly CPU-addressable when active, but it holds a parked BASIC program rather than extending the current work area, so **`MEM` never reflects it** — allocating it leaves `MEM` unchanged. `TITLE`-named, cleared with `NEW 0`, held in the module SRAM so it *does* survive a battery swap. Internally it has the same fixed layout as §3's internal RAM: an 8-byte header + a 189-byte "Reserve Program Area" + the **"BASIC text area"** (the tokenized program lines themselves) — the CE-1601M manual names those two sub-regions, but the only term that matters at the `INIT` level is "program memory".
- **RAM file / RAM disk (data storage)** — reached *only* through the file system (`SAVE`/`LOAD`/`FILES`/`KILL`/`PRINT#`/`INPUT#`…). The file-system driver is the only code that issues per-access `OUT (28H)` vertical-bank writes, so it can walk all 8 vertical banks of a Slot 2 module (256 KB), of which only vertical bank 0 is ever eligible to become program or expansion memory. `DSKF` reports its free space; `MEM` never sees it.

`INIT "S2:","P",n` (CE-1601M Mode D, `PC-1600-Memory-Bank-Switching.md` Part 7a) makes the split explicit — it partitions one module's vertical bank 0 into *n* KB of program memory + (32−*n*) KB of expansion memory, and hands vertical bank 1 to a 32 KB RAM file, in one command. So `MEM` rises by exactly (32−*n*) KB: plain `INIT "S2:","P"` is the *n* = 32 case (all program memory, `MEM` unchanged) and plain `INIT "S2:","M"` is the *n* = 0 case (all expansion memory, `MEM` +32 KB). This is why a 256 KB Slot 2 module adds at most 32 KB to `MEM` with the remainder data-storage-only. `INIT "S2:","P",n` is a *vertical-banked-module* mechanism — a flat 32 KB extension-type module (CE-1600M) in Slot 2 just merges its whole 32 KB at boot with no `INIT` step, the same way a Slot 1 module does (Slot 1's two banks sit in global Bank 0/1 alongside internal RAM, contiguous).

---

## 4b. Where a Module Sits in the 8000–BFFF Window, and How the BASIC/ML Area Slides (TRM §3.12–§3.13)

§4 covered the `NEW "Sx:"` *command*; this section adds the two TRM figures that show the *geometry* — **§3.12.1** ("Slots and Memory Modules", TRM p.127) and **§3.13.1** ("Location of Memory Module", TRM p.135) — plus the "no `NEW` yet" starting state, worked as memory maps. These are the third and fourth previously-untranscribed Chapter-2/Chapter-3 figures (the first two are §2.1's dual bank map and §2.1's internal-RAM map, §2–§3 above).

### 4b.1 The four module "locations" A / B / C / D

TRM §3.13.1 names the four 16 KB module apertures — identical to `PC-1600-Memory-Bank-Switching.md` Part 1's Slot 1a/1b/2a/2b and §2a's convention-1 table, but with the TRM's own single-letter labels:

| Loc | Z-80 window | Global bank | Slot | Port 31H page-2 field (b6:b5:b4) |
|---|---|---|---|---|
| **A** | 8000–BFFF | Bank 0 | Slot 1, lower 16 KB | `000` |
| **B** | 8000–BFFF | Bank 1 | Slot 1, upper 16 KB | `001` |
| **C** | 8000–BFFF | Bank 2 | Slot 2, lower 16 KB | `010` |
| **D** | 8000–BFFF | Bank 3 | Slot 2, upper 16 KB | `011` |

"Main memory" is always Bank 0's C000–FFFF (internal 16 KB). TRM §3.13.1's capacity→location rule:

| Module size | Slot 1 | Slot 2 |
|---|---|---|
| ≤ 16 KB | → A | → C |
| 32 KB | → A + B | → C + D |
| ≥ 48 KB | **cannot be used** | → C + D (one 32 KB slice), rest via Port 28H vertical-bank switching |

### 4b.2 Small modules are top-justified inside their 16 KB location

The single most important detail in the §3.12.1 figure, and the answer to "a CE-155 only covers 8 KB of the window": a sub-16 KB module **occupies the *high* end of location A**, ending at BFFF, with the low part of the window left unmapped (the figure hatches it "not used"). From the figure:

| Module | Size | Slot(s) | Covers (in location A / bank 0) |
|---|---|---|---|
| CE-151 | 4 KB | S1 only | **B000–BFFF** (low B000-worth… i.e. top 4 KB) |
| CE-155 | 8 KB | S1 only | **A000–BFFF** (top 8 KB) |
| CE-159 | 8 KB (program) | S1 only | **A000–BFFF** (top 8 KB) |
| CE-161 | 16 KB | S1 **or** S2 | **8000–BFFF** (fills the whole location) |
| CE-1600M | 32 KB | S1 **or** S2 | 8000–BFFF **× 2 banks** (A + B, or C + D) |
| CE-1620M | 32 KB EPROM | S1 or S2 | A + B, or C + D |
| CE-1601M | 64 KB | **S2 only** | C + D, one vertical bank live, Port 28H for the rest |

Top-justification is what makes the merge with internal RAM seamless: the module's last byte is BFFF, internal RAM's first byte is C000, so module-then-internal is one gap-free ascending run and BASIC only needs a single `RAM_START` pointer. The unmapped low part of the window (8000–9FFF for a CE-155, 8000–AFFF for a CE-151) is simply dead address space — not counted by `MEM`, not usable.

TRM §3.12.1's own footnote: *"Even when a memory module is installed in S1 or S2, if it is used as an extension memory, it is referred to as S0."* — i.e. the moment a module's RAM is glued onto the work area, `NEW`/`MEM`/`STATUS` treat it as part of **S0**, not as a separate S1/S2 object. S1/S2 as `NEW`/`INIT`/`TITLE` targets mean "the module *as a program module or RAM file*", a different role (§4a).

### 4b.3 No `NEW` executed yet — the default BASIC-area structure

`NEW` with no machine-language reservation (equivalently `NEW 0`, or power-on default) leaves the **Machine Program Area empty**: BASIC's program-text pointer sits directly on top of the 197-byte reserve, at `[RAM start] + C5H`. What `[RAM start]` *is* depends on the modules:

**(a) Bare machine, no modules** — `[RAM start]` = C000H (internal RAM base).

```
Z-80 view, Bank 0                       MEM = 11 834
  8000 ┌───────────────────┐ ─┐
       │  open bus          │  │  no Slot 1 module → dead space
  C000 ├───────────────────┤ ─┘
       │ Header      8 B    │  C000–C007
  C008 │ Reserve   189 B    │  C008–C0C4     ┐ 197 B fixed (C5H)
  C0C5 ├───────────────────┤ ◄─ BASIC text start   ┐
       │ BASIC program  ▲  │                       │
       │       ⋮           │  grows up             │ User Area
       │ Variables      ▼  │  grows down from EFFF │ = 11 834 B
  EFFF ├───────────────────┤                       ┘
  F000 │ Work Area (fixed) │  4 KB, F000–FFFF (never moves, §2/§3)
  FFFF └───────────────────┘
```

**(b) CE-155 (8 KB) in Slot 1, used as extension memory** — `[RAM start]` slides down to A000H. The header + 197-byte reserve **move to the module base**; internal RAM's own C000 area becomes plain user space (only one reserve exists — TRM §3.13.2: *"only one header is placed in location A or C"*).

```
Z-80 view                              MEM = 20 026   (= 11 834 + 8 192, PC-1500-Address-Decoding.md §5.2)
  8000 ┌───────────────────┐  open bus (CE-155 does not reach here)
  A000 ├───────────────────┤ ◄─ [RAM start]
       │ Header + Reserve  │  A000–A0C4  (197 B)
  A0C5 ├───────────────────┤ ◄─ BASIC text start
       │ BASIC program  ▲  │   CE-155 body  A0C5–BFFF  ┐
  C000 ├─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤   (module → internal,     │ one contiguous
       │       ⋮   ▲/▼      │    no gap at BFFF→C000)   │ User Area
  EFFF ├───────────────────┤                           ┘
  F000 │ Work Area (fixed) │
  FFFF └───────────────────┘
```

Same shape for CE-151 (`[RAM start]` = B000H, `MEM` = 11 834 + 4 096) and CE-161 (`[RAM start]` = 8000H, `MEM` = 11 834 + 16 384).

**(c) CE-1600M (32 KB) in Slot 1** — fills locations A **and** B. `[RAM start]` = 8000H (bank 0). The OS leaves the page-2 register on bank 0, so the CPU sees `8000–BFFF(A) → C000–FFFF(internal)` as a flat 32 KB run; the B half (bank 1) is reached by the OS flipping page-2 to bank 1 transparently while walking the program text.

```
                                        MEM = 44 602   (≈ CE-1600M manual's "up to 44,612")
  Bank 0  8000–BFFF  CE-1600M low  (loc A)   header+reserve at 8000H, BASIC text from 80C5H
  Bank 1  8000–BFFF  CE-1600M high (loc B)   ← page-2 flips here transparently
  Bank 0  C000–EFFF  internal RAM (BASIC/vars)
  Bank 0  F000–FFFF  Work Area
```

**(d) Slot 2 — depends on the module type.** Slot 2's RAM is in **Bank 2/3**, not the default bank, so *something* has to repoint page-2 at Bank 2 and leave it there. Two cases:

- **A flat module carrying an *extension-module* header (CE-1600M; a CE-161 formatted as extension).** Boot-time module detection reads the header, sees the extension type (§3.13.2 type 1), and folds the module into the work area **automatically at reset** — page-2 is repointed and left there, exactly as for Slot 1. `MEM` reflects it immediately; `INIT "S2:","M"` is then a no-op. (Emulator-confirmed for the CE-1600M: `MEM` = 77 370 straight after reset with a CE-1600M in each slot.) `INIT "S2:","M"` is only needed here to *re-type* a module that is currently a file or program module back to extension memory.
- **A vertical-banked module (CE-1601M, CE-1650M, *superRAM*, 128 KB+), or a module typed as file/program.** Default state is RAM disk / parked program — `MEM` stays at the internal-only figure (plus whatever Slot 1 added). `INIT "S2:","M"` (or `NEW "S2:",expr`, or the `(32−n)` remainder of `INIT "S2:","P",n`) dedicates **one 32 KB vertical bank** as expansion memory; the rest stays file-system-only. After it, the instantaneous Z-80 map `8000–BFFF(C) → C000–FFFF(internal)` is flat again — same picture as (c), `MEM` += 32 768.

The structural Slot-1/Slot-2 asymmetry (`PC-1600-Memory-Bank-Switching.md` Part 2) is really about the *ceiling* — Slot 2 can only ever contribute one 32 KB vertical bank to `MEM` regardless of module size — not about whether a command is required: a flat extension-type module auto-merges in either slot.

### 4b.4 `NEW "Sx:",<expr>` — the BASIC area sliding "around" the machine area

The Machine Program Area is always carved at the **bottom** of its target region: from `[target base] + C5H` to `[target base] + <expr> − 1` (with `<expr>` = wanted ML size + C5H). The BASIC program text then starts on the byte **above** that block and grows up; variables still grow down from EFFF. So the ML area is a *fixed low anchor* and the BASIC/variable area is what fills the rest of the merged user span — it "slides" upward by exactly the size of whatever ML block(s) you reserved, and the three targets S0/S1/S2 just let you drop that anchor in three different physical places (internal RAM base, Slot 1 base, Slot 2 base) at the same time.

**Worked example (TRM §2.2, p.128 figure): CE-159 in S1 + CE-1600M in S2**, both as program modules, then:

```
NEW "S1:",&1000     → ML area  A0C5H–AFFFH        (Slot 1, loc A)     — BASIC text now starts B000H
NEW "S2:",&5000     → ML area  80C5H–BFFFH (bank2) + 8000H–8FFFH (bank3, no 2nd +C5H)
NEW "S0:",&1000     → ML area  C0C5H–CFFFH        (internal, bank 0)  — BASIC text in internal RAM starts D000H
```

Three independent fixed ML blocks (one per base + C5H); the BASIC program/variable area occupies every user byte *not* in one of them — literally sliding "around" all three. Note `NEW "S2:",&5000` (≈ 20 KB) straddles the C/D bank boundary transparently: `80C5–BFFF` in bank 2, continuing at `8000–8FFF` in bank 3 with **no** second reserve, because it is one allocation, not a new base (§4).

### 4b.5 The load order (TRM §3.12.2 "Work Area used for Memory")

When several regions are joined, the OS records — in `S0MTb` (F02AH), `S1MTb`/`S1MBb` (F016H/F018H), `S2MTb`/`S2MBb` (F020H/F022H) and the `ADTBL+1…ADTBL+5` byte table (F1D6H–F1DAH, bank number in bits 4–5) — **the order in which the BASIC program is laid down across the banks**. TRM §3.12.2 Example 1 (CE-159 S1 + CE-1600M S2 as *extension* memory): program fills **bank 0 → bank 2 → bank 3 → main memory** in that order; `S1MTb`/`S2MTb` = FEH ("not a program module — used as extension memory"), `ADTBL+3…+5` = 01H/22H/32H (bank 0, bank 2, bank 3). Example 2 (CE-1600M S1 + CE-161 S2 as *program* modules): `S1MTb`/`S1MBb` = 02H/03H (S1 spans ADTBL+2..+3), `S2MTb` = 04H, load order S0 → S1 → S2. The takeaway: "one contiguous user area" is a firmware abstraction over an explicit, recorded bank sequence — the program text really is scattered across banks 0/2/3/main and the ADTBL list is the map.

The `ADTBL+n` byte-level encoding (`bank = (b>>4)&3`, low nibble = slot, bit 7 = program-module leading bank), and a step-by-step reconstruction of where each tokenised byte lands — for an emulator that injects a program image directly instead of running `LOAD` — are in `PC-1600-Work-Area-Map.md` §4 and `PC-1600-BASIC-Program-Placement.md`.

### 4b.6 LH5803 view of the same configurations

In MODE 1 / under `XCALL`, the LH5803 sees module RAM at **0000–3FFF** and internal RAM at **4000–7FFF** (§5–§6). The same top-justification applies, shifted by −8000H:

```
Config (b), CE-155 in Slot 1, LH5803 view:
  0000 ┌───────────┐  open bus
  2000 ├───────────┤ ◄─ CE-155 body 2000–3FFF  (= Z-80 A000–BFFF)
  3FFF ├───────────┤
  4000 │ internal  │  4000–7FFF  (= Z-80 C000–FFFF, bank 0)
  7000 │  …work    │  7000–7FFF work area  (= Z-80 F000–FFFF)
  7FFF └───────────┘
```

This is deliberately a PC-1500-shaped map: a flat module window at the bottom, fixed internal RAM above it, work area at the very top (§6's address-by-address comparison). It only holds when the module is a *single flat ≤16 KB region with no banking* — which is exactly the constraint behind ERROR 110 (§8).

### 4b.7 Worked example: CE-1600M in **both** slots — the maximum-RAM configuration

Two genuine CE-1600Ms (32 KB each, flat, two-bank, no vertical banking) + the internal 16 KB is the largest `MEM` a PC-1600 can reach. **Both slots merge automatically at boot** — a CE-1600M carries an *extension-module* header (§3.13.2 type 1), so module detection folds it into the work area at reset for Slot 2 just as for Slot 1. `MEM` reports **77 370 immediately after a reset**, and `INIT "S2:","M"` is a **no-op** in this state (confirmed on the emulator). `INIT "S2:","M"` only matters if the module is *currently* typed as a file or program module — it re-types it back to extension memory. (Contrast the vertical-banked modules below.)

```
   Bank 0  8000–BFFF  Slot 1 CE-1600M, low half   (loc A)   ┐
   Bank 1  8000–BFFF  Slot 1 CE-1600M, high half  (loc B)   │ one logical
   Bank 2  8000–BFFF  Slot 2 CE-1600M, low half   (loc C)   │ user area,
   Bank 3  8000–BFFF  Slot 2 CE-1600M, high half  (loc D)   │ scattered
   Bank 0  C000–EFFF  internal RAM                          │ across banks
   Bank 0  F000–FFFF  Work Area (fixed)                     ┘ per ADTBL (§4b.5)

   16384 + 32768 + 32768 − 4550 = 77 370   ← MEM, confirmed on the emulator (2 × CE-1600M)
```

**This is the ceiling.** Both slot contributions are already at their architectural cap (Slot 1: only Bank 0 + Bank 1 exist for its window; Slot 2: only vertical bank 0 can be S0 expansion memory — and a CE-1600M *is* exactly one 32 KB vertical bank). A CE-1601M / CE-1650M / *superRAM* in Slot 2 keeps `MEM` at this same figure and adds its extra vertical banks **only as RAM-disk space** (`PC-1600-Memory-Bank-Switching.md` Part 2, "Why Slot 1 and Slot 2 contribute so differently"). The one untapped reserve anywhere is Bank 7 ("addressable but unused", §2) — no module uses it.

**Machine-language areas in this configuration.** `NEW "S0:"`, `NEW "S1:"` and `NEW "S2:"` are three independent targets that **accumulate** — issuing them in sequence leaves all three ML areas reserved; only the BASIC program text is cleared by each `NEW` (TRM §2.2's own example does exactly this). Each carves `[base]+C5H … [base]+<expr>−1` from the bottom of its region (`<expr>` = program size + `&C5` = size + 197):

| `NEW` | Base | ML area | Max one contiguous block |
|---|---|---|---|
| `NEW "S1:",<expr>` | 8000H | 80C5H → Bank 0's 8000–BFFF, then Bank 1's 8000–BFFF | **32 571 bytes** (`<expr>` ≤ `&8000`) |
| `NEW "S2:",<expr>` | 8000H | 80C5H → Bank 2, then Bank 3 (transparent across the C/D boundary) | **32 571 bytes** |
| `NEW "S0:",<expr>` | C000H | C0C5H → internal RAM only (stops below the F000H work area) | **≈ 11.8 KB** |

So one contiguous ML program is capped at **≈ 32.5 KB** (a full slot); reserving all three regions yields ≈ 77 KB of ML area total, i.e. almost all of `MEM`. For a program larger than one slot, split it across regions and cross the bank boundary with `BANKCALL` (019FH) / `RST 20H` / `BANKCALL2` (0020H).

**Two programs in two slots** — the intended use of the multi-target form:

```
NEW "S1:",&<sizeA+C5>          ' area A at 80C5H, Bank 0/1
NEW "S2:",&<sizeB+C5>          ' area B at 80C5H, Bank 2/3   (does not disturb area A)
' load program A (e.g. CLOADM "A";#0,&80C5,… or POKE #0,…), load program B into #2
CALL #0,&80C5 [,var]           ' run A
CALL #2,&80C5 [,var]           ' run B
```

All of this is **SC-7852 (Z-80)** code (`CALL` / `PEEK` / `POKE` / `BLOAD` / `CLOADM`); the LH-5803 side is the separate `XCALL` / `XPEEK` / `XPOKE` path with its own address map (§5–§6).

**Effect on the BASIC area — it flows around the reservations; a slot is never lost.** The German TRM §2.2 puts it directly: `NEW` reserves the ML space "*and thereby simultaneously specifies the lower address of the BASIC program area*". Every byte of the ≈ 77 KB user area not inside an ML block stays BASIC-program / variable space; the interpreter tracks the scattered bank order in `ADTBL` (§4b.5) and treats it as one stream. Reserve 8 KB in Slot 1 and the other 24 KB of that slot is still BASIC space. Rule of thumb:

```
MEM after reservations  ≈  77 370 − Σ <expr>        (over the regions you targeted;
                                                     each <expr> already includes its 197-byte reserve)
```

Regions you never point `NEW` at cost nothing extra; targeting all three pays ≈ 3 × 197 B of reserve rather than one. With two CE-1600Ms there is **no** slot unavailable to BASIC — both are live expansion memory from reset. (A slot only goes dark if its module is typed as a file/program module, or — for a *vertical-banked* module such as the CE-1601M — until `INIT "S2:","M"` dedicates vertical bank 0; see §4b.3(d).)

---

## 5. The LH5803 View: Same Silicon, Different Address Space

The PC-1600 carries two CPUs sharing one bus (`PC-1600-Memory-Bank-Switching.md` Part 8): the Z-80-compatible SC7852 (the machine's primary CPU — BASIC's own command loop runs here, always, per the note below) and an LH5803, present specifically to execute PC-1500-compatible code — genuine LH5801 assembly, either from `CLOAD`ed PC-1500 programs or from PC-1500-era peripheral ROMs like CE-150/CE-158. Only one CPU runs at a time — `ELH` (pin 58 on the 60-pin system bus, `Expansion-Connectors.md` §4.0) selects which — but that exclusivity is a hardware bus-arbitration fact, not evidence for how long any given handoff lasts.

The TRM gives the LH5803's own memory map as a **separate figure**, not a re-labeling of the Z-80's — the LH5803 sees a plain, unbanked-from-its-own-perspective 64KB space (bank 0–3 shown, but see below for what "bank" means here):

| LH5803 address | Contents | Z-80-side equivalent |
|---|---|---|
| 0000–3FFF | Module Slot 1 / Module Slot 2 | Z-80's 8000–BFFF (Slot 1/2 RAM) |
| 4000–7FFF | Internal RAM (fixed, no banking) | Z-80's C000–FFFF, Bank 0 only |
| 8000–A000 | CE-158 ROM (when PVOUT=1) | same physical ROM chip as CE-158's Z-80-side mapping |
| A000–C000 | CE-150 ROM (when PVOUT=0) | same physical ROM chip as CE-150's Z-80-side mapping |
| C000–FFFF | Internal ROM (fixed) | Z-80's Bank-6-class system ROM (CS123-equivalent) |

This matches `PC-1600-Memory-Bank-Switching.md` Part 8's existing summary table exactly (0000–3FFF = Z-80's 8000–BFFF; 4000–7FFF = Z-80's C000–FFFF; 8000–BFFF = CE-150/CE-158 by PVOUT; C000–FFFF = ROM), and the TRM figure adds the concrete sub-split of 8000–BFFF (CE-158 in the lower 8KB, CE-150 in the upper 8KB) and shows this "4 banks" (0–3) structure is really **2 module slots × 2 PVOUT states**, not a Port-31H-style page-bank system of its own — the LH5803 doesn't do the Z-80's four-independent-pages bank switching at all. Its 0000–3FFF is whichever Slot-1/Slot-2 RAM bank the Z-80 side last selected via Port 31H (the LH5803 rides on the same physical RAM chip-selects, RAM1/RAM2, that the Z-80 uses); its 4000–7FFF is unconditionally the internal RAM's Bank 0 (no LH5803-side equivalent of switching in Bank 1); its 8000–BFFF split is driven purely by PVOUT, the same physical bit Port 31H's b0 also drives for the Z-80's own page 0/3 select.

**Why this specific remapping.** The LH5803 is present to execute genuine PC-1500-compatible LH5801 machine code — user `ML`/`XCALL` programs, and peripheral-ROM-provided BASIC command implementations reached via the `CALLH`-class fallback (see the revised model below). Its memory map is therefore not an independent design — it's built to make the PC-1600's actual physical memory *look like a PC-1500's memory map from the LH5803's point of view*, address for address, wherever practical, so that code written against real PC-1500 absolute addresses keeps working unmodified. §6 makes this comparison explicit.

**Confirmed model of MODE0/MODE1, from the PC-1600's own German user manual (*Bedienungsanleitung*, §9.2, Appendix H).** Two earlier revisions of this document guessed at this mechanism from indirect evidence; the manual settles it directly, and the confirmed picture is different from both guesses:

- **`MODE0`/`MODE1` are officially called "Anzeige-Modi" (display modes)**, switched by the BASIC command `MODE` — and this is explicitly *not* the same thing as the physical `[MODE]` key, which the manual documents separately as a PRO/RUN/RESERVE edit-mode toggle. The manual itself anticipates the confusion: *"Die zwei Anzeige-Modi werden MODE 0 und MODE 1 genannt, was Sie vielleicht verwirren... mag."* ("The two display modes are called MODE 0 and MODE 1, which might confuse you...").
- **MODE 1 is 26×1: only the bottom of the four display lines is used**, specifically for PC-1500 program compatibility — confirming the display-restriction hypothesis raised earlier in this conversation. Character codes `&27`/`&5B`/`&5D` are also remapped to their PC-1500-specific meanings (insert symbol, root sign, etc.) while in MODE 1.
- **BASIC's command set and interpreter are Z-80-resident in both modes, at the dispatcher level.** Appendix H states plainly: *"BASIC-Programme, die auf dem PC-1500 geschrieben worden sind, laufen grundsätzlich auch auf dem PC-1600, sofern dieser im MODE 1 betrieben wird. Die überwiegende Mehrheit der BASIC-Befehle stimmt bei beiden Rechnern überein."* ("PC-1500-written BASIC programs generally also run on the PC-1600, provided it's run in MODE 1. The vast majority of BASIC commands agree between the two machines.") This is compatibility by *shared command set and adjusted behavior*, not by handing the interactive session to a separate interpreter.
- **`SETCOM` (and by extension, other peripheral-provided commands) genuinely dispatches to the attached peripheral's own ROM — confirmed by necessity, via a modern device.** `SETCOM` appears as one ordinary command in the PC-1600's own command list (Appendix G: *"SETCOM: Setzt Protokoll für serielles Interface"*), unlike the explicit `CALL`/`XCALL`-style split — meaning any per-peripheral dispatch is automatic (detected from what's physically attached, the same way boot-time module detection works, `PC-1600-Memory-Bank-Switching.md` Part 6), not exposed in the syntax. This resolves what would otherwise be an open question: **CE-158X**, a modern recreation of the CE-158 with a modified ROM adding USB support (an additional serial port neither the real CE-158's original ROM nor the PC-1600's own native ROM could possibly have any knowledge of, since USB postdates both by decades), works correctly on a PC-1600 — including through `SETCOM`/`SETDEV` reaching its USB channel. That's only possible if those commands genuinely execute CE-158X's own (modified) ROM code when it's present; a fixed native PC-1600 implementation with hardcoded knowledge of the real CE-158's registers has no code path that could reach a port invented after the fact. So: the plain PC-1500's peripheral-ROM-precedence mechanism (`PU-PV-Signals.md` §4–5 — a peripheral's own BASIC-command-table implementation takes precedence over the base ROM's) survives intact into the PC-1600, generalized through the `CALLH`-class dispatch — a peripheral's ROM can extend or override BASIC command behavior in ways the base PC-1600 firmware has no knowledge of, not just reproduce PC-1500-era behavior faithfully.
- **Genuine cross-CPU access is explicit and programmer-facing**, not inferred by any dispatcher: `CALL` (Z-80 machine program) vs. `XCALL` (LH-5801/3-coded machine program), `PEEK`/`POKE` (Z-80-managed address) vs. `XPEEK`/`XPOKE` (LH-5801-managed address), and the port equivalents `PEEK#`/`POKE#` vs. `XPEEK#`/`XPOKE#` — a full, confirmed table in Appendix E/H. This is the actual mechanism for touching the LH5803 side of the machine: a specific command, chosen by the programmer or already baked into a loaded PC-1500 program's tokenized bytecode, not a fallback triggered by an unrecognized command name.
- **Running an actual PC-1500 program in MODE 1 requires a module under 16KB present** in one of the two slots — CE-151, CE-155, CE-159, or CE-161 specifically named — with no module present producing an ERROR. Directly relevant to the capacity discussion earlier in this conversation: MODE 1 compatibility isn't just a display/behavior toggle, it has a real hardware prerequisite tied to the module-window RAM.
- **Confirms, with the exact address range, what §3's earlier note could only infer architecturally:** Appendix H, "Inkompatibilität zum PC-1500A" — *"Der beim PC-1500A für den Anwender frei benutzbare Speicher im Adreßbereich &7C00 bis &7FFF steht dem Anwender beim PC-1600 nicht mehr zur Verfügung, weil dieser Bereich für Systemzwecke benötigt wird. Aus diesem Grunde können die Modelle PC-1500A und PC-1600 nicht als kompatibel angesehen werden."* ("The memory freely usable on the PC-1500A at `&7C00`–`&7FFF` is no longer available to the user on the PC-1600, because this range is needed for system purposes. For this reason, the PC-1500A and PC-1600 cannot be considered compatible [in this respect].") — the PC-1500A's own machine-language area (`PC-1500-Address-Decoding.md` §4) is explicitly, by name, reserved on the PC-1600, not merely "probably reserved by architectural necessity" as guessed earlier.

**Consequence for `MEM`:** the real-hardware test that prompted this section — a stock PC-1600 with a plain (non-vertical-banked, CE-163-class) 16KB `S0:`-expanded module in Slot 2 reporting **`MEM` = 28218 in both MODE 0 and MODE 1** — is now explained simply: `MEM` is native, always-Z-80-resident BASIC housekeeping, run by the identical routine regardless of which display mode is active. The identical figure isn't architecturally significant, just the same command computing the same thing every time.

The address-adjacency fact is still real and still explains why the *number itself* is what it is: Slot 2's window (Z-80 8000–BFFF, page 2) sits directly below internal RAM (Z-80 C000–FFFF, page 3) — `BFFF`+1 = `C000` — so a module that fits within one 16KB bank merges into one physically contiguous 32KB span with internal RAM, needing only a static `RAM_START` pointer, no bank-switching-per-array-access trickery. With fixed overhead (header + 197-byte reserve + 4096-byte work area) totaling either 4293 or 4550 bytes depending on which of §3's two conflicting baselines is used, paid once at the bottom of that span:

```
16384 − 4550 = 11834   (internal RAM alone — matches the real-hardware-anchored baseline)
32768 − 4550 = 28218   (16KB module + 16KB internal RAM, contiguous — matches the observed figure exactly)
```

Whether a 32KB+ `S0:` allocation (spanning two Z-80 banks, needing genuine dynamic bank-switching mid-array-access — the *superRAM*/CE-1601M examples in Part 7a–7b) behaves identically is untested and not addressed by the manual.

**Correction on "4000–7FFF: fixed, no banking" — this does not mean flat, undifferentiated RAM.** The TRM figure this section is built on only resolves the LH5803's memory map down to 4000H/8000H-level bank boundaries — the same coarse granularity as the Z-80's own top-level figure in §2, not the fine S0–S7/V2/V3-level detail the PC-1500's own TRM chip-select tables give (`PC-1500-Address-Decoding.md` §2.2 and its two Chip-Select Table appendices). Absence of sub-decode *in this figure* is not evidence of absence *in the hardware*.

In fact it almost certainly isn't flat. Whatever Sharp adapted at the system-ROM level for PC-1600 integration (§ above), *user* PC-1500 programs still run at their original absolute addresses and expect the machine's low-level behavior to match — including code that writes the display buffer at `&7600–&774F` and touches the CPU stack/fixed variables from `&7800` up (`LH5801_Guide.md`'s memory map — the real PC-1500's S6/S7 region, `PC-1500-Address-Decoding.md` §2.2–2.3). The PC-1600's *native* Z-80-side display path is entirely different hardware — I/O-port-mapped HD61202 controllers (ports 50–5BH, `PC-1600-Memory-Bank-Switching.md` Part 9), not memory-mapped SC882G chips. Nothing about the PC-1600's own design puts real display hardware at address `&7600` in any CPU's memory map by coincidence — if a PC-1500 program writing to that literal address is going to produce anything on screen, *something* has to translate those writes into HD61202 I/O accesses. Two mechanisms are structurally possible and neither is confirmed by any source reviewed for this document:

1. A **hardware shim** in the gate array, watching LH5803 accesses to that address range and translating them to HD61202 I/O writes on the fly.
2. A **software shim** — that range is ordinary RAM from the LH5803's side, and separate PC-1600 firmware (running in compat mode alongside/around the literal PC-1500 ROM code, not part of it) periodically copies it out to the HD61202 controllers.

Either way, the practical conclusion is the same: **the top slice of the LH5803's 4000–7FFF block is not generic, free capacity** — it's functionally playing the same role a real PC-1500's S6 (display buffer) and S7 (CPU stack, fixed variables, machine-language area) do, reserved by the compatibility requirement itself, not by anything visible in the coarse TRM bank map. This is corrected in the capacity comparison, §7.

**Partially confirmed, directly, since first writing the above.** The PC-1600's own German user manual, Appendix H, states outright that `&7C00`–`&7FFF` — the PC-1500A's machine-language area specifically — is *not* available to the user on the PC-1600, reserved instead "für Systemzwecke" (for system purposes), and that this is exactly why Sharp does not consider the PC-1500A and PC-1600 compatible on this point (quoted in full in §5). That confirms the S7-equivalent portion of the speculation above by name and address range. It does **not** independently confirm anything about the S6-equivalent display-buffer region (`&7600`–`&774F`) specifically, or say anything about *how* writes there (if they're still memory-mapped at all) reach the PC-1600's actual I/O-port-mapped HD61202 display hardware — that half of the speculation remains open.

---

## 6. Comparison to the PC-1500 / PC-1500A

This is the part that isn't a re-statement of anything else in this project — a direct, address-by-address comparison between what the LH5803 sees inside a PC-1600 and what an LH5801 sees inside a real PC-1500/1500A.

| Region | Real PC-1500/1500A (LH5801) | PC-1600 in LH5803 mode | Same or different? |
|---|---|---|---|
| **0000–3FFF** (module window) | Y0, gated by pin 4 (YO) on the 40-pin connector; a module does its own internal sub-decode (`PC-1500-Address-Decoding.md` §3.2) | Whichever Slot 1/2 RAM bank Port 31H selected on the Z-80 side | **Same address, same size (16KB), same "raw module window" character** — remarkable given the PC-1600's underlying hardware (Z-80 bank-switched RAM behind two dedicated slot connectors) shares nothing physically with the PC-1500's (a single 40-pin connector with fixed 2KB/16KB strobes). The LH5803 view was deliberately built to present the *same address range* here regardless. |
| **4000–7FFF** (built-in + module RAM area, real PC-1500(A)) | S0–S7 sub-decode: built-in RAM (S0 on PC-1500; S0–S2 on PC-1500A), module-reachable strobes (S1–S4 or S3–S5), then display buffer (S6) and CPU stack/fixed vars/ML area (S7) fixed at the top (`PC-1500-Address-Decoding.md` §2.2–3.1) | **Fixed 16KB internal RAM, unconditionally** — no sub-decode visible in the TRM's coarse bank map, no module extension possible here — but almost certainly still carrying a display-buffer/CPU-stack/fixed-variable region at the top, functionally equivalent to the PC-1500's own S6/S7, by the compatibility requirement alone (see the note in §5) | **Structurally similar, but PC-1600 gives 16KB where the PC-1500(A) gives 4–16KB depending on model/module, and does so entirely without the S1–S4/S3–S5 pin-reassignment story.** A real PC-1500A can put *module* RAM in part of this range (S3–S5 via the connector); a PC-1600 in LH5803 mode cannot — this whole range is hard-wired to the PC-1600's own internal RAM regardless of what's in Slot 1/2, so its capacity is fixed rather than model/module-dependent. |
| **8000–BFFF** (peripheral ROM area) | Y2, PU/PV-banked between CE-150/CE-158 (`PU-PV-Signals.md` §4–5) | Same address range, same size (16KB), same two peripherals (CE-150/CE-158), same PVOUT/PV-style bank bit | **Same in every respect that matters** — this is the cleanest match in the whole comparison. `PU-PV-Signals.md` §3 already notes PVIN/PVOUT on the PC-1600's slot connectors are "LH-5803 PV signal input (direct from LH-5803 pin 60)" — i.e. the PC-1600's own gate array literally wires the LH5803's native PV output through to become the Z-80-side PVOUT bit. The PC-1500's PU/PV mechanism wasn't reimplemented for the PC-1600 — the same physical CPU flip-flop pin is reused, just relayed through an extra buffering stage (the gate array) instead of going straight to a connector pin. |
| **C000–FFFF** (system ROM) | Y3, PC-1500/1500A system ROM + I/O port (`PC-1500-Address-Decoding.md` §2.1) | Same address range, same size (16KB), fixed internal ROM, no banking | **Same address and size; different content** — necessarily so, since this ROM holds the LH5803-side portion of PC-1600 firmware (16KB per `PC-1600-Memory-Bank-Switching.md` Part 1's "80KB Z-80 BASIC + 16KB LH-5803" ROM split), not a literal copy of a PC-1500's system ROM. |

**The overall pattern:** the LH5803 memory map is a *purpose-built compatibility shim*, not a byproduct of shared hardware, and it reproduces the PC-1500's own address ranges and sizes far more faithfully than the coarse TRM bank map alone suggests. 0000–3FFF and C000–FFFF match address-for-address. 8000–BFFF matches address-for-address *and* reuses the literal PU/PV signal path for its bank selection (`PU-PV-Signals.md` §3). And 4000–7FFF, on closer inspection (§5's note), is not the odd one out it first appears — it almost certainly still carries the PC-1500's own S6 (display buffer) / S7 (CPU stack, fixed variables) structure at the same relative offset, fixed at the top of the block, for the same reason the other three quadrants are address-faithful: real PC-1500 ROM code touches those addresses literally and unconditionally. What genuinely *is* different in that quadrant is the *growth mechanism*: the PC-1500A's S0–S7 sub-decode and its module-facing pin reassignment (`PC-1500-Address-Decoding.md` §3, `Expansion-Connectors.md` §3) has no PC-1600 equivalent at all — the PC-1600 just gives the whole 16KB as fixed internal hardware, with no model-dependent tiering and no way for a module to extend it.

---

## 7. Summary Table: PC-1600 Views vs. Each Other and vs. PC-1500(A)

| Axis | Z-80 view (native) | LH5803 view (compat. mode) | Real PC-1500/1500A |
|---|---|---|---|
| Addressable space | 64KB × 8 banks (320KB total, mostly ROM/mixed) | 64KB, unbanked from its own view | 64KB |
| Module window | 8000–BFFF, Slot 1/2, bank-switched via Port 31H (+ Port 28H for >32KB) | 0000–3FFF, same window a PC-1500 module would see | 0000–3FFF (Y0) |
| Built-in RAM growth mechanism | N/A — internal RAM is a fixed 16KB bank, no S-block sub-decode | N/A — fixed 16KB, likely still internally reserving a display-buffer/CPU-stack slice at the top (§5), but no S-block sub-decode and no module-extensibility | S0 (PC-1500) → S0–S2 (PC-1500A), `PC-1500-Address-Decoding.md` §3 |
| Peripheral-ROM bank select | Port 31H b0 (PVOUT) | LH5803's own native PV pin, relayed | PU/PV CPU flip-flops, direct to connector |
| Reserve-area convention | `NEW "Sx:",expr` = size + C5H (197 bytes), per §3–4 | `NEW`/BASIC commands are Z-80-resident throughout (§5, confirmed by the German user manual) — presumably the same convention, since running MODE 1 programs uses the same BASIC housekeeping | `NEW 0` = `[RAM start]+C5`, `PC-1500-Address-Decoding.md` §5.4 |
| Compatibility mechanism | N/A (native) | `MODE1` = display/behavior compatibility, confirmed via German user manual §9.2/Appendix H — not a CPU handoff for BASIC itself; genuine LH5803 execution is explicit (`CALL`/`XCALL`, `PEEK`/`XPEEK`, `POKE`/`XPOKE`, port equivalents) | N/A |
| ML-area compatibility | N/A | `&7C00`–`&7FFF` (PC-1500A's ML area) explicitly reserved for PC-1600 system use, confirmed by the German manual — Sharp states the two models are *not* compatible here | `&7C01`–`&7FFF` is the PC-1500A's own ML area (`PC-1500-Address-Decoding.md` §4) |
| Largest documented module | *superRAM*, 512KB (Slot 2, Port 28H extended), `PC-1600-Memory-Bank-Switching.md` Part 7b | N/A — module capacity as seen from LH5803 is whatever Z-80-side bank is currently selected, 16KB at a time | CE-155-class, ≤28KB combined with built-in RAM (`Expansion-Connectors.md` §3.2) |
| Confirmed max user (`MEM`), 16KB module | 32KB raw span, `PC-1500-Address-Decoding.md` §5.3 (0000–8000H); `MEM` = 28218 confirmed on real hardware, computed by Z-80-resident BASIC regardless of MODE (§5's note) | **Identical to Z-80 view — trivially, since `MEM` is core BASIC housekeeping and never runs on the LH5803**; `MODE1` doesn't reroute it, per §5's revised model | 28KB raw span (Y0 16KB + S0–S5 12KB, deliberately excluding the PC-1500A's own S6/S7) — no confirmed real `MEM` figure for this exact hypothetical configuration |

---

## 8. `ERROR 110` — "Cannot set MODE 1", and why the module configuration is the trigger

`ERROR 110` is the code the PC-1600 shows when `MODE 1` (or `MODE1`) is refused. From the PC-1600 Operation Manual, Appendix F:

> **110** — Cannot set MODE 1 (PC-1500 mode). / Command invalid in MODE 0. Commands associated with PC-1500 peripherals will only work in MODE 1.

So one code covers two situations: (a) you asked for `MODE 1` and the hardware/module state won't allow it, and (b) you issued a CE-150/CE-158/CE-162E command while still in MODE 0. This section is about (a).

### 8.1 What the manuals state as the prerequisite

**TRM §5.15(1)** ("Running PC-1500/1500A BASIC programs"):

> To use the PC-1600 in MODE 1, the following conditions must be satisfied:
> 1. A RAM module of **more than 16 KB must not be installed in slot 1**, and **any RAM module must not be installed in slot 2**. However, if a RAM module is used as a RAM disk, CE-1600M can be installed in slot 1 and CE-1600M or CE-161 can be installed in slot 2. In this case, the formatting of a RAM disk (`INIT "Sn:","F"`) must be done in MODE 0.

**Operation Manual, Appendix H** ("Running a PC-1500 BASIC Program on the PC-1600"):

> Ensure that there is a module in slot 1 or slot 2 … the size should be **less than 16 K bytes: CE-151, CE-155, CE-159, CE-161**. If there is no module in either slot, an error code will be displayed.

Read together: MODE 1 wants a module present to give the PC-1500 program its work RAM, that module must be **≤ 16 KB**, it must **not** be a bank-switched PC-1600 module, and Slot 2 is officially off-limits unless the module is a pure RAM disk formatted in MODE 0.

### 8.2 Reconciling with real-hardware observation

Field results reported against real units:

| Slot 1 | Slot 2 | `MODE 1`? |
|---|---|---|
| — | — | `ERROR 110` (no work RAM available) |
| CE-151/155/159/161 (≤16 KB, flat) | — | OK |
| — | CE-155/161-class (≤16 KB, flat) | OK *(more lenient than the TRM's "nothing in slot 2")* |
| CE-1600M / CE-1601M (PC-1600, bank-switched) | — | `ERROR 110` |
| — | CE-1600M / CE-1601M (PC-1600, bank-switched) | `ERROR 110` |
| CE-155 (8 KB, flat) | CE-163-class (2 × 16 KB, latch-banked) | `ERROR 110` |
| CE-1600M *as RAM disk, formatted in MODE 0* | CE-1600M/CE-161 *as RAM disk, formatted in MODE 0* | OK (the TRM exception) |

The deviation from the TRM's literal wording (a plain ≤16 KB module *is* tolerated in Slot 2; a combination that includes a >16 KB or latch-banked module is *not*, in either slot) points to the firmware's actual gate being:

> **The RAM the LH5803 will see at 0000–3FFF must resolve to a single, flat, directly-addressable region of ≤ 16 KB with no bank switching of its own.**

Everything in the table follows from that one rule:

- **No module at all** → nothing backs 0000–3FFF as usable work RAM → refuse. (The internal RAM at LH5803 4000–7FFF is not enough on its own — a PC-1500 program expects its module window populated.)
- **CE-1600M (32 KB)** → needs the connector's PVOUT/A14-equivalent to pick between its two 16 KB halves; the MODE 1 setup fixes Port 31H once and cannot half-select mid-execution on behalf of PC-1500 code that doesn't know the window is banked → refuse.
- **CE-1601M (64 KB+)** → adds Port 28H vertical banking on top → refuse.
- **CE-163-class** → a 2 × 16 KB PC-1500 module that latches its bank from an address-line pulse (`PC-1500-Bank-Switching.md` §9); > 16 KB and self-banking → refuse. Whether it sits in Slot 1 or Slot 2 is irrelevant; the CE-155 next to it in the other slot is fine on its own but cannot rescue the configuration.
- **Plain ≤16 KB module (CE-151/155/159/161, or a flat modern 16 KB card), either slot** → exactly one flat bank at 8000–BFFF (Z-80) / 0000–3FFF (LH5803), no banking → the LH5803 map in §4b.6 holds → OK.

The user-facing shorthand "it's the total amount of memory" is a good first approximation — the effective ceiling is one PC-1500-style 16 KB `Y0` module — but the precise trigger is *bankedness*, not a byte count: a single 32 KB flat region would fail for the same reason two flat 16 KB regions do.

### 8.3 Why bankedness is fatal here (mechanism)

In MODE 1 the LH5803 runs genuine PC-1500 object code that (a) addresses its RAM module linearly across the full 0000–3FFF window and (b) expects BASIC's work pointers to sit in a PC-1500-shaped map (§6). The PC-1600 firmware supports this by programming Port 31H **once** so a single flat 16 KB block occupies 8000–BFFF (Z-80) and leaving it there for the duration — there is no code path that re-banks that window per-access for the benefit of PC-1500 code, because PC-1500 code has no convention for requesting it. A module that *needs* PVOUT half-select (CE-1600M), Port 28H vertical banks (CE-1601M), or an address-strobe latch (CE-163) therefore cannot back that window, and `MODE` returns `ERROR 110` rather than enter a mode it cannot honour.

The **RAM-disk exception** is consistent: a module used purely as a RAM disk contributes *nothing* to the directly-addressable 0000–3FFF window — its banking is performed per-access by the file-system driver, and the module window stays flat/free — so MODE 1 is still possible. Formatting must be done in MODE 0 because the `INIT "Sn:","F"` format path itself is native Z-80 code that isn't run from the MODE 1 environment.

See `PC-1600-CPU-LH5803-Compat.md` §5 for the MODE 1 command-porting rules that go with this.
