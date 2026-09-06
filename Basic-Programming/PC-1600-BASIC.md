# PC-1600 BASIC — Pointer

> **STATUS: POINTER DOC.** PC-1600 BASIC reference material is not kept in this repo; it
> lives in the sibling `SharpBasicReference/` project. Created 2026-09-06 when that
> project was enhanced with a full PC-1600 BASIC reference.

## Why it isn't here

The PC-1600's BASIC is a near-superset of the PC-1500's (≈99 % shared token codes), so it
is documented for both machines together in `SharpBasicReference/` rather than split
between two corpora. See this repo's `README.md` — *Part 2 → PC-1600/* and *External
references* — for the standing policy that nothing is moved out of `SharpBasicReference/`.

## Where it lives

`~/Development/sharp/SharpBasicReference/`
([github.com/tinue/SharpBasicReference](https://github.com/tinue/SharpBasicReference)):

| File | What |
|---|---|
| `PC-1600-BASIC-Reference.md` | Full language reference — PC-1600 Operation Manual Part IV (ch. 8–14): operating modes (RUN/PRO/RESERVE, MODE 0 vs MODE 1), data representation and operators, files, serial ports, debugging, the command-dictionary index by category, appendices A–K, and the Systemhandbuch's internal data representation (X/Y/Z arithmetic registers; BCD-float / binary-int / string 8-byte encodings). **Appendix H** is the PC-1500 → PC-1600 porting guide. |
| `PC-1600-Command-Dictionary.md` | Per-command entries for the ≈200 commands (manual ch. 14), A–Z: format, abbreviation, purpose, remarks, examples. |
| `PC-1600-Error-Codes.md` | Error-code table: reworded PC-1500 codes 1–39 plus the PC-1600's three-digit subsystem codes (100–131 system/editing, 140–144 serial, 150–168 files). Codes 40–80 (PC-1500 peripherals) still apply in MODE 1. |
| `Command-Index.md` | Combined A–Z index across PC-1500 BASIC, CE-150, CE-158 **and** PC-1600 BASIC. |
| `PC-1500-BASIC-Reference.md`, `Error-Codes.md`, `CE-150-Reference.md`, `CE-158-Reference.md` | The PC-1500-side references the above build on. |

## Porting gotchas worth knowing before reading a PC-1500 program as PC-1600 code

From `PC-1600-BASIC-Reference.md` Appendix H and the command dictionary:

- **`LINE` → `LLINE`.** On the PC-1600 `LINE` draws on the 156×32 graphics *screen*;
  the *plotter* line command is `LLINE` (CE-1600P, or CE-150 in MODE 1). A PC-1500
  plotter program's `LINE -(x,y)` must become `LLINE -(x,y)` — and for code ported from
  the PC-1500's `LINE`, the `<type>` argument must be given explicitly, e.g.
  `LLINE -(x,y),0` (0 = solid).
- **`LCURSOR` → `TAB`**, **`CALL` → `XCALL`**, **`POKE`/`PEEK` → `XPOKE`/`XPEEK`** (the
  bare PC-1600 `CALL`/`POKE`/`PEEK` act on the Z-80A space); `TAB` (PC-1600) is a
  *screen* op — the printer analog is still `LCURSOR`.
- **`TIME = 0` cannot be set** on the PC-1600.
- **`LET` is mandatory inside a `THEN` / `ELSE` clause** (as on the PC-1500).
- **Early PC-1500s only:** `FOR…NEXT` leaves the counter one higher, and `IF…THEN`
  treats only `>0` as true where the PC-1600 treats `≠0` as true.

## Related in this corpus

- `Basic-Programming/sharp-basic-prompt.md` — the PC-1500 BASIC authoring prompt; **not**
  extended to the PC-1600.
- `Basic-Programming/reference/Tokenizer-Analysis.md`, `reference/Peripheral-Commands.md`
  — PC-1500 ROM tokenizer and CE-150/CE-158 token space (the shared-token angle).
- `PC-1600/` — the PC-1600 hardware / firmware / Z-80 machine-language sub-corpus.
