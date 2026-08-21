# Bank Switching on the Sharp PC-1500 / PC-1500A

## 1. Overview

Memory expansion modules plug into the rear expansion slot and physically occupy the lowest 16KB of the PC-1500/1500A's address space (&0000–&3FFF). Bank switching allows multiple 16KB memory banks to be mapped into this same address window, multiplying a module's effective capacity beyond what the address bus alone could reach.

**Bank switching vs. additional address lines.** These are two different solutions to the same problem — accessing more memory than the address bus can directly reach:

- **Additional address lines** extend the CPU's address bus. If the PC-1500 had 3 extra lines (A14–A16), it could directly address 128KB in a flat, contiguous space; every byte would be permanently visible, at the cost of requiring every program to be aware of the larger space.
- **Bank switching** reuses the same &0000–&3FFF window for multiple physical memory banks. Only one bank is visible at a time; a hardware latch on the module determines which physical bank responds. Programs written for a 16KB space work unchanged, but context must be saved and restored on every switch.

The PC-1500 uses the second approach — but "the second approach" actually covers two mechanically different techniques, covered in §2. The rest of the document covers how a bank switch is actually triggered and used in software (§3–§7), firmware design recommendations (§8), and the CE-163's specific pin-18 mechanism, including its behavior in the PC-1600 (§9–§10).

For the underlying address-decoder architecture, physical RAM chips, and connector pinout referenced throughout (S0–S7 strobes, the PC-1500A pin rewiring, etc.), see `PC-1500-Address-Decoding.md`.

---

## 2. Two Kinds of Bank Switching: Line-Based vs. Latch-Based

Everything in this document falls into one of two mechanically distinct categories. They're often lumped together as "bank switching" because they solve the same problem (more than 16KB of module memory in a 16KB window), but the hardware mechanism — and what "which bank is selected" actually means electrically — is completely different between them.

### 2.1 Line-based: ME0/ME1 and PU/PV — the mechanism the Technical Reference Manual documents

Two signals, at two different levels, work this way:

- **ME0/ME1** are the LH5801's own memory-enable pins. The CPU asserts exactly one of them per bus cycle, decided purely by which addressing form the current instruction uses — `(addr)` drives ME0, `#(addr)` drives ME1 (see `LH5801_Guide.md`'s Addressing Mode Reference). This is resolved by the instruction decoder before any external address decoding happens at all; it isn't something software "switches" at runtime with a register write.
- **PU/PV** are two general-purpose flip-flop outputs built into the LH5801, set and reset by dedicated instructions (`SPU`/`RPU`/`SPV`/`RPV`) and wired straight out to expansion-connector pins 3 and 2. Within the ME0 address space, the TRM documents them as the bank-select mechanism for &8000–&BFFF specifically (see `PU-PV-Signals.md`).

The defining property of this category: PU and PV sit on their connector pins continuously, for as long as the CPU last left them set. There is no discrete "switch" event as far as a module is concerned — a module's chip-select logic simply ANDs the matching address range together with whatever PU/PV levels happen to be present *at the moment of the access*, exactly the way it ANDs in the address lines themselves. Nothing about this requires the module to remember anything; the state lives entirely on the connector, all the time, like two extra, slowly-changing address bits. This is why it isn't "bank switching" in the classical sense at all — from the module's point of view it's closer to widening the effective address bus by however many PU/PV/ME0-ME1 bits are involved, just implemented with dedicated CPU flip-flops instead of dedicated address-decoder pins.

### 2.2 Latch-based: the S3/S5 address-write mechanism

The mechanism used by the CE-163 (§9) and its modern recreations works completely differently. Writing to an address in &5800–&5FFF (PC-1500) or &6800–&6FFF (PC-1500A) pulses the S3/S5 strobe, and that pulse triggers a **latch inside the module itself** — for the CE-163, a single flip-flop that also samples A0 at the moment of the write (§9 covers the exact mechanism, and how modules with more banks extend it).

After that one write, the module remembers which bank is selected in its own internal state. The connector carries no ongoing signal that says which bank is active — unlike PU/PV, nothing about the bank selection is present on any external pin once the write cycle ends. Every subsequent access to &0000–&3FFF uses only the ordinary 14 address lines (A0–A13); the module supplies the extra high-order address bits (A14–A16, for a 128KB chip) itself, out of its own latch, with the CPU and the connector having no further part in tracking which bank is live.

This is bank switching in the familiar, classical sense: select once, then the module behaves as if the address space had simply changed underneath the CPU.

### 2.3 The latch-based mechanism isn't purely a third-party workaround

Even though it isn't part of the LH5801's own documented pin/instruction set the way ME0/ME1/PU/PV are, the latch-based mechanism carries real Sharp sanction:

- **The CE-163 is Sharp's own module**, not a third-party clone using a reverse-engineered trick — pin 18 + A0 is Sharp's own design (§9).
- **The PC-1600 has firmware-level support for address/port-triggered bank latching too** — Port 31H's primary bank register and Port 28H's Slot 2 sub-banking (`PC-1600-Memory-Bank-Switching.md` Part 2, Part 9) are both write-once, module/gate-array-latched mechanisms in the same family as S3/S5, and the CE-1601M module manual documents Port 28H's mechanism by name as a "vertical bank" switch (§9). Whether that pairs with a Sharp-documented "horizontal bank switching" term for the PU/PV-style line-based mechanism is plausible but not yet confirmed in the material gathered for this project — no instance of "horizontal" turned up in a search of this corpus, only the one "vertical bank" reference sourced from the CE-1601M manual excerpt in §9. If you have the Systemhandbuch passage that pairs the two terms, it's worth adding here to pin down which mechanism each name refers to.

**One case that doesn't sort cleanly into either bucket:** TRAMsoft's RAM module (§3) uses `SPU`/`RPU` as a *trigger*, not as a continuously-read line — on each transition it runs a ~1-second routine that physically copies 16KB of RAM from one bank to the other and updates system pointers, rather than switching which of two independently-wired chips responds. Its ROM variant, by contrast, needs no copy and behaves like a straightforward line-based PU-gated chip-select. So "TRAMsoft uses PU" describes two different underlying mechanisms depending on which variant is installed — a reminder that PU/PV being *involved* doesn't automatically make something line-based in the §2.1 sense.

---

## 3. How a Bank Switch Is Triggered in Software

### The raw hardware mechanism

Writing (POKEing) any value to an address in the bank-select range selects a bank. The address offset encodes the bank number; the value written is irrelevant.

| Action | PC-1500 | PC-1500A |
|--------|---------|----------|
| Select bank 0 | `POKE &5800, 0` | `POKE &6800, 0` |
| Select bank 1 | `POKE &5801, 0` | `POKE &6801, 0` |

(Modules with more than 2 banks extend this same pattern using additional address bits — see §9.)

**This bare POKE will corrupt BASIC programs.** The BASIC interpreter maintains several pointers in standard RAM that describe where the current program lives, where it ends, and where variables begin. When you switch banks, the memory contents at &0000–&3FFF change instantly, but those pointers still point into the old bank's layout.

### The safe firmware-assisted mechanism

Each properly initialized bank contains a small machine-code stub (~60–70 bytes, stored at &C5 near the start of the bank). This stub:

1. Saves the current bank's BASIC program pointers back into the bank's own memory.
2. Writes to the bank-select register to perform the physical switch.
3. Reads the new bank's saved BASIC pointers and writes them into the standard RAM locations where BASIC expects them.
4. Returns to BASIC, which now sees a consistent, valid program in the new bank.

### The TRAMsoft approach (older 2-bank module)

The TRAMsoft 32kB-RAM/ROM module uses the **PU control line** rather than the address-range method. It provides only 2 banks (BANK 0 and BANK 1). The RAM version of its banking software physically copies the entire 16KB of one bank to the other and updates system pointers — a process that takes approximately 1 second and cannot be interrupted. The ROM version is faster (no copy needed) but cannot be used during development.

Manual switch (after installing with `NEW &100`):
```
CALL 285
```

Programmatic jump to label in the other bank:
```
GB$ = "LABEL" : GOTO "GOBA"
```

Call subroutine in other bank:
```
GB$ = "SUBNAME" : GOSUB "GSBA"
```

---

## 4. Hardware Mechanics Inside the Module

When the CPU writes to an address in &5800–&5FFF (PC-1500) or &6800–&6FFF (PC-1500A), the on-board address decoder (TC40H138F) does exactly what it always does: it asserts the strobe for whichever 2KB block was addressed. There is no special-case "bank-select write" logic in the machine itself. The bank-number encoding in the low address bits (A0, or A0–A3 for multi-bank modules) is entirely a convention of the module's own latch — the PC-1500 has no concept of "bank number" at all.

The CE-163 (and its modern recreations) latch on S3/S5 as their bank-select trigger — *not* PU or PV. PU and PV are reserved for the &8000–&BFFF ROM-banking role (see `PU-PV-Signals.md`).

---

## 5. BASIC Pointers Affected by Bank Switching

The BASIC interpreter maintains several pointers in standard RAM (above &4800, not bank-switched). When a bank is switched, the firmware stub must save the old bank's values and restore the new bank's values for these pointers:

| Address | Description |
|---------|-------------|
| (start pointer) | Address of first BASIC line in bank |
| (end pointer) | Address one past last BASIC line |
| &7864 | Top of RAM / bottom of variable area |
| &7899 / &789A | Start of DIM and 2-character variables (STATUS 3) |

A firmware stub implementing the safe mechanism (§3) saves and restores the program start/end pointers on every bank switch. This keeps A–Z variables global (they live above &4800) but means DIM variables and 2-character variables are also global — they point into standard RAM above &4800 and are shared across all banks.

---

## 6. Segmented Variable RAM (Local Variables)

It is possible to make DIM variables and 2-character variables **local** to a bank — stored within the bank's 16KB window rather than in standard RAM — by manipulating the two pointers at &7864 and &7899/&789A before dimensioning them. This is what TRAMsoft called "local variables."

Procedure:
1. Save the current "global" values of &7864 and &7899/&789A.
2. Set &7864 to point to the top of the module (&4000) and &7899/&789A accordingly.
3. DIM the local variables (they are now allocated within the bank window).
4. Restore &7864 and &7899/&789A to the global values.

The loop variables and array indices used within a bank for local data must themselves be local, or they collide with the other bank's loop state.

---

## 7. Caveats and Pitfalls

**NEW command offset.** Each bank reserves space at its start for a firmware stub, sized to that module's own implementation. `NEW` must use a matching offset — e.g. TRAMsoft uses `NEW &100` (= NEW 256).

Bare `NEW 0` clears the firmware stub and corrupts the bank. Recovery: call that module's pointer-restore entry point with its bank-8 (or equivalent) argument, which restores BASIC pointers from the saved copy in bank memory.

**16KB program size limit.** If a program or its data crosses the &3FFF boundary, switching banks will destroy it. Programs that don't use bank switching can ignore this and use the full module as flat memory.

**Loading programs.** Use `MERGE`, not `CLOAD` — `CLOAD` overwrites the banking firmware at the start of the program area; `MERGE` appends after the firmware stubs.

**Reserve memory per bank.** Reserve key assignments are stored within each bank's memory area and must be set independently in each bank after switching.

**CE-158 RS-232 conflict.** The CE-158 uses the **PU control line** for its own bank-switching (mapping a ROM into the module slot), the same line the TRAMsoft module uses. Powering on with both connected causes an immediate bank switch, leaving stale system pointers and potentially destroying programs; the TRAMsoft manual warns the banking software must be called immediately on power-up in this configuration, and all CE-158-related code must exist at identical addresses in both banks. Recreations wired for the address-range latch method (§2.2) avoid this conflict entirely, since they don't touch PU at all.

---

## 8. Firmware Recommendations

Based on what existing implementations do and the problems they solve, a well-designed bank-switching firmware should:

1. Save and restore BASIC program pointers on every bank switch.
2. Save and restore DIM variable pointers (&7864, &7899/&789A) for per-bank local variable spaces.
3. Store the current bank number in a known, fixed location within each bank.
4. Intercept the OFF key to flush BASIC pointers before power-down.
5. Provide a copy command to duplicate a bank's contents to another bank.
6. Provide a format/install command that writes a working firmware stub to all banks from scratch.
7. Provide cross-bank subroutine calls (GOSUB into another bank, RETURN back), as TRAMsoft does.
8. Use a distinct entry point per function (switch, copy, format).
9. Reserve a small, documented, fixed-offset area in each bank for the firmware stub.

---

## 9. The CE-163: Pin-18-Based Bank Switching and PC-1600 Compatibility

### How it works

The CE-163 is a 2×16K RAM module. A module can use any number of address lines to indicate the bank — modern recreations use up to 4 (A0–A3, up to 16 banks), while the CE-163 uses only 1 (A0, 2 banks), via a simple latch triggered by the decoded-address strobe on **connector pin 18** plus **A0**. Which named strobe that physically is depends on the host — S3 on the PC-1500, S5 on the PC-1500A (see `PC-1500-Address-Decoding.md` §3) — but the module circuit doesn't care; it just reacts to pin 18 going low on a write, with A0 selecting the bank (0 = even address, 1 = odd address):

```
PC-1500:   POKE &5800, 0 → bank 0   POKE &5801, 0 → bank 1
PC-1500A:  POKE &6800, 0 → bank 0   POKE &6801, 0 → bank 1
```

The written value is irrelevant; only address parity matters. Pin 18 and A0 together constitute the entire bank-select circuit.

### PC-1600 slot compatibility

**"S3" is not a portable concept between the PC-1500 and PC-1600.** On the PC-1500, S3 is one specific decode strobe from the TC40H138F. The PC-1600 has entirely different memory-management hardware (a Z-80-based SC-7852 I/O controller and gate array, with its own OS-level bank switching — see `PC-1600-Memory-Bank-Switching.md`). Whatever the PC-1600 calls "S3" is not guaranteed to be the same electrical concept — it may just reuse a familiar letter.

Two sources disagree on which PC-1600 slot's pin 18 carries which signal, and this is unresolved: the PC-1600 TRM's own connector tables list pin 18 as K2 on slot 1 and S3 on slot 2; a forum write-up describes the opposite assignment. The forum account is internally consistent and matches observed CE-163 behavior (works in slot 2, not slot 1), so it's taken as reliable for the *behavioral* claims below even though the K2-vs-S3 naming-per-slot is left open pending a continuity check on real hardware.

**The forum's account** (paraphrased): for an unmodified CE-163, the bank switch is operated by S3 and A0. In PC-1600 slot 1, S3 maps to &A800–&AFFF — which sits *inside* the module's own 16K RAM range (&8000–&BFFF), so any code touching &A800–&AFFF triggers a spurious bank switch. Slot 2 uses a completely different mechanism for the equivalent signal (K2#, part of "vertical bank switch" for modules >32K), operated via `OUT` port access only, not mapped to any RAM address — so there's no conflict there. Compatibility rules: modules <16K → slot 1 only; 16K/32K → either slot; CE-163 → slot 2 only; >32K → slot 2 only.

This matches independent confirmation from the PC-1600 TRM (I/O map dedicates port 28H–2FH to "S2 (slot 2)") and the CE-1601M module manual ("the vertical bank of S2 is selected when data of 0 to 9 are written in 28H of the I/O space").

| Module type | Slot 1 | Slot 2 |
|-------------|--------|--------|
| < 16K | Yes | No |
| 16K or 32K flat | Yes | Yes |
| CE-163 (unmodified) | No — address conflict | Yes |
| > 32K | No | Yes |

### Why the CE-163 works in slot 2 "by accident" — the Z80 OUT-instruction quirk

The CE-1601M's official protocol (bank number as the **data byte** to port 28H) and the CE-163's protocol (sampling **A0 of the address** at a write strobe) look incompatible. Yet the unmodified CE-163 can be bank-switched in PC-1600 slot 2 with:

```
OUT &28, 0   → bank 0
OUT &29, 0   → bank 1
```

This works because, during a Z-80 `OUT (n),A` instruction, the CPU places the port number on address lines A0–A7. The PC-1600's I/O map treats 28H–2FH as one undifferentiated block, so A0–A2 pass through undecoded, appearing on the module connector exactly as they would during an ordinary memory write. The CE-163's hardware doesn't distinguish a memory-write cycle from an I/O-write cycle — it's a dumb latch reacting to its select-strobe pin plus A0. `OUT &28,0` and `OUT &29,0` differ only in A0 and both assert the slot-2 strobe, so the CE-163 sees an event indistinguishable from a PC-1500-style `POKE &5800,0`/`POKE &5801,0`.

### Modding the CE-163 into a 32K flat module

The CE-163 contains a 32K SRAM with its high address line (A14) controlled by the S3/A0 bank-select latch — the two 16K banks are the lower/upper halves of the same chip. The mod: cut the trace from the latch output to the SRAM's A14, and connect AD14 (connector pin 23) directly to it instead. The CPU's own address bus then naturally selects which half of the 32K chip to access, with no bank switching at all — the modded module must then be treated as a CE-1600M for all software purposes.

---

## 10. Module Comparison Summary

| Feature | CE-163 (orig.) | CE-163 (modded) | TRAMsoft 32kB |
|---------|---------------|-----------------|--------------|
| Banks | 2 | 1 (flat) | 2 |
| Bank size | 16KB | — | 16KB |
| Total capacity | 2×16KB | 32KB flat | 32KB |
| Switch mechanism | pin 18 + A0 (S3/S5) | None (A14 direct) | PU line (pin 3) |
| Switch speed | Fast | n/a | ~1 sec (RAM ver.) |
| PC-1500(A) compat. | Yes | Yes | Yes |
| PC-1600 slot 1 | No (conflict) | Yes | Yes |
| PC-1600 slot 2 | Yes (OUT&28/29) | Yes | Yes |
| Non-volatile storage | No | No | No |
| BASIC pointer save | Manual | n/a | Yes |
| DIM var. per bank | Manual | n/a | Yes (manual) |
| Cross-bank GOSUB | No | n/a | Yes |
| CE-158 conflict | No | No | Yes (PU conflict) |

A comparison table with the same rows, covering modern CE-163 recreations by name, lives in the sibling `pc1500` research project (`pc1500/CE-1638/CE1638-CE163F-BankSwitching-Reference.md`) — that project is **private and not published**, so this table isn't reachable outside the author's own workspace; this document only covers the Sharp-original/historical modules.
