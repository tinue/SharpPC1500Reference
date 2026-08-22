# PC-1500 / PC-1500A Address Decoding and Physical Memory Map

## 1. Overview

The Sharp PC-1500 and PC-1500A use a 16-bit address bus giving a 64KB address space. This document covers the machine's actual address-decoder hardware and physical RAM layout: the top-level 16KB blocks and their sub-decoding into 2KB strobes (§2), why the PC-1500A's expansion connector was rewired relative to the PC-1500, using the CE-155 module as a worked example (§3), the origin and exact boundary of the PC-1500A's separate machine-language area (§4), and RAM-sizing / `NEW`-offset calculations that follow directly from the chip population described in §2–§3 (§5).

For how multiple 16KB memory banks are switched into the &0000–&3FFF window in software (POKE triggers, the CE-163 and its modern recreations, firmware pointer save/restore), see `PC-1500-Bank-Switching.md`, which builds on the decoder facts established here.

---

## 2. Address Decoder Architecture and Physical RAM

### 2.1 Top-level 16KB blocks (Y0–Y3)

The **TC40H139F** decodes address lines AD14/AD15 into four 16KB blocks. This decoder is identical on both models:

| Block | Range | PC-1500 | PC-1500A |
|---|---|---|---|
| Y0 | 0000H–3FFFH | Module unit user memory area | Optional user memory (module slot) |
| Y1 | 4000H–7FFFH | Module unit user RAM area (further decoded below) | (further decoded below) |
| Y2 | 8000H–BFFFH | Module unit optional ROM area — CE-150/CE-153/CE-158 system program & I/O port | Same |
| Y3 | C000H–FFFFH | System program ROM + I/O port | PC-1500A system program, I/O port; CE-158 I/O port/UART also appears here |

System ROM part reads cleanly as **SC61328F** in a typed Sharp Service Manual excerpt (the most legible of several sources; other hand-drawn/scanned schematics elsewhere in this document read it as SC61329F or SC613128 — same chip). I/O port chip is documented as both **LH5810 and LH5811** across Sharp's own material, and this isn't a transcription conflict: an older PC-1500 Service Manual (predating the PC-1500A, consistent with the PC-1500's early A01/A03 ROM era) shows LH5810, while direct teardown of two separate units (a PC-1500 and a PC-1500A, both presumably later-production/A04-era) shows LH5811 in both. Both parts are genuine, from different production eras.

### 2.2 Sub-blocks of Y1 (S0–S7)

The **TC40H138F** further decodes AD11–AD13 within Y1 (4000H–7FFFH) into eight 2KB sub-blocks, S0–S7 (active only while Y1 is asserted). The address range each strobe covers is fixed and identical on both models — what differs between models is which of these ranges is populated with built-in RAM vs. left available for expansion modules:

| Signal | Range | PC-1500 usage | PC-1500A usage |
|---|---|---|---|
| S0 | 4000H–47FFH | Standard user memory (built-in) | Standard user memory (built-in) |
| S1 | 4800H–4FFFH | Optional user memory (module slot) | Standard user memory (built-in) |
| S2 | 5000H–57FFH | Optional user memory (module slot) | Standard user memory (built-in) |
| S3 | 5800H–5FFFH | Optional user memory — also the CE-163-style bank-select trigger | Optional user memory (module slot) |
| S4 | 6000H–67FFH | Optional user memory (module slot) | Optional user memory (module slot) |
| S5 | 6800H–6FFFH | Not used | Optional user memory — also the CE-163-style bank-select trigger |
| S6, 7000H–75FFH | — | Inhibited | Inhibited |
| S6/V2, 7600H–76FFH | — | Display-driver RAM (LCD chips 1 & 3) | Display-driver RAM (LCD chips 1 & 3) |
| S6/V3, 7700H–77FFH | — | Display-driver RAM (LCD chips 2 & 4) | Display-driver RAM (LCD chips 2 & 4) |
| S7 | 7800H–7FFFH | System memory (partially populated, see §2.3) | Standard user and system memory, including the machine-language area (&7C01–&7FFF, see §4) |

A second-stage TC40H139F, gated by S6, splits it into 2Y2 (V2, display chips 1 & 3) and 2Y3 (V3, display chips 2 & 4).

*Source: PC-1500 Technical Reference Manual §4-3 for the decoder ICs; the PC-1500A's usage-category labels (the "standard"/"optional"/"inhibited" column above) are transcribed directly from a photographed page of the PC-1500A TRM's own memory-map figure.*

### 2.3 Physical RAM chips

Confirmed by direct teardown of both a PC-1500 unit and a PC-1500A unit, and — for the PC-1500A — independently by a Sharp circuit block diagram that labels each RAM chip's chip-select input.

**PC-1500** (3.5KB total physical RAM):

| Chip | Capacity | CPU window | Role |
|---|---|---|---|
| HM6116 (×1) | 2048B | S0, &4000–&47FF | User RAM — 1850B free for BASIC after the reserve area |
| TC5514 (×2, 1K×4bit each) | 1024B | S7, &7800–&7FFF (see note below) | System memory + part of fixed variables |
| SC882G display chips (×4) | 512B | S6/V2+V3, &7600–&77FF | Rest of fixed variables + display buffer |

**S7 is chip-selected across its full 2KB, but only holds 1KB of distinct storage.** The TC5514 pair has 10 address lines (A0–A9); S7 is a 2KB block, needing 11 (A0–A10) to address every byte uniquely. The chip-select schematic shows the pair fed by a single, ungated wire straight off Y7 — no logic conditions the select on A10. Since the chips have no A10 pin at all, they simply can't distinguish it: they respond to *any* access anywhere in the 2KB S7 window, decoding only A0–A9. The practical result is that **&7800–&7BFF and &7C00–&7FFF are not independent — they're the same 1024 physical bytes, mirrored**, at a fixed offset of &400 (a write to any address *n* in &7C00–&7FFF lands on the same cell as address *n*−&400 in &7800–&7BFF). This is why the PC-1500's own TRM decode table marks the entire S7 block "inhibited" rather than exposing any of it as user-accessible memory (see the PC-1500 Chip-Select Table appendix): it's not merely unpopulated, a write anywhere in the upper half would silently corrupt whatever system data occupies the corresponding byte in the lower half. A separate Sharp Service Manual independently confirms this with its own memory-map diagram, marking &7C00–&7FFF with the caption **"Inhibit to use by redundancy"** — Sharp's own term for the same mechanism, from a source unrelated to the TRM table.

**PC-1500A** (8.5KB total physical RAM):

| Chip | Capacity | CPU window | Role |
|---|---|---|---|
| HM6116 (×3, "User RAM") | 6144B | S0+S1+S2, &4000–&57FF | Standard/contiguous BASIC RAM |
| HM6116 (×1, "System RAM") | 2048B | S7, &7800–&7FFF | System memory + machine-language area |
| SC882G display chips (×4) | 512B | S6/V2+V3, &7600–&77FF | Same as PC-1500, unchanged |

The PC-1500A simply populates four of the eight possible 2KB blocks (S0, S1, S2, S7) with an identical, off-the-shelf 2K×8 SRAM part (reused four times), where the PC-1500 only populated one full block (S0) and half of another (S7, via a narrower 1K×4bit part).

---

## 3. The Expansion Connector and the PC-1500 → PC-1500A Pin Rewiring

### 3.1 What changed

The PC-1500 exposes its expansion bus on a 40-pin edge connector (confirmed by physical pin count on a real PC-1500A; full 40-pin table, plus the PC-1600's slot connectors, in `Expansion-Connectors.md`). Four pins carry different signals depending on the model:

| Pin | PC-1500 signal | PC-1500A signal |
|---|---|---|
| 5 | S4 (&6000–&67FF) | NC |
| 16 | S1 (&4800–&4FFF) | S3 (&5800–&5FFF) |
| 17 | S2 (&5000–&57FF) | S4 (&6000–&67FF) |
| 18 | S3 (&5800–&5FFF) | S5 (&6800–&6FFF) |

This is a **connector pinout change, not a change to the decoder itself.** &5800–&5FFF is called S3 on both models — the TC40H138F's own address-to-strobe mapping doesn't move. What moves is which physical connector pin a given strobe is routed to. A module whose hardware is hard-wired to a specific physical pin therefore sees a different named strobe (and needs a different POKE address) depending on which machine it's plugged into, even though its own circuitry is completely unchanged.

### 3.2 Why: the CE-155 worked example

The CE-155 is a plain 8KB RAM module, useful here because it has no bank-switching logic of its own — just fixed chip-select wiring, which makes the effect of the pin reassignment directly visible.

**On the PC-1500:**
- &3800–&3FFF (2KB) — the top of the module's own internal &0000–&3FFF window, gated by YO (pin 4), entirely internal to the module slot.
- &4800–&5FFF (6KB) — three external chip-select pins: pin 16 (S1), pin 17 (S2), pin 18 (S3).

Built-in RAM occupies only &4000–&47FF (S0, 2KB) — exactly the gap between the module's two windows. Module (8KB) + built-in (2KB) tile the address space with no gaps or overlap.

**How the module narrows YO's 16KB down to just its own 2KB.** Three of CE-155's four RAM chips get an already-narrowed, individually-dedicated chip-select pin straight from the mainboard (S1, S2, S3) — no extra decode logic needed. The fourth lives inside the module's own raw &0000–&3FFF (YO) allocation, a 16KB window with no pre-narrowing from the mainboard side. CE-155 solves this the same way the mainboard solves the analogous problem for S0–S7: an onboard 138-family decoder takes AD11–AD13 on its select inputs (producing its own local Y0–Y7, exactly mirroring the mainboard's own S0–S7 decoder design) and YO on one of its enable inputs — gating the whole decoder active only while the CPU is actually addressing this module's slot. The chip is selected by (module's own decoded) Y7 specifically, the last of the eight possible 2KB sub-positions, landing exactly on &3800–&3FFF. Because the select logic and the enable logic are on separate pins of the same chip — matching how the mainboard's own decoder separates AD11–AD13 (select) from Y1 (enable), §2.2 — the module correctly restricts itself to just its 2KB allocation rather than mirroring across the other 14KB of its YO window or, worse, responding to the same AD11–AD13 pattern anywhere else in the 64KB address space.

**On the PC-1500A**, the CE-155's wiring is physically unchanged — it has no idea which model it's in. But pins 16/17/18 now carry S3/S4/S5 instead of S1/S2/S3, so the identical module now decodes:
- &3800–&3FFF (2KB) — unchanged, still YO-gated.
- &5800–&6FFF (6KB) — pin 16 → S3, pin 17 → S4, pin 18 → S5.

Total capacity is still exactly 8KB — the module's second window just slides up by 4KB. This is confirmed directly by the PC-1500A's own TRM decode table (§2.2): S0–S2 are labeled "standard user memory" and S3–S5 "optional user memory" — the same category used for module-facing blocks on the PC-1500.

**The cause:** built-in RAM on the PC-1500A grew to occupy S1 and S2, which used to be (and on the PC-1500 still are) driven out to external modules via pins 16–18. Left unchanged, a CE-155 in a PC-1500A would try to decode RAM at addresses the mainboard's own built-in RAM chips were now also driving — a bus conflict. Sharp's fix cost nothing on the module side: reroute which strobes reach those three physical pins so the module's fixed 3-pin skeleton lands on the next three free blocks (S3/S4/S5) instead.

This also explains why pin 18 specifically ends up as the CE-163's bank-select trigger on both models (see `PC-1500-Bank-Switching.md` §9): whichever strobe lands on pin 18 is, by construction, always the *last* of the module's three "extra" 2KB blocks — structurally no different from S1/S2, just conventionally the one banking modules commandeer as a side-channel trigger instead of using for storage.

### 3.3 Why the shift could only be 4KB

The direct cause is simpler than a decoder-availability argument: the PC-1500A has exactly **four** identical RAM chips (§2.3 — three "User RAM" + one "System RAM," all HM6116, confirmed by the block diagram). One of those four is not optional. S7 has to be populated by *something*, because fixed, ROM-referenced system pointers and variables physically live there (§4) — there is no version of this machine that skips populating S7. That leaves exactly three chips free for standard/expandable user RAM, and three chips wired to three chip-selects lands on exactly S0+S1+S2 — 6KB, not more, because there was never a fourth chip available to spend on S3. Extending standard RAM into S3 wasn't merely inconvenient for the module-facing pin rewiring; there was no fifth chip to do it with in the first place.

This is also consistent with (and independently confirmed by) a decoder-availability argument: had built-in RAM absorbed S3 too, a CE-155-class module's pins 16/17/18 would need to shift one block further, into S4/S5/**S6**. But S6 is not an ordinary block — &7000–&75FF is inhibited outright, and &7600–&77FF is committed to display-driver RAM (§2.2). There is no fourth free ordinary block to shift into. The 3-pin rewiring scheme works for exactly one 4KB (2-block) shift, because the block immediately past the shifted-to window is off-limits twice over. Both explanations point at the same 6KB boundary; the chip-count argument is the more direct cause, since it doesn't depend on Sharp having *wanted* to go further and being blocked — there simply wasn't a fourth chip on the table to try.

This is confirmed against real hardware: a stock PC-1500A reports `MEM` = 5946. Built-in contiguous RAM (S0+S1+S2) is 6144 bytes. `NEW` on the PC-1500A defaults to `NEW &C5` (197 decimal) rather than `NEW 0` — the first 197 bytes of the RAM area are a reserve area, not available to BASIC programs. 6144 − 197 = 5947, one byte off from the reported 5946 — within the documented `MEM` = `RAM_END − BASPRG_END` inclusive/exclusive rounding (see `PC-1500-BASIC-Pointers.md` §7).

---

## 4. The Machine-Language Area (&7C01–&7FFF)

### 4.1 What it is

The PC-1500A's own TRM decode table (§2.2) explicitly marks &7800–&7FFF (S7) as "standard user and system memory," with a nested annotation naming **"MACHINE LANGUAGE AREA (7C01H–7FFFH)"** — an intentional Sharp designation, not a reconstruction from pointer addresses.

It is architecturally a separate story from the S1/S2 standard-RAM growth in §3, not a continuation of it. S5, S6, and S7 never appear on any connector pin (only S1–S4, YO, and Y2 reach the expansion bus) — so growing usable capacity at &7800+ required no pin reshuffling of any kind, unlike S1/S2, which are wired out to external modules. This block sits entirely on the mainboard side of the connector.

### 4.2 Why exactly &7C01

On the plain PC-1500, S7 is chip-selected across its full 2KB but only backed by 1024 bytes of distinct storage (§2.3): the TC5514 pair's missing 11th address line means &7C00–&7FFF exactly mirrors &7800–&7BFF, byte for byte, at a fixed &400 offset. &7C00 specifically aliases &7800 — the very first byte of that block.

The PC-1500A drops in a full 2K×8 HM6116 at that same socket instead of the TC5514 pair — the same part already used for S0–S2 — which fully decodes all 11 address lines and gives &7C00–&7FFF genuinely independent storage for the first time. Declaring that newly-independent region the machine-language area is the natural next step; the interesting question is why the boundary is &7C01 rather than the round number &7C00.

What makes this a hard constraint rather than just an aliasing curiosity is that the PC-1500 and PC-1500A run the **identical** system ROM — not a ported or adapted variant. (The PC-1500 briefly shipped with earlier ROM revisions A01 and A03 before A04 became standard; the PC-1500A shipped with A04 from the start, and A04 is confirmed to run unmodified on both models. Whether A03 would run on a PC-1500A is untested.) A literal-operand search of the disassembly turned up no instruction referencing &7800 or &7C00 directly — the mechanism responsible reaches that address by computed, auto-incrementing addressing, not a literal operand. Tracing it down (via ROM disassembly, real-hardware testing, and the `pc1500emu` emulator) surfaces a confirmed, specific reason.

**The confirmed mechanism: the input-buffer-clear routine, and why the tokenizer needs its guarantee.** `INBUF_CLR_1` ($D02B, "Clear input buffers with 0D and initializes Input buffer pointers") sets X=&7BB0 and A=&0D, then falls into a generic fill loop (`DEL_DIM_VAR_4` at $D0B0: `SIN X` — store A at (X), increment X — looped `UL+1` times via `LOP UL,...`). The fill count is `UL=&50` (80) on A03/A04, so the loop runs 81 times, writing &0D to every address from &7BB0 up to and including **&7C00**. This runs on every input-buffer clear — confirmed live in the emulator with `pc1500emu`'s scriptable command pipe: POKE-ing an arbitrary value into &7C00 and then pressing CL or Enter reliably resets it back to &0D, matching the exact hands-on behavior observed on real PC-1500 and PC-1500A units — PEEK &7C00 always reads back 13 regardless of what was POKEd, on both real machines and the emulator.

That extra 81st byte matters because of how the line tokenizer consumes the buffer it fills. `TOK_INBUF_1`/`TOK_INBUF_2` ($F959/$F961) — the routine that tokenizes a typed line after Enter — starts at `INBUFPTR` (&7BB0) and walks forward with `LIN Y` in a loop, comparing each byte against `$27` (comment handling) and `$0D`, stopping only when it hits `$0D`. **This scan has no independent length bound** — termination depends entirely on encountering a `$0D` byte somewhere in memory. A line that completely fills the 80-byte buffer (&7BB0–&7BFF) with no `$0D` inside it would leave this scan nothing to stop it at &7BFF; the guaranteed &0D at &7C00 is what gives even a maximally-full 80-character line a guaranteed terminator immediately past the buffer.

So &7C00 isn't just at risk of aliasing — it's the **actively-used terminator byte one past the 80-byte input/display buffer**, re-stamped with CR on every buffer clear and read by the tokenizer's unbounded scan, on both models, by the exact same ROM code. That's the real, confirmed reason the PC-1500A's TRM withholds it from the machine-language area: a user ML program stored at &7C00 would be silently overwritten by this routine the next time the user returns to the ready prompt, and the tokenizer depends on it staying &0D.

**Why the fix works identically on the PC-1500, via the alias rather than despite it.** The ROM code is model-agnostic: it issues 81 sequential `SIN X` stores starting at &7BB0, oblivious to what's physically behind the top address. On the PC-1500A, &7C00 is genuine independent RAM, so the 81st write lands in its own byte. On the PC-1500, the TC5514 pair only decodes A0–A9, so &7C00 and &7800 share the same low-10-bit pattern and are physically the same SRAM cell (§2.3's mirroring) — the 81st write is electrically indistinguishable from a store to &7800. That means the exact byte the tokenizer's scan needs at "&7C00" is guaranteed &0D on the PC-1500 too, automatically, via the alias — with no model-specific code required. Sharp's fix doesn't need to special-case the PC-1500's aliasing; it works *because of* it, using one instruction sequence on both models. &7800 specifically is documented in this repo's own `LH5801_Guide.md` memory map as the base of `CPU_STACK` (&7800–&784F, 80 bytes) — not generic filler, but the CPU's own return-address stack — which turns out to be exactly why the incidental overwrite there is safe; see below.

**Confirming this via the A01/A03 boundary.** A01's version of `INBUF_CLR_1` uses `UL=&4F` instead of `UL=&50` — one byte shorter, so its loop stops at &7BFF and never reaches &7C00/&7800 at all. This is confirmed directly by the project's own `Original_ROMs/A03-A01_Diff.txt`, which independently isolates this as the *only* byte difference in `INBUF_CLR_1` between A01 and A03: `$D037 $50→$4F`. On a PC-1500 running A01, a full 80-character line with no embedded `$0D` leaves the tokenizer's unbounded scan nothing to stop it at &7BFF — it runs into &7C00–&7FFF, the mirror of &7800–&7BFF, which holds real, documented state (the CPU stack at &7800–&784F, then system variables/BASIC state from &7860 onward per `LH5801_Guide.md`'s memory map), not garbage; whether it finds a `$0D` quickly depends on what that state holds, and only running through the entire mirrored 2KB without one would carry it past &7FFF into Y2 (the &8000+ module/ROM area). A03/A04's one-byte extension closes this gap directly at its source. This lines up cleanly with the earlier explanation: the same fix, applied once in the shared ROM, closes the gap on the PC-1500A by writing directly to independent RAM at &7C00, and on the PC-1500 by writing to &7800 through the alias.

**Why the incidental overwrite of &7800 — and the A01 overrun risk it guards against — are both harmless in practice.** `LH5801_Guide.md` documents the LH5801's stack pointer `S` as starting at `&784F` and *decrementing* on every push, so the CPU stack grows downward from &784F toward &7800. That makes &7800 the extreme floor of the 80-byte stack reserve — reachable only after roughly 40 nested two-byte pushes (subroutine calls/interrupts) with no intervening pops, a depth ordinary BASIC/ROM execution never approaches. More directly: `INBUF_CLR` (and the tokenizer scan it guarantees a terminator for) only ever runs when clearing the input buffer or returning to the READY prompt — precisely the moments the call stack is back at the top-level command loop, shallow, with `S` sitting at or near its base &784F. The one address this routine's incidental write reaches is, at the exact moment it writes there, never holding live stack data. The same logic bounds the A01 overrun risk from the paragraph above: even in the rare case of an unterminated 80-character line, the tokenizer's scan starts reading the stack region at exactly the same shallow-stack moment, so it's reading mostly-stale/idle stack bytes rather than an actively in-use call chain — not a guarantee of immediately finding `$0D`, but not a scan into meaningfully "live" data either.

Sharp didn't design two independent RAM expansions: they replaced small, oddly-sized parts (one HM6116 + two TC5514) with four of one cheap, standard, off-the-shelf chip, and exposed what that gave them beyond &7C00 — the one byte the shared ROM's input-buffer-clear routine still actively claims, as the tokenizer's guaranteed terminator. The pin-16/17/18 rewiring in §3 was the necessary side effect on the module-facing side of that swap; the machine-language area was the side effect on the system-RAM side, with &7C00 itself withheld because the identical ROM genuinely, repeatedly writes to it on both models.

Total PC-1500A physical RAM: 8192B (S0+S1+S2+S7, four HM6116) + 512B (unchanged display-driver RAM) = **8704B ≈ 8.5KB** — the figure the standard-RAM comparison in `PU-PV-Signals.md` §8 refers to, distinct from the 6KB contiguous "standard user memory" figure that `MEM` actually reports.

---

## 5. RAM Sizing and NEW Offset Calculations

These figures follow directly from the chip population in §2–§3: the size of the reserve area used by `NEW` depends on which model and which expansion modules are attached, and the total addressable RAM depends on how far the resulting module + built-in tiling extends.

### 5.1 Empty machine (no memory module)

|Model|Start|End|Size|MEM|
|-----|-----|---|----|---|
|PC-1500|4000|4800|2k|1850|
|PC-1500A|4000|5800|6k|5946|
|PC-1600 LH5803|4000|8000|16k|11834|
|PC-1600 Z80|C000|10000|16k|11834|

### 5.2 Machine plus CE-155 (8k)

|Model|Start|End|Size|MEM|
|-----|-----|---|----|---|
|PC-1500|3800|6000|10k|10042|
|PC-1500A|3800|7000|14k|14138|
|PC-1600 LH5803|2000|8000|24k |20026|

### 5.3 Machine plus a 16k memory module (modern recreation)

|Model|Start|End|Size|
|-----|-----|---|----|
|PC-1500|0000|4800|18k|
|PC-1500A|0000|5800|22k|
|PC-1600 LH5803|0000|8000|32k|

(Exact `NEW`/MEM figures depend on the specific module's own firmware reserve — see its own documentation.)

### 5.4 Calculations

Find the `[RAM start]` with `256 * PEEK(&7863)`

`NEW 0` will set the start of Basic memory to `[RAM start] + C5`. This is because the first 197 bytes are used by various Basic data structures. Therefore, if one needs to reserve e.g. 100 bytes for a machine language program, the Basic start must be `[RAM start] + 197 + 100`. This
results in e.g. `NEW &129` on a machine with the 16k RAM module.

A memory module's own onboard firmware needs its own reserve of bytes on top of the 197-byte BASIC reserve (see `PC-1500-Bank-Switching.md` for the mechanism); the exact figure is module-specific — see that module's own documentation for the minimum `NEW` offset it requires.

On the PC-1600, the start is not set using an absolute address. This is because the LH5803 processor and the Z80 processor see the same memory in different address ranges.
Instead, the memory is reserved using an amount, i.e. 197 plus whatever is needed for the assembly program.

### 5.5 Screen Reverse start addresses

The screen reverse program is 18 bytes long. The start addresses are therefore at least:
* PC-1500 / CE-158: `NEW &38D7`; Add 197
* PC-1500A / a memory module: `NEW` offset depends on the module's own firmware reserve (see the module's own documentation)
* PC-1600: `NEW "S0:",&D7`: Add 197

---

## Appendix: Reading the Decoder Notation (1Y0, 2Y2, etc.)

§2.1–2.2's tables list each address block as, e.g., `Y0 (1Y0)`, `S0 (Y0)`, or `V2 (2Y2)`. This notation appears directly in the source TRM figure and is worth decoding once, since three different things are packed into it.

**The unmarked name is the signal name; the parenthesized name is the decoder pin.** Throughout this document, "S3," "Y1," "V2," and so on are the *logical* names used consistently regardless of model or physical implementation — this is what the rest of the document always refers to (the pin-rewiring discussion in §3, the CE-155 example). The bank-switching mechanics in `PC-1500-Bank-Switching.md` §4 and §9 also just say "S3" or "S5." The parenthesized form — `1Y0`, `Y0`, `2Y2` — is the actual output pin of the physical decoder chip that generates that signal. It only shows up in the reference tables in §2.1–2.2, where it matters which chip and which pin produce a given line.

**The overline (bar) means active-low.** A decoder output is asserted — meaning "this address range is selected" — by being driven *low*, and sits high otherwise. This is standard behavior for the 74139/74138 decoder family that Sharp's TC40H139F and TC40H138F belong to, and it's why these outputs wire directly into memory chips' select pins without an inverter in between: chip-select inputs are conventionally active-low too.

**The numeric prefix ("1Y0" vs. "2Y2") identifies which half of a dual decoder chip is being used — not two separate chips.** The TC40H139F is a *dual* 2-line-to-4-line decoder: one physical package contains two independent decoder circuits, and the 74139-family datasheet convention labels their outputs `1Y0–1Y3` (first internal decoder) and `2Y0–2Y3` (second internal decoder). Concretely:

- **Decoder half 1** of a single TC40H139F, fed by AD14/AD15, produces the top-level 16KB blocks `Y0 (1Y0)` through `Y3 (1Y3)` (§2.1).
- **Decoder half 2** of that *same physical chip* is reused elsewhere on the board to further split S6 into the two display-driver sub-windows: `V2 (2Y2)` and `V3 (2Y3)` (§2.2). This is the "second-stage decoder" mentioned there — the same IC, its other independent half, doing an unrelated job.

The TC40H138F (producing S0–S7) is a *single* 3-to-8 decoder — only one decoder circuit per chip — so its outputs carry no numeric prefix at all; there's nothing to disambiguate.

**Three columns applying to one address range means a cascaded decode tree, not three unrelated signals.** &7600–&76FF, for example, lists Y1, S6, and V2 together because each decoder stage's *enable* input is wired to the previous stage's output:

1. **Y1 (1Y1)** says "this address is somewhere in &4000–&7FFF" — true just enough to enable the next stage.
2. **S6 (Y6)**, enabled by Y1, narrows it to "somewhere in &7000–&77FF."
3. **V2 (2Y2)**, enabled by S6, narrows it one more step to specifically &7600–&76FF.

All three lines must be simultaneously low before the actual display-driver chip-select fires — each row only "counts" because the row above it already gated it on.

---

## Appendix: PC-1500A Chip-Select Table (TRM Figure, Reproduced)

Reproduced from the photographed TRM page described in §2.2/§2.1 — a bad scan, so treat this as a draft pending correction against the original. Merged cells reflect the source figure's own grouping (e.g. "STANDARD USER MEMORY" spanning S0–S2 as one label, not three separate ones); bars denote active-low, per the notation appendix above.

<table>
<thead>
<tr><th>Y-block</th><th>S-block</th><th>V</th><th>Address</th><th>Description</th></tr>
</thead>
<tbody>
<tr>
<td>Y0 (<span style="text-decoration:overline">1Y0</span>)</td>
<td></td><td></td>
<td>0000H–<br>3FFFH</td>
<td>OPTIONAL USER MEMORY</td>
</tr>
<tr>
<td rowspan="10">Y1 (<span style="text-decoration:overline">1Y1</span>)</td>
<td>S0 (<span style="text-decoration:overline">Y0</span>)</td><td></td>
<td>4000H–<br>47FFH</td>
<td rowspan="3">STANDARD USER MEMORY</td>
</tr>
<tr>
<td>S1 (<span style="text-decoration:overline">Y1</span>)</td><td></td>
<td>4800H–<br>4FFFH</td>
</tr>
<tr>
<td>S2 (<span style="text-decoration:overline">Y2</span>)</td><td></td>
<td>5000H–<br>57FFH</td>
</tr>
<tr>
<td>S3 (<span style="text-decoration:overline">Y3</span>)</td><td></td>
<td>5800H–<br>5FFFH</td>
<td rowspan="3">OPTIONAL USER MEMORY</td>
</tr>
<tr>
<td>S4 (<span style="text-decoration:overline">Y4</span>)</td><td></td>
<td>6000H–<br>67FFH</td>
</tr>
<tr>
<td>S5 (<span style="text-decoration:overline">Y5</span>)</td><td></td>
<td>6800H–<br>6FFFH</td>
</tr>
<tr>
<td rowspan="3">S6 (<span style="text-decoration:overline">Y6</span>)</td>
<td></td>
<td>7000H–<br>75FFH</td>
<td>INHIBITED</td>
</tr>
<tr>
<td>V2 (<span style="text-decoration:overline">2Y2</span>)</td>
<td>7600H–<br>76FFH</td>
<td rowspan="3">STANDARD USER AND SYSTEM MEMORY<br><small>(nested annotation, aligned with the S7 row below: <b>MACHINE LANGUAGE AREA (7C01H–7FFFH)</b>)</small></td>
</tr>
<tr>
<td>V3 (<span style="text-decoration:overline">2Y3</span>)</td>
<td>7700H–<br>77FFH</td>
</tr>
<tr>
<td>S7 (<span style="text-decoration:overline">Y7</span>)</td><td></td>
<td>7800H–<br>7FFFH</td>
</tr>
<tr>
<td>Y2 (<span style="text-decoration:overline">1Y2</span>)</td>
<td></td><td></td>
<td>8000H–<br>BFFFH</td>
<td>CE-150: system program, I/O port<br>CE-153: I/O port<br>CE-158: system program</td>
</tr>
<tr>
<td>Y3 (<span style="text-decoration:overline">1Y3</span>)</td>
<td></td><td></td>
<td>C000H–<br>FFFFH</td>
<td>PC-1500A: system program, I/O port<br>CE-158: I/O port, UART</td>
</tr>
</tbody>
</table>

*Footnote in the source: "S0–S7, V2, and V3 are applicable only for the ME0 area." The V3 row's decoder pin is `2Y3` — the original address-map scan showed V3 also labeled `2Y2` (the same as V2), which is a genuine error in that source table, not a scan-reading problem: confirmed against the separate "Chip select circuit for the PC-1500A" schematic (TRM p.163), which explicitly shows two distinct NAND gates driven by `2Y2` and `2Y3` respectively, producing "To Display chip 1,3" and "To Display chip 2,4."*

**Further confirmed by that same schematic** (TC40H139F + TC40H138F chip-select circuit, TRM p.163):
- TC40H138F's select inputs are wired exactly as expected: A=AD11, B=AD12, C=AD13, with its main enable (G1) driven by the Y1 signal from the other decoder — matching §2.2's "active only while Y1 is asserted."
- The system ROM chip's designation is legible here as **CS613128F** — converging with the "SC61328F"/"SC61329F"/"SC613128" readings from other low-quality sources elsewhere in this document; all are almost certainly the same part, read slightly differently off different scans.
- **LH5811** (I/O port) is confirmed again as a direct schematic destination — consistent with teardown of this specific unit, though see §2.1 for why LH5810 also appears in older Sharp material.
- **Y7 feeds "System RAM" directly**, consistent with §2–4 throughout. Y6 (the S6 block, &7000–&77FF) separately feeds a NAND gate together with a signal labeled **WEX**, whose output goes to the I/O port — a Sharp Service Manual excerpt for the PC-1500 describes this exact mechanism in words: *"With low state of AD11 and high state of AD12 and AD13, S6 goes to the low state to receive the interrupt input from an option into the I/O port (7000~77FF address setup)."* This is a legitimate function spanning the *entire* S6 block, not something specific to any sub-range within it — see the PC-1500 Chip-Select Table appendix below for why &7000–&75FF specifically is the part marked "redundant," which turns out to be a separate, unrelated mechanism.

---

## Appendix: PC-1500 Chip-Select Table (TRM Figure, Reproduced)

Same TRM figure format as the PC-1500A table above, this one for the plain PC-1500. Reproduced from a photographed TRM page; treat as a draft pending correction against the original.

<table>
<thead>
<tr><th>Y-block</th><th>S-block</th><th>V</th><th>Address</th><th>Description</th></tr>
</thead>
<tbody>
<tr>
<td>Y0 (<span style="text-decoration:overline">1Y0</span>)</td>
<td></td><td></td>
<td>0000H–<br>3FFFH</td>
<td>OPTIONAL USER MEMORY</td>
</tr>
<tr>
<td rowspan="10">Y1 (<span style="text-decoration:overline">1Y1</span>)</td>
<td>S0 (<span style="text-decoration:overline">Y0</span>)</td><td></td>
<td>4000H–<br>47FFH</td>
<td>STANDARD USER MEMORY</td>
</tr>
<tr>
<td>S1 (<span style="text-decoration:overline">Y1</span>)</td><td></td>
<td>4800H–<br>4FFFH</td>
<td rowspan="5">OPTIONAL USER MEMORY</td>
</tr>
<tr>
<td>S2 (<span style="text-decoration:overline">Y2</span>)</td><td></td>
<td>5000H–<br>57FFH</td>
</tr>
<tr>
<td>S3 (<span style="text-decoration:overline">Y3</span>)</td><td></td>
<td>5800H–<br>5FFFH</td>
</tr>
<tr>
<td>S4 (<span style="text-decoration:overline">Y4</span>)</td><td></td>
<td>6000H–<br>67FFH</td>
</tr>
<tr>
<td>S5 (<span style="text-decoration:overline">Y5</span>)</td><td></td>
<td>6800H–<br>6FFFH</td>
</tr>
<tr>
<td rowspan="3">S6 (<span style="text-decoration:overline">Y6</span>)</td>
<td></td>
<td>7000H–<br>75FFH</td>
<td>INHIBITED</td>
</tr>
<tr>
<td>V2 (<span style="text-decoration:overline">2Y2</span>)</td>
<td>7600H–<br>76FFH</td>
<td rowspan="2">STANDARD USER AND SYSTEM MEMORY</td>
</tr>
<tr>
<td>V3 (<span style="text-decoration:overline">2Y3</span>)</td>
<td>7700H–<br>77FFH</td>
</tr>
<tr>
<td>S7 (<span style="text-decoration:overline">Y7</span>)</td><td></td>
<td>7800H–<br>7FFFH</td>
<td>INHIBITED</td>
</tr>
<tr>
<td>Y2 (<span style="text-decoration:overline">1Y2</span>)</td>
<td></td><td></td>
<td>8000H–<br>BFFFH</td>
<td>CE-150: system program, I/O port<br>CE-153: I/O port<br>CE-158: system program</td>
</tr>
<tr>
<td>Y3 (<span style="text-decoration:overline">1Y3</span>)</td>
<td></td><td></td>
<td>C000H–<br>FFFFH</td>
<td>PC-1500: system program, I/O port<br>CE-158: I/O port, UART</td>
</tr>
</tbody>
</table>

*Footnote in the source: "S0–S7, V2, and V3 are applicable only for the ME0 area." Two typos in Sharp's original table are corrected here rather than reproduced: the Y2 row's end address is printed as `8FFFH` (implying a 4KB block, inconsistent with the fixed 16KB Y-block architecture established throughout this document) and is given here as `8000H–BFFFH`; V3's decoder pin is printed as `2Y2` (duplicating V2's) and is given here as `2Y3`, per the same reasoning and schematic evidence as the PC-1500A table above. Both are confirmed typos in the source document itself, not scan-reading errors — kept corrected rather than reproduced faithfully.*

**The key structural difference from the PC-1500A table**: S7 (&7800–&7FFF) is marked **INHIBITED** here, not "standard user and system memory" — there is no machine-language-area annotation on the PC-1500 at all. §2.3 explains why in hardware terms: the TC5514 pair's missing 11th address line means the block's two halves mirror each other, so exposing either half as independent user memory would let a write silently corrupt whatever system data occupies the same aliased cell. "Inhibited" here means "unsafe for general use," not "physically unpopulated."

**Independently confirmed by a second Sharp source.** A Sharp Service Manual for the PC-1500 (a different document from the TRM table reproduced above) includes its own memory-map diagram, which marks &7C00–&7FFF with diagonal hatching and the caption **"Inhibit to use by redundancy"** — Sharp's own term for exactly the address-line-aliasing mechanism derived independently in §2.3. The same hatching and caption also cover &7000–&75FF (see below) — Sharp uses one label for both mirrored regions.

**Confirmed by the PC-1500's own "Chip select circuit" schematic** (same TC40H139F + TC40H138F structure as the PC-1500A, now available in a clean scan):
- S0's destination is labeled **"To RAM3 (TC5517AF)"** — a different part number than the HM6116 identified by teardown and the text-sourced chip description in §2.3. Both are 2K×8 CMOS SRAM and functionally interchangeable; this is most likely Sharp's official BOM reference designator vs. whichever second-sourced part actually shipped in a given production run, not a contradiction.
- The line feeding "RAM 1, 2" is labeled **"To RAM 1, 2 (TC5514P)"** — confirms the exact part number (including the "P" package suffix) for the system-RAM pair identified in §2.3.
- **CS613128F** (ROM) and **LH5810** (I/O port) both appear again — LH5810, not LH5811 as an earlier revision of this section stated from a harder-to-read scan; see §2.1 for why both parts are genuinely correct, just from different production eras.
- S6's own select condition is spelled out precisely: "with low state of AD11 and high state of AD12 and AD13, S6 goes to the low state" — confirming A=AD11 (least significant), B=AD12, C=AD13 (most significant) for the TC40H138F's select inputs, consistent with binary index 6 = 110 (C,B,A).

**The V2/V3 display-RAM mirroring mechanism, precisely.** The same Service Manual spells out exactly how V2/V3 are generated, resolving the mirroring question raised earlier in this document:
- The second TC40H139F decoder half (producing 2Y2/2Y3, i.e. V2/V3) is enabled ("2G active") only when S6 (Y6) is selected.
- Its select inputs are **2A = AD8** and **2B = DME0** (a CPU timing/qualifier signal, not a raw address bit) — not AD9 or AD10, which is where the "narrow one more level" pattern used everywhere else in this document (§2.2's cascaded decode) would have predicted them to be.
- V2 fires when AD8 is low and DME0 is high; V3 fires when AD8 is high and DME0 is high.

Because AD9 and AD10 are never examined anywhere in this chain — not by S6's own selection (already narrowed to the whole 2KB block by AD11–AD13 alone) and not by the V2/V3 sub-decode (only AD8 and DME0) — the V2/V3 pattern repeats identically across all four 512-byte quarters of the 2KB S6 block: the "real" occurrence at &7600–&77FF, plus mirrored copies at &7000–&71FF, &7200–&73FF, and &7400–&75FF. This is exactly the "Inhibit to use by redundancy" hatching on the memory-map diagram, and it means the earlier explanation in this document — that &7000–&75FF is inhibited *because* it's where the WEX-qualified I/O port interrupt access happens — was wrong. That WEX/I-O-port mechanism is real (see next paragraph) but applies uniformly to the *entire* &7000–&77FF range, hatched or not, so it can't be what distinguishes the hatched sub-range from the display-active one. The display-RAM mirroring is the actual, distinguishing cause.

**S6's separate, legitimate function.** The same source states S6's purpose directly: *"With low state of AD11 and high state of AD12 and AD13, S6 goes to the low state to receive the interrupt input from an option into the I/O port. (7000~77FF address setup)"* — S6, combined with a signal labeled **WEX** through a NAND gate, lets an optional external peripheral's interrupt line reach the I/O port controller. This is a real, intentional function of the whole S6 block, coexisting with (not explaining) the display-RAM mirroring described above — accessing anywhere in &7000–&77FF both potentially touches the (mirrored, for 3/4 of the range) display RAM *and* participates in this interrupt-forwarding path. "WEX" most plausibly stands for something like "write enable, external," though this is speculation, not a sourced expansion.

---

## Appendix: Superseded Hypotheses

Three plausible-but-wrong hypotheses arose while researching §3–§4, kept here because each is the kind of thing a reasonable person would derive from partial evidence and get wrong the same way.

**"Sharp added the entire &7600–&8000 RAM chip and declared the leftover the machine-language area."** Plausible reading: since &7C01 sits inside a block adjacent to the display-buffer region, it's tempting to assume the ML area comes from claiming the *whole* &7600–&8000 range on a shared chip that also backs the display. This is wrong: &7000–&75FF is inhibited (not RAM at all), and &7600–&77FF belongs to the LCD driver chips specifically, not a general-purpose RAM chip shared with system memory (§2.2). The ML area is entirely within S7 (&7800–&7FFF), a separate block from the display region, and never involves display-buffer capacity at all.

**"A single, larger HM6264 (8K×8) chip replaces the PC-1500's HM6116+TC5514 combination, mapped into two non-contiguous CPU windows via internal address-line remapping."** This looked attractive because the totals matched exactly (8192 bytes = 6144B standard RAM + 2048B system RAM, with zero remainder) and because "one bigger chip" is a natural guess when total capacity increases cleanly. It's wrong: both a Sharp circuit block diagram and an independent teardown of a second PC-1500A unit confirm **four separate, ordinary HM6116 chips**, each with its own chip-select wired straight to one of the decoder's existing S0/S1/S2/S7 strobes — reusing one off-the-shelf part four times rather than introducing a differently-shaped chip that needs to answer two disjoint address windows. The lesson: matching totals is necessary but not sufficient evidence for a specific physical implementation when a decoder already provides one chip-select per block for free.

**"&7C01 (rather than &7C00) is a reserve-area convention, matching the same off-by-one pattern seen elsewhere in this document (e.g. `NEW &C5`)."** This looked attractive because the document already establishes a real, repeated pattern of "reserve up to and including a marker byte, then usable space starts one byte later," and &7C01 fits that shape numerically. It's wrong, or at least unmotivated: `NEW &C5`'s 197-byte reserve is a BASIC-interpreter convention describing where a *program* may safely start within a bank — it has no connection to why one specific *hardware* byte at the edge of the S7 block would need protecting. The confirmed explanation (§4.2) is that the shared ROM's input-buffer-clear routine (`INBUF_CLR_1`/`DEL_DIM_VAR_4`, $D02B/$D0B0) genuinely writes &0D to &7C00 on every buffer clear, on both models, as part of an 81-byte fill loop starting at &7BB0 — confirmed by ROM disassembly and by matching live POKE/PEEK behavior on real PC-1500/PC-1500A hardware and in `pc1500emu`. On the plain PC-1500, that same write incidentally also lands on &7800 (the TC5514 pair's missing 11th address line means the two addresses are the same physical cell), but the ROM's dependency on &7C00 is real and active, not merely a legacy aliasing risk. The rest of the newly-independent region, from &7C01 onward, is never touched by this or any other found routine, so it's safe to expose. The lesson: a numeric pattern matching a real convention elsewhere in the same system is suggestive, not sufficient, when a more specific hardware/firmware mechanism (here, an active OS buffer terminator, confirmed by tracing the actual write) directly explains the same number.
