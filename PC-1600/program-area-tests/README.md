# PC-1600 program-area tests (Calc-U-1600)

Emulator tests for the open questions in `../PC-1600-Memory-Architecture.md` §4.0–§4.1 and §4b.5:
where BASIC and ML programs land when modules are merged into S0 or used as program areas,
what `(B)LOAD` does at a bank boundary, and what `MEM`, `SAVE`, `NEW` do per `TITLE` area.

All tests: **PC-1600, no plotter, a CE-1600M in each slot.** Each preset only sets the
machine up (memory split, `NEW` reservations, COM1:); **nothing is loaded by the preset**.
Programs go in by hand over COM1: with `sde`.

| File | What |
|---|---|
| `t1-merged-basic.pc1600` … `t4-merged-large-ml.pc1600` | the four presets |
| `t*.bas` | BASIC payloads: every line prints `<TAG>:<line>` + X padding |
| `t*.bin` | ML payloads with a PC-1600 header (load = bank:address, no auto-run). **Not code — never `CALL` them.** Content is 16-byte records `<TAG>@<file offset>......` |
| `make_tests.py` | regenerates all payloads |
| `analyze_dump.py` | turns a Debug-panel log into "which lines / which file offsets sit in which bank at which address" |

## Common procedure

**Once:** `sde config set pc1600emul.port ~/Calc-U-1600` (or add `--port ~/Calc-U-1600/calcu1600.serial` to every `sde` call).

**Load a preset:** File ▸ Load Preset…. The last line on the LCD shows the test name and `MEM`.
Expected `MEM` right after each preset (COM1: buffer of 4096 included):

| Test | `MEM` | why |
|---|---|---|
| 1 | 73 274 | 77 370 − 4096 |
| 2 | 3 839 | 11 834 − 3899 (S0 ML area) − 4096 |
| 3 | 7 738 | 11 834 − 4096 |
| 4 | 32 511 | 77 370 − 40 763 (S0 ML area) − 4096 |

**Send a file** — calculator first, then the computer:

| Payload | on the PC-1600 | on the computer |
|---|---|---|
| BASIC (`.bas`) | `LOAD"COM1:"` ENTER | `sde put t2_s1.bas --device pc1600emul` |
| ML (`.bin`) | `BLOAD"COM1:"` ENTER | `sde put t2_s1.bin --device pc1600emul` |
| get a program back | `sde get back.bas --device pc1600emul` first | then `SAVE"COM1:"` |

`NEW` (every form) is only valid in **PRO** mode; in RUN mode it gives ERROR 26.

**Collect the evidence:** in the Debug panel press **Clear**, then **Dump Card YAML** (both
slots — works for the CE-1600M since the `DebugPanel.cpp` fix of 2026-09-26) and
**Dump Mem** (its last section is internal RAM C000–FFFF). Copy the panel text into a file
and run

```sh
python3 analyze_dump.py log.txt
```

Quick look without the panel: `PRINT CHR$(PEEK#1,&8000);CHR$(PEEK#1,&8001)` etc.
Slot 1 = banks 0/1, Slot 2 = banks 2/3, each bank at 8000–BFFF.

---

## Test 1 — merged S0, one big BASIC program

Preset: both CE-1600Ms merged into S0 (boot default), `NEW0`, COM1:.

1. `LOAD"COM1:"` ← `t1_big.bas` (67 900 bytes tokenized, about 75 s). Then `PRINT MEM` (expected ≈ 5 400).
2. Dump + analyze.
3. `RUN` prints `T1:00010 …` in line order (just a sanity check; BREAK to stop).
4. Two quick checks:
   - `TITLE"S1:"` — which error is it? (101 expected: no program module)
   - in PRO: `NEW"S1:",&1000` — the emulator gives ERROR 24, the PASS/password error.

**Settles:**
- The fill order. Which segment holds line 10, and in what order do the lines continue?
  - Appendix B says S2 → S1 → internal RAM.
  - TRM §3.12.2 Example 1 says S1 (bank 0) → S2 (banks 2/3) → internal RAM.
- Whether S0's header + reserve sit at the first module's base, i.e. whether line 10 starts at xx C5+.
- Whether the second module is used from 8000 with no reserve of its own.

## Test 2 — program areas, small ML areas (inside one bank)

Preset: `INIT"S1:","P"`, `INIT"S2:","P"`, then in PRO `NEW"S0:",&1000`, `NEW"S1:",&1000`,
`NEW"S2:",&1000`. The ML areas are C0C5–CFFF (internal), bank 0 80C5–8FFF and bank 2 80C5–8FFF.
`TITLE"S0:"`.

1. **ML, `TITLE` left at S0:** `BLOAD"COM1:"` ← `t2_s0.bin`, then `t2_s1.bin` (header bank 0:80C5), then `t2_s2.bin` (bank 2:80C5). Each exactly fills its ML area.
2. **BASIC per area:**
   - `TITLE"S1:"`, `LOAD"COM1:"` ← `t2_s1.bas`
   - `TITLE"S2:"`, `LOAD"COM1:"` ← `t2_s2.bas`
   - `TITLE"S0:"`, `LOAD"COM1:"` ← `t2_s0.bas`
3. **For each of `TITLE"S0:"` / `"S1:"` / `"S2:"`:** `LIST` (which tag?), `PRINT MEM`, `RUN` (which tag is printed?).
4. Dump + analyze.
   - Expected: each BASIC program starts on the byte after its ML area (D000 / bank 0 9000 / bank 2 9000).
   - Expected: every ML record is intact.
5. **SAVE per area:** `TITLE"S2:"`, start `sde get back_s2.bas --device pc1600emul`, then `SAVE"COM1:"`. Does `back_s2.bas` contain the T2S2 lines? Repeat for S1 if in doubt.
6. **NEW vs. NEW0 in a program area**, with `TITLE"S1:"`:
   - PRO: `NEW` → `LIST` is empty.
   - `PRINT CHR$(PEEK#0,&80C5)` → `T` means the ML area survived.
   - `LOAD"COM1:"` ← `t2_s1.bas` again → it should land at bank 0 9000 again.
   - PRO: `NEW0`, then `LOAD"COM1:"` ← `t2_s1.bas` → does it now start at 80C5, over the old ML bytes?
   - Dump + analyze.
7. **Bare `TITLE`:** `TITLE"S2:"`, then `TITLE`, then `TITLE?` → 0 expected.

**Settles:**
- Does `LOAD` go to the TITLE-selected area?
- Does `SAVE` send the TITLE-selected program?
- What does `MEM` report under S1/S2? With empty areas the emulator reports 11 834 for all three.
- Is `BLOAD` placement fixed by the header, whatever `TITLE` is?
- `NEW` vs `NEW0` inside a program module.

## Test 3 — program areas, ML areas larger than one bank

Preset: both modules program areas. In PRO: `NEW"S1:",&5000` and `NEW"S2:",&5000`. Each ML area is
80C5–BFFF in the module's leading bank plus 8000–8FFF in its second bank (20 283 bytes).
`TITLE"S0:"`.

**A — one file across the bank boundary.** (It may spill into internal RAM, so reload the preset after each run.)

1. `BLOAD"COM1:"` ← `t3_s1.bin` (bank 0:80C5, 20 283 bytes; the last 4096 bytes go past BFFF).
2. Dump + analyze. Where did offsets 03F3B… go?
   - bank 1 at 8000: `BLOAD` switches banks.
   - internal RAM at C000: plain Z-80 addressing. That would overwrite S0's header, reserve and program, so note whether `LIST`/`MEM` still work.
   - an error.
3. Reload the preset and do the same with `t3_s2.bin` (bank 2 → bank 3?).

**B — split files, then BASIC.** Reload the preset.

1. `BLOAD` ← `t3_s1_lo.bin` (bank 0:80C5–BFFF), `t3_s1_hi.bin` (bank 1:8000–8FFF), `t3_s2_lo.bin`, `t3_s2_hi.bin`. The hi parts carry the same records the single file would put there.
2. `TITLE"S1:"`, `LOAD"COM1:"` ← `t3_s1.bas`. Then `TITLE"S2:"`, `LOAD"COM1:"` ← `t3_s2.bas`.
3. `LIST`/`RUN` per area, then dump + analyze. Expected: BASIC starts at bank 1 9000 and bank 3 9000.

**Settles:**
- Is `BLOAD` bank-aware across BFFF?
- Does the program area's BASIC continue in the module's second bank, straight after the logical end of the ML area?

## Test 4 — merged S0, one very large ML area

Preset: both modules merged. In PRO: `NEW"S0:",&A000` (40 763 bytes of ML area, `MEM` drops by exactly that).

1. `LOAD"COM1:"` ← `t4_probe.bas`, then dump + analyze. The first probe line sits right after the ML area's end, which shows where the merged S0's ML area really is. The expectation (§4.0, inferred) is bank 0 80C5 → bank 1 → 8 KB into the next segment in the test-1 fill order.
2. `BLOAD"COM1:"` ← `t4_ml_b0.bin` (header bank 0:80C5). If test 1 showed S2 first, use `t4_ml_b2.bin` (bank 2:80C5) instead. Dump + analyze.
   - **Caution:** if test 3A showed a linear spill into C000, these 40 763 bytes would run through C000–FFFF, including the work area and stack. Expect a crash, and skip this step or reload the preset afterwards.
3. `LIST`: is the probe program still intact after the `BLOAD`?

**Settles:**
- Where a merged S0 ML area starts and how it continues across modules (§4.0's S0 exception).
- What `BLOAD` does with a file larger than one bank in the merged case.

---

## Further tests worth adding

- **Mixed:** Slot 1 as a program area, Slot 2 merged (`INIT"S1:","P"` only), and the reverse.
  - Does S0's header move to bank 2 80C5?
  - Does `NEW"S1:"` work while Slot 2 is merged?
- **`PASS` with several areas:** does a password set under `TITLE"S0:"` also protect S1/S2 and block `TITLE`, as the manual says?
- **Too big for the selected area:** `TITLE"S1:"`, `LOAD` ← `t1_big.bas` into a 32 KB program module. ERROR 22 expected; does anything spill?
- **Real hardware:** repeat test 2 steps 3 and 7 on the real PC-1600 once a program module is available. The emulator runs the real ROM, but its bank logic is the emulator's own.
