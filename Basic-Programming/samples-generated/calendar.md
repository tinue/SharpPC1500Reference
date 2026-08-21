### CALENDAR — Companion Guide (European Style)

#### Program Overview
The CALENDAR program generates a monthly calendar on the Sharp CE-150 plotter using the European standard (Monday as the first day of the week). The user provides a target date (yyyy-mm-dd), and the program calculates the layout, highlighting weekends in red and the target day in green.

#### How to Enter / Load

**Transfer via SharpDataExchange (recommended):**
Connect the PC-1500 and send `calendar.bas` using the SharpDataExchange tool.
*(Note: SharpDataExchange is not yet available on this Mac; transfer is pending.)*

**Manual entry:**
Type each numbered line exactly as shown in `calendar_clean.bas`. **Do not type the `//` lines** — they are not valid BASIC syntax on the device.

**Cassette:**
Use `CSAVE "CALENDAR"` to save and `CLOAD "CALENDAR"` to reload.

#### How to Run
1. Press **DEF** then **C** (or type `GOTO 10`).
2. Prompt: `Date (yyyy-mm-dd)? `
3. Enter the date and press **ENTER**.
4. Result: A multi-color calendar starts printing on the CE-150.

#### Variable Reference

| Variable | Type | Role |
|---|---|---|
| `D$` | String | User input date |
| `Y`, `M`, `D` | Numeric | Year, Month, Day extracted |
| `L` | Numeric | Leap year flag |
| `N` | Numeric | Days in month |
| `H` | Numeric | Zeller weekday (0=Sat) |
| `S` | Numeric | Start column (0=Mon, 6=Sun) |
| `I` | Numeric | Day loop counter |
| `C` | Numeric | Column counter (0–6) |
| `P` | Numeric | Pen position |
| `Z` | Numeric | Active pen color tracking |
| `K` | Numeric | Desired pen color |

#### Line Range Index

| Lines | Purpose |
|---|---|
| 10 | Program REM |
| 20–30 | Clear and load Month names |
| 40–70 | Input and parse date |
| 80–120 | Month length and leap year |
| 130–190 | Weekday of 1st (European mapping) |
| 200–230 | Printer setup and header |
| 240–320 | Main loop with color optimization |
| 330–350 | Cleanup |
| 360–380 | Data tables |

#### Algorithm Description
1. **Initialisation:** Resets variables and loads names.
2. **Parsing:** Extracts year, month, and day from ISO string.
3. **Weekday Calculation:** Uses Zeller's Congruence. The raw result `H` (where 0=Sat, 1=Sun, 2=Mon...) is mapped to `S` (where 0=Mon, ..., 6=Sun) using `S = H - 2` with modulo correction.
4. **Grid Plotting:**
   - Headers: ` Mon Tue Wed Thu Fri Sat Sun`.
   - Days: Right-aligned using `RIGHT$(" " + STR$(I), 2)` to ensure vertical alignment.
   - Weekend coloring: Saturday (col 5) and Sunday (col 6) use `COLOR 3` (Red).
   - Target day: Uses `COLOR 2` (Green).
5. **Optimization:** A tracking variable `Z` prevents redundant `COLOR` commands, protecting the CE-150's mechanical pen holder.

#### Known Limitations / Tips
- **Pen Slot Mapping:** Black=0, Green=2, Red=3.
- **European Standard:** This version starts the week on Monday. For Sunday-start calendars, use the previous version.
- **Alignment:** The `RIGHT$` padding ensures that " 1" aligns perfectly under "31".
