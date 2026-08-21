### LISSAJOU — Companion Guide

#### Program Overview
Plots a red Lissajous figure on the CE-150 plotter with a black title. This version follows standard typography by using mixed-case text for titles and status reports.

#### How to Enter / Load

**Transfer via SharpDataExchange (recommended):**
Connect the PC-1500 and send `lissajou.bas`.

**Manual entry:**
Type each numbered line exactly as shown. **Do not type the `//` lines**.

**Cassette:**
Use `CSAVE "LISSAJOU"` to save and `CLOAD "LISSAJOU"` to reload.

#### How to Run
```
RUN
```
Ensure the CE-150 plotter is connected and pens are loaded (Slot 0: Black, Slot 3: Red).

#### Variable Reference

| Variable | Type | Role |
|---|---|---|
| `A`, `B` | Numeric | Amplitudes (set to 100 for maximum paper width) |
| `F`, `G` | Numeric | Frequencies for X and Y axes |
| `D` | Numeric | Phase shift (radians) |
| `I` | Numeric | Integer loop counter (0 to 100) |
| `T` | Numeric | Derived angle (I × π / 50) |
| `P` | Numeric | Current progress percentage |
| `L` | Numeric | Last reported progress (for 5% filtering) |
| `X`, `Y` | Numeric | Calculated plotter coordinates |

#### Line Range Index

| Lines | Purpose |
|---|---|
| 10 | Program name / copyright REM |
| 20 | Initialisation, `WAIT 0` for progress report |
| 30–40 | Reset pen to `LCURSOR 0` and print mixed-case title |
| 50 | Plotter origin setup (centered at X=108, shifted Y=-120) |
| 60 | Parameter assignment (A=100 for width) |
| 70–150 | Plotting and progress loop (Mixed-case updates) |
| 160 | Advance paper for visibility (`GLCURSOR` with negative Y) |
| 170–180 | Return to text mode and finish with mixed-case completion message |

#### Algorithm Description
1. `CLEAR` variables and set `WAIT 0` to enable non-blocking LCD updates.
2. Reset the printer pen to the left margin with `LCURSOR 0` and print the mixed-case title "Lissajous Figure" in Black.
3. Switch to `GRAPH` mode, move the pen to the center, and set a new origin below the text.
4. Select the Red pen (`COLOR 3`).
5. Loop $I$ from $0$ to $100$:
   - Derive the angle $T = I \cdot \pi / 50$.
   - Calculate coordinates $X, Y$.
   - Draw the figure segment by segment using the `LINE` command.
   - Every 5%, print the progress on the LCD as "Progress: n%".
6. Use `GLCURSOR (0, -120)` to feed the paper forward so the entire plot is past the tear-off bar.
7. Switch back to `TEXT` mode, print "Complete", restore `WAIT` behaviour, and `END`.

#### Known Limitations / Tips
- Requires CE-150 printer/plotter.
- Using mixed-case characters for titles and progress reports follows the recommended coding style for the PC-1500.
- Ensure the Red pen is in Slot 3 and the Black pen is in Slot 0.
