# CE-150 Printer/Plotter/Cassette — Hardware Notes (from the Service Manual schematic)

Hardware-level reference for the CE-150, aimed at emulator authors. Everything here is
derived from the **CE-150 Service Manual (English)**, specifically:

- **Circuit diagram** — manual sheet "‑33‑" (PDF page 61), section *4. CIRCUIT DIAGRAM*.
  Readable at 600 dpi; not extractable with `pdftotext`.
- **Parts and signals position** — manual sheet "‑34‑" (PDF page 62), section
  *5. PARTS AND SIGNALS POSITION* — a PCB artwork with the edge‑connector signal names
  labelled down the left edge.

The rest of the 64‑page manual is the pen/plotter mechanism (disassembly, adjustment,
lubrication) and has no electrical content beyond §5 "Electrical characteristics"
(motor/solenoid currents, step pitches).

Cross‑references in this repo:
- Window/bank context: `../Memory-Architecture/PC-1500-Address-Decoding.md` §2.1 (Y2 = &8000–&BFFF),
  `../Memory-Architecture/PU-PV-Signals.md` (PV selects CE‑150 vs CE‑158 ROM in that window).
- Bus pinout: `../Memory-Architecture/Expansion-Connectors.md` §2.2 (60‑pin connector).
- Software side of the same registers/ROM: `SharpBasicReference/CE-150-Reference.md`
  ("Internal Technical Reference") and `SharpBasicReference/reference/CE-150.lib`.

Confidence is called out per item: **[schematic]** = read directly off sheet ‑33‑/‑34‑,
**[confirmed]** = schematic finding independently matches the ROM‑disassembly symbol files,
**[uncertain]** = could not be fully traced in the raster / needs bench or ROM‑code check.

---

## 1. Chip complement

| Ref on PCB | Part | Function |
|---|---|---|
| I/O | **LH5810** (silkscreen: "LH5810 OR LH5811") | 3×8‑bit parallel ports (PA/PB/PC) + serial I/O + mask/IRQ regs; memory‑mapped. Same family as the PC‑1500's internal I/O chip. |
| ROM | **LH5367‑02**, 44‑pin QFP ("TOP VIEW" on sheet) | 8 K×8 mask ROM = the CE‑150 firmware (character vectors + plot/print/cassette handlers). Pins A0–A12, D0–D7, CE1, CE2, plus 4 mask‑programmable selects CS0–CS3. |
| decode | **TC40H000P** | Quad 2‑input NAND. Two gates form the address decode (§3); the other two are the cassette read squarer (§6). |
| bus buffers | 3–4 × **TC50H001F** | Hex buffers isolating/regenerating the PC‑1500 bus onto the rear EX‑BOX connector (§7). |
| motor driver | **LB1287** | Sinks the 8 stepper phases (X motor A–D, Y motor A–D) from LH5810 Port C. |
| solenoid/relay driver | **M54515P** | Drives the pen‑lift solenoid pair and the two cassette REMOTE relays from LH5810 Port A/B. |
| transistor arrays | 2 × **AE5411**, plus 2SD1246 / 2SB926 / 2SC458 / 2SC2021 discretes | pen‑solenoid H‑bridge, charge circuit, analog conditioning. |
| relays | 2 × reed relay ("Relay 1", "Relay 2") | cassette REMOTE‑0 / REMOTE‑1 contacts. |

---

## 2. Address map (net result)

| Range | Device | Notes |
|---|---|---|
| **&A000–&BFFF** | LH5367‑02 ROM (8 KB) | Character vectors `&A000–&A28A`, then handler code up through `&BFxx`. **[confirmed]** — matches `CE-150.lib` symbol span. |
| **&B000–&BFFF** page, low nibble | LH5810 register file | Software uses `&B00A–&B00F` (see §4). LH5810 register = address bits A3..A0. **[confirmed]** |
| EX‑BOX rear connector | pass‑through + regenerated bus | §7 |

The ROM and the LH5810 register file **overlap** at `&B00A–&B00F`: both devices decode that
address. Writes are unambiguous (mask ROM ignores them → LH5810). For **reads** of
`&B00A–&B00F` the LH5810 must win (the firmware reads back the IRQ‑flag and port‑input
registers). The `CE-150.lib` / CE‑150‑Reference annotate every one of these registers
"(ME1)", which suggests the LH5810 read is qualified by the **ME1** strobe specifically
while the ROM output‑enable is suppressed (via **OD**, pin 60) during that cycle.
**Emulator guidance:** route the whole `&B00x` LH5810 register file to the I/O chip, not
to ROM, for both read and write. Exact ROM‑vs‑LH5810 read arbitration hardware is
**[uncertain]** — not fully traceable on the sheet.

---

## 3. Address decode logic  **[schematic]**

### 3.1 The window gate (TC40H000P)

```
NAND gate A  (pins 1,2 → 3):   inputs 1 & 2 both tied to A14   →  out(3) = /A14      (inverter)
NAND gate B  (pins 12,13 → 11): input 13 = /A14, input 12 = A15 →  out(11) = /(A15 · /A14)
```

`out(11) = /(A15 · /A14)` is **low exactly for &8000–&BFFF**. This single line is the
"CE‑150 is being addressed" strobe. It feeds:

- **LH5810 /CS2** (pin drawn with overbar → active‑low), and
- the ROM chip‑enable path.

This is the module deriving the &8000–&BFFF window *itself* from A15/A14, rather than
relying on a single bus "area" pin. It is still additionally qualified by the bus memory
strobe(s) — **ME1 / DME1** — and by **R/W**, and (per `PU-PV-Signals.md`) by **PV** when a
CE‑158 is also chained (PV picks CE‑150 vs CE‑158 in this same window).

### 3.2 LH5810 select/register wiring

| LH5810 pin | Tied to | Effect |
|---|---|---|
| RS0, RS1, RS2, RS3 | **A0, A1, A2, A3** | selects one of 16 internal registers |
| CS0 | **A13** (active high) | → must be in &A000–&BFFF |
| CS1 | **A12** (active high) | → must be in &B000–&BFFF |
| /CS2 | **`/(A15·/A14)`** from gate B | → must be in &8000–&BFFF |
| R/W, ME0, ME1, DME0, DME1, W0, W1, INT, WAIT, RES, φOS | straight off the 60‑pin bus | |

Net: LH5810 selected for `A15=1, A14=0, A13=1, A12=1` ⇒ **&B000–&BFFF**, register =
`A3..A0`. Firmware touches `&B00A–&B00F` (§4); the rest of the 16‑register file
(`&B000–&B009`, incl. Port C) is driven internally by the LH5367 firmware and mirrored in
system RAM `&79E0–&79F9`.

### 3.3 ROM effective decode

The LH5367 has CE1, CE2 **and** four mask‑programmable selects CS0–CS3. Their individual
wiring could not all be traced in the raster **[uncertain]** — CS0/CS1 appear strapped to
a fixed rail (mask polarity config); CE1/CE2/CS2/CS3 carry the dynamic decode and the
`C1`/`C2` connector qualifiers (§7). But the **effective** decode is pinned down by the
confirmed 8 KB firmware footprint:

```
ROM enabled  ≈  (A15 · /A14 · A13) · <bus read strobe>       →  &A000–&BFFF, read only
```

i.e. gate B's output AND‑ed with A13 (= the same line as LH5810 CS0).

---

## 4. LH5810 memory‑mapped registers  **[confirmed]**

From `SharpBasicReference/CE-150-Reference.md` "I/O Ports (0xB00A‑0xB00F)" and `CE-150.lib`:

| Addr | Symbol | R/W | Meaning |
|---|---|---|---|
| `&B00A` | `CE150_MSK_REG` | R/W | LH5810 mask register |
| `&B00B` | `CE150_IF_REG` | R/W | LH5810 interrupt‑flag register |
| `&B00C` | `CE150_PRT_A_DIR` | R/W | Port A direction (1 = output) |
| `&B00D` | `CE150_PRT_B_DIR` | R/W | Port B direction |
| `&B00E` | `CE150_PRT_A` | R/W | Port A data |
| `&B00F` | `CE150_PRT_B` | R/W | Port B data |

Port C (stepper phases) is not in this table; the firmware keeps its shadow at
`&79EE` (`MTR_PHASE`, "stored in Port C") and writes it through the LH5810's Port C data
register, which sits lower in the same `&B00x` file (offset not documented in the symbol
files — **[uncertain]**, but by RS0‑3 wiring it is one of `&B000–&B009`).

---

## 5. LH5810 port → CE‑150 hardware  **[schematic]**

### Port C — steppers
`PC0–PC7` → **LB1287** → **X motor A/B/C/D** and **Y motor A/B/C/D** (4‑phase, 2‑phase
excitation). Per manual §5‑3 / §3: 260 steps/s, 0.2 mm per pulse on both axes;
X gear reduction 1 : 9.01, Y 1 : 37.86. Firmware phase shadow at `&79EE`, hold‑time
counters at `&79ED` (X) / `&79EF` (Y).

### Port B — pen solenoid
`PB0`, `PB1` → 2SD1246 / 2SB926 push‑pull via **M54515P** → pen‑lift **electromagnet**
("solenoid(+)" / "solenoid(−)" on the DPG1802 internal connector). Self‑holding magnet,
~4.85 V, ~1.1 A peak, energised ~5 ms per pen up/down (manual §5‑2, §3). Firmware pen
state at `&79E9` / `&79EC`; handler `PENUPDOWN` = `&AAE3`.
`PB7` (input, 10 kΩ pull‑up) ← the **PRINT** push‑button on the CE‑150 case.

### Port A — cassette REMOTE + colour/misc
`PA1–PA4` → **M54515P** → **Relay 1 / Relay 2** → **REMOTE‑0 / REMOTE‑1** jack contacts
(cassette motor control). Handlers `REMOTEON` = `&BF11`, `REMOTEOFF` = `&BF43`,
`RMT` = `&BEF9`.
`PA0` (buffered out; note the sheet's "100 kΩ ×6 pcs (except PA0)" — PA0 alone has no
pull) → 10 kΩ into the cassette **read** amplifier (first TC40H000P gate). Read‑path
enable / return.
`PA5` (input) ← 10 kΩ/10 kΩ divider sense node. The board carries a `VR 22 kΩ` trimmer
set at manufacture so "Point A = 1.0 V" when "Point B = 4.81–4.85 V" and "VCC 3.9–4.1 V"
(note on sheet ‑33‑) — a supply/low‑battery monitor.
`PA6`, `PA7` (inputs, pulled) ← pen/paper/colour position sensing (the "Color position
sensor" contact of manual §5‑5: DC 24 V max, 100 mA max).

### Serial pins
LH5810 `φOS, CL0, CL1, SD0, SD1, LC` (left side of the package) are wired but their use
was not traced **[uncertain]** — likely idle in the CE‑150.

---

## 6. Cassette analog path  **[schematic]**

The MIC / EAR / REMOTE jacks are physically on the CE‑150, but the **bit stream is not**:
it is the 60‑pin bus's **CMTOUT** (pin 29) and **CMTIN** (pin 27), generated/sampled by
the PC‑1500's own internal I/O chip. The CE‑150 only conditions the analog:

- **Write:** `CMTOUT` → 18 kΩ / 0.01 µF / 0.0047 µF / 10 kΩ / 270 Ω / 270 Ω / 0.1 µF
  ladder attenuator → **MIC** jack (line‑to‑mic level).
- **Read:** **EAR** jack → 0.047 µF coupling, 100 kΩ, clamp diodes → two **TC40H000P**
  NAND gates as cascaded inverters with **1 MΩ** feedback (self‑biased limiter/squarer)
  → `CMTIN`.
- **Motor:** REMOTE relays, switched by LH5810 `PA1–PA4` (§5).

So for emulation, "start/stop tape motor" = an LH5810 Port A write inside the CE‑150 ROM;
the actual FSK encode/decode timing lives on the PC‑1500 side. Tape data format:
`../Data-Formats/PC-1500-Tape-Format.md`.

---

## 7. Bus buffering and the EX‑BOX pass‑through  **[schematic]**

The CE‑150's rear 64‑pin female connector chains a further peripheral (typically a
CE‑158). The CE‑150 does **not** just parallel the bus — it regenerates it (TC50H001F
buffers):

| Signal(s) | Direction through CE‑150 |
|---|---|
| **A0–A15** | buffered **out** to EX‑BOX only (unidirectional, "▷16" on the sheet) |
| **D0–D7** | **bidirectional** buffer |
| **R/W, OD, ME1, DME0, DME1, φOS** | buffered out to EX‑BOX |
| **W0EX1+2 / W1EX1+2** (bus WEX/W1) → **W0EX2 / W1EX2**, **INT → INT2** | *regenerated* for the next box |
| **PU, PV, BFO, PU0/PU1** | pass‑through (unbuffered) |
| **PB0, PB1, PC7** | LH5810 port bits brought out to the EX‑BOX connector (also "not used" pins per the PC‑1500 TRM 60‑pin table) |

Two bus signals matter for ROM/overlay arbitration in a multi‑module chain:

- **INHIBIT** (60‑pin pin 25) — "prohibits ROM select of the PC‑1500 when tied to GND"
  (TRM). Present on the CE‑150 connector; lets a downstream module suppress the host's
  own ROM decode for an overlay.
- **`C1` / `C2`** — labelled on sheet ‑34‑ immediately next to `A14`, on the EX‑BOX side
  (they are **not** PC‑1500 60‑pin signals). Best reading **[uncertain]**: buffered
  copies of the CE‑150's ROM chip‑enable / decode‑qualifier lines, exported so a chained
  ROM box (CE‑158) shares the &8000–&BFFF decode. Worth confirming against a CE‑158
  schematic.

---

## 8. Power, reset, clock  **[schematic]**

- The CE‑150 has its **own supply**: an ADAPTOR jack + **5 × Ni‑Cd cells** + charge
  circuit (27 Ω ½ W series, `10D‑1 ×4` and `1S1588` steering diodes). It generates a
  separate motor rail **VM** distinct from logic **VCC**, and takes **VBAT** from the
  host for backup.
- **Reset:** LH5810 `RES` is a **local RC** power‑on reset (1 µF + 10 kΩ), *not* the host
  bus reset. Port latches are indeterminate for that RC interval after power‑up.
- **Clock/strobe:** LH5810 runs off bus strobes (`φOS`, `ME1`, `R/W`); no separate
  crystal on the board. (Note the PC‑1500 TRM labels 60‑pin **BFO** as "VCC output", not
  a clock — the clock‑phase line is **φOS**, pin 51.)

---

## 9. Key takeaways for an emulator

1. **CE‑150 ROM at &A000–&BFFF, read‑only, always mapped** whenever addressed — there is
   **no bank/enable latch chip on the CE‑150**. The only software‑visible "paging" in this
   window is the **PV** flip‑flop in the LH5801 CPU, used by the host firmware to choose
   CE‑150 vs CE‑158 ROM when both are present (`PU-PV-Signals.md`).
2. **LH5810 register file in the &B00x page**, `A3..A0` = register index; firmware uses
   `&B00A–&B00F` (mask, IRQ‑flag, Port A/B dir, Port A/B data). Send **all** `&B00x`
   register reads and writes to the LH5810, not ROM, despite the ROM also covering that
   address.
3. Window/decode is `(/(A15·/A14))` from a TC40H000P NAND pair, then A13 (ROM) / A13·A12
   (LH5810), then `ME1`/`R/W`.
4. Port C → stepper phases (via LB1287); Port B → pen solenoid + PRINT key; Port A →
   cassette REMOTE relays + supply sense + position sensors.
5. Cassette **data** is host‑side (`CMTIN`/`CMTOUT` on the 60‑pin bus); the CE‑150 only
   does analog conditioning and relay motor control.
6. The CE‑150 **buffers** the bus to the rear connector (address out‑only, data
   bidirectional) and exposes `INHIBIT` + `C1`/`C2` for downstream overlay arbitration.
