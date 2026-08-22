# Hypothetical: A Software-Defined Memory Extension (SDME)

## 1. Concept

This document is speculative, not a description of anything Sharp shipped. It works out what a **microcontroller-based universal module** — plugged into the 40-pin expansion connector, with enough I/O pins to read every address/control line and drive a data bus, backed by 512KB of SRAM or Flash — would need to *do on the wire* to emulate any of the real memory modules ever built for the PC-1500, PC-1500A, or PC-1600, plus a few hypothetical "maxed out" variants.

**The recurring principle, established throughout this project's other documents, still applies: the connector never tells a module which host it's in.** A module only ever reacts to whichever strobes physically arrive on its fixed pins (`Expansion-Connectors.md` §3.1). An SDME is no different — it cannot self-detect "I am plugged into a PC-1500A, emulate mode X." Whoever configures the device (a DIP switch, a startup command over a debug UART, whatever) has to tell it which module *and* which host it's pretending to be, because the same physical pins carry different names on different hosts, and the emulation logic has to react to the correct one.

**Confidence levels vary per row.** Modules already researched in depth elsewhere in this project (CE-155, CE-163, CE-1600M, CE-1601M) are given with full citations to those documents. Others (CE-151, CE-157, CE-160) are reconstructed from the *pattern* those confirmed modules establish, cross-checked against what could be found online — flagged as inferred where no direct schematic was available. Treat inferred rows as a working hypothesis for prototyping, not as a spec to build hardware against without further verification.

---

## 2. Emulation Table: PC-1500 / PC-1500A Modules

All addresses below are PC-1500 native; see §4 for how the same physical pins are renamed on the PC-1500A (`Expansion-Connectors.md` §3.1), and substitute accordingly — the SDME's *logic* doesn't change, only which pin name maps to which signal.

| Module | Capacity | Enable condition | Bank select | Notes |
|---|---|---|---|---|
| **CE-151** | 4KB | Y0 (pin 4) AND AD11–AD13 = `111` (2KB, internal Y7 slot) **OR** S1 (pin 16, 2KB) | none (flat) | *Inferred by pattern from CE-155's confirmed design (§below), scaled down* — half of CE-155's window on each side. Built-in S0 (2KB, &4000–&47FF) fills the gap between the Y0 slot (&3800–&3FFF) and S1 (&4800–&4FFF), exactly like CE-155. Not independently confirmed against a schematic. |
| **CE-155** | 8KB | Y0 (pin 4) AND AD11–AD13 = `111` (2KB, &3800–&3FFF) **OR** S1+S2+S3 (pins 16/17/18, 6KB, &4800–&5FFF) | none (flat) | Fully confirmed — the worked example in `PC-1500-Address-Decoding.md` §3.2. Onboard 138-style decoder (AD11–AD13 select, Y0 enable) narrows YO's 16KB down to just &3800–&3FFF for the internal slot. |
| **CE-157** | 4KB RAM + Kana ROM | RAM: same as CE-151, S1+S2 (4KB) — *inferred*. ROM: likely Y2 (pin 19, &8000–&BFFF), PV-banked like CE-150/CE-158's own token tables (`PU-PV-Signals.md` §4–5) — **unconfirmed**, no schematic found. | RAM: none. ROM: PV, if the peripheral-ROM pattern applies. | Least-confirmed row in this table — a Japan-only module (Katakana + compressed Kanji character ROM + printer routines) with no schematic located online. Emulating the ROM half correctly would need the actual character-ROM dump, not just the address mechanism. |
| **CE-159** | 8KB, write-protectable | **Same as CE-155**, byte-for-byte: Y0 AND AD11–AD13=`111` (2KB) OR S1+S2+S3 (6KB) | none (flat) | Confirmed indirectly: the CE-159 Service Manual states the module gives *"10K bytes including the reserve area"* when installed — the exact same total span `PC-1500-Address-Decoding.md` §5.2 documents for a CE-155 (`&3800`–`&6000`, 10K, `MEM 10042`). Electrically identical to CE-155; adds only a write-protect DIP switch and CR2032 backup. An SDME emulating this needs a soft write-protect flag, not new address logic. |
| **CE-160** | 7.8KB, ROM/pseudo-ROM | Y0 AND AD11–AD13 ∈ upper positions (same territory class as CE-159, read-only) — **inferred, not confirmed**. | none | Described in period sources as storing "custom invisible BASIC programs" via write-protected battery-backed RAM used as ROM — same underlying mechanism as a write-protected CE-159/CE-161, just factory/dealer-programmed and marketed as read-only. The odd 7.8KB (not a clean 8K) suggests a few bytes are reserved for a header/id the SDME would need to reproduce exactly if it's meant to be indistinguishable from a real one. |
| **CE-161** | 16KB | Y0 (pin 4) alone — **all 8 of its own internal Y0–Y7 positions populated**, no external S-pins at all | none (flat) | Confirmed by address mapping (base `&0000`, full 16KB) and independently by `PC-1500-Address-Decoding.md` §5.3's "machine plus a 16k memory module" table (`0000`–`4800`, 18k total with built-in S0) — this is exactly what a plain, fully-populated Y0-only module produces. |
| **CE-163** | 32KB (2×16KB banks) | Y0 (pin 4) for the RAM itself (16KB window, either bank) | **Trigger-based, not address-mapped:** a single flip-flop latches on a write-strobe pulse on **pin 18** (S3 on PC-1500, S5 on PC-1500A) and samples **A0 of the write address** at that instant — even address = bank 0, odd = bank 1. The bank number is *not* the data byte written. | Fully confirmed — `PC-1500-Bank-Switching.md` §9. The SDME must watch pin 18 for a write pulse and latch A0, not interpret the data bus for this module. |
| **16-bank CE-163-alike** (hypothetical) | 256KB (16×16KB banks) | Same Y0 mechanism as CE-163 | Same trigger (pin 18 write pulse) but sampling **A0–A3** (4 bits) instead of just A0 — 16 banks instead of 2 | This is literally what `PC-1500-Bank-Switching.md` §9 already names as the modern-recreation extension of CE-163's design ("modern recreations use up to 4 (A0–A3, up to 16 banks)"). No new mechanism to invent — just widen the latch. |
| **PC-1500/1500A "maxed out," no vertical banking** (hypothetical) | PC-1500: 24KB module (+2KB built-in = 26KB total). PC-1500A: 22KB module (+6KB built-in = 28KB total) | Y0 (pin 4), full 16KB, own internal decoder — **AND**, on the same physical pins, PC-1500: S1+S2+S3+S4 (pins 16/17/18/5, 8KB). PC-1500A: NC+S3+S4+S5 (pins 16/17/18 only — pin 5 is NC on this model, so that portion is simply dead) | none (flat) | This is the maximal fixed-wiring module worked out earlier in this project's `Expansion-Connectors.md` §3.2 — the ceiling for *any* module using only address-range strobes (no vertical banking), and it's asymmetric by model purely because pin 5 (S4 on PC-1500) has nothing behind it on the PC-1500A. An SDME built to this spec doesn't need to know which host it's in — same wiring reaches 24KB or 22KB automatically depending on what arrives on pins 5/16/17/18. |

---

## 3. Emulation Table: PC-1600 Modules

*Slot naming below follows the module-hardware-confirmed convention established in `Expansion-Connectors.md` §4.2a (RAM1/K0–K2 on the physical bay branded "Slot 2"), not the TRM's own connector table, which that section documents as internally inconsistent with real module behavior.*

| Module | Capacity | Slot | Enable condition | Bank select | Notes |
|---|---|---|---|---|---|
| **CE-1600M** | 32KB | Slot 1 or Slot 2 | RAM2 (Slot 1, pin 4) or RAM1 (Slot 2, pin 4) | Ordinary Port 31H bank selection (`PU`/`PT`, pins 3/19) — no module-side extra logic needed beyond a plain 2-to-4 decoder (`TC74HC139F` in the real part, `PC-1600-Memory-Bank-Switching.md` Part 7) picking 1-of-4 8KB SRAM chips | Fits entirely within its slot's native two-bank capacity (Bank 0+1 or Bank 2+3) — no Port 28H involvement at all. This is the largest module size that never needs vertical banking. |
| **CE-1601M** | 64KB (2×32KB vertical banks) | **Slot 2 only** | RAM1 (pin 4) | **Port 28H** ("vertical bank" register, values 0–1 for this module, decoded on-module from K0–K2, pins 16/18) selects *which* 32KB physical chip is behind Bank 2/3; **PVOUT** (pin 5) then selects the 16KB half within whichever bank is currently selected | Fully confirmed — `PC-1600-Memory-Bank-Switching.md` Part 7a, including the real on-module decoder chip (a 3-to-8 decoder/latch) and why it's Slot-2-only (Slot 1 has no K0–K2 wiring to reach). |
| **CE-1620M** | 32KB (EPROM) | Slot 1 or Slot 2 | Same as CE-1600M — RAM-select pin + native PU/PT two-bank selection | none beyond CE-1600M's native mechanism | Read-only in normal operation (27-series EPROM, programmed externally via the CE-1601E adapter at VPP=21V) — otherwise electrically the same address/enable story as CE-1600M, since it's the same 32KB-fits-in-two-native-banks size class. An SDME emulating this just needs to reject writes (or accept them silently if you want a "reprogrammable CE-1620M" for testing). |
| **PC-1600 Slot 2 "maxed out"** (*superRAM*-alike) | 512KB (16×32KB vertical banks) | **Slot 2 only** | RAM1 (pin 4) | Same Port 28H mechanism as CE-1601M, but the on-module register is widened to **4 bits** (values 0–15) instead of 3 — a `74HC173`-class latch feeding extra high-order address lines directly onto a single large SRAM chip, rather than a decoder picking among several small chips; PVOUT still selects the 16KB half within whichever vertical bank is current | Fully confirmed as a real, documented product — `PC-1600-Memory-Bank-Switching.md` Part 7b (*superRAM*). Only vertical bank 0 is ever reachable as live BASIC/ML memory (`S0:` expansion); banks 1–15 are RAM-disk-only, by firmware design, regardless of what the module itself supports (see that document's "theoretical maximum" analysis). |

---

## 4. Reference: The Four 40-Pin Slot Layouts

Full detail, all 40 pins, in `Expansion-Connectors.md`. Condensed here to just the signals the emulation table above actually depends on.

### 4.1 PC-1500

| Pin | Signal | Pin | Signal | Pin | Signal |
|---|---|---|---|---|---|
| 2 | PV | 16 | S1 (&4800–&4FFF) | — | |
| 3 | PU | 17 | S2 (&5000–&57FF) | — | |
| 4 | YO (&0000–&3FFF enable) | 18 | S3 (&5800–&5FFF) | — | |
| 5 | S4 (&6000–&67FF) | 19 | Y2 (&8000–&BFFF enable) | — | |

### 4.2 PC-1500A (pin reassignment vs. PC-1500, `Expansion-Connectors.md` §3.1)

| Pin | PC-1500 | PC-1500A |
|---|---|---|
| 5 | S4 | NC |
| 16 | S1 | S3 (&5800–&5FFF) |
| 17 | S2 | S4 (&6000–&67FF) |
| 18 | S3 | S5 (&6800–&6FFF) |

Everything else (YO on pin 4, Y2 on pin 19, PU/PV on pins 3/2) is unchanged between models.

### 4.3 PC-1600 Slot 1 (module-hardware-confirmed assignment, `Expansion-Connectors.md` §4.2a)

| Pin | Signal | Pin | Signal | Pin | Signal |
|---|---|---|---|---|---|
| 3 | PU | 16 | S1 | — | |
| 4 | RAM2 | 17 | S2 | — | |
| 5 | PVOUT | 18 | S3 | — | |
| 19 | PT | — | | — | |

### 4.4 PC-1600 Slot 2 (module-hardware-confirmed assignment)

| Pin | Signal | Pin | Signal | Pin | Signal |
|---|---|---|---|---|---|
| 3 | PU | 16 | K0 | — | |
| 4 | RAM1 | 17 | K1 | — | |
| 5 | PVOUT | 18 | K2 | — | |
| 19 | PT | — | | — | |

---

## Sources

Web research used to fill in modules not already covered elsewhere in this project (CE-151, CE-157, CE-159, CE-160, CE-1620M):

- [Full text of "Sharp CE-159 Service manual - PC"](https://archive.org/stream/manualzilla-id-6018708/6018708_djvu.txt) — capacity and the "10K bytes including reserve area" figure used to infer CE-159 is electrically identical to CE-155.
- [Sharp PC-1500 CE-159 Service Manual | Manualzz](https://manualzz.com/doc/6333459/sharp-ce-159-service-manual---pc)
- [Sharp CE-161 Service manual - PC-1500A | Manualzz](https://manualzz.com/doc/1759896/sharp-ce-161-service-manual)
- [4-Extensions Archives - PC-1500.info](http://www.pc-1500.info/category/cat_family/cat_4extensions/)
- [Hardware Archives - Page 3 of 8 - PC-1500.info](http://www.pc-1500.info/category/hardware/page/3/) — CE-151/155/159/161/163 capacity summary, CE-160 "7.8KB pseudo-ROM" description, TE-1506 modern-module reference.
- [BASWORD - BASIC keyword manager for the Sharp PC-1500/A](http://www.pc1500.com/basword.html) — module base-address table (CE-161/163 at &0000, CE-159 at &2000 — the latter superseded here by the CE-159 service manual's own figure).
- [GitHub - Jeff-Birt/Sharp_CE-158: ROM disassembly of Sharp CE-158](https://github.com/Jeff-Birt/Sharp_CE-158)
- [Sharp PC-1600 - Wikipedia](https://en.wikipedia.org/wiki/Sharp_PC-1600)
- [Accessories Page 1 SHARP PC-1600/K](https://www.sharp-pc-1600.de/PDF/PC-1600_Accessories%201.pdf)
- [CE-1620M - beim SHARP PC-1600](http://www.sharp-pc-1600.de/PDF/CE1620M/CE-1620M.pdf) — capacity, VPP=21V, CE-1601E adapter.
- [SHARP CE-1620M CE-1601E Service Manual - elektrotanya.com](https://elektrotanya.com/sharp_ce-1620m_ce-1601e.pdf/download.html)
