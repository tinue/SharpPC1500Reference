# PC-1600 Fixed ROM Jump Table (0000H–0312H)

## Scope

The **bank-independent, fixed-address** entry-point table at the very bottom of ROM
(0000H–0312H, mapped in all banks / always reachable with a plain `CALL xxxxH`, no
bank-switch needed). This is distinct from the per-bank `CALL Bank n, addr` entry points
documented elsewhere (`PC-1600-IOCS.md`, `PC-1600-Peripherals-Hardware.md`) — those live
inside a specific expansion-ROM bank; everything here is always callable regardless of
the current bank mapping. Several routines already named elsewhere in this corpus
(`BOUT`/`SOUT` in `PC-1600-IO-Ports.md` §6.1, `CALL 02DDH` in
`PC-1600-Work-Area-Map.md` §2.4, the file/COM/timer IOCS dispatchers in
`PC-1600-IOCS.md`) turn out to be entries in this same table — cross-referenced below.

**Source:** Systemhandbuch (David von Oheimb, *Das Systemhandbuch für den PC-1600*),
Appendix 8 "Sprungtabelle" (PDF pp. 115–122, printed pp. 115–122 / "Anhang 8" 1–8). The
manual gives only a one-line German gloss per routine — translated here, kept terse by
design (this is an index, not a functional spec; follow the cross-references for detail
where this corpus already has it).

**Note on RST vectors.** 0000H/0008H/0018H/0020H/0028H/0030H/0038H are the Z-80 `RST`
targets (`RST 00`, `RST 08`, … `RST 38`); several of them just forward through a pointer
held in the F0xx work area (`PC-1600-Work-Area-Map.md` §3 — e.g. `RST 08` → whatever
address is held at `F0CEH`, confirmed against that file's F0CE–F0D9 RST-vector entries).

**Caveat (source's own note):** "on some ROM versions, 4 more jumps follow [after
`0312H`], used only by the reset routine" — not enumerated by the source. **They are
present in the dumped (NEW-revision) ROM and are now enumerated** — see
[`PC-1600-ROM-Versions.md`](PC-1600-ROM-Versions.md) §4, which also identifies the two
BASIC ROM revisions "some ROM versions" refers to and how to tell them apart on a real
unit.

---

| Addr | Name | Function |
|---|---|---|
| 0000H | RESET | `RST 00`: warm start |
| 0005H | APO | Auto Power Off |
| 0008H | (RST 08 → `F0CEH`) | `RST 08`: jump to the vector held at `F0CEH` |
| 0015H | EXROMCAL | ROM-bit call; bit pattern in `DE` |
| 0018H | BANKJP | `RST 18`: bank jump |
| 001BH | JPHLA | jump to address `HL`, bank `A` |
| 0020H | BANKCAL | `RST 20`: bank call |
| 0023H | CHKMSG | for check/error messages |
| 0028H | (RST 28 → `F0D1H`) | `RST 28`: jump to the vector held at `F0D1H` |
| 002BH | APOTST | test whether Auto Power On is possible |
| 0030H | (RST 30 → `F0D4H`) | `RST 30`: jump to the vector held at `F0D4H` |
| 0035H | POCLOS | close all open files + power off |
| 0038H | (RST 38 → `F0D7H`) | `RST 38`: jump to the vector held at `F0D7H` (e.g. for IMI) |
| 003BH | SSLOTMP | set the system address for memory/program modules |
| 003EH | SETPRSLOT | set the system address `F050H`–`F05BH` |
| 0041H | WAKE$ | — |
| 0044H | WAKE$= | — |
| 0047H | CALL | — |
| 004AH | OUT | — |
| 004DH | POKE | — |
| 0050H | JAPAN | Japan-mode only |
| 0053H | JAPAN | Japan-mode only |
| 0056H | EXROMAWK | RAM allocation for ROM bank 3, address `6000H` |
| 0059H | *(unused)* | — |
| 005CH | POWER | — |
| 005FH | USGCNT | convert a number in `XX` (`FA10H`–`FA37H`) with `USING` format — same routine as `0298H SUSING` calls into, per the source's own "wie 005F" note at `029EH` |
| 0062H | TOKLEN | length in ASCII characters of the token in `DE` → `A` |
| 0066H | NMI | non-maskable interrupt (PC-1500 LCD emulation) |
| 006DH | SUSING2 | set `USING` parameters |
| 0070H–00B8H | (RAM calls) | RAM-relocated calls for the display routines |
| 00BBH–00BEH | (RAM calls) | RAM-relocated calls for the print routines |
| 00C1H–00D6H | (RAM calls) | RAM-relocated calls for the keyboard routines |
| 00D9H | (RAM call) | RAM-relocated call for the COM routine `CRCVI` |
| 00E5H | BSPCTR | display on/off |
| 00E8H | SLOTST | header test |
| 00EBH | PRTASTR | print `-A`, normal matrix only |
| 00EEH | PRTGSTR | Gprint character `(DE)`−`A` |
| 00F1H | PRTBSTR | print `-A` |
| 00F4H | LOC | — |
| 00F7H | LOF | — |
| 00FAH | EOF | — |
| 00FDH | DSKF | — |
| 0100H | PRTANK | print character `A` |
| 0103H | PRTDBL | print double-width character `DE` |
| 0106H | PRTASTRO | print `-00`, normal matrix only |
| 0109H | SETANK | home + clear cursor |
| 010CH | DBLMATR | possibly 16×8 matrix |
| 010FH | LWIDTH | 26/40-character mode |
| 0112H | CLS | clear screen |
| 0115H | CRSRSET | set X/Y coordinates |
| 0118H | CRSRPOS | get cursor coordinates |
| 011BH | RVSCHR | invert character |
| 011EH | CRSRSTAT | set cursor blink status |
| 0121H | LINE | draw a line |
| 0124H | BOX | draw a filled area |
| 0127H | DOTSET | set a point |
| 012AH | DOTREAD | read a 1-bit point |
| 012DH | UPSCRL | scroll forward |
| 0130H | DOWNSCRL | scroll backward |
| 0133H | CGMODE | IBM / PC-1500 character set |
| 0136H | CGSET80 | set character set for codes `≥80H` |
| 0139H | SMBLREAD | read status symbols |
| 013CH | SMBLSET | set status symbols |
| 013FH | EKSSTR | print a space |
| 0142H | INS1LN | insert a line |
| 0145H | ERS1LN | clear a line, without removing it |
| 0148H | GCRSRPOS | get graphics cursor |
| 014BH | GCRSRSET | set graphics cursor |
| 014EH | PRTGCHR | Gprint one character |
| 0151H | PRTGSTRO | Gprint character `-00` |
| 0154H | PRTGPTN | Gprint |
| 0157H | CPY150LCD | PC-1500 LCD emulation |
| 015AH | GPTNREAD | read an 8-bit point |
| 015DH | SAVELCD | copy a line into RAM |
| 0160H | LOADLCD | copy a line from RAM |
| 0163H | PRTBSTRO | print `-00` |
| 0166H | KEYGET | wait for a key |
| 0169H | KEYGETR | `INKEY` |
| 016CH | KBUFSET | set the keyboard buffer |
| 016FH | BREAKCHK | check for BREAK |
| 0172H | CURUDCHK | vertical cursor keys |
| 0175H | KEYDIRECT | currently-pressed key |
| 0178H | KEYSTRB | scan the key matrix |
| 017BH | KEYAUX | set the input source |
| 017EH | KEYSTATSET | click + repeat |
| 0181H | KEYSTATREAD | read key status |
| 0184H | OFFCHK | check the OFF key |
| 0187H | KEYGETND | `INKEY`, keeps the buffer |
| 018AH | BREAKRESET | clear the keyboard buffer |
| 018DH | MEMORYCHK | test whether memory is present |
| 0190H | BANKSET | bank select |
| 0193H | BANKREAD | read the selected bank |
| 0196H | SLOT1MAP | remap slot 1 |
| 0199H | SLOT2MAP | remap slot 2 |
| 019CH | BANKJUMP | jump to another bank |
| 019FH | BANKCALL | call a subroutine on another bank |
| 01A2H | RSLT150 | subroutine for printing the result on the CE-150 |
| 01A5H | FOTOK1500 | search the PC-1500 token table for commands with token `F0..` |
| 01A8H | TOK1500 | as above, for other commands |
| 01ABH | EXCOMM1500 | subroutine for `01AEH` |
| 01AEH | COMM1500 | PC-1500 commands (e.g. `XCALL`) |
| 01B1H | BANKCPY | `OUT 31,B` + `LDIR` |
| 01B4H | BOUT | beep — see `PC-1600-IO-Ports.md` §6.1 |
| 01B7H | SOUT (source: "SUUT") | beep once — see `PC-1600-IO-Ports.md` §6.1 |
| 01BAH | SWAIT | wait |
| 01BDH | BONOFF | beep on/off |
| 01C0H | BON | beep on |
| 01C3H | BUZON | buzzer on |
| 01C6H | CALLH | activate the second CPU (LH-5803) |
| 01C9H | P(A)OFF | for Power Off / Auto-Power-Off |
| 01CCH | INT150 | interrupt routine for PC-1500 peripherals |
| 01CFH | NMI | non-maskable interrupt (distinct from `0066H`'s NMI entry) |
| 01D2H | USCNVL | convert the number in `XX` with `USING` format, address in `HL` |
| 01D5H | TIMER | sub-CPU (RTC/timer/analog) routines — dispatcher, `PC-1600-IO-Ports.md` §7 |
| 01D8H | COM | serial-interface routines — dispatcher, `PC-1600-IOCS.md` §3.6 |
| 01DBH | JAPAN | Japan-mode only |
| 01DEH | FILE | file routines — dispatcher, `PC-1600-Filesystem.md` §3 |
| 01E1H | WPCHK | RAM-disk write-protect: slot in `A` → `B`; `v80` = write-protected |
| 01E4H | SETMDSKSIZ | set RAM-disk size, `F055H`/`F05BH` |
| 01E7H | INITMDSK | init slot `A`, `"F"` |
| 01EAH | POFF | for Power Off |
| 01EDH | PAOFF | for Auto-Power-Off |
| 01F0H | JAPAN | Japan-mode only |
| 01F3H | `^` (exponent) | — |
| 01F6H | AND | — |
| 01F9H | OR | — |
| 01FCH | CMPNUM | numeric comparison |
| 01FFH | CMPSTR | string comparison |
| 0202H | FUNC | BASIC functions |
| 0205H | `&` (hex numbers) | — |
| 0208H | CRSRVS | cursor, possibly inverted (on interrupt) |
| 020BH | CGNORM80 | normal character set, codes `≥80H` |
| 020EH | STATSYMGET | read status symbols |
| 0211H | STATSYMSET | set status symbols |
| 0214H | KEYSCAN | key query on interrupt |
| 0217H | KEYNORM | normal key table |
| 021AH | `+` | — |
| 021DH | `-` | — |
| 0220H | `*` | — |
| 0223H | `/` | — |
| 0226H | MOD | — |
| 0229H | `\` | — |
| 022CH–0234H | *(unused, 3 entries)* | — |
| 0235H | BANKPEEK | `PEEK#(HL)` |
| 0238H | BANKPOKE | `POKE#(HL)` |
| 023BH | SYSRESET | total reset of system RAM |
| 023EH | ASCBIN | ASCII `(HL)` → integer, `DE` |
| 0241H | BCBINS | BCD `XX` → two's complement, `DE` |
| 0244H | GETRESULT | get the last result (`XX`) as a string, `(DE)` |
| 0247H | BCDBIN | BCD `XX` → integer, `DE` |
| 024AH | BI2BCD | integer `DE` → `XX` (BCD) |
| 024DH | SCONT | set the `CONT` address |
| 0250H | SCA | for the CA key |
| 0253H | RESCA | CA after reset |
| 0256H | TOKENIZE | process the BASIC buffer — see `Basic-Programming/reference/Tokenizer-Analysis.md` for the PC-1500 sibling routine |
| 0259H | ARRAYIND | compute an array index address |
| 025CH | EOCHK2 | test statement-end code (`CR`, `":"`, else) |
| 025FH | LINLIST | read the line starting at `(HL)`, with the cursor address in `BC` → input buffer `F21DH`–`F31CH` |
| 0262H | DATSKP | skip, from the processing pointer `HL`, the rest of the line |
| 0265H | EOCHK3 | test statement-end |
| 0268H | BUFCLR | clear the input buffer, cursor position `00` |
| 026BH | EOCHK2 | same as `025CH` |
| 026EH | EOSCHK | test the attribute at `027DH` against the statement-end code |
| 0271H | SERROR | set the error address |
| 0274H | EXPRESS | numeric or string parameter → `XX` |
| 0277H | EXPREX | as `0274H`, but partial expressions are also evaluated |
| 027AH | ALLCLOSE | close all open files |
| 027DH | GETCDI | read the attribute of `(HL)` → `B`: b0 = single ASCII code → `A`; b1 = BASIC token → `DE`; b2 = binary-coded line number → `DE`; b3 = double-width ASCII; b4 = insert character |
| 0280H | BASTACKRES | reset the BASIC stack |
| 0283H | STRCNV | integer `HL` → string `(DE)` |
| 0286H | SLIST | set the `LIST` start |
| 0289H | VARPAR | variable parameter `(HL)` → address `DE` |
| 028CH | LINSRH | find the line `DE` or the next one → `F8A6H`–`F8A9H` |
| 028FH | AUTORUN | for `ARUN` |
| 0292H | VARNAME | variable name `(HL)` → encoding in `DE` |
| 0295H | RUNSET | set system addresses for `RUN` |
| 0298H | SUSING | `USING (HL)` |
| 029BH | CMPTOK | compare token `DE` against `(HL)` |
| 029EH | (= `005FH`) | — |
| 02A1H | VARLET | value in `XX` → copy into variable |
| 02A4H | VARGET | variable `(HL)` → copy into BASIC register `DE` |
| 02A7H | VARPEEK | peek logical address `(HL)` → `A` |
| 02AAH | POPDAT | pop data off the BASIC stack `(DE)` |
| 02ADH | VARLET2 | copy BASIC register `(HL)` → variable `(DE)` |
| 02B0H | VARPOKE | poke logical address `(HL)`, `A` |
| 02B3H | VARADR | address of the variable `DE` → `HL` |
| 02B6H | TOKSRH | token of the command ASCII `(HL)` → `DE`, code → `C`, length → `A` |
| 02B9H | TOK2ASC | token `DE` → ASCII `(HL)` |
| 02BCH | COMMADR | token `DE` → jump address `HL`, bank-out → `C`, code → `A` |
| 02BFH | EXROMCOM | as `02BCH`, but ROM-bit only (`F1BFH`) |
| 02C2H | EXROMBANK | bank-select the ROM module in `C` |
| 02C5H | LINSRH2 | find line `BC` from address `DE` |
| 02C8H | LINSRHREL | find line `BC` relative from address `(F89CH)` — e.g. for `GOTO` |
| 02CBH | EXCOMMEXE | execute the command token `(F35FH)` of a ROM module |
| 02CEH | LABSCH | find label `(HL)`, length `BC`, in all slots |
| 02D1H | LBSCH2 | as `02CEH`, but only in the slot currently selected via `TITLE` |
| 02D4H | TADCNV | bank-select logical bank `C` |
| 02D7H | LOGADR | convert logical address `DE` → physical address, `BC`, bank-out → `A` |
| 02DAH | LOGEND | logical address of the BASIC program end → `DE` |
| 02DDH | EXROM3WK | allocate `DE` bytes of ROM module 3's work area (for own use) — see `PC-1600-Work-Area-Map.md` §2.4 |
| 02DFH | EXROMWK | allocate `DE` bytes of the work area of the ROM module in `C`; RAM address → `HL` |
| 02E2H | DIRCOMEXE | execute a direct-command token `DE`, processing pointer `HL` |
| 02E5H | PRGEXE | run the program from `(FE00H)`, after calling `02BCH` |
| 02E8H | INPUT1 | for `INPUT` |
| 02EBH | INPUT1 (NXTADR) | for `PRINT`: start address of the line that follows the one at `HL`, logical bank → `A` |
| 02F1H | PASWPTST | test password and write-protect for the slot selected via `TITLE` → `sc` |
| 02F4H | PRGADR | set the BASIC start/end addresses, `FE3CH`–`FE41H` |
| 02F7H | EXROMCOMC | find the same token in another ROM module |
| 02FAH | RAMODSET | set the system addresses of the RAM modules, `A` = mode (`00`/`01`) |
| 02FDH | ALLOFF2 | plotter motors off |
| 0300H | LPRTASTR2 | `LPRINT B`* `(HL)` |
| 0303H | BINBCD | `DE` → BCD, BASIC register `(HL)` |
| 0306H | EOF2 | for `EOF` |
| 0309H | JAPAN | Japan-mode only |
| 030CH | EDRESET | editor reset |
| 030FH | PRTWAITK | print `(DE)`−`0D` and wait for a keypress |
| 0312H | BASPARES | set BASIC parameters after reset |

## Open items

- ~~The 4 extra reset-only jump entries the source says exist "on some ROM versions" past
  `0312H` — not enumerated by the source, not yet found by inspection.~~ **Found.** In the
  dumped NEW-revision ROM they are `0315H`/`0318H`/`031BH`/`031EH`, each `RST 18`
  (`BANKJP`) to `40E1H`/`40E4H`/`40E7H`/`40EAH` in **bank 3**, where a secondary table
  jumps on to `6BAFH`/`6BD0H`/`6BF0H`/`6C0BH`. Remaining unknowns: what that bank-3 code
  does, and whether the OLD revision is the one lacking these entries (inferred, not
  shown). Full working in [`PC-1600-ROM-Versions.md`](PC-1600-ROM-Versions.md) §4.
- Several German names transcribed as literally as legible could not be resolved to a
  confident English gloss (`RSLT150`, `EXCOMMEXE`/`EXCOMMEXE` family) — cross-check
  against a ROM disassembly if precision here matters.
