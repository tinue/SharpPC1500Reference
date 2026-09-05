# PC-1600 CPU: LH-5803 compatibility co-processor

## Scope

The LH-5803 side of the PC-1600: its memory map, how it differs from the PC-1500's
LH-5801, the Z-80↔LH-5803 call bridge, and the rules for running PC-1500/1500A software
(MODE 1). The **LH-5801 instruction set** is shared and lives in
`../Assembly-Programming/LH5801_Guide.md` — only the deltas are here.

**Sources:** PC-1600 Technical Reference Manual §5.14 (SC-7852↔LH-5803, the `CALLH`
parameter block), §5.15 (compatibility with the PC-1500/1500A) — read from the German
Systemhandbuch scan; §7.1.4 / §7.2.3 (the bus mapping and the LH-5803 memory map,
already in `PC-1600-Machine-Overview.md` §3 and `PC-1600-Memory-Architecture.md` §5–6).

---

## 1. What the LH-5803 is for

The PC-1600 has two main CPUs sharing one bus; only one runs at a time
(`PC-1600-Machine-Overview.md` §3). The SC-7852 (Z-80) is the normal main CPU. Control is
switched to the **LH-5803** to (a) drive PC-1500 peripherals (CE-150, CE-158, CE-162E)
and (b) run LH-5801/5803 machine code — user `XCALL` programs and `CLOAD`ed PC-1500
programs.

- Clock: **1.3 MHz** (2.6 MHz crystal ÷ 2).
- The LH-5803 is a successor to the LH-5801 and supports the LH-5801 instruction set (per
  TRM §7.1.2). Documented behavioural deltas from the LH-5801 used on a real PC-1500:
  reversed address byte order (**hi, lo**), inverted A15 as seen from the SC-7852 side,
  and the ME0/ME1 usage in `PC-1600-Machine-Overview.md` §3. Any timing differences are
  not documented.

## 2. Memory map

The LH-5803 sees a plain 64 KB space (TRM §7.2.3):

| LH-5803 address | Contents | = SC-7852 view |
|---|---|---|
| 0000H–3FFFH | Slot 1 / Slot 2 module RAM (whichever bank Port 31H last selected) | Z-80 8000H–BFFFH |
| 4000H–7FFFH | internal 16 KB RAM (fixed, no banking) | Z-80 C000H–FFFFH, Bank 0 |
| 8000H–BFFFH | CE-158 ROM (`PVOUT`=1) / CE-150 ROM (`PVOUT`=0) — CE-158 in the lower 8 KB, CE-150 in the upper 8 KB | same physical peripheral ROM |
| C000H–FFFFH | internal ROM (16 KB, the LH-5803 half of PC-1600 firmware) | Z-80 Bank-6-class system ROM |

Bank selection in 8000H–FFFFH is completed by the LH-5803's own **PV** signal — the same
physical CPU flip-flop as on the PC-1500 (`../Memory-Architecture/PU-PV-Signals.md` §3),
relayed through the gate array. The full narrative, the address-by-address comparison to
a real PC-1500/1500A, and the open question about the S6 display-buffer / S7 stack region
inside 4000H–7FFFH are in `PC-1600-Memory-Architecture.md` §5–6.

## 3. The Z-80 → LH-5803 bridge: `CALLH` (TRM §5.14)

`CALLH` at **01C6H** hands control from the SC-7852 to an LH-5803 machine subroutine and
returns when it finishes. Parameters go in a work-area block; addresses are given
SC-7852-view (LH-5803-view in parentheses):

| Name | Addr | Content |
|---|---|---|
| **CMDZ** | F002H (7002H) | operation mode — **20H** = do *not* pass registers into the LH-5803; **30H** = load PARA…PARUH (F005H–F00BH) into the LH-5803 registers before entry |
| PARA | F005H (7005H) | → LH-5803 `A` |
| PARXL / PARXH | F006H / F007H | → `XL` / `XH` |
| PARYL / PARYH | F008H / F009H | → `YL` / `YH` |
| PARUL / PARUH | F00AH / F00BH | → `UL` / `UH` |
| PARPCL / PARPCH | F00CH / F00DH | subroutine entry address, low / high byte — **an LH-5803-view address** |
| PARBAN | F00EH (700EH) | subroutine bank — **00H = PV(0), 01H = PV(1)** |

**On return** the LH-5803 registers are written back to memory:

- `CMDZ = 20H`: F005H = `A`, F004H = `STATUS (T)`.
- `CMDZ = 30H`: F005H = `A`, F004H = `STATUS (T)`, F006H–F00BH = `XL, XH, YL, YH, UL, UH`.

Clobbers all Z-80 registers.

The BASIC-level equivalents (TRM Appendix E/H) are `XCALL` (run LH-5803 code) vs. `CALL`
(Z-80 code), `XPEEK`/`XPOKE` vs. `PEEK`/`POKE`, `XPEEK#`/`XPOKE#` vs. `PEEK#`/`POKE#`.

## 4. MODE 0 / MODE 1

`MODE0` / `MODE1` are the two **display modes**, set by the BASIC `MODE` command (not the
physical `[MODE]` key, which is the PRO/RUN/RESERVE editor toggle). Confirmed from the
PC-1600 German user manual, §9.2 / Appendix H (`PC-1600-Memory-Architecture.md` §5):

- **MODE 1** = 26 × 1 — only the bottom of the four display lines is used, for PC-1500
  program compatibility; character codes `&27` / `&5B` / `&5D` are remapped to their
  PC-1500 meanings.
- BASIC's command set and dispatcher are **Z-80-resident in both modes** — MODE 1 is
  compatibility by shared command set + adjusted behaviour, not a handoff of the
  interactive session to a separate interpreter. Genuine LH-5803 execution is always
  explicit (`XCALL` / `XPEEK` / `XPOKE`), or baked into a loaded PC-1500 program's
  tokenized bytecode.

## 5. Running PC-1500/1500A BASIC programs (TRM §5.15(1))

1. Put the PC-1600 in **MODE 1** before starting the program.
2. **MODE 1 prerequisites:** no RAM module larger than 16 KB in Slot 1, and **no module
   at all in Slot 2** — *unless* the modules are used purely as a RAM disk (CE-1600M in
   Slot 1, CE-1600M or CE-161 in Slot 2), in which case the RAM disk must have been
   formatted (`INIT "Sn:","F"`) while in **MODE 0**.
3. **Renamed commands** — a PC-1500 program must use the PC-1600 name:

   | PC-1500 / 1500A | PC-1600 |
   |---|---|
   | `LCURSOR` | `TAB` |
   | `LINE` | `LLINE` |
   | `CALL` | `XCALL` |
   | `POKE` / `PEEK` | `XPOKE` / `XPEEK` |
   | `POKE#` / `PEEK#` | `XPOKE#` / `XPEEK#` |

   Cassette-loading auto-renames all of these **except `LCURSOR`** (change it to `TAB`
   by hand). Keyboard entry: rename all by hand.
4. Cassette load of a PC-1500 program: via CE-150 / CE-162E — OK; via CE-1600P interface
   — a program can be loaded in MODE 1 but **not data**.
5. `TIME = 0` is valid on the PC-1500 but an **error** on the PC-1600.
6. New PC-1600 reserved words (`NAME`, `AS`, `XOR`, …) — rename any that a PC-1500
   program used as variable names.
7. The BASIC work-area layout differs, so PC-1500 BASIC programs (and especially their
   machine-language parts) **may not run cleanly**.
8. **`7C01H`–`7FFFH`** — the PC-1500A's own user/ML area — is the **PC-1600 system work
   area**. A PC-1500 program that uses that range will not run.
9. An array variable cannot be the `INPUT`-target variable when the statement runs on a
   CE-158.

## 6. Running PC-1500/1500A peripherals (TRM §5.15(2))

- **RAM modules** work only in the memory slots — Slot 1: CE-1600M, CE-161, CE-159,
  CE-155, CE-151; Slot 2: CE-1600M, CE-161.
- **CE-150 / CE-158 / CE-162E:**
  - *MODE 0:* `LLIST` / `CSAVE` / `CLOAD` / `CSAVEM` / `CLOADM` cannot run on these; any
    command with a **non-standard-variable** operand errors (`LPRINT A1` fails — use
    `A = A1 : LPRINT A`); `TERMINAL` and `DTE` cannot run on the CE-158.
  - *MODE 1:* only the subset that PC-1500 BASIC itself supports (`LPRINT TIME$` fails,
    `TIME$` being unknown to PC-1500 BASIC).
- **CE-153:** its bundled utility program cannot be used on the PC-1600 (see TRM §5.12,
  the CE-153 control utility for the PC-1600).
- **CE-150 vs CE-1600P:** different plottable width → output layout can differ. CE-150 is
  X = 0..216 units ≈ 42.75mm on 56mm tape; CE-1600P is X = 0..960 units ≈ 190mm on A4
  (shared scale 0.198mm/unit — see `PC-1600-Peripherals-Hardware.md` §1.0 and
  `SharpBasicReference/CE-150-Reference.md`). Adjust with `PCONSOLE "LPT1:"` and `PAPER`.
  The CE-150 has two remote-control outputs, the CE-1600P only one.

## Cross-references

- `../Assembly-Programming/LH5801_Guide.md` — the shared LH-5801/5803 instruction set.
- `PC-1600-Machine-Overview.md` §3–4 — dual-CPU bus mapping, `ELH#`, the physical
  hand-off sequence.
- `PC-1600-Memory-Architecture.md` §5–6 — the LH-5803-view memory map narrative and the
  PC-1500 comparison.
- `../Memory-Architecture/PU-PV-Signals.md` — the PV bank-select mechanism.
- `~/Development/sharp/pc1600/notes/LH5803-A04-Crosscheck.md` — `rom1500.bin` vs. real
  PC-1500 A04 ROM (68–71 % identical; consolidated-dispatcher change).
