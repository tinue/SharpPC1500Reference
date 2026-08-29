# Sharp PC-1600 Memory Extension and Bank Switching -- Complete Analysis

**Sources:**
- `Service_Manual.pdf` -- hardware architecture, schematics, gate array, slot pinouts
- `SHARP-PC1600-Systemhandbuch.pdf` -- firmware, OS calls, module headers, software

---

## Part 1: System Architecture Overview

The PC-1600 is a dual-CPU pocket computer with a sophisticated bank-switched memory system that expands a 64KB directly-addressable Z-80 address space to 320KB.

### Main Chips (FPC PWB unit)

| Ref | Part | Function |
|-----|------|----------|
| IC1 | SC7852 | Main CPU 2 (Z-80 compatible, CMOS, 3.58MHz) |
| IC2 | LH5803 | Main CPU 1 (8-bit, CMOS, 2.6MHz / 1.3MHz internal) |
| IC3 | LU57813P | Sub CPU (4-bit, CMOS, 307.2KHz) -- power mgmt, RTC |
| IC4 | LR38041 | Gate Array -- central memory management and bus routing |

### Memory PWB Chips

| Ref | Part | Function |
|-----|------|----------|
| IC1 | 64K SRAM | Internal RAM 1 (8KB) |
| IC2 | 64K SRAM | Internal RAM 2 (8KB) |
| IC3 | 27C256FA51 | System ROM 1 (32KB) |
| IC4 | 27C256FPA5 | System ROM 2 (32KB) |
| IC5 | 27C256FPA6 | System ROM 3 (32KB) |

- **Total internal ROM:** 96KB (80KB for Z-80 BASIC interpreter + 16KB for LH-5803)
- **Total internal RAM:** 16KB (two 8KB SRAMs), expandable to 80KB with modules

---

## Part 2: Memory Map and Bank Switching Mechanism

The Z-80 has 16 address lines = 64KB address space, divided into four 16KB pages. Bank switching expands this to 320KB across 8 banks (Bank 0--7).

### Port 31H (IOW MAP / IOR MAP) -- The Primary Bank Select Register

Writing to Z-80 I/O port 31H selects which bank appears in each page:

| Bit | Name | Function |
|-----|------|----------|
| b0 | PVOUT | Bank select for 0000-3FFF **only** (1 bit, independent of b7 below) |
| b1 | PU | Bank select for 4000-7FFF, together with b2-b3 (3-bit field, independent of PVOUT) |
| b2 | PT | Bank select for 4000-7FFF, together with b1/b3 |
| b3 | b3 | Bank select for 4000-7FFF, together with b1-b2 |
| b4 | b4 | Bank select for 8000-BFFF, together with b5-b6 (3-bit field, independent of PVOUT) |
| b5 | b5 | Bank select for 8000-BFFF, together with b4/b6 |
| b6 | b6 | Bank select for 8000-BFFF, together with b4-b5. **Separately**, also controls LHS1/LHS2/LHS3 memory select remapping (Part 4) |
| b7 | b7 | Bank select for C000-FFFF **only** (1 bit, independent of b0 above) |

**Correction (2026):** an earlier revision described b0/PVOUT as governing *both* 0000-3FFF and C000-FFFF together, and had PVOUT as a fourth input to the 4000-7FFF and 8000-BFFF bank number — both self-contradictory with the separate "b7 selects C000-FFFF" line. The **PC-1600 Technical Reference Manual's own §7.2.1 table** ("SC-7852 memory-access spaces and contents of I/O port 31H") settles it: each page uses one exact, non-overlapping bit field — **b0** alone for 0000-3FFF (bank 0/1), **b3:b2:b1** for 4000-7FFF (bank 0-7), **b6:b5:b4** for 8000-BFFF (bank 0-7), **b7** alone for C000-FFFF (bank 0/1); no bit is shared between pages. (The TRM table carries the same "C"-for-"4" typo in the bank-4 row that the truth tables below note.) The corrected model above and the two truth tables reflect this; an independent emulator implementation agrees (`README.md` — *Sources & validation*). Treat the four-independent-fields model as settled.

**Example** (from Systemhandbuch):

```asm
3E 2E    LD A,2EH       ; = 0010 1110 binary
D3 31    OUT (31H),A    ; b4-b6=010: 8000-BFFF -> Bank 2
                        ; b1-b3=111: 4000-7FFF -> Bank 7
```

### Bank Selection Truth Tables

**Address range 0000-3FFF (Page 0):**

| b0 | Selected Bank |
|----|---------------|
| 0 | Bank 0 (PVOUT=0) |
| 1 | Bank 1 (PVOUT=1) |

**Address range 4000-7FFF (Page 1) — corrected, see note above:**

| Bank | b3 | b2 (PT) | b1 (PU) |
|------|----|---------|---------|
| 0 | 0 | 0 | 0 |
| 1 | 0 | 0 | 1 |
| 2 | 0 | 1 | 0 |
| 3 | 0 | 1 | 1 |
| 4 | 1 | 0 | 0 |
| 5 | 1 | 0 | 1 |
| 6 | 1 | 1 | 0 |
| 7 | 1 | 1 | 1 |

Plain 3-bit binary value of b3:b2:b1, PVOUT/b0 not involved. (The original table's "C" row is corrected to "4" here — it was a straight binary-count table miscopied with a stray hex digit.)

**Address range 8000-BFFF (Page 2) — corrected, see note above:**

| Bank | b6 | b5 | b4 |
|------|----|----|----|
| 0 | 0 | 0 | 0 |
| 1 | 0 | 0 | 1 |
| 2 | 0 | 1 | 0 |
| 3 | 0 | 1 | 1 |
| 4 | 1 | 0 | 0 |
| 5 | 1 | 0 | 1 |
| 6 | 1 | 1 | 0 |
| 7 | 1 | 1 | 1 |

Plain 3-bit binary value of b6:b5:b4, PVOUT/b0 and PT/PU (which are b1/b2, page-1's own bits) not involved — the original table's PT/PU columns here were almost certainly a copy-paste leftover from the page-1 table, not a real page-2 input.

**Address range C000-FFFF (Page 3):**

| b7 | Selected Bank |
|----|---------------|
| 0 | Bank 0 |
| 1 | Bank 1 |

### Memory Map by Bank

| Address Range | Bank 0 | Bank 1 | Bank 2 | Bank 3 |
|---------------|--------|--------|--------|--------|
| 0000-3FFF | System ROM (CS001) **NEVER SWITCHED OUT** | (Slot 2) | -- | -- |
| 4000-7FFF | System ROM (BASIC, Editor) | Slot 2 ROM | Slot 1 ROM | System ROM (CS24, sub-banked 2x8K) |
| 8000-BFFF | Slot 1a (RAM2) | Slot 1b (RAM2) | Slot 2a (RAM1) | Slot 2b (RAM1) |
| C000-FFFF | Internal 16KB RAM (RAM3) | **`b7`=1: not confirmed.** An earlier revision left this cell as "(Bank 1)", an acknowledged unknown; an independent emulator implementation routes `b7`=1 to the external 60-pin system-bus connector rather than any local RAM (so what is there depends on what is attached). Not cross-checked against the service manual. | -- | -- |

Additional banks in 4000-7FFF:

| Bank | Contents |
|------|----------|
| 3b | Hidden BASIC ROM (selected via Port 3DH, bit b2) |
| 4 | CE-1600P Plotter/Centronics ROM |
| 5 | CE-1600P Floppy (5000-5FFF) / Cassette (6000-7FFF) |

Additional banks in 8000-BFFF:

| Bank | Contents |
|------|----------|
| 6 | Display routines, timer/serial control, char/token tables (CS123) |
| 7 | Unused, but addressable (confirmed by TRM §2.1's own prose; see `PC-1600-Memory-Architecture.md` §2) |

### Auxiliary Bank Control Ports

**Port 3DH (IOW C/D):**
- Bit b2 normally set. Clearing b2 selects hidden BASIC ROM on Bank 3 -> Bank 3b at 4000-7FFF
- Cannot be read via IN instruction; readable from system address F07DH
- Bits D0-D2 written here are latched by the gate array into outputs A14A-A16A, providing extra address lines for sub-banking the CS24 ROM space (Bank 3, 4000-7FFF) into two 8KB halves

**Port 28H (Slot 2 sub-banking) -- "vertical bank" select:**
- Write-only, `OUT (28H),A` in Z-80 assembler. Confirmed by two independent sources now: the CE-1601M Service Manual's memory-map figure (*"The vertical bank of S2 is selected when data of 0 to 7 are written in 28H of the I/O space"* -- an OCR-garbled scan renders this "0 to 9", but is settled by the second source), and the *superRAM* modern-module manual (§8, "Memory Map"), which states outright: *"in 256KB Mode it takes values between 0 and 7 (8 vertical banks 32KB each result in 256KB). So in 512KB Mode it takes values between 0 and 15."* Confirmed: **0-7**, 8 vertical banks.
- This is a **second, independent bank-select axis for Slot 2's 8000-BFFF window**, orthogonal to Port 31H's b4-b6 field (Part 2 above). Port 31H's field selects among the *global* 8 banks for the whole 8000-BFFF page, of which only Bank 2 and Bank 3 physically route to Slot 2 (RAM1) at all -- call this the "horizontal" axis (2 usable positions for Slot 2, 16KB each = 32KB reachable per module without touching Port 28H). Port 28H then multiplexes *within* whatever module sits in Slot 2, selecting one of up to 8 "vertical banks" -- each vertical bank being a distinct 32KB unit occupying that same Bank-2/Bank-3 footprint. Confirmed against the CE-1601M's own chip layout (a 64KB module built from two 32Kx8 SRAM chips occupies exactly *two* vertical banks, 0 and 1) and, independently, against the *superRAM*'s own memory map (Part 7b): 8 vertical banks x 32KB = **256KB, the officially-supported ceiling for Slot 2**. An independent emulator implementation lands on the same 8-bank / 32KB / 256KB figure (`README.md` — *Sources & validation*).
- **Only vertical bank 0 is usable as directly-addressable program or expansion memory** (i.e. through ordinary `BANKSET`/Port 31H access); vertical banks 1-7 are reachable only through the file system (RAM-disk), because the OS's program/expansion-memory bank management drives Port 31H alone and has no notion of also holding Port 28H at a particular value -- only the file-system driver issues explicit `OUT 28H` writes per access. Stated directly by both the CE-1601M manual and the *superRAM* manual (§8: *"only vertical bank 0 can be configured as main memory expansion (S0)"*). This is also why Mode A-D of the CE-1601M (Part 7a) always reserves at least 32KB -- vertical bank 0 -- for program/expansion use, with any additional 32KB blocks (vertical banks 1+) usable only as a RAM file.
- **The 512KB figure is now directly confirmed, not just plausible**, by a real product: the *superRAM* module (Part 7b) uses vertical-bank values 8-15 for its 512KB mode, on the exact same Port 28H mechanism -- the PC-1600's own firmware `INIT` command simply never generates or validates values above 7, since Sharp never shipped a module needing them; a small patch routine (loaded and `CALL`ed, not a ROM modification) is sufficient to retarget the file-system header/capacity fields to the wider range. Nothing about Port 28H itself, or the Z-80 I/O space, imposes an 8-bank ceiling -- that was purely a consequence of Sharp's own modules never using more than a 3-bit vertical-bank field.

**Counter-example: the CE-163 does not actually speak this protocol, and firmware has no way to manage it as if it did.** Full mechanism in `PC-1500-Bank-Switching.md` §9-10; summarized here because it's the clearest illustration of what "vertical bank switching" requires a module to actually implement, versus what merely *works* in Slot 2 by coincidence.

The CE-163 is a PC-1500-era 2x16K RAM module -- a single flip-flop latch that reacts to a select-strobe pulse on connector pin 18, sampling **A0** at that moment as the bank bit. It predates Port 28H entirely and was designed for the PC-1500's S3/S5 memory-mapped strobe, not for any I/O-port protocol. It happens to be usable in PC-1600 Slot 2 only because of an unrelated quirk: a Z-80 `OUT (n),A` places the port number itself on address lines A0-A7 during the I/O cycle, and the PC-1600 doesn't decode A0-A2 within the 28H-2FH range -- they pass straight to the connector. So `OUT &28,0` and `OUT &29,0` differ, from the CE-163's perspective, only in A0 -- indistinguishable from two ordinary memory writes. **The module never reads the data byte Port 28H actually carries the vertical-bank number in; it only reacts to which of two adjacent port addresses was used.**

This is why firmware can't detect or drive it the way it does a CE-1601M-class module:

- **No module header to key off.** Boot-time detection (`SLOTST`, the F0AE/F0AF bitmaps, the 8-byte 43H/16H ID header, Part 6 above) is Sharp's own module-identification convention. The CE-163 carries none of it -- to a boot-time probe it looks like plain unbanked SRAM at whatever bank happens to be selected, not a self-describing bank-switched device.
- **A real vertical-bank probe would never even trigger it.** Enumerating banks the documented way means `OUT (28H), n` for n = 0..7 -- port address fixed at an even value (&28), only the *data* byte changes. The CE-163 ignores the data byte outright and only cares about A0, which stays 0 throughout that whole loop. Its second bank is reachable only via the accident of the *odd port number* &29 -- not a vertical-bank value in any sense the firmware's own protocol defines.
- **Wrong granularity even if detected.** The real protocol assumes up to 8 uniform 32KB banks, addressed by an 8-bit value; the CE-163 has exactly 2 banks of 16KB, selected on a completely different axis (an address bit, not a data value). There's no mapping from "vertical bank N" to "CE-163 state" that the OS's RAM-disk bank-walking logic could use even if it tried.

So this isn't firmware declining to exploit a capability that's present -- the CE-163 was never built to implement Sharp's vertical-bank protocol, and the property letting it work at all in Slot 2 is a side effect of Z-80 I/O-address encoding that has nothing to do with Port 28H's actual, documented semantics. Auto-detection and OS-managed banking are only possible for devices that declare themselves the way Sharp's own module family (CE-1600M, CE-1601M, and modern work-alikes like *superRAM*) does.

### Why Slot 1 and Slot 2 contribute so differently to BASIC main memory (`MEM`)

A frequent point of confusion, worth stating explicitly: **a large Slot 2 module (128KB, 256KB, 512KB -- any size) can never contribute more than 32KB to `MEM`, while a Slot 1 module of the same physical size contributes its full capacity automatically.** This isn't a quirk of any specific module -- it follows directly from the bank table above.

- **Slot 1's RAM sits at Bank 0's 8000-BFFF quadrant (Slot 1a)** -- the *same* global Bank 0 that houses the fixed internal RAM at C000-FFFF. Bank 0 is the default/reset-state bank for both pages, and `BFFF`+1 = `C000`, so a Slot 1 module and internal RAM are automatically one contiguous span with **zero configuration** -- no `INIT`, no bank-switching. This matches the CE-1600M's own documented Slot 1 figure exactly: *"When in Slot 1: Bank 0 and Bank 1 accessible. User area: up to 44,612 bytes"* -- no `INIT` step mentioned, because none is needed. Its ceiling here is Slot 1's own native two-bank capacity (Bank 0 + Bank 1 at 8000-BFFF, 32KB) -- there's no "Slot 1c/1d" in the architecture, so 32KB is the natural cap regardless of what a larger Slot 1 module might otherwise support.
- **Slot 2's RAM sits at Bank 2/Bank 3 -- a different global bank, never selected by default.** None of it is BASIC-addressable until software explicitly repoints page 2's bank register there via `INIT "S2:","M"` or `"P"` (the `S0:` expansion mechanism, Part 5 of `PC-1600-Memory-Architecture.md`). Left un-`INIT`'d this way, a Slot 2 module is only ever a RAM disk. And even once configured, the ceiling is exactly **one vertical bank (32KB)** -- per the rule already established above (*"only vertical bank 0 can be configured as main memory expansion (S0)"*), independent of the module's actual physical capacity. The rest is reachable only through the file system, one vertical bank at a time via `OUT 28H`, never as live program/array memory -- the OS's ordinary bank management drives page 2's register alone and never holds Port 28H at a particular value outside a transient file access (Part 2 above).

**Worked confirmation:** a real test -- a 128KB Slot 2 module (RAM-disk only, as expected) plus a CE-155 (8KB) in Slot 1 -- reported `MEM` = 52794 after `NEW`, matching the Sharp-documented CE-1600M+CE-159 combo figure exactly. The model predicts this precisely: raw total 16384 (internal) + 8192 (Slot 1) + 32768 (Slot 2, one vertical bank) = 57344, minus the fixed 4550-byte overhead confirmed in `PC-1600-Memory-Architecture.md` §3 (header + reserve + work area + a ~257-byte fixed system-variable table not itemized in the TRM's simplified diagram) = **52794**, exact. The two additions are independent and simply stack; Slot 1 isn't "unlocking" more of Slot 2 -- it's contributing its own, architecturally uncapped share through a completely different, automatic path.

### The theoretical maximum: ~77KB, not 64KB

Since both slots' contributions are independently capped (Slot 1 at 32KB -- Bank 0 + Bank 1 are the only two global banks ever assigned there; Slot 2 at 32KB -- one vertical bank, regardless of physical module size) and add on top of the fixed 16KB internal RAM, the ceiling is:

```
16384 (internal) + 32768 (Slot 1, capped) + 32768 (Slot 2, capped at one vertical bank)
= 81920 raw bytes - 4550 fixed overhead (confirmed exactly across three configurations, PC-1600-Memory-Architecture.md §3)
= 77370 bytes theoretical
```

This exceeds the Z-80's own 64KB address space because `MEM` counts total storage reachable via the OS's transparent bank-switching (already evidenced by the Slot-1 32KB and Slot-2 `S0:` 32KB examples above individually, and by the 16KB+16KB and 8KB+32KB real-hardware tests both landing exactly on the 4550-overhead model), not bytes simultaneously visible in the address space at one instant.

**Close to confirmed on real hardware, not just arithmetic:** the *superRAM* manual's own screenshots (Part 7b) show almost exactly this configuration -- a 32KB `S0:` expansion from Slot 2 plus a 32KB module in Slot 1 -- reporting **`MEM` = 77114**, about 256 bytes under the now-precise 77370 prediction. Unlike the two exact matches above, this gap isn't fully reconciled -- possibly a small additional reserve specific to the *superRAM* module's own firmware/header, distinct from a plain CE-1600M's. Either way, a module larger than 32KB in either slot adds nothing further to `MEM` -- the excess is permanently RAM-disk-only. The one piece of genuinely untapped headroom: Bank 7 is documented ("addressable but unused," confirmed independently by both the TRM and the PC-1600's German user manual) but nothing -- no Sharp module, no known modern one -- has ever been built to use it; if one existed, it could in principle add up to another 16KB (a single bank, not a full slot-pair) to this ceiling, but this is speculative, not an achieved figure.

---

## Part 3: Gate Array LR38041 -- The Memory Management Hub

The LR38041 gate array (IC4 on FPC PWB) handles all memory address decoding, bank switching signal generation, bus arbitration between the two CPUs, and chip select generation.

### Full pin table (TRM §7.8)

Complete 64-pin list from the PC-1600 Technical Reference Manual §7.8 "Gate Array
(LR38041) Pin Beschreibung" (read from the German Systemhandbuch scan). Overbar shown as
trailing `#`.

| Pin | Signal | Dir | Active | Function |
|---|---|---|---|---|
| 1 | SLCB | In | | `PI` signal from the sub-CPU (system-operation compatibility). Goes high when the system is off → (1) D2–D0 pulled low, (2) all outputs except A13A pulled to a fixed level. |
| 2 | Q3 | In | | Hardware low-battery detect. Low = battery OK. High (low battery) → S1/S2/S3/K0/K1/K2 forced high, KH pulled low, RD set high-Z. |
| 3 | Z12 | In | | High when on. |
| 4 | Z13 | In | Low | Poll of BREAK/ON status while the sub-CPU is in power-save; held high during power-save to keep KH low. |
| 5 | ON | In | Low | BREAK/ON key input (low = pressed). |
| 6 | KC1 | In | | Signal input for the analog-input connector. |
| 7 | CL2 | In | | Sub-CPU **1.229 MHz** clock input. |
| 8 | RD | Out | Low | Combined read strobe: wired-OR of ME0, ME1, OD, CKOS, BRQ with the Z-80 `RD#`. High-Z while the Z-80 runs. |
| 9–16 | R20–R33 | In | | Return data from the sub-CPU; becomes Z-80 data when the Z-80 reads I/O 33H. |
| 17 | PRIM | In | | RS-232C (high) vs. SIO (low) select. Drives SDA/SDF/RXD routing (see `PC-1600-Serial-Hardware-Notes.md`). |
| 18 | TXD | In | Low | Transmit data, from the TC8576F UART. |
| 19 | RXD | Out | Low | Receive data, into the RS-232C interface. |
| 20 | RDA | In | Low | RS-232C-side transmit routing; asserted low when PRIM low. |
| 21 | RDF | In | High | SIO-side receive input. |
| 22 | SDF | Out | High | SIO-side transmit output; asserted when PRIM high. |
| 24 | CKOS | In | | Part of the LH-5803 read-timing set (with ME0/ME1/OD/BRQ) that gates pin-8 RD. |
| 25 | VCC | — | | Power (system VGG input). |
| 26 | GND | — | | Power. |
| 27 | BRQ | In | | See pin 24. |
| 28–35 | D0–D7 | I/O / Out | | Z-80 data bus. When SLCB is asserted (system off) D2–D0 are pulled low to fix the input level. |
| 36 | C/D | In | High | Goes high when the Z-80 writes I/O 3DH. |
| 37 | IORP# | In | Low | Places R33–R20 on the Z-80 data bus; low when the Z-80 reads I/O 33H. |
| 38 | CL# | In | Low | **System reset.** Forces A13A high, A15A low, A14A high. |
| 39 | A13 | In | | CPU address A13. |
| 40 | A14 | In | | CPU address A14 (marked "insignificant"). |
| 41 | DSR | Out | | Not used. |
| 42 | CLK1 | Out | | Passes CL2 through as the TC8576F UART base clock while the system is on; low when off. |
| 43 | KH | Out | High | Inverted BREAK/ON key input, to the sub-CPU. |
| 44 | A13A | Out | | Inverted A13 — 8 KB half-select for the internal RAM chips. |
| 45–47 | A14A / A15A / A16A | Out | | C/D-latched D0/D1/D2. **A16A** also splits the CS24-selected 16 KB region (bank 3, 4000–7FFF) into two 8 KB banks. |
| 48–50 | LHS1–LHS3 | In | Low | Memory-select signals from the SC-7852, buffered to the slots. |
| 51–53 | KA0–KA2 | In | Low | I/O-select signals from the SC-7852, buffered to the slots. |
| 54–56 | S1–S3 | Out | Low | Buffered LHS1–3 to the expansion slots. All high when the system is off or on low battery. |
| 59–61 | K0–K2 | Out | Low | Buffered KA0–2 to the expansion slots. Same. |
| 62 / 63 / 64 | ME1 / ME0 / OD | In | | LH-5803 memory-enable / output-disable strobes; feed the pin-8 RD generation. |

Buffering LHS/KA → S/K through the gate array is required because the SC-7852 is
unpowered during system-off while the gate array (on VGG) keeps the slot select lines at
a safe inactive level.

### Key Gate Array Functions

1. **Bus Arbitration:** Manages shared bus between Z-80 (SC7852) and LH-5803. Signal ELH: High = Z-80 operating, Low = LH-5803 operating.

2. **Address Line Translation:**
   - A13A: Inverted A13, used as 8KB half-select for RAM chips
   - A14A-A16A: Latched from data bus via C/D register write
   - A16A separates CS24 16KB space into two 8KB banks

3. **Slot Signal Buffering:** LHS1-3 and KA0-K2 from SC7852 are buffered to S1-S3 and K0-K2 for expansion slots. Required because SC7852 power is off during system-off while gate array maintains levels.

4. **Reset Behavior:** When CL goes low, A16A forced high, A15A forced low, A14A forced high -- establishing known initial bank config.

---

## Part 4: Chip Select Signals -- Address Decoding

Generated internally by the SC7852 custom CPU, based on bank selection register and current address:

| Signal | SC7852 Pin | Active | Selects |
|--------|------------|--------|---------|
| CS001 | 43 | Low | ROM 0000-7FFF Bank 0 (main system ROM) |
| CS123 | 44 | Low | ROM 8000-BFFF Bank 6, LH-5803 ROM C000-FFFF |
| CS24 | 45 | Low | ROM 4000-7FFF Bank 3/4 (sub-banked by A16A) |
| RAM3 | 49 | High | Internal 16KB RAM C000-FFFF Bank 0 |
| RAM2 | 50 | Low | Slot 1 (S1) RAM 8000-BFFF Bank 0/1 |
| RAM1 | 51 | Low | Slot 2 (S2) RAM 8000-BFFF Bank 2/3 |
| LHS1 | 46 | Low | Sub-select within 8000-BFFF (remappable) |
| LHS2 | 47 | Low | Sub-select within 8000-BFFF (remappable) |
| LHS3 | 48 | Low | Sub-select within 8000-BFFF (remappable) |

**INH signal** (on slot connectors): inhibits the internal ROM (CS001/CS123), letting an external slot module override internal memory.

> **Correction / cross-check against TRM §7.2.2.** The PC-1600 Technical Reference
> Manual states the ROM selected by CS001/CS123 is made non-selectable **by driving INH
> *high***, and that "on the PC-1600 the INH terminal is tied to ground and fed to the
> ROM's OE signal" — i.e. INH *is* the ROM output-enable (active-low OE), grounded by
> default so the ROM is enabled; a module drives it high to disable the ROM. This is the
> **opposite polarity** from the "pull INH low to inhibit" convention on the PC-1500 and
> from `../Memory-Architecture/Expansion-Connectors.md` §4.3. Trust the TRM for the
> PC-1600; the connector-doc wording needs reconciling (flagged there).

**Other TRM §7.2.2 details** not previously captured:
- **RAM3** is **active-high** and drives the **CE2** (second chip-enable) input of *each*
  of the two internal 8 KB RAMs.
- **CS24** feeds the CS of a **256 Kbit** ROM; that ROM's **OE receives A15**, and the
  16 KB window is extended to **32 KB by the A16A signal** (bank 3 sub-banking).
- **RAM2#** (Slot 1) asserts on bank **0 or 1**, 8000H–BFFFH; **RAM1#** (Slot 2) asserts
  on bank **2 or 3**, 8000H–BFFFH.

**LHS1/LHS2/LHS3 remapping via bit b6 of I/O 31H:**

| Signal | b6=0 | b6=1 |
|--------|------|------|
| LHS1 | A800-AFFF (Bk 0) | B000-B7FF (Bk 0) |
| LHS2 | B000-B7FF (Bk 0) | A800-FAFF (Bk 0) |
| LHS3 | B800-BFFF (Bk 0) | A000-A7FF (Bk 0) |

---

## Part 5: Expansion Slot Connectors

Full CN-7 (Slot 1) and CN-8 (Slot 2) 40-pin tables, plus a by-function signal summary, have moved to `Expansion-Connectors.md` §4, alongside the PC-1500/1500A connector for direct comparison. Key pins referenced elsewhere in this document: RAM2 (Slot 1 pin 4) / RAM1 (Slot 2 pin 4) as chip select; PVOUT (pin 5), PU (pin 3), PT (pin 19) as the three raw bank-select bits from I/O port 31H; S1-S3 (Slot 1) / K0-K2 (Slot 2) on pins 16-18; INH (pin 15) to inhibit internal ROM.

---

## Part 6: Firmware -- Transparent Bank Switching

### How the OS Makes Bank Switching Transparent

The critical design principle: **Bank 0 (0000-3FFF) is NEVER switched out.** It contains all gateway routines. Any code in any bank can always call these routines to switch banks. The `BANKCALL` routine saves the current bank state and restores it on return, making cross-bank calls transparent.

### System Calls (all in Bank 0, always accessible)

| Address | Name | Description |
|---------|------|-------------|
| 0190H | **BANKSET** | Set bank. A=bank number, B=page number. |
| 0193H | **BANKREAD** | Read current bank of page in B. Returns in A. |
| 018DH | **MEMORYCHK** | Test if memory exists at bank. D=bank, E=high byte of address (40-B8). Returns: Carry+A=00 = no memory; NC+A=01 = RAM; NC+A=03 = ROM. |
| 019CH | **BANKJUMP** | Jump to different bank. A=bank, HL=address. WARNING: return address destroyed. |
| 019FH | **BANKCALL** | Call routine in different bank. A=bank, HL=address. Current bank saved and restored on return. |
| 0196H | **SLOT1MAP** | Remap Slot 1 addressing. A=00: Normal. A=01: Slot 1b -> 4000-7FFF of Bank I. |
| 0199H | **SLOT2MAP** | Remap Slot 2 addressing. A=00: Normal. A=01: Slot IIa -> 0000-3FFF of Bank 1. A=02: Slot IIb -> 0000-3FFF of Bank 1. |
| 00E8H | **SLOTST** | Test slot header at high byte in D. Returns: A=00 error; F0="P" (program); F2="S" (system); FF="M" (RAM-Disk). |

### RST Shortcuts (single-byte opcodes, fastest cross-bank calls)

**RST 18H + 2-byte immediate (nn): BANKJP (Bank Jump)**

Address encoding implicitly selects bank:

| Address Range | Target Bank |
|---------------|-------------|
| 0000-3FFF | Bank 0 |
| 4000-7FFF | Bank 3 |
| 8000-BFFF | Bank 6 |
| C000-FFFF | Bank 0, mapped to 4000-7FFF |

**RST 20H + 3-byte immediate (b, nn): BANKCAL (Bank Call)**

- b = Bank number
- nn = Target address
- Example: `E7 05 08 40` = `CALL Bank 5, address 4008H`

### ROM Module Detection and Headers

At reset, the system scans for modules. Bitmaps at F0AEH and F0AFH encode which ROM modules are present:
- **F0AEH:** Modules with start address 4000 (bit-encoded)
- **F0AFH:** Modules with start address 6000 (bit-encoded)
- Bit mapping: b6=Bank 1, b5=Bank 2, ... b0=Bank 7

Each module begins with an **8-byte header** at 8000H, A000H, or B000H:

| Offset | Field |
|--------|-------|
| +0 | ID Code: 43H |
| +1 | ID Code: 16H |
| +2 | Reset jump / checksum |
| +3 | Start address / boot indicator |
| +4 | Module length / boot address |
| +5 | BASIC address |
| +6 | End address |
| +7 | Type byte: 80H/FFH = "M" (RAM-Disk), F0H = "P" (Program), F2H = "S" (System), 01H = Write-protected |
| +8 | RESERVE area (RAM-Disk formatting info) |

### Module Jump Table (at address 4000H for Page 1 modules)

```
4000 : 43       ID-Code
4001 : 16       ID-Code
4002 : JP XXXX  Reset jump
4005 : JP XXXX  Interrupt jump
4008 : JP XXXX  Jump to important routines
400B : (not used)
400E : JP XXXX  Jump for AUTORUN.BAS search
4011 : XX XX    Pointer to Device Name (e.g., "COM1:")
4013 : XX XX    Pointer to Token Table (+0036)
4015 : JP XXXX  Jump for File processing
```

### Working Memory Allocation for ROM Modules

ROM modules can allocate working memory via `CALL 02DFH`. Parameters: DE = size in bytes, C = module number (Creg).

| Creg | Purpose |
|------|---------|
| 00 | Standard system memory |
| 01-07 | ROM Bank 1-7, Start 4000 (EXROM1-EXROM7) |
| 08-0E | ROM Bank 1-7, Start 6000 (EXROM8-EXROME) |
| 0F | COM buffer |
| 10 | File buffer (DE = n * 313 bytes) |

### Slot Management System Addresses

| Address Range | Purpose |
|---------------|---------|
| F015-F01EH | Slot S1 descriptor |
| F01F-F028H | Slot S2 descriptor |
| F029-F02CH | Slot S0 descriptor |
| F050-F053H | S1: EPROM or write-protected |
| F054-F055H | S1: RAM only |
| F056-F059H | S2: EPROM or write-protected |
| F05A-F05BH | S2: RAM only |
| F07DH | Mirror of Port 3D state |
| F0AE-F0AFH | ROM module bitmaps |
| F0DC-F0DDH | Boot bank and address |
| F123-F126H | Coded module config (for reset) |

### Boot Sequence

1. Reset cause determined (stored at F1ABH). Bits: b0=ALL RESET, b1=Internal RESET, b2=External RESET, b4=POWER ON, b5=External POWER ON, b6=WAKE$(0), b7=WAKE$(I)=CI
2. Peripheral reset and device identification via ROM-Bit scan
3. `CALL 4002` issued to all devices (A=07: device can deregister)
4. Memory module detection (changed config sets FA23H bit b7 = "NEW0?")
5. Power-on test (can program resume from `POWER AOFF`?)
6. Boot search priority:
   1. Peripheral device (Floppy) -- `CALL 4002, A=05`
   2. Found peripheral -- `CALL 4002, A=06`
   3. System software (EPROM)
   4. System software (RAM)
   5. Jump to bank (F0DCH), address (F0DDH)

---

## Part 7: CE-1600M Memory Extension Module

### Specifications

| Property | Value |
|----------|-------|
| Model | CE-1600M |
| Capacity | 32KB (4 x 8KB SRAM) |
| Battery | 3V DC lithium (CR2032 x 1), ~5 years in use, ~24 months removed |
| Write protect | Slide switch (dot side = protected) |
| Size | 40.9 x 42.8 x 8.5 mm, 15 grams |

### Internal Hardware

- 4 x 8KB SRAM chips (RAM1-RAM4, wire-bonded, not replaceable)
- 1 x TC74HC139F dual 2-to-4 decoder/demultiplexer
- 2 x 560K ohm pull-up resistors
- DAN202 diode array + 1SS98 diode (battery protection)
- CR2032 lithium battery
- DIP switch (configuration)

### Circuit Description

The TC74HC139F dual decoder selects one of four 8KB SRAMs based on address lines from the slot connector. Its enable/select inputs come from the slot's bank signals, and its active-low outputs each enable one SRAM chip.

### Memory Maps

**When in Slot 2:**
- 8000-BFFF: Bank 2 and Bank 3 accessible
- User area: up to 44,612 bytes

**When in Slot 1:**
- 8000-BFFF: Bank 0 and Bank 1 accessible
- User area: up to 44,612 bytes

**With CE-159 in S1 and CE-1600M in S2:**
- User area: up to 52,794 bytes (across Banks 0, 2, and 3)

---

## Part 7a: CE-1601M Memory Extension Module (64KB)

**Source:** Sharp Service Manual, CE-1601M (code 00ZCE1601MSME, 1987-02).

Where the CE-1600M (Part 7) is small enough (32KB) to be addressed with Port 31H's PVOUT/PU/PT bits alone and can go in either slot, the CE-1601M is the first module that actually needs Port 28H's vertical-bank mechanism, and Sharp restricts it to Slot 2 accordingly.

### Specifications

| Property | Value |
|---|---|
| Model | CE-1601M |
| Capacity | 64KB (2 x 32Kx8 SRAM) |
| Slot | **Slot 2 (S2) only** -- "If mounted in memory slot S1, the computer may not perform properly or data may not be written properly in the RAM module." |
| Battery | 3V DC lithium (CR2032 x1); ~5 years in-module, ~20 months removed |
| Write protect | Slide DIP switch, hardware-gated (see Circuit below) |
| Size / weight | 40.9 x 42.8 x 8.5mm, 15g -- identical footprint to the CE-1600M |

### Internal Hardware

- 2 x D43256G SRAM (32Kx8 = 32KB each), part suffix -12L or -15L (speed grade; -15L from '87 Feb. production) -- labeled RAM0 and RAM1 on the PWB
- 1 x TC74HC13xF logic IC (OCR of the scanned manual reads "TC74HC131F"; the pinout in the circuit diagram -- A/B/C address inputs, CK latch-enable, G1/G2A/G2B enables, Y1-Y6 outputs visible -- matches a **74HC137, a 3-line-to-8-line decoder/demultiplexer with an address latch**, not a plain 138. The latch is presumably what lets the module hold its last-selected vertical bank across the brief interval when the Z-80 address bus is doing something unrelated to port 28H.)
- DAN202K diode array + 1SS98 diode -- battery-vs-VCC switchover, so the module runs off system power when installed and off the CR2032 only when removed or the host is off
- DTA143XK transistor pair + 4.7K/10K resistor network -- write-protect gating, driven by the DIP slide switch (560K pull-up) and both RD/WR lines
- 1uF capacitor -- supply smoothing near the battery node

### Circuit Description

The TC74HC137-class decoder's A/B/C select inputs are driven from low address bits, its G-family enables from the slot's **K0/K2** I/O-select lines (pins 4/16/18 on CN-8, per `Expansion-Connectors.md` §4.2) -- i.e. from the Z-80 I/O-port decode for the 28-2FH range, not from the memory-mapped M REQ path. Its Y-outputs each active-low-enable one physical SRAM chip's CS. Because there are only 2 physical SRAM chips (RAM0, RAM1), only 2 of the decoder's 8 possible outputs are ever populated -- the CE-1601M occupies **vertical banks 0 and 1** of the 8 that Port 28H can select (Part 2 above), leaving banks 2-7 electrically unconnected on this specific module. The same decoder, populated with up to 8 physical 32KB chips instead of 2, would use all 8 outputs and reach the full 256KB Slot-2 ceiling described in Part 2 -- the CE-1601M's own decode logic already has that headroom; it's simply built with a fraction of the possible RAM behind it.

Address lines A0-A14 (15 bits, enough for a 32Kx8 chip) go directly to both SRAM chips' address pins; PVOUT is also wired to the RAM chips (visible on both DIP footprints in the schematic) as the bit that distinguishes the two 16KB halves (Z-80 Bank 2 vs. Bank 3) of whichever 32KB vertical bank is currently selected -- confirming the "one vertical bank = 32KB = Bank2+Bank3 together" model from Part 2.

### Usage Modes (via `INIT`)

The 64KB is split at the file-system level, not the hardware level -- hardware always presents all 64KB (2 vertical banks); `INIT` just partitions how the OS's driver treats each vertical bank:

| Mode | Layout | Command |
|---|---|---|
| A | Entire 64KB as RAM file | `TITLE ENTER`, `NEW 0 ENTER`, `INIT "S2:","F" ENTER` -> 61KB user (62,464B), 48 directory entries |
| B | 32KB program memory + 32KB RAM file | `INIT "S2:","P" ENTER` |
| C | 32KB expansion memory + 32KB RAM file | `INIT "S2:","M" ENTER` -> 29.5KB (30,208B) RAM file; expansion memory area grows by exactly 32,768 bytes |
| D | Program memory (n KB) + expansion memory ((32-n) KB) + 32KB RAM file | `INIT "S2:","P",n ENTER` -- n is an odd number of KB, 2 to 32 |

Since only vertical bank 0 can hold program/expansion memory (Part 2), Modes B-D always consume vertical bank 0 for that purpose and leave vertical bank 1 (or whatever's left of the split within it) as the RAM-file area -- the OS never needs to drive Port 28H to reach program/expansion memory, only to walk the file system across both banks.

Changing an already-initialized module's mode requires clearing it first (`KILL` every file, or `TITLE "S2:" ENTER NEW 0 ENTER` to clear program memory / `TITLE ENTER NEW ENTER` to clear expansion memory) -- the manual is explicit that the mode can't be changed with live data present.

### Write Protect and Battery Notes

- The slide switch, marked with a dot for the protected position, gates WR through the DTA143XK transistor network -- this is a hardware block on writes, not a software flag, matching the CE-1600M's mechanism.
- Resetting the PC-1600 while accessing a CE-1601M file can show `NEW0?`; CL clears it and both main memory and module contents survive.
- Swapping the CR2032 requires removing the module from the computer first if it's in active use as a RAM file or program file; expansion-memory contents do **not** survive a battery swap and must be saved elsewhere first (RAM-file/program-memory contents, held in the SRAM itself, do survive -- it's the expansion-memory *bookkeeping*, held in main-unit RAM, that's lost).

---

## Part 7b: superRAM (Modern 256KB / 2x256KB / 512KB Module)

**Source:** "SHARP PC-1600 'superRAM' Memory Expansion" user manual, Revision 2 (third-party/hobbyist kit).

This is a modern, from-scratch Slot-2 module, useful here because its manual documents the vertical-bank mechanism explicitly and in the module-designer's own words, rather than requiring inference from Sharp's chip layout as with the CE-1601M (Part 7a). It independently confirms the Part 2 model exactly, and directly demonstrates the 512KB path.

### Design

Where Sharp's own modules (CE-1600M, CE-1601M) use one small SRAM chip per vertical bank behind a 3-to-8 decoder, *superRAM* inverts the approach: a **single 4096Kbit (512Kx8) SRAM** (AS6C4008-55ZIN, 19 address lines) is used, and the vertical-bank number written to Port 28H is latched (via a 74HC173, a 4-bit D-type register) directly onto the chip's *high-order* address lines rather than used to pick among several small chips' chip-selects. A 74HC00 (quad NAND) provides glue logic. Functionally identical to Sharp's scheme from the Z-80/OS side -- same Port 28H semantics, same 32KB-per-vertical-bank granularity -- but a materially different circuit: one chip whose address space is sliced by the vertical-bank register, instead of N chips each fully decoded by it.

### Three modes, one board, a solder jumper

A 3-pad jumper field (Options 1/2/3 -- structurally the same idea as a solder-selectable connector pin, just on the module rather than the mainboard) selects which of the SRAM's address line A15 (and, implicitly, whether vertical-bank values 8-15 are reachable at all) is tied to:

| Mode | Option | Mechanism | Result |
|---|---|---|---|
| 256KB (default) | 1 (A15 -> GND) | A15 fixed low; only the SRAM's lower 256KB is ever reachable | Native -- `INIT`/`DSKF` work unmodified, exactly like a CE-1601M |
| 2x256KB | Switch between 1 and 2 (A15 -> GND or VGG) | A15 hardware-toggled between the SRAM's lower and upper 256KB halves | Two independent 256KB banks, native `INIT` in each, but not concurrently addressable -- an operator/hardware switch, not software |
| 512KB | 1 temporarily, then 3 (A15 -> decoder output Q4) | A15 driven by on-board logic from the vertical-bank register itself (i.e. becomes vertical-bank bit 3, extending the field from 3 to 4 bits) | Full flat 512KB, vertical banks 0-15 -- but only reachable once a patch (below) retargets the OS's capacity bookkeeping |

This confirms directly, from a working implementation, that the 3-bit vs. 4-bit vertical-bank field is purely a hardware choice at the module -- Sharp's own chips just never wired a 4th select bit anywhere.

### The 512KB software patch

Because the PC-1600's `INIT` command has no notion of a >256KB S2: disk, initializing 512KB mode natively fails outright. The manual's documented procedure:

1. Set the jumper to Option 1 (256KB) and `INIT "S2:"` normally (`"F"`, `"M"`, or `"P"` -- same as Part 7a's CE-1601M modes) -- `DSKF"S2:"` reads 251904 (pure RAM disk) or 220160 (with a 32KB S0: expansion carved out), identical figures to a real CE-1601M/256KB-mode module.
2. Load and `CALL &C0C5` a small patch binary (`SUPERRAM.BIN`) that detects the 256KB/224KB disk just initialized and rewrites its file-system header and capacity fields in place to 512KB/480KB -- described as "not a full replacement of the `INIT` command, but a patch routine only."
3. Switch the jumper to Option 3 (512KB) and power-cycle -- `DSKF"S2:"` now reads 514048 or 481280.

The manual is explicit that the patch **cannot verify the module actually has 512KB of physical SRAM behind it** -- it only recognizes and rewrites a 256KB/224KB disk's header. Skipping the jumper change (step 3) after patching corrupts the disk, since the OS would then address only the low 256KB of a disk whose header claims 512KB.

Three upload paths for the patch binary are documented (CE-133T/CE-140T RS-232 in native PC-1600 mode; CE-158 in PC-1500-compatibility mode via `MODE1`; CE-150 via cassette-audio `.WAV` playback through Audacity) -- useful context for how any custom machine-code utility gets onto a PC-1600 with no other transfer path, not specific to this module.

### Confirms, precisely

- Port 28H: `OUT (28H),A`, values 0-7 native (256KB), 0-15 with the patch (512KB) -- the exact figures this document's Part 2 derives independently from the CE-1601M.
- 32KB per vertical bank, exactly matching the CE-1601M's two-chip/two-bank layout.
- Only vertical bank 0 usable as S0: (main memory expansion); the rest is file-system-only.
- Sharp's *own* documented ceiling for a factory module is 64KB (CE-1601M) -- the manual states this directly: *"The largest original RAM module from SHARP is the CE-1601M with 64KB."* 256KB and 512KB are exclusively third-party/modern territory as far as this source is aware, though the CE-1601M's own memory-map diagram (Part 7a) does depict a second, larger, Japan-only module -- **CE-1650M** -- using the same vertical-bank scheme; no schematic-level source for it has turned up yet.

---

## Part 8: Dual-Processor Architecture (Z-80 + LH-5803)

The second processor (LH-5803) provides PC-1500 compatibility.

### LH-5803 Memory Map

| Address Range | Contents |
|---------------|----------|
| 0000-3FFF | Same as Z-80's 8000-BFFF (S1/S2 modules) |
| 4000-7FFF | RAM 16KB (same as Z-80's C000-FFFF) |
| 8000-BFFF | CE-150 (PVOUT=0) or CE-158 (PVOUT=1) |
| C000-FFFF | ROM 16KB (CS123) |

### Key Differences from Z-80

- Addresses stored in reversed byte order (hi-lo vs Z-80's lo-hi)
- Bit b15 is inverted
- Both CPUs share the same bus -- cannot operate simultaneously
- One is always in HALT while the other runs

### Calling LH-5803 from Z-80

Set parameters at:
- **F002H:** 20 = no params, 30 = pass registers (F005-F00BH)
- **F00C/H:** Start address (LH-5803 notation)
- **F00EH:** Bank (00=RPV, 01=SPV)

Execute: `CALL 01C6H` (CALLH)

### LH-5803 Memory Enable Signals

| Signal | Pin | Function |
|--------|-----|----------|
| ME0 | 29 | Accesses 64KB area for program counter P and stack S |
| ME1 | 30 | Accesses second 64KB area for CPU data commands |

**PV signal** (pin 60): Internal flip-flop output, sent directly to PVOUT of SC7852. When Z-80 operates, PV floats and is pulled down internally.

---

## Part 9: Complete I/O Port Map for Memory Management

### Memory-Related Ports

| Port | Dir | Function |
|------|-----|----------|
| **31H** | R/W | **PRIMARY BANK SELECT REGISTER** (IOW MAP / IOR MAP). b0: Page 0 bank (PVOUT), independent 1 bit. b1-b3: Page 1 bank (4000-7FFF), independent 3-bit field, 8 banks. b4-b6: Page 2 bank (8000-BFFF), independent 3-bit field, 8 banks. b6: also separately controls LHS1/2/3 remapping. b7: Page 3 bank (C000-FFFF), independent 1 bit -- **corrected, was previously described as sharing a bit with b0/Page 0; see Part 2's correction note.** |
| **3DH** | W | **HIDDEN ROM / EXTENDED ADDRESS** (IOW C/D). b2: normally set; clearing selects Bank 3b. D0-D2: latched to gate array A14A-A16A. |
| **28H** | W | **SLOT 2 VERTICAL-BANK SELECT.** Values 0-7 (CE-1601M manual, Part 7a; *superRAM* manual, Part 7b) select which 32KB "vertical bank" occupies Banks 2+3 (8000-BFFF) -- decoded on the module itself, not by the mainboard. 8 banks x 32KB = 256KB ceiling for Slot 2 with a standard 3-to-8 on-module decoder; see Part 2. |
| 30H | R/W | Module control (IOW MOD / IOR MOD) |
| 32H | R/W | Interrupt cause/priority |
| 35H | W | Interrupt mask register |
| **38H** | W | **CPU SWITCH TRIGGER.** `OUT (38H),A` (any value) then `HALT` hands control from the Z-80 to the LH-5803 (TRM §7.1.4 / §5.14; the LH-5803 returns control with `STA #A038H`). The software-visible counterpart to the `ELH`/`SLCB` gate-array bus-arbitration signals in Part 3. See `PC-1600-Machine-Overview.md` §3 and `PC-1600-CPU-LH5803-Compat.md` §3. |
| 39H | W | Interrupt vector low byte (Z-80 IM2 mode) |

### Z-80 I/O Space Overview

| Address Range | Assignment |
|---------------|------------|
| 00-0FH | Prohibited |
| 10-1FH | LH-5810 compatible port (in SC7852) |
| 20-27H | TC8576F UART |
| 28-2FH | S2 (Slot 2) I/O |
| 30-3FH | SC7852 internal control registers |
| 40-4FH | System reserve |
| 50-57H | HD61202 LCD driver (IC2) |
| 58-5BH | HD61202 LCD driver (IC3) |
| 60-6FH | S2 (Slot 2) I/O |
| 78-7FH | CE-1600F |
| 80-83H | CE-1600P |

---

## Part 10: Using a PC-1500 8x16K Module in the PC-1600

This section describes how to adapt a PC-1500 memory extension module (8 banks of 16KB = 128KB) for use in the PC-1600 with transparent bank switching.

### Challenge 1: Physical Connector

The PC-1500 uses a different expansion connector than the PC-1600's 40-pin slot connectors. An adapter board is needed.

**PC-1600 Slot 2 is preferred** because:
- Port 28H provides vertical-bank sub-selection for modules >32KB (up to 256KB, confirmed in Part 2/7a)
- RAM1 chip select is on pin 4
- K0/K1/K2 I/O select signals available on pins 16-18
- Full address bus (A0-A15), data bus (D0-D7), RD, WR available

### Challenge 2: Bank Select Signal Mapping

The PC-1600 natively supports 2 banks per slot (e.g., Bank 2 + Bank 3 for Slot 2). Your module has 8 banks of 16KB each = 128KB.

Standard bank signals on the slot connector:
- **PVOUT** (pin 5): 1 bit
- **PU** (pin 3): 1 bit
- **PT** (pin 19): 1 bit
- **RAM1** (pin 4): chip select for Slot 2

**Correction (confirmed against real CE-1601M hardware, Part 7a):** Port 28H's vertical-bank field selects among 32KB units, not 16KB ones -- PVOUT still does the within-vertical-bank 16KB half-select, exactly as it does for the un-sub-banked case. So this 128KB module doesn't need all 8 vertical banks; it needs exactly **4** (0-3), with PVOUT distinguishing each bank's two 16KB halves. The wiring below is adjusted accordingly -- 2 bank-select bits from Port 28H (not 3), plus PVOUT.

### Approach A: Direct Port 28H Sub-Banking (Recommended)

Port 28H is specifically designed for Slot 2 modules larger than 32KB. The module's bank select lines should be wired to the sub-bank signals provided through Port 28H.

**Implementation:**

1. Build an adapter board that maps the PC-1500 module's edge connector to the PC-1600 Slot 2 (CN-8) 40-pin connector.

2. Wire 2 of your module's 3 bank-select lines to a vertical-bank value (0-3) written to Port 28H; wire the third to PVOUT (pin 5) directly, since it's already the within-vertical-bank 16KB half-select. Port 28H itself is decoded on the module side from the K0/K1/K2 I/O-select lines (pins 16-18), per Part 7a.

3. Use RAM1 (pin 4) as the master chip enable, gated with the decoded bank select.

4. Wire address lines A0-A13 to select within each 16KB bank.

5. Connect RD (pin 38), WR (pin 39), and data bus D0-D7 (pins 7-14).

### Approach B: Firmware Driver with BANKCALL

If direct Port 28H wiring is insufficient, write a machine-language driver that:

1. Resides in Bank 0 (0000-3FFF) or is called via `BANKCALL` (019FH).

2. Manages the 8 banks -- 4 vertical banks x 2 PVOUT halves each -- by writing the vertical-bank number to Port 28H and setting PVOUT for the half:

```asm
LD A,<vertical_bank>  ; 0-3
OUT (28H),A            ; Select vertical bank in Slot 2
; then RPV/SPV or the module's own PVOUT-equivalent logic selects the 16KB half
```

3. Performs the actual data transfer while the correct bank is selected.

4. Provides a RAM-Disk interface by placing proper module headers at the start of each bank:
   - Offset +0: 43H (ID code)
   - Offset +1: 16H (ID code)
   - Offset +7: FFH ("M" = RAM-Disk module)

5. Hooks into the boot sequence so the OS detects the module.

### Software Integration for Transparent Access

To make the 128KB module work transparently with BASIC commands:

1. Format the module as RAM-Disk using the `INIT` command or by manually writing the correct headers.

2. The OS will detect the module at boot via `SLOTST` (00E8H) and the module header scan.

3. Once detected as type "M" (RAM-Disk), the OS handles all bank switching transparently when you use:

```basic
SAVE "S2:filename"
LOAD "S2:filename"
FILES "S2:"
KILL "S2:filename"
```

4. For the 8 sub-banks (4 Port-28H vertical banks x 2 PVOUT halves), you may need a custom driver that extends the standard 2-bank (32KB) Slot 2 handling to cover all 128KB. This driver would:
   - Hook the file system calls for S2:
   - Calculate which vertical bank and PVOUT half contains the target data
   - Write the vertical bank to Port 28H and set PVOUT for the half
   - Perform the access in the 8000-BFFF window
   - Restore the previous Port 28H/PVOUT state

### Key Considerations

- Bank 0 (0000-3FFF) must never be disturbed -- all gateway routines live here
- The module must respond correctly to `MEMORYCHK` (018DH) probes during boot -- each 16KB bank should return A=01 (RAM)
- Battery backup must be maintained for SRAM contents
- The write-protect signal should be wired through if the PC-1500 module supports it

**Total accessible RAM with this setup:**

| Component | Size |
|-----------|------|
| Internal (C000-FFFF) | 16KB |
| Slot 1 (if CE-1600M or CE-159) | up to 32KB |
| Slot 2 (your 8x16K module) | 128KB |
| **Total** | **up to 176KB** |

---

## Part 11: Signal Summary -- All Memory-Related Signals

### Bank Selection Signals (from SC7852, controlled by Port 31H)

| Signal | Pin | Function |
|--------|-----|----------|
| PT | 5 | Memory bank signal |
| PU | 6 | Memory bank signal |
| PVOUT | 7 | Bank 0/1 selector |

### Gate Array Generated Signals

| Signal | Pin | Function |
|--------|-----|----------|
| A13A | 44 | Inverted A13, selects 8KB RAM half |
| A14A | 45 | Latched D0 from C/D write |
| A15A | 46 | Latched D1 from C/D write |
| A16A | 47 | Latched D2 from C/D write, sub-banks CS24 |

### Bus Control Signals

| Signal | Chip | Function |
|--------|------|----------|
| ELH | SC7852 | CPU ownership (H=Z-80, L=LH-5803) |
| SLCT | SC7852 | Master memory/IO enable from sub CPU |
| LHWAIT | SC7852 | Wait signal to LH-5803 |
| MREQ | SC7852 | Memory request |
| IORQ | SC7852 | I/O request |
| INH | Slot | Inhibit internal ROM |
| DME0 | SC7852 | LH-5803 memory select |

---

## Part 12: Internal RAM/ROM Wiring (Memory PWB)

### Connector CN-12 (Memory PWB to main board, 36 pins)

| Pin | Signal | Pin | Signal | Pin | Signal |
|-----|--------|-----|--------|-----|--------|
| 1 | VGG | 13 | D6 | 25 | A1 |
| 2 | WR | 14 | D5 | 26 | A2 |
| 3 | RAM3 | 15 | D4 | 27 | A3 |
| 4 | A8 | 16 | D3 | 28 | A4 |
| 5 | A9 | 17 | INH | 29 | A5 |
| 6 | LHA90 | 18 | VCC | 30 | A6 |
| 7 | A11 | 19 | GND | 31 | A7 |
| 8 | A13A | 20 | CS001 | 32 | A12 |
| 9 | RD | 21 | D2 | 33 | CS123 |
| 10 | A10 | 22 | D1 | 34 | A14 |
| 11 | A13 | 23 | D0 | 35 | A15 |
| 12 | D7 | 24 | A0 | 36 | CS24 |

### RAM Wiring

**RAM1 (IC1):** A0-A12 to address bus, D0-D7 to data bus
- CS1 = A13A (inverted A13 from gate array)
- CS2 = LHA90, OE = RD, WR = WR

**RAM2 (IC2):** Identical except CS1 = A13 (direct, not inverted)
- RAM1 covers one 8KB half, RAM2 covers the other

Both have RAM3 on chip enable -> only active when C000-FFFF Bank 0 is selected.

### ROM Wiring

- **ROM1 (IC3):** CE = CS001 (Bank 0, 0000-7FFF), A15 = OE
- **ROM2 (IC4):** CE = CS001, same structure
- **ROM3 (IC5):** CE via resistor network, A15 = OE, A16A for extra banking
