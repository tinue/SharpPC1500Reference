# Sharp LH5801 Assembly Language Guide

This guide provides a technical overview of the Sharp LH5801 8-bit microprocessor architecture, registers, flags, and instruction set, based on the PC-1500 Technical Reference Manual and opcode tables.

---

## Quick Reference Card

A concise cheat sheet for writing correct PC-1500 assembly programs from scratch. An AI given this guide should be able to write common code from this section alone.

### Registers

| Reg | Bits | Purpose |
|---|---|---|
| **A** | 8 | Accumulator — all arithmetic and load/store goes through A |
| **XL/XH** | 8+8 | Byte regs; pair **X** = 16-bit data pointer / address |
| **YL/YH** | 8+8 | Byte regs; pair **Y** = 16-bit data pointer / address |
| **UL/UH** | 8+8 | Byte regs; pair **U** = 16-bit; UL is the `lop` counter |
| **S** | 16 | Stack pointer; starts at `0x784F`; decrements on push |
| **P** | 16 | Program counter |
| **T** | 8 | Status register (flags C, IE, Z, V, H in bits 0–4) |
| **PU/PV** | 1+1 | General-purpose flip-flops; used for bank switching |

### Status Flags

| Flag | Bit | Set when… | Important note |
|---|---|---|---|
| **C** | 0 | Carry out from bit 7 in addition; **no borrow** in subtraction | C=1 after CPA/SBC means ≥, not < |
| **IE** | 1 | Interrupts enabled | |
| **Z** | 2 | Result is zero | |
| **V** | 3 | Signed overflow (ADC/SBC/INC/DEC only) | NOT set by AND/OR/EOR |
| **H** | 4 | Half-carry (digit carry bit 3→4) | Used by BCD operations |

### ME0 vs ME1

`(addr)` accesses ME0. `#(addr)` accesses ME1 (ROM/extension). Most instructions have ME0 form only — see Limitations section.

Bank switching: `HIGH_BANK` = `spu` then `spv` → ME1. `LOW_BANK` = `rpu` then `spv` → ME0.

### 15 Most-Used Instructions

| Instruction | Operation | Flags |
|---|---|---|
| `lda (LABEL)` | A = memory at LABEL (ME0) | Z |
| `sta (LABEL)` | memory at LABEL = A | — |
| `ldi a,0xnn` | A = immediate byte | Z |
| `ldi xh,0xnn` then `ldi xl,0xnn` | X = 16-bit immediate | — |
| `adc (x)` | A = A + (X) + C | C,Z,V,H |
| `sbc (x)` | A = A − (X) − NOT(C) | C,Z,V,H |
| `inc a` / `inc x` | A++; or X++ (no flags) | C,Z,V,H / — |
| `dec a` / `dec x` | A--; or X-- (no flags) | C,Z,V,H / — |
| `cpa (x)` | A − (X) → flags; C=1 if A≥(X) | C,Z,V,H |
| `cpi a,0xnn` | A − n → flags | C,Z,V,H |
| `bcr+e` / `bcs+e` | Branch if C=0 / C=1 | — |
| `bzr+e` / `bzs+e` | Branch if Z=0 / Z=1 | — |
| `sjp LABEL` | Call subroutine at LABEL | — |
| `rtn` | Return from subroutine | — |
| `psh u` / `pop u` | Push/pop U pair (LIFO) | — |

### Minimal Program Skeleton

```asm
; Symbol definitions use .equ (with the dot):
MY_CONST     .equ    0x42

            .area   CODE (ABS)
            .org    0x7800          ; user program start (below CPU stack)

MY_PROG:
            ; --- body ---
            sec                 ; C=1 so BASIC writes X back to the variable
            rtn                 ; return to BASIC (called via CALL &7800)
```

Called from BASIC: `CALL &7800`

**Toolchain — building and assembling:**
- `sdaslh5801` is built from the sibling repo `sdcc-pc1500` (public: [github.com/pchambre/sdcc-pc1500](https://github.com/pchambre/sdcc-pc1500), not part of this repository — see this repo's README for the full sibling-repo map), from its `sdcc` checkout (`sdcc-pc1500/sdcc/`). Run `git submodule update --init` first if `sdcc/` isn't checked out yet, then `./configure && make` from inside `sdcc-pc1500/sdcc/`. The built binary ends up at `sdcc-pc1500/sdcc/bin/sdaslh5801` (or `sdcc/bin_vc/sdaslh5801.exe` for the native-Windows MSVC build).
- Assemble a source file directly with `sdaslh5801 -plosgff file.asm`, or use the `lh5801-asm` VS Code extension's **"LH5801: Assemble to BIN"** command, which runs `sdaslh5801` → `sdld` → `makebin` for you and produces a flat, loadable `<name>.bin` beside the source. No separate load-address prompt is needed — it's read straight out of the file's own `.area CODE (ABS)` / `.org` pair, so always include that header. `.lst`/`.ihx`/`.map` files are left in place beside the `.bin` in case a link error needs investigating.
- **Doing the same three steps by hand** (no VS Code, e.g. from a headless agent shell) — confirmed working end to end against a real `sdcc-pc1500` build:
  ```sh
  sdaslh5801 -plosgff file.asm          # -> file.rel, file.lst, file.sym
  sdld -i file file.rel                 # -> file.ihx (Intel hex)
  makebin -p -o 0x<ORG> file.ihx file.bin
  ```
  The `-o 0x<ORG>` on `makebin` is not optional: `makebin` maps Intel-hex addresses onto file offset 0, so a program `.org`'d at, say, `0x7C01` without `-o 0x7C01` produces a ~32 KB file that's almost entirely `0xFF` padding before the real 50-ish bytes of code. `-p` (pack) then truncates the file to the last occupied byte, so the two flags together give exactly the flat, loadable blob the VS Code extension itself produces — verify with `wc -c file.bin` against the `.lst` file's own last address minus `.org`.
- Disassemble a binary back to sdas source with `pc1500disasm`, e.g. `pc1500disasm --mode program --base 0xADDR file.bin -o file.asm` (default `--dialect sdas`, matching this project's own convention).

**File requirements:** ASCII text, Unix (LF) line endings — non-ASCII characters (Unicode arrows, em-dashes) and Windows CRLF line endings both risk parse errors.

### Running a program in the emulator (`pc1500preset`)

`pc1500preset` (public sibling repo to `pc1500emu`: [github.com/tinue/pc1500preset](https://github.com/tinue/pc1500preset) / [github.com/tinue/pc1500emu](https://github.com/tinue/pc1500emu) — neither is part of this repository) launches an unmodified `pc1500emu` binary and drives it entirely through its own FIFO/pipe scripting interface, from a single YAML `.pc1500` state file — no manual clicking through File > Load Binary or typing boot keystrokes by hand. This is the normal way to run an assembled program.

A minimal `.pc1500` file for a program assembled to `myprog.bin`, loaded at `0x00C5` and started via `CALL`:

```yaml
model: PC-1500
firmware: ../roms/PC-1500_A04.ROM

memory-expansion:
  - address: 0x0000
    size: 16k

pre-load-keys:
  - key: cl
  - type: NEW&200
  - key: mode

program:
  path: myprog.bin
  format: binary
  address: 0x00C5

post-load-keys:
  - type: CALL&C5
```

- `firmware`, `program.path`, and any `rom-modules[].path` resolve relative to the `.pc1500` file's own directory.
- `pre-load-keys` runs after the cold-boot reset but before the program loads (typically `NEW&<offset>` to protect the program's memory from BASIC); `post-load-keys` runs after — typically the `CALL` that starts it, plus any `wait`/`check` steps.
- Add a `check: 0` step to `post-load-keys` to turn the file into an automated pass/fail test (reads the live dot-matrix display for the digit `0`) instead of just an interactive launch. See `pc1500preset/docs/preset_file_format.md` for the full field reference (`rom-modules`, `basic-tokenized`/`basic-text` program formats, CE-163 module support, etc.) and `pc1500preset/samples/memtest.pc1500` for a complete worked example.

Launch it with:

```sh
./build/src/pc1500preset path/to/myprog.pc1500
```

This always cold-boots the emulator from the preset's own firmware/hardware sections; there's no "attach to an already-running instance" mode. If the script has no `check` step, the emulator window is left open afterward for interactive use.

### Loading a program onto real hardware

Once a program works correctly in the emulator, transfer it to a real PC-1500/PC-1500A over its serial port using `SharpDataExchange` (`/Users/me/Development/sharp/SharpDataExchange` locally; public repo, not part of this repository: [github.com/tinue/SharpDataExchange](https://github.com/tinue/SharpDataExchange)) and a CE-158X USB serial adapter (Jeff Birt's modern replacement for the original Sharp CE-158, connected via its USB port labeled **U1**; no driver setup needed on modern OSes).

For a raw assembled `.bin` with no CE-158 header, supply the load address explicitly (and a run address if it should auto-start on load):

```sh
java -jar SharpDataExchange.jar put --start-address 00C5 --run-address 00C5 myprog.bin
```

On the PC-1500 itself, **before** running the `put` command above:

```
SETDEV U1,CI,CO
CLOADM
```

(`SETDEV U1,CI,CO` redirects console I/O to the CE-158X's USB port; it must be re-entered after every power cycle or `NEW`. `CLOADM` — not plain `CLOAD`, which only loads BASIC programs — receives machine language.) The PC-1500 needs paced transmission — `SharpDataExchange` applies this automatically; if transfer is unreliable, check the USB cable and CE-158X connection before suspecting the program itself. See `SharpDataExchange/MANUAL.md` for BASIC-program transfer (`get`/`put`), Reserve Area backup, and PC-1600 wiring — this appendix only covers the machine-code-load path relevant to assembly programs.

---

## Architecture Overview

The Sharp LH5801 is an 8-bit CMOS microprocessor designed for low-power portable applications, most notably used in the Sharp PC-1500 (Radio Shack PC-2) pocket computers.

- **Data Bus:** 8-bit parallel.
- **Address Space:** 128 KB (split into two 64 KB banks: ME0 and ME1).
- **Machine Cycle:** Typically 1.3 MHz (with a 2.6 MHz crystal).
- **Instruction Set:** 82 documented instructions.

## Registers and Flags

### Internal Registers

| Symbol | | Name | Bits | Description |
|---|---|---|---|---|
| **P** | | Program counter | 16 | Indicates the address next to the address the CPU is now executing. It will be incremented by 1 when the next instruction is fetched. |
| **S** | | Stack pointer | 16 | Indicates the stack address. |
| **A** | | Accumulator | 8 | Used for retention of operational result or for data transfer with the external memory. |
| **Xreg** | XL | Data register | 8 | XL, XH, YL, YH, UL, UH comprise independent 8-bit registers. Also used as 16-bit data pointers Xreg, Yreg, and Ureg when used in a pair. |
| | XH | | 8 | |
| **Yreg** | YL | Data register | 8 | |
| | YH | | 8 | |
| **Ureg** | UL | Data register | 8 | |
| | UH | | 8 | |
| **TM** | | Timer counter | 9 | When 0 is set to TM, it stops the counter action. When anything other than 0 is set, it puts the counter into action. When TM turns full of 1 with the interrupt enable flag IE on, CPU executes an interrupt processing. |
| **PU** | | — | 1 | General-purpose flip-flop. |
| **PV** | | — | 1 | General-purpose flip-flop. |
| **DISP** | | — | 1 | LCD on/off control. |
| **T** | | Status register | 8 | Low order 5 bits represent one of five states of the operational result. |

P and S are internally split as `PH:PL` and `SH:SL` (high byte : low byte).

### Status Register (T)

```
Bit:  7   6   5   4   3   2   1   0
      0   0   0   H   V   Z  IE   C
```

| Bit | Flag | Name | Description |
|---|---|---|---|
| 7–5 | — | (unused) | Always 0. |
| 4 | **H** | Half Carry | Set if there is a carry from bit 3 to bit 4 (digit-to-digit carry). |
| 3 | **V** | Overflow | Set if a signed arithmetic overflow occurs (carry from bit 6 XOR carry from bit 7). |
| 2 | **Z** | Zero | Set if the result of an operation is zero. |
| 1 | **IE** | Interrupt Enable | Set to enable maskable and timer interrupts. |
| 0 | **C** | Carry | Set if there is a carry out from bit 7. **In subtractions, C=1 means NO BORROW.** |

### Carry Logic in Subtraction/Comparison
Unlike many common CPUs, the LH5801 Carry flag acts as a "No Borrow" bit during subtraction (`sbc`, `sbi`, `dcs`, `cpa`, `cpi`).
- **C = 1**: Result was positive or zero (no borrow occurred).
- **C = 0**: Result was negative (borrow occurred).

## Addressing Mode Reference

| Mode | Syntax | Example | Notes |
|---|---|---|---|
| Immediate 8-bit | `ldi a,0xnn` | `ldi a,0x42` | Literal byte value |
| Immediate 16-bit | `ldi s,0xnnnn` | `ldi s,0x7800` | S only; byte regs use 8-bit form |
| Register (byte) | `lda xl` | `lda uh` | XL, XH, YL, YH, UL, UH |
| ME0 absolute | `lda (0xnnnn)` | `lda (0x7800)` | Parentheses = memory access in ME0 |
| ME0 register indirect | `lda (x)` | `lda (u)` | Parens around 16-bit reg |
| ME0 absolute (label) | `lda (LABEL)` | `lda (ARX)` | Label resolves to 16-bit address |
| ME0 indirect + offset | `lda (LABEL+0xnn)` | `lda (ARX+0x07)` | Offset expression in parens |
| ME1 absolute | `lda #(0xnnnn)` | `lda #(LABEL)` | `#` prefix = ME1 bank |
| ME1 register indirect | `lda #(x)` | `lda #(u)` | Not all instructions have ME1 form |
| Post-increment load | `lin x` | `lin u` | A = (Rreg), Rreg++ |
| Post-decrement load | `lde x` | `lde u` | A = (Rreg), Rreg-- |
| Post-increment store | `sin x` | `sin y` | (Rreg) = A, Rreg++ |
| Post-decrement store | `sde x` | `sde u` | (Rreg) = A, Rreg-- |
| Relative branch | `bzs+e` / `bzs-e` | `bzs LABEL` | Assembler computes ±offset |

**Note:** `sta` syntax is symmetric with `lda` — `sta (LABEL)` stores A to ME0 address, `sta #(x)` stores to ME1.

**ME1 restriction:** Not all instructions support the ME1 `#(...)` form. Only: `lda/sta`, `adc/sbc`, `and/ora/eor`, `cpa/bit/bii`, `adi/ori/ani`, `dca/dcs`. `ldi`, `inc Rreg`, `dec Rreg`, `lin/sin/lde/sde`, `tin/cin` have no ME1 form.

---

## Memory Access and Bank Switching

The LH5801 uses two memory enable signals, **ME0** and **ME1**, allowing access to two 64 KB banks.

- **(addr)**: Access memory at `addr` in the **ME0** bank.
- **#(addr)**: Access memory at `addr` in the **ME1** bank.
- **(Rreg)**: Indirect access through register pair X, Y, or U in **ME0**.
- **#(Rreg)**: Indirect access through register pair X, Y, or U in **ME1**.

### Bank Switching (PC-1500)
Firmware often uses the `PU` and `PV` bits to control bank selection for specific hardware modules.
- **HIGH_BANK**: `spu` then `spv` (Set PU and PV)
- **LOW_BANK**: `rpu` then `spv` (Reset PU and Set PV)

---

## sdas Assembler Syntax

### Basic Syntax Rules

Confirmed against `pc1500preset/samples/memtest.asm`, the canonical working sdas source for this project.

- **Comments:** `;` to end of line
- **Labels:** code labels followed by `:`; casing is the programmer's own choice (this guide follows `memtest.asm`'s convention of uppercase labels)
- **Symbol definitions:** `.equ` (with the dot), e.g. `ENTRY .equ 0x00C5`
- **Hex literals:** `0x` prefix, C-style -- `0xC000`, `0xFF`, `0x42`
- **Current location:** a bare `.` refers to the address of the current instruction -- e.g. `OUT_OF_RANGE-.-1` for a relative branch-offset byte
- **No space after a comma** in a two-operand instruction -- `ldi a,0x42`, not `ldi a, 0x42` (matches this project's own disassembler output)
- **Expression syntax in operands:** `(LABEL + 0xnn)` -- e.g. `lda (ARX + 0x07)`
- **Program header:** wrap assembled code in `.area CODE (ABS)` followed by `.org <address>` -- the VS Code extension's "LH5801: Assemble to BIN" command reads the load address straight back out of this pair
- **No `.end` directive** -- sdas has none, and a real `sdaslh5801` build actively rejects a trailing `.end`. Just stop after the last instruction/data byte.
- **File encoding:** ASCII, Unix (LF) line endings

### Assembler Directives

| Directive | Usage | Example |
|---|---|---|
| `.area CODE (ABS)` | Declare an absolute code area (once, before the first `.org`) | `.area CODE (ABS)` |
| `.org 0xnnnn` | Set assembly origin within the current area | `.org 0xC000` |
| `.db 0xnn,...` | Emit byte(s) | `.db 0x55`, `.db 0xCD,0x71` |
| `.dw 0xnnnn` | Emit 16-bit word | `.dw 0xC4AF` |
| `.ascii "..."` | Emit ASCII string (no terminator) | `.ascii "HELLO"` |
| `LABEL .equ value` | Define constant (**dot required**) | `CPU_STACK .equ 0x7800` |
| `.include "file"` | Include another source file (standard sdas `.include`) | `.include "macros.inc"` |

### Standard Library Macros

These small address-arithmetic and bank-switch idioms come up constantly but are not built-in instructions. sdas has real macro support (`.macro`/`.endm`), but the expressions below are simple enough to just write inline wherever they're needed:

| Expression | Meaning |
|---|---|
| `(label)>>8` | High byte of `label`'s address |
| `(label)&0xFF` | Low byte of `label`'s address |
| `(label+n)>>8` | High byte of `label+n` |
| `(label+n)&0xFF` | Low byte of `label+n` |
| `>label` | High byte of `label` (sdas prefix operator, equivalent to `(label)>>8`) |
| `<label` | Low byte of `label` (sdas prefix operator, equivalent to `(label)&0xFF`) |
| `spu` then `spv` | HIGH_BANK -- switch to ME1 |
| `rpu` then `spv` | LOW_BANK -- switch to ME0 |

**Example — loading a 16-bit address into Y:**
```asm
            ldi     yh,(MY_TABLE)>>8
            ldi     yl,(MY_TABLE)&0xFF

; equivalent, using sdas's own prefix operators instead:
            ldi     yh,>MY_TABLE
            ldi     yl,<MY_TABLE
```

Both forms were confirmed byte-identical against a real `sdaslh5801` build (`>`/`<` are `asexpr.c`'s own high/low-byte-select operators, source `sdcc-pc1500/sdcc/sdas/asxxsrc/asexpr.c`, not a project-specific macro) — pick whichever reads better; this guide's own samples use both.

**`.equ` constants support address arithmetic directly**, so a block of related addresses can be defined once relative to a single base and relocated by editing only that base line:
```asm
D           .equ    0x7C01      ; move this one line to relocate the whole block
D_FLAG      .equ    D+0
D_RESULT_HI .equ    D+1
D_RESULT_LO .equ    D+2
```
`D_RESULT_HI` etc. assemble to plain absolute addresses (`0x7C02` here) — this is ordinary constant-folding at assemble time, not a runtime computation, and combines with `>`/`<` normally (`ldi yh,>D_RESULT_HI`).

**The V-prefix instructions** (`vej`, `vmj`, `vzs`, `vzr`) are real sdas mnemonics — ROM vector calls, not bare LH5801 instructions. See the VEJ/VMJ syntax rules in the Instruction Set Reference below.

### Typical Code Structure

```asm
; Symbol definitions -- use .equ (dot required)
MY_PARAM_ADDR   .equ    0x7C10

            .area   CODE (ABS)
            .org    0x7800          ; user RAM area

MY_ROUTINE:
            psh     u               ; save U
            ldi     ul,0x00         ; clear UL
            lda     (MY_PARAM_ADDR) ; load from absolute address
            cpi     a,0x0D          ; compare with carriage return
            bzs     MY_DONE         ; branch if zero set
            sta     (x)             ; store to [X]
            inc     x               ; X = X + 1
MY_DONE:
            pop     u               ; restore U
            sec                     ; C=1: BASIC writes X back to variable
            rtn                     ; return
```

---

## What Doesn't Exist — LH5801 Limitations

Critical for AI code generation: the LH5801 cannot do these things. Do not hallucinate instructions for them.

- **No 16-bit arithmetic on X/Y/U directly** — except `inc Rreg`, `dec Rreg`, `adr Rreg` (A → Rreg), and `sbr Rreg` (A from Rreg); there is no `ADD x,y` or `ldi x,0xnn`.
- **No 16-bit load immediate** — `ldi` only loads 8-bit values into byte registers (XL, XH, etc.) or a 16-bit address into S. To set X to 0xC000 you must write `ldi xh,0xC0` then `ldi xl,0x00`.
- **No memory-to-memory copy** — all copies must go through A: `lda (src)` then `sta (dst)`. Use `tin` in a loop for block copies.
- **No multiply or divide** — use ROM math routines (see ROM Subroutine Reference) or implement in software.
- **No bitwise NOT of A** — use `eai 0xFF` (XOR A with 0xFF) to invert all bits.
- **No stack pointer arithmetic** — there is no `ADD s,n`. Adjust S by using `ldx s` / `adr x` / `stx s`.
- **No conditional call or return** — all conditionals are relative branches (`bzs`, `bcr`, etc.). To call conditionally: branch over an `sjp`; to return conditionally: branch over an `rtn`.
- **No indirect jump through register** — `jmp` always uses an absolute address. `stx p` (opcode `0xFD 0x5E`) loads P from X and can be used as a register-indirect jump. `vej` is ROM-vector only.
- **No SBR instruction for all pairs** — `sbr` exists as the 16-bit subtract-register counterpart to `adr` but is undocumented; do not rely on it.
- **ME1 access is instruction-specific** — only the `#(addr)` / `#(Rreg)` forms of LDA/STA/ADC/SBC/AND/OR/EOR/CPA/BIT/BII/ADI/ORI/ANI/DCA/DCS access ME1. `ldi`, `inc`, `dec`, `tin`, `cin`, `lin`, `sin`, `lde`, `sde` have no ME1 form.
- **Flag V is only set by arithmetic** — `adc`, `sbc`, `inc` (8-bit), `dec` (8-bit). Logical operations (`and`, `ora`, `eor`, `ani`, etc.) do not set V.
- **`lop` only loops on UL** — cannot use XL, YL, or any other register as a loop counter with `lop`. To loop on another register, use `dec` + conditional branch.
- **No `FSM`/`SSM` block search** — the LH5801 has `cin` (compare-and-increment), but there is no single-instruction string search; build loops with `cin` + `lop`.
- **C=1 means NO BORROW in subtraction** — this is the inverse of many CPUs. After `cpa`/`sbc`/`cpi`: C=1 → result ≥ 0 (no borrow), C=0 → result < 0 (borrow).

---

## Common Patterns and Idioms

### 1. 16-bit Register Load (Immediate)

There is no `ldi x,0xnnnn`. Load each byte separately:

```asm
    ldi  xh,0x78         ; x = 0x7800
    ldi  xl,0x00
```

### 2. 16-bit Zero Check

There is no 16-bit zero flag. Test both bytes.

**Branch if zero (ORA form):** combine bytes into A via OR; Z=1 only if both are zero.
```asm
    lda  xh
    ora  (XL_addr)      ; need xl in memory; or: sta temp; lda xl; ora (temp)
    bzs  IS_ZERO
```

**Branch if nonzero (CPA form):** compare each byte against 0x00 and branch on first nonzero — no temp memory needed.
```asm
    ldi  a,0x00
    cpa  xh
    bzr  IS_NONZERO     ; xh != 0
    cpa  xl
    bzr  IS_NONZERO     ; xh==0 but xl != 0
    ; both bytes are zero
IS_NONZERO:
```

The CPA form is preferred when X (or another pair) holds both halves in registers and no memory slot is available for the OR trick.

### 3. 8-bit Counted Loop (LOP)

```asm
    ldi  ul,0x09         ; loop 10 times (ul = N-1 for N iterations)
LOOP:
    ; ... loop body ...
    lop  ul,LOOP        ; ul--; branch back if no borrow
```

**LOP iteration count:** `lop` branches on "no borrow" from the decrement. Decrementing from 1 to 0 is **no borrow** (it still branches); only decrementing from 0 to 0xFF is a borrow (falls through). Therefore `ldi ul,N` loops **N+1** times. **To loop exactly N times, use `ldi ul,N-1`.**

| LDI UL value | Iterations |
|---|---|
| 0 | 1 |
| 1 | 2 |
| 9 | 10 |
| 0xFF | 256 |

`lop` uses only UL. For a 16-bit count, use `dec x` + `bzr`.

### 4. Multi-byte Block Copy (LIN / SIN)

```asm
    ldi  xh,SRC>>8      ; x → source
    ldi  xl,SRC&0xFF
    ldi  yh,DST>>8      ; y → destination
    ldi  yl,DST&0xFF
    ldi  ul,COUNT-1     ; lop runs ul+1 times; use COUNT-1 for exactly COUNT iterations
COPY_LOOP:
    lin  x              ; a = (x), x++
    sin  y              ; (y) = a, y++
    lop  ul,COPY_LOOP
```

For ME1 source: use `lin #(x)` (not available — LIN has no ME1 form). Use `lda #(x)` then `inc x` instead.

### 5. Call a ROM Routine via SJP

```asm
    ldi  xh,ARG>>8      ; set up entry registers as required
    ldi  xl,ARG&0xFF
    sjp  SOME_ROM_FUNC  ; push return addr, jump to ROM
    ; return value typically in a or x
```

### 6. Call a ROM Routine via VMJ (inline parameters)

`vmj` takes a plain byte immediate (`0x` prefix, no parentheses). Inline parameter bytes after the call are written directly with `.db`.

```asm
    vmj  0x00            ; CD 00 -- call vmj vector 00
    .db 0x20           ; P1 -- lower bound
    .db 0x7E           ; P2 -- upper bound
    .db OUT_OF_RANGE-.-1  ; P3 -- relative forward branch offset if out of range
    ; falls through here if in range
OUT_OF_RANGE:
    ; ...
```

### 7. 16-bit Add A to Register Pair (ADR)

`adr` adds A into the full 16-bit register (A → RL, carry → RH):

```asm
    ldi  a,0x07
    adr  x              ; x = x + 7
```

For signed 16-bit addition of a larger value, load the low byte into A, use ADR, then handle the high byte manually.

### 8. Subtract Without Borrow (SBC with C=1 pre-set)

```asm
    sec                 ; C = 1 (no borrow preset)
    lda  MINUEND
    sbc  (SUBTRAHEND)   ; a = MINUEND - SUBTRAHEND (no borrow)
```

If C was 0 beforehand, you subtract an extra 1. Use `sec` before any standalone subtraction that should not include a borrow.

### 9. Negate A (Two's Complement)

```asm
    eai  0xFF            ; a = a XOR 0xFF (bitwise NOT)
    inc  a              ; a = ~a + 1 = -a
```

Or via subtraction: `sec`, then `ldi (temp),0x00`, then `sbc a` stores 0 - A - NOT(C) = -A.

### 10. Save / Restore Registers (PSH / POP Order)

Stack is LIFO — push order must be reversed on pop:

```asm
    psh  x              ; save x first
    psh  u              ; save u second
    ; ... work ...
    pop  u              ; restore u first (LIFO)
    pop  x              ; restore x second
```

Each `psh Rreg` decrements S by 2 (pushes RH then RL). Each `pop Rreg` increments S by 2 (pops RH then RL). Stack starts at `CPU_STACK + 0x4F` (0x784F).

**Early exit from a loop that uses PSH/POP:** if you jump out of a loop body (e.g. to a failure handler) before the matching `pop` instructions execute, the stack is left with unpopped bytes. Any subsequent `rtn` will pop those bytes instead of the real return address and jump to a garbage address — a hard crash. Always `pop` every register that was `psh`ed before jumping out of a loop, even on the error path.

### 11. BCD Arithmetic (DCA / DCS)

```asm
    sec                 ; no borrow for first digit
    lda  (BCD_A)        ; load BCD byte a
    dca  (BCD_B)        ; a = a + (BCD_B), BCD-adjusted
    sta  (BCD_RESULT)
```

`dca` does BCD addition (packed, 2 digits per byte). `dcs` does BCD subtraction.

### 12. Test a Single Bit

```asm
    bii  (TARGET),0x04   ; Z=1 if bit 2 is clear, Z=0 if set
    bzr  BIT_IS_SET
```

`bii` ANDs the operand with the mask and sets Z only. Neither A nor the operand is modified.

### 13. Find and Test Unused RAM

> **WARNING:** `ldx (x)` and `SBM` do **not exist** on the LH5801. `ldx` only takes register arguments (X, Y, U, S, P) -- there is no memory-indirect form. `SBM` is not a valid LH5801 instruction. `stx DATA_BASE` (STX to absolute address) is also invalid -- STX only takes register arguments. Do not use any of these.

Use this pattern to locate the free memory region between the BASIC program and BASIC variables. The approach below uses only confirmed-valid instructions, matching the style of `pc1500preset/samples/memtest.asm`:

```asm
; --- Locate TST_START = BASPRG_END + 1 ---
; BASPRG_END is a 16-bit big-endian pointer at 0x7867/0x7868.
; Read it byte-by-byte through a (there is no ldx (addr) form).
; ROM addresses: use .equ for fixed system pointers (never change).
; Scratch variables: declare as labels with .db at end of program
;   (not .equ to hardcoded addresses — that is brittle and error-prone).
BASPRG_ENDH  .equ 0x7867
BASPRG_ENDL  .equ 0x7868
VAR_STARTH   .equ 0x7899
VAR_STARTL   .equ 0x789A

    lda  (BASPRG_ENDH)
    sta  xh
    lda  (BASPRG_ENDL)
    sta  xl
    inc  x                  ; x = BASPRG_END + 1 (16-bit, no flags)
    lda  xh
    sta  (TST_STARTH)
    lda  xl
    sta  (TST_STARTL)

; --- Locate TST_END = VAR_START - 1 ---
    lda  (VAR_STARTH)
    sta  xh
    lda  (VAR_STARTL)
    sta  xl
    dec  x                  ; x = VAR_START - 1
    lda  xh
    sta  (TST_ENDH)
    lda  xl
    sta  (TST_ENDL)

; ... rest of program ...

; Scratch variables — declared as labels, assembled into the binary.
; The assembler assigns their addresses automatically; no hardcoded .equ needed.
TST_STARTH:  .db 0x00
TST_STARTL:  .db 0x00
TST_ENDH:    .db 0x00
TST_ENDL:    .db 0x00
```

**Key addresses:**

| Symbol | Address | Meaning |
|---|---|---|
| `0x7867/0x7868` | `BASPRG_END` | 16-bit big-endian pointer: end of BASIC program |
| `0x7899/0x789A` | `VAR_START` | 16-bit big-endian pointer: start of variable area |

**Notes:**
- These addresses are only valid from a `CALL`ed assembly routine -- BASIC must already be loaded.
- `inc x` / `dec x` operate on the 16-bit register pair without setting flags.
- Variables grow downward from `VAR_START`; your data must fit in the gap.
- For a permanent workspace, use `NEW &<decimal address>` from BASIC to reserve space before loading the program.
- There is no `ldx (addr)` (load X from memory indirect) -- all 16-bit address loading requires two separate `lda`/`sta` byte operations through A.

### 14. X as Bidirectional BASIC Parameter (Input + Result Code)

`CALL addr, VAR` loads the numeric variable into Xreg on entry and — when the routine returns with C=1 — writes Xreg back to the variable. This lets a single variable serve as both the input argument and the return code.

```asm
; BASIC:
;   10 N = 4               ; pass count / receives result
;   20 CALL &7C01, N
;   30 IF N=0 THEN PRINT "OK"
;   40 IF N=1 THEN PRINT "FAIL"
;   50 IF N=2 THEN PRINT "BAD INPUT"
;
; Entry: Xreg = value of N (consumed as input)
; Exit:  Xreg = result code; C=1 so BASIC writes it back to N

MY_ROUTINE:
    ;-- validate: reject zero input --
    ldi  a,0x00
    cpa  xh
    bzr  INPUT_OK       ; xh != 0, input is valid
    cpa  xl
    bzr  INPUT_OK       ; xl != 0, input is valid
    ; input is zero -- return code 2
    ldi  xh,0x00
    ldi  xl,0x02
    sec
    rtn

INPUT_OK:
    ; ... use Xreg as the input value; overwrite it before returning ...

    ; Success path
    ldi  xh,0x00
    ldi  xl,0x00         ; result code 0
    sec
    rtn

FAIL:
    ldi  xh,0x00
    ldi  xl,0x01         ; result code 1
    sec
    rtn
```

**Key points:**
- X is consumed immediately as input; there is no separate "input register" and "output register" -- the same Xreg slot is reused for the return code before `sec; rtn`.
- BASIC reads N once before `CALL` and reads the (overwritten) N once after -- the caller never needs a second variable.
- Return codes are 16-bit; use the high byte for extended codes if needed.

---

### 15. Priming T to an Exact Bit Pattern for a Flag-Behavior Test

There is no immediate-load for T -- the only way to write it is `att` (`a → t`, all 5 bits overwritten unconditionally, see the ATT entry below), so setting T to a literal value always routes through A first. This matters when the routine under test also needs a *specific* value in A (not whatever `att` happened to leave behind), because almost every way of loading a new value into A -- `ldi a,n`, `lda ...`, `tta`, `pop a`, `and`/`ora`/`eor` -- sets the Z flag from the loaded/computed result as a side effect (`ldi RL,n`/`ldi RH,n` into the byte registers are the exception: no flag changes, see the LDI entry below). A careless reload of A after `att` can silently corrupt the very T value the test is trying to hold steady.

The fix is to pick the post-`att` A value so its own Z side effect is a no-op against the T bit pattern already in place -- most simply, by choosing a T value whose Z bit already matches whether the follow-up A load is zero or not:

```asm
; Goal: T = 0x1F (IE|H|V|Z|C all set) going into some instruction under
; test, with A = 0x00 as that instruction's own operand.
            ldi     a,0x1F
            att                 ; T = 0x1F -- direct overwrite, all 5 bits
; A must become 0x00 for the instruction under test, but "ldi a,0x00"
; sets Z from the loaded value (0x00 -> Z=1) -- which 0x1F's own Z bit
; (bit 2) already is, so this is a no-op against T:
            ldi     a,0x00      ; A = 0x00; T is still 0x1F
            adr     u           ; the instruction under test
```

If the needed A value and the needed T pattern don't line up this conveniently, `psh a` / `pop a` (`0xC8` / `0xFD 0x8A`) around the reload is the general-purpose fix -- `pop a` does set Z too, but from the popped value itself, which is exactly what was pushed, so no information is lost; T's other bits (C/V/H/IE) are never touched by push/pop at all. Confirmed against `Core/CPU/LH5801/LH5801.cpp` in the `Calc-U-1600` sibling project (this user's own, not part of this repo) and exercised end to end in `examples/debug/instrquirks_1500a.asm`'s ADR test.

---

## Instruction Set Reference

### Compact Instruction Summary

One row per mnemonic; most common forms shown. `●`=may change, `—`=unchanged, `1`=forced set, `0`=forced reset.

| Mnemonic | Common forms | Bytes | Cycles | C | Z | V | H | Notes |
|---|---|---|---|:---:|:---:|:---:|:---:|---|
| `lda` | `reg`, `(addr)`, `#(addr)`, `(Rreg)` | 1–4 | 5–16 | — | ● | — | — | Load A |
| `ldi` | `a,n` / `RL,n` / `RH,n` / `s,pp` | 2–3 | 6–12 | — | ● | — | — | Z only on `ldi a,n` |
| `sta` | `reg`, `(addr)`, `(Rreg)` | 1–4 | 5–16 | — | — | — | — | Store A |
| `ldx` | `y` / `u` / `s` / `p` | 2 | 11 | — | — | — | — | 16-bit load to X |
| `stx` | `y` / `u` / `s` / `p` | 2 | 11 | — | — | — | — | 16-bit store from X |
| `lin` | `x` / `y` / `u` | 1 | 6 | — | ● | — | — | Load A, Rreg++ |
| `lde` | `x` / `y` / `u` | 1 | 6 | — | ● | — | — | Load A, Rreg-- |
| `sin` | `x` / `y` / `u` | 1 | 6 | — | — | — | — | Store A, Rreg++ |
| `sde` | `x` / `y` / `u` | 1 | 6 | — | — | — | — | Store A, Rreg-- |
| `adc` | `reg`, `(addr)`, `#(addr)` | 1–4 | 6–17 | ● | ● | ● | ● | A = A + op + C |
| `adi` | `a,n` / `(Rreg),n` | 2–5 | 7–23 | ● | ● | ● | ● | Add immediate |
| `adr` | `x` / `y` / `u` | 2 | 11 | ● | ● | ● | ● | 16-bit: Rreg = Rreg + A |
| `sbc` | `reg`, `(addr)`, `#(addr)` | 1–4 | 6–17 | ● | ● | ● | ● | A = A − op − NOT(C); C=1=no borrow |
| `sbi` | `a,n` | 2 | 7 | ● | ● | ● | ● | Subtract immediate |
| `dca` | `(Rreg)` | 1–2 | 15–19 | ● | ● | ● | ● | BCD add |
| `dcs` | `(Rreg)` | 1–2 | 13–17 | ● | ● | ● | ● | BCD subtract |
| `inc` | `a` / `RL` / `RH` / `Rreg` | 1–2 | 5–9 | ● | ● | ● | ● | 16-bit form: no flags |
| `dec` | `a` / `RL` / `RH` / `Rreg` | 1–2 | 5–9 | ● | ● | ● | ● | 16-bit form: no flags |
| `cpa` | `reg`, `(addr)`, `#(addr)` | 1–4 | 6–17 | ● | ● | ● | ● | Compare A; C=1 if A≥op |
| `cpi` | `a,n` / `RL,n` / `RH,n` | 2 | 7 | ● | ● | ● | ● | Compare immediate |
| `and` | `(addr)`, `(Rreg)` | 1–4 | 7–17 | — | ● | — | — | A = A & op |
| `ani` | `a,n` / `(Rreg),n` | 2–5 | 7–23 | — | ● | — | — | AND immediate |
| `ora` | `(addr)`, `(Rreg)` | 1–4 | 7–17 | — | ● | — | — | A = A \| op |
| `ori` | `a,n` / `(Rreg),n` | 2–5 | 7–23 | — | ● | — | — | OR immediate |
| `eor` | `(addr)`, `(Rreg)` | 1–4 | 7–17 | — | ● | — | — | A = A ^ op |
| `eai` | `n` | 2 | 7 | — | ● | — | — | A = A ^ n |
| `bit` | `(addr)`, `(Rreg)` | 1–4 | 7–17 | — | ● | — | — | A & op → Z only |
| `bii` | `a,n` / `(Rreg),n` | 2–5 | 7–20 | — | ● | — | — | Bit test immediate |
| `rol` | — | 1 | 8 | ● | — | — | — | Rotate A left through C |
| `ror` | — | 1 | 9 | ● | — | — | — | Rotate A right through C |
| `shl` | — | 1 | 6 | ● | — | — | — | Shift A left; 0→bit0 |
| `shr` | — | 1 | 9 | ● | — | — | — | Shift A right; 0→bit7 |
| `drl` | `(x)` / `#(x)` | 1–2 | 12–16 | — | — | — | — | Digit rotate left (4-bit) |
| `drr` | `(x)` / `#(x)` | 1–2 | 12–16 | — | — | — | — | Digit rotate right (4-bit) |
| `aex` | — | 1 | 6 | — | — | — | — | Swap nibbles of A |
| `tin` | — | 1 | 7 | — | — | — | — | (X)→(Y), X++, Y++ |
| `cin` | — | 1 | 7 | ● | ● | ● | ● | A−(X)→flags, X++ |
| `psh` | `a` / `Rreg` | 2 | 11–14 | — | — | — | — | Push to stack |
| `pop` | `a` / `Rreg` | 2 | 12–15 | — | ● | — | — | Z only on `pop a` |
| `att` | — | 2 | 9 | — | — | — | — | A → T (all flags) |
| `tta` | — | 2 | 9 | — | ● | — | — | T → A |
| `jmp` | `pp` | 3 | 12 | — | — | — | — | Unconditional jump |
| `bch` | `±e` | 2 | 8–9 | — | — | — | — | Unconditional relative |
| `bcs/bcr` | `±e` | 2 | 8–11 | — | — | — | — | Branch on C |
| `bzs/bzr` | `±e` | 2 | 8–11 | — | — | — | — | Branch on Z |
| `bvs/bvr` | `±e` | 2 | 8–11 | — | — | — | — | Branch on V |
| `bhs/bhr` | `±e` | 2 | 8–11 | — | — | — | — | Branch on H |
| `lop` | `ul,e` | 2 | 8–11 | — | — | — | — | UL--; branch if no borrow |
| `sjp` | `pp` | 3 | 19 | — | — | — | — | Call subroutine |
| `vej` | `(C0)–(FE)` | 1 | 17 | — | 0 | — | — | ROM vector call (1-byte); syntax: `vej (nn)`, no `0x` prefix inside parens |
| `vmj` | `0x00–0xBE` | 2 | 20 | — | 0 | — | — | ROM vector call (2-byte); syntax: `vmj 0xnn` no parens |
| `vcs/vcr` | `i` | 2 | 8/21 | — | 0 | — | — | Conditional vector call on C |
| `vzs/vzr` | `i` | 2 | 8/21 | — | 0 | — | — | Conditional vector call on Z |
| `vhs/vhr` | `i` | 2 | 8/21 | — | 0 | — | — | Conditional vector call on H |
| `vvs` | `i` | 2 | 8/21 | — | 0 | — | — | Conditional vector call on V |
| `rtn` | — | 1 | 11 | — | — | — | — | Return from subroutine |
| `rti` | — | 1 | 14 | ● | ● | ● | ● | Return from interrupt (restores T) |
| `sec/rec` | — | 1 | 4 | 1/0 | — | — | — | Set/reset carry |
| `sie/rie` | — | 2 | 8 | — | — | — | — | Set/reset interrupt enable |
| `spu/rpu` | — | 1 | 4 | — | — | — | — | Set/reset PU flip-flop |
| `spv/rpv` | — | 1 | 4 | — | — | — | — | Set/reset PV flip-flop |
| `sdp/rdp` | — | 2 | 8–9 | — | — | — | — | Set/reset display (LCD on/off) |
| `am0/am1` | — | 2 | 9 | — | — | — | — | A → timer (bit8=0/1) |
| `atp` | — | 2 | 9 | — | — | — | — | A → output port |
| `ita` | — | 2 | 9 | — | ● | — | — | Input port → A |
| `cdv` | — | 2 | 8 | — | — | — | — | Clear clock divider |
| `nop` | — | 1 | 5 | — | — | — | — | No operation |
| `hlt` | — | 2 | 9 | — | — | — | — | Halt until interrupt |
| `off` | — | 2 | 8 | — | — | — | — | Power off (reset BF) |

---

### Notation and Conventions

| Symbol | Meaning |
|---|---|
| **RL** | XL, YL, or UL (low byte of a register pair) |
| **RH** | XH, YH, or UH (high byte of a register pair) |
| **Rreg** | X, Y, or U (16-bit register pair) |
| **(Rreg)** | Contents of memory at address in Rreg, accessed via ME0 |
| **#(Rreg)** | Contents of memory at address in Rreg, accessed via ME1 |
| **(pp)** | Memory at absolute 16-bit address `pp`, ME0 |
| **#(pp)** | Memory at absolute 16-bit address `pp`, ME1 |
| **n / i** | 8-bit immediate data |
| **pp** | 16-bit immediate address (high byte `a` first, then low byte `b`) |
| **e** | 8-bit relative offset |
| **→** | Data transfer direction |
| **∧** | AND |
| **∨** | OR |
| **⊕** | Exclusive OR |

**Flag columns:** `C` = Carry, `Z` = Zero, `V` = Overflow, `H` = Half Carry.
`●` = may change, `—` = unchanged, `1` = forced set, `0` = forced reset.

**Opcode prefix `FD`:** Instructions prefixed with `0xFD` are two-byte instructions where `0xFD` is the first byte.

**Register encoding in opcodes:** Most instructions encode the register pair in bits 5:4 of the opcode: `00`=X, `01`=Y, `10`=U. The encoding `11` (V) is **undocumented** and not guaranteed on all hardware revisions. These are marked **(undoc)** below.

---

### Add, Subtract, and Logical Instructions

#### ADC — Add with Carry
`a = a + [operand] + C`
**Flags:** C, V, H, Z may change.

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `adc xl` | A = A + XL + C | `0x02` | 1 | 6 |
| `adc yl` | A = A + YL + C | `0x12` | 1 | 6 |
| `adc ul` | A = A + UL + C | `0x22` | 1 | 6 |
| `adc xh` | A = A + XH + C | `0x82` | 1 | 6 |
| `adc yh` | A = A + YH + C | `0x92` | 1 | 6 |
| `adc uh` | A = A + UH + C | `0xA2` | 1 | 6 |
| `adc (x)` | A = A + (X) + C  (ME0) | `0x03` | 1 | 7 |
| `adc (y)` | A = A + (Y) + C  (ME0) | `0x13` | 1 | 7 |
| `adc (u)` | A = A + (U) + C  (ME0) | `0x23` | 1 | 7 |
| `adc (pp)` | A = A + (pp) + C (ME0) | `0xA3 a b` | 3 | 13 |
| `adc #(x)` | A = A + (X) + C  (ME1) | `0xFD 0x03` | 2 | 11 |
| `adc #(y)` | A = A + (Y) + C  (ME1) | `0xFD 0x13` | 2 | 11 |
| `adc #(u)` | A = A + (U) + C  (ME1) | `0xFD 0x23` | 2 | 11 |
| `adc #(pp)` | A = A + (pp) + C (ME1) | `0xFD 0xA3 a b` | 4 | 17 |

---

#### ADI — Add Immediate
`adi a,n`: `a = a + n + C` (carry is included when operand is accumulator).
`adi (Rreg),n`: `[operand] = [operand] + n` (no carry, result stored back to memory).
**Flags:** C, V, H, Z may change.

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `adi a,n` | A = A + n + C | `0xB3 n` | 2 | 7 |
| `adi (x),n` | (X) = (X) + n  (ME0) | `0x4F n` | 2 | 13 |
| `adi (y),n` | (Y) = (Y) + n  (ME0) | `0x5F n` | 2 | 13 |
| `adi (u),n` | (U) = (U) + n  (ME0) | `0x6F n` | 2 | 13 |
| `adi (pp),n` | (pp) = (pp) + n (ME0) | `0xEF a b n` | 4 | 19 |
| `adi #(x),n` | (X) = (X) + n  (ME1) | `0xFD 0x4F n` | 3 | 17 |
| `adi #(y),n` | (Y) = (Y) + n  (ME1) | `0xFD 0x5F n` | 3 | 17 |
| `adi #(u),n` | (U) = (U) + n  (ME1) | `0xFD 0x6F n` | 3 | 17 |
| `adi #(pp),n` | (pp) = (pp) + n (ME1) | `0xFD 0xEF a b n` | 5 | 23 |

---

#### DCA — Decimal Add
BCD addition between accumulator and memory, including carry. The operation:
1. `a = a + 0x66`
2. `a = a + [operand] + C`
3. `a = a + DA` (decimal compensation based on C and H flags)

**Flags:** C, V, H, Z may change.

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `dca (x)` | A = A + (X) BCD (ME0) | `0x8C` | 1 | 15 |
| `dca (y)` | A = A + (Y) BCD (ME0) | `0x9C` | 1 | 15 |
| `dca (u)` | A = A + (U) BCD (ME0) | `0xAC` | 1 | 15 |
| `dca #(x)` | A = A + (X) BCD (ME1) | `0xFD 0x8C` | 2 | 19 |
| `dca #(y)` | A = A + (Y) BCD (ME1) | `0xFD 0x9C` | 2 | 19 |
| `dca #(u)` | A = A + (U) BCD (ME1) | `0xFD 0xAC` | 2 | 19 |

---

#### ADR — Add Register (16-bit)
Adds the accumulator to the full 16-bit register pair. `RL + a → RL`, then `RH + C → RH`.

**Flags: UNCHANGED — this contradicts the Sharp Technical Reference Manual's own text**, which documents ADR as publishing C/V/H/Z from the internal 8-bit low-byte addition (as this entry itself used to say). Real-hardware testing settled it the other way: silicon preserves the caller's flags across ADR, full stop. This was confirmed by a reproducible bug — the PC-1500's own ROM key-dispatch path relies on carry surviving an `adr y`/`rtn` pair to redraw the display correctly after Up/Down in PRO mode; an ADR that clobbers flags (as MAME's implementation still does, as of this writing) breaks that redraw. Treat any emulator/tool that clobbers C/V/H/Z on ADR as buggy, not the manual's description as authoritative.
- Empirical test + write-up: sibling project `Calc-U-1600` (this user's own, not part of this repo), `examples/debug/adrtest_1500a.asm` (single-purpose: SEC then `adr x` with a guaranteed-no-carry add, reads carry back) and `examples/debug/instrquirks_1500a.asm` (broader 3-instruction test, see the DRL/DRR entries below); background in that project's `docs/Up-Down-Key-Investigation.md`, "The ADR conflict".

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `adr x` | X = X + A (16-bit) | `0xFD 0xCA` | 2 | 11 |
| `adr y` | Y = Y + A (16-bit) | `0xFD 0xDA` | 2 | 11 |
| `adr u` | U = U + A (16-bit) | `0xFD 0xEA` | 2 | 11 |

---

#### SBC — Subtract with Carry
`a = a - [operand] - NOT(C)` (equivalently, `a = a + complement([operand]) + C`).
**Flags:** C, V, H, Z may change. **C=1 means no borrow.**

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `sbc xl` | A = A - XL - NOT(C) | `0x00` | 1 | 6 |
| `sbc yl` | A = A - YL - NOT(C) | `0x10` | 1 | 6 |
| `sbc ul` | A = A - UL - NOT(C) | `0x20` | 1 | 6 |
| `sbc xh` | A = A - XH - NOT(C) | `0x80` | 1 | 6 |
| `sbc yh` | A = A - YH - NOT(C) | `0x90` | 1 | 6 |
| `sbc uh` | A = A - UH - NOT(C) | `0xA0` | 1 | 6 |
| `sbc (x)` | A = A - (X) - NOT(C)  (ME0) | `0x01` | 1 | 7 |
| `sbc (y)` | A = A - (Y) - NOT(C)  (ME0) | `0x11` | 1 | 7 |
| `sbc (u)` | A = A - (U) - NOT(C)  (ME0) | `0x21` | 1 | 7 |
| `sbc (pp)` | A = A - (pp) - NOT(C) (ME0) | `0xA1 a b` | 3 | 13 |
| `sbc #(x)` | A = A - (X) - NOT(C)  (ME1) | `0xFD 0x01` | 2 | 11 |
| `sbc #(y)` | A = A - (Y) - NOT(C)  (ME1) | `0xFD 0x11` | 2 | 11 |
| `sbc #(u)` | A = A - (U) - NOT(C)  (ME1) | `0xFD 0x21` | 2 | 11 |
| `sbc #(pp)` | A = A - (pp) - NOT(C) (ME1) | `0xFD 0xA1 a b` | 4 | 17 |

---

#### SBI — Subtract Immediate
`a = a - n - NOT(C)`
**Flags:** C, V, H, Z may change. **C=1 means no borrow.**

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `sbi a,n` | A = A - n - NOT(C) | `0xB1 n` | 2 | 7 |

---

#### DCS — Decimal Subtract
BCD subtraction. `a = a - [operand] - NOT(C)` with decimal adjustment.
**Flags:** C, V, H, Z may change. **C=1 means no borrow.**

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `dcs (x)` | A = A - (X) BCD (ME0) | `0x0C` | 1 | 13 |
| `dcs (y)` | A = A - (Y) BCD (ME0) | `0x1C` | 1 | 13 |
| `dcs (u)` | A = A - (U) BCD (ME0) | `0x2C` | 1 | 13 |
| `dcs #(x)` | A = A - (X) BCD (ME1) | `0xFD 0x0C` | 2 | 17 |
| `dcs #(y)` | A = A - (Y) BCD (ME1) | `0xFD 0x1C` | 2 | 17 |
| `dcs #(u)` | A = A - (U) BCD (ME1) | `0xFD 0x2C` | 2 | 17 |

---

#### AND — Logical AND (Accumulator)
`a = a and [operand]`
**Flags:** Z only.

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `and (x)` | A = A & (X)  (ME0) | `0x09` | 1 | 7 |
| `and (y)` | A = A & (Y)  (ME0) | `0x19` | 1 | 7 |
| `and (u)` | A = A & (U)  (ME0) | `0x29` | 1 | 7 |
| `and (pp)` | A = A & (pp) (ME0) | `0xA9 a b` | 3 | 13 |
| `and #(x)` | A = A & (X)  (ME1) | `0xFD 0x09` | 2 | 11 |
| `and #(y)` | A = A & (Y)  (ME1) | `0xFD 0x19` | 2 | 11 |
| `and #(u)` | A = A & (U)  (ME1) | `0xFD 0x29` | 2 | 11 |
| `and #(pp)` | A = A & (pp) (ME1) | `0xFD 0xA9 a b` | 4 | 17 |

---

#### ANI — AND Immediate
`ani a,n`: `a = a & n`.
`ani (Rreg),n`: `[operand] = [operand] & n` (result stored back to memory).
**Flags:** Z only.

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `ani a,n` | A = A & n | `0xB9 n` | 2 | 7 |
| `ani (x),n` | (X) = (X) & n  (ME0) | `0x49 n` | 2 | 13 |
| `ani (y),n` | (Y) = (Y) & n  (ME0) | `0x59 n` | 2 | 13 |
| `ani (u),n` | (U) = (U) & n  (ME0) | `0x69 n` | 2 | 13 |
| `ani (pp),n` | (pp) = (pp) & n (ME0) | `0xE9 a b n` | 4 | 19 |
| `ani #(x),n` | (X) = (X) & n  (ME1) | `0xFD 0x49 n` | 3 | 17 |
| `ani #(y),n` | (Y) = (Y) & n  (ME1) | `0xFD 0x59 n` | 3 | 17 |
| `ani #(u),n` | (U) = (U) & n  (ME1) | `0xFD 0x69 n` | 3 | 17 |
| `ani #(pp),n` | (pp) = (pp) & n (ME1) | `0xFD 0xE9 a b n` | 5 | 23 |

---

#### ORA — Logical OR (Accumulator)
`a = a OR [operand]`
**Flags:** Z only.

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `ora (x)` | A = A \| (X)  (ME0) | `0x0B` | 1 | 7 |
| `ora (y)` | A = A \| (Y)  (ME0) | `0x1B` | 1 | 7 |
| `ora (u)` | A = A \| (U)  (ME0) | `0x2B` | 1 | 7 |
| `ora (pp)` | A = A \| (pp) (ME0) | `0xAB a b` | 3 | 13 |
| `ora #(x)` | A = A \| (X)  (ME1) | `0xFD 0x0B` | 2 | 11 |
| `ora #(y)` | A = A \| (Y)  (ME1) | `0xFD 0x1B` | 2 | 11 |
| `ora #(u)` | A = A \| (U)  (ME1) | `0xFD 0x2B` | 2 | 11 |
| `ora #(pp)` | A = A \| (pp) (ME1) | `0xFD 0xAB a b` | 4 | 17 |

---

#### ORI — OR Immediate
`ori a,n`: `a = a | n`.
`ori (Rreg),n`: `[operand] = [operand] | n`.
**Flags:** Z only.

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `ori a,n` | A = A \| n | `0xBB n` | 2 | 7 |
| `ori (x),n` | (X) = (X) \| n  (ME0) | `0x4B n` | 2 | 13 |
| `ori (y),n` | (Y) = (Y) \| n  (ME0) | `0x5B n` | 2 | 13 |
| `ori (u),n` | (U) = (U) \| n  (ME0) | `0x6B n` | 2 | 13 |
| `ori (pp),n` | (pp) = (pp) \| n (ME0) | `0xEB a b n` | 4 | 19 |
| `ori #(x),n` | (X) = (X) \| n  (ME1) | `0xFD 0x4B n` | 3 | 17 |
| `ori #(y),n` | (Y) = (Y) \| n  (ME1) | `0xFD 0x5B n` | 3 | 17 |
| `ori #(u),n` | (U) = (U) \| n  (ME1) | `0xFD 0x6B n` | 3 | 17 |
| `ori #(pp),n` | (pp) = (pp) \| n (ME1) | `0xFD 0xEB a b n` | 5 | 23 |

---

#### EOR — Exclusive OR (Accumulator)
`a = a XOR [operand]`
**Flags:** Z only.

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `eor (x)` | A = A ^ (X)  (ME0) | `0x0D` | 1 | 7 |
| `eor (y)` | A = A ^ (Y)  (ME0) | `0x1D` | 1 | 7 |
| `eor (u)` | A = A ^ (U)  (ME0) | `0x2D` | 1 | 7 |
| `eor (pp)` | A = A ^ (pp) (ME0) | `0xAD a b` | 3 | 13 |
| `eor #(x)` | A = A ^ (X)  (ME1) | `0xFD 0x0D` | 2 | 11 |
| `eor #(y)` | A = A ^ (Y)  (ME1) | `0xFD 0x1D` | 2 | 11 |
| `eor #(u)` | A = A ^ (U)  (ME1) | `0xFD 0x2D` | 2 | 11 |
| `eor #(pp)` | A = A ^ (pp) (ME1) | `0xFD 0xAD a b` | 4 | 17 |

---

#### EAI — Exclusive OR Accumulator Immediate
`a = a XOR n`
**Flags:** Z only.

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `eai n` | A = A ^ n | `0xBD n` | 2 | 7 |

---

#### INC — Increment
For 8-bit operands (A, RL, RH): flags C, V, H, Z may change.
For 16-bit operand (Rreg): no flag changes.

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `inc a` | A = A + 1 | `0xDD` | 1 | 5 |
| `inc xl` | XL = XL + 1 | `0x40` | 1 | 5 |
| `inc yl` | YL = YL + 1 | `0x50` | 1 | 5 |
| `inc ul` | UL = UL + 1 | `0x60` | 1 | 5 |
| `inc xh` | XH = XH + 1 | `0xFD 0x40` | 2 | 9 |
| `inc yh` | YH = YH + 1 | `0xFD 0x50` | 2 | 9 |
| `inc uh` | UH = UH + 1 | `0xFD 0x60` | 2 | 9 |
| `inc x` | X = X + 1 (16-bit, no flags) | `0x44` | 1 | 5 |
| `inc y` | Y = Y + 1 (16-bit, no flags) | `0x54` | 1 | 5 |
| `inc u` | U = U + 1 (16-bit, no flags) | `0x64` | 1 | 5 |

---

#### DEC — Decrement
For 8-bit operands (A, RL, RH): flags C, V, H, Z may change.
For 16-bit operand (Rreg): no flag changes.

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `dec a` | A = A - 1 | `0xDF` | 1 | 5 |
| `dec xl` | XL = XL - 1 | `0x42` | 1 | 5 |
| `dec yl` | YL = YL - 1 | `0x52` | 1 | 5 |
| `dec ul` | UL = UL - 1 | `0x62` | 1 | 5 |
| `dec xh` | XH = XH - 1 | `0xFD 0x42` | 2 | 9 |
| `dec yh` | YH = YH - 1 | `0xFD 0x52` | 2 | 9 |
| `dec uh` | UH = UH - 1 | `0xFD 0x62` | 2 | 9 |
| `dec x` | X = X - 1 (16-bit, no flags) | `0x46` | 1 | 5 |
| `dec y` | Y = Y - 1 (16-bit, no flags) | `0x56` | 1 | 5 |
| `dec u` | U = U - 1 (16-bit, no flags) | `0x66` | 1 | 5 |

---

### Compare and Bit Test Instructions

#### CPA — Compare Accumulator
Subtracts operand from A to set flags; A is not modified.
`a - [operand]` → flags only.
**Flags:** C, V, H, Z may change.

**Flag Table for `cpa`:**

| Condition | C | Z |
|---|:---:|:---:|
| **A > operand** | 1 | 0 |
| **A == operand** | 1 | 1 |
| **A < operand** | 0 | 0 |

*V and H are also updated but are typically ignored for simple comparisons.*

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `cpa xl` | `0x06` | 1 | 6 |
| `cpa yl` | `0x16` | 1 | 6 |
| `cpa ul` | `0x26` | 1 | 6 |
| `cpa xh` | `0x86` | 1 | 6 |
| `cpa yh` | `0x96` | 1 | 6 |
| `cpa uh` | `0xA6` | 1 | 6 |
| `cpa (x)` | `0x07` | 1 | 7 |
| `cpa (y)` | `0x17` | 1 | 7 |
| `cpa (u)` | `0x27` | 1 | 7 |
| `cpa (pp)` | `0xA7 a b` | 3 | 13 |
| `cpa #(x)` | `0xFD 0x07` | 2 | 11 |
| `cpa #(y)` | `0xFD 0x17` | 2 | 11 |
| `cpa #(u)` | `0xFD 0x27` | 2 | 11 |
| `cpa #(pp)` | `0xFD 0xA7 a b` | 4 | 17 |

---

#### CPI — Compare Immediate
Subtracts immediate `n` from the operand to set flags; operand is not modified.
`[operand] - n` → flags only.
**Flags:** C, V, H, Z may change.

**Flag Table for `cpi`:**

| Condition | C | Z |
|---|:---:|:---:|
| **Operand > n** | 1 | 0 |
| **Operand == n** | 1 | 1 |
| **Operand < n** | 0 | 0 |

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `cpi a,n` | `0xB7 n` | 2 | 7 |
| `cpi xl,n` | `0x4E n` | 2 | 7 |
| `cpi yl,n` | `0x5E n` | 2 | 7 |
| `cpi ul,n` | `0x6E n` | 2 | 7 |
| `cpi xh,n` | `0x4C n` | 2 | 7 |
| `cpi yh,n` | `0x5C n` | 2 | 7 |
| `cpi uh,n` | `0x6C n` | 2 | 7 |

---

#### BIT — Bit Test (Accumulator AND Memory)
ANDs the accumulator with memory; only the Z flag is updated. Neither A nor memory is modified.
`a and [operand]` → Z flag only.
**Flags:** Z only.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `bit (x)` | `0x0F` | 1 | 7 |
| `bit (y)` | `0x1F` | 1 | 7 |
| `bit (u)` | `0x2F` | 1 | 7 |
| `bit (pp)` | `0xAF a b` | 3 | 13 |
| `bit #(x)` | `0xFD 0x0F` | 2 | 11 |
| `bit #(y)` | `0xFD 0x1F` | 2 | 11 |
| `bit #(u)` | `0xFD 0x2F` | 2 | 11 |
| `bit #(pp)` | `0xFD 0xAF a b` | 4 | 17 |

---

#### BII — Bit Test Immediate
ANDs the operand with immediate `n`; only the Z flag is updated.
`[operand] and n` → Z flag only.
**Flags:** Z only.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `bii a,n` | `0xBF n` | 2 | 7 |
| `bii (x),n` | `0x4D n` | 2 | 10 |
| `bii (y),n` | `0x5D n` | 2 | 10 |
| `bii (u),n` | `0x6D n` | 2 | 10 |
| `bii (pp),n` | `0xED a b n` | 4 | 16 |
| `bii #(x),n` | `0xFD 0x4D n` | 3 | 14 |
| `bii #(y),n` | `0xFD 0x5D n` | 3 | 14 |
| `bii #(u),n` | `0xFD 0x6D n` | 3 | 14 |
| `bii #(pp),n` | `0xFD 0xED a b n` | 5 | 20 |

---

### Transfer and Search Instructions

#### LDA — Load Accumulator
`[operand] → a`
**Flags:** Z only.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `lda xl` | `0x04` | 1 | 5 |
| `lda yl` | `0x14` | 1 | 5 |
| `lda ul` | `0x24` | 1 | 5 |
| `lda xh` | `0x84` | 1 | 5 |
| `lda yh` | `0x94` | 1 | 5 |
| `lda uh` | `0xA4` | 1 | 5 |
| `lda (x)` | `0x05` | 1 | 6 |
| `lda (y)` | `0x15` | 1 | 6 |
| `lda (u)` | `0x25` | 1 | 6 |
| `lda (pp)` | `0xA5 a b` | 3 | 12 |
| `lda #(x)` | `0xFD 0x05` | 2 | 10 |
| `lda #(y)` | `0xFD 0x15` | 2 | 10 |
| `lda #(u)` | `0xFD 0x25` | 2 | 10 |
| `lda #(pp)` | `0xFD 0xA5 a b` | 4 | 16 |

---

#### LDE — Load and Decrement
Loads memory at Rreg into A, then decrements Rreg by 1.
`(Rreg) → a`, `Rreg - 1 → Rreg`
**Flags:** Z only.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `lde x` | `0x47` | 1 | 6 |
| `lde y` | `0x57` | 1 | 6 |
| `lde u` | `0x67` | 1 | 6 |

---

#### LIN — Load and Increment
Loads memory at Rreg into A, then increments Rreg by 1.
`(Rreg) → a`, `Rreg + 1 → Rreg`
**Flags:** Z only.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `lin x` | `0x45` | 1 | 6 |
| `lin y` | `0x55` | 1 | 6 |
| `lin u` | `0x65` | 1 | 6 |

---

#### LDI — Load Immediate
Loads an immediate value into the accumulator, a register byte, or the stack pointer.
- `ldi a,n`: Z changes. `n → a`
- `ldi RL,n` / `ldi RH,n`: No flag changes. `n → register`
- `ldi s,pp`: No flag changes. `pp → s` (16-bit)

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `ldi a,n` | `0xB5 n` | 2 | 6 |
| `ldi xl,n` | `0x4A n` | 2 | 6 |
| `ldi yl,n` | `0x5A n` | 2 | 6 |
| `ldi ul,n` | `0x6A n` | 2 | 6 |
| `ldi xh,n` | `0x48 n` | 2 | 6 |
| `ldi yh,n` | `0x58 n` | 2 | 6 |
| `ldi uh,n` | `0x68 n` | 2 | 6 |
| `ldi s,pp` | `0xAA a b` | 3 | 12 |

---

#### LDX — Load X Register (16-bit)
Transfers a 16-bit register or the stack/program counter into Xreg.
`[operand] → x`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `ldx y` | X = Y | `0xFD 0x18` | 2 | 11 |
| `ldx u` | X = U | `0xFD 0x28` | 2 | 11 |
| `ldx s` | X = S (Stack Pointer) | `0xFD 0x48` | 2 | 11 |
| `ldx p` | X = P (Program Counter) | `0xFD 0x58` | 2 | 11 |

---

#### STA — Store Accumulator
`a → [operand]`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `sta xl` | `0x0A` | 1 | 5 |
| `sta yl` | `0x1A` | 1 | 5 |
| `sta ul` | `0x2A` | 1 | 5 |
| `sta xh` | `0x08` | 1 | 5 |
| `sta yh` | `0x18` | 1 | 5 |
| `sta uh` | `0x28` | 1 | 5 |
| `sta (x)` | `0x0E` | 1 | 6 |
| `sta (y)` | `0x1E` | 1 | 6 |
| `sta (u)` | `0x2E` | 1 | 6 |
| `sta (pp)` | `0xAE a b` | 3 | 12 |
| `sta #(x)` | `0xFD 0x0E` | 2 | 10 |
| `sta #(y)` | `0xFD 0x1E` | 2 | 10 |
| `sta #(u)` | `0xFD 0x2E` | 2 | 10 |
| `sta #(pp)` | `0xFD 0xAE a b` | 4 | 16 |

*Note: `sta VH` (opcode `0x38`) is functionally identical to `nop`.*

---

#### SDE — Store and Decrement
Stores A to memory at Rreg, then decrements Rreg by 1.
`a → (Rreg)`, `Rreg - 1 → Rreg`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `sde x` | `0x43` | 1 | 6 |
| `sde y` | `0x53` | 1 | 6 |
| `sde u` | `0x63` | 1 | 6 |

---

#### SIN — Store and Increment
Stores A to memory at Rreg, then increments Rreg by 1.
`a → (Rreg)`, `Rreg + 1 → Rreg`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `sin x` | `0x41` | 1 | 6 |
| `sin y` | `0x51` | 1 | 6 |
| `sin u` | `0x61` | 1 | 6 |

---

#### STX — Store X Register (16-bit)
Transfers Xreg to another 16-bit register, the stack pointer, or the program counter.
`x → [operand]`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `stx y` | Y = X | `0xFD 0x5A` | 2 | 11 |
| `stx u` | U = X | `0xFD 0x6A` | 2 | 11 |
| `stx s` | S = X (Stack Pointer) | `0xFD 0x4E` | 2 | 11 |
| `stx p` | P = X (Program Counter — indirect jump) | `0xFD 0x5E` | 2 | 11 |

---

### Stack Instructions

#### PSH — Push to Stack
Pushes the accumulator or a 16-bit register pair onto the stack.
- `psh a`: `a → (s)`, `s - 1 → s`
- `psh Rreg`: `RL → (s)`, `s - 1 → s`, `RH → (s)`, `s - 1 → s`

**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `psh a` | `0xFD 0xC8` | 2 | 11 |
| `psh x` | `0xFD 0x88` | 2 | 14 |
| `psh y` | `0xFD 0x98` | 2 | 14 |
| `psh u` | `0xFD 0xA8` | 2 | 14 |

---

#### POP — Pop from Stack
Pops the accumulator or a 16-bit register pair from the stack.
- `pop a`: `s + 1 → s`, `(s) → a`. **Z flag changes.**
- `pop Rreg`: `s + 1 → s`, `(s) → RH`, `s + 1 → s`, `(s) → RL`. **No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `pop a` | `0xFD 0x8A` | 2 | 12 |
| `pop x` | `0xFD 0x0A` | 2 | 15 |
| `pop y` | `0xFD 0x1A` | 2 | 15 |
| `pop u` | `0xFD 0x2A` | 2 | 15 |

---

### Register Transfer Instructions

#### ATT — Accumulator to T Register
Loads the T (status flags) register from the accumulator.
`a → t`
**No flag changes** (but all flags are overwritten with the value of A).

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `att` | `0xFD 0xEC` | 2 | 9 |

---

#### TTA — T Register to Accumulator
Transfers the T (status flags) register to the accumulator.
`t → a`
**Flags:** Z changes based on the value of T.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `tta` | `0xFD 0xAA` | 2 | 9 |

---

### Block Transfer and Search Instructions

#### TIN — Transfer and Increment
Copies one byte from memory at X to memory at Y, then increments both pointers.
`(x) → (y)`, `x + 1 → x`, `y + 1 → y`
**No flag changes.**

Typically used in a `lop` loop for block memory copies.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `tin` | `0xF5` | 1 | 7 |

---

#### CIN — Compare and Increment
Compares A with the byte at memory X (like CPA), then increments X.
`a - (x)` → flags, `x + 1 → x`
**Flags:** C, V, H, Z may change (same table as CPA).

Typically used in a `lop` loop for block memory searches.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `cin` | `0xF7` | 1 | 7 |

---

### Rotate and Shift Instructions

#### ROL — Rotate Left Through Carry
Rotates the accumulator left through the carry flag. The carry becomes the new bit 0; the old bit 7 becomes the new carry.
`C ← a[7:0] ← C`
**Flags:** C changes.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `rol` | `0xDB` | 1 | 8 |

---

#### ROR — Rotate Right Through Carry
Rotates the accumulator right through the carry flag. The carry becomes the new bit 7; the old bit 0 becomes the new carry.
`C → a[7:0] → C`
**Flags:** C changes.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `ror` | `0xD1` | 1 | 9 |

---

#### SHL — Shift Left
Shifts the accumulator left. Bit 7 moves into carry; 0 is shifted into bit 0.
`C ← a[7:0] ← 0`
**Flags:** C changes.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `shl` | `0xD9` | 1 | 6 |

---

#### SHR — Shift Right
Shifts the accumulator right. Bit 0 moves into carry; 0 is shifted into bit 7.
`0 → a[7:0] → C`
**Flags:** C changes.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `shr` | `0xD5` | 1 | 9 |

---

#### DRL — Digit Rotate Left

**✅ CONFIRMED on real PC-1500A hardware.** Three mutually incompatible readings of DRL/DRR existed across emulators; a real-silicon test settled it:

With `a = 0x12` and `(Xreg) = 0x34` going in, DRL produces `a = 0x34`, mem `= 0x41`. That is **whole-byte swap: A becomes the entire old memory byte**; memory becomes a merge of its own old low nibble with A's old opposite nibble, and A's other old nibble is genuinely discarded, not conserved anywhere. The two readings this ruled out:

| Reading | Seen in | `a` after DRL | mem after DRL | `a` after DRR | mem after DRR |
|---|---|---|---|---|---|
| **whole-byte swap (confirmed)** | MESS/MAME, PockEmul, forever1500, this project's own core | `0x34` | `0x41` | `0x34` | `0x23` |
| 3-nibble rotate — **ruled out** | (an earlier guess in this project's own core, before this test) | `0x32` | `0x41` | `0x14` | `0x23` |
| Z80 RLD/RRD semantics — **ruled out** | — | `0x13` | `0x42` | `0x14` | `0x23` |

**Transfer diagram** (left rotation between the accumulator and memory at Xreg, in units of 4 bits / one BCD digit):
- `Mem[old]` (the entire old byte) → `a` (A becomes the whole old memory byte, high nibble included)
- `Mem[3:0]` (old) → `Mem[7:4]` (new) (memory's own old low nibble rotates up into its new high nibble)
- `a[7:4]` (old) → `Mem[3:0]` (new) (A's old high nibble becomes the new memory low nibble)
- `a[3:0]` (old) — discarded; not conserved anywhere

**No flag changes.** Only operates on `(Xreg)` or `#(Xreg)`.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `drl (x)` | ME0 | `0xD7` | 1 | 12 |
| `drl #(x)` | ME1 | `0xFD 0xD7` | 2 | 16 |

Confirmed by sibling project `Calc-U-1600` (this user's own, not part of this repo) running `examples/debug/instrquirks_1500a.asm` / `.bin` / `.pc1500a` on a real PC-1500A and PEEKing the result bytes — see that file's own header comment for the full discriminating-test writeup. `Core/CPU/LH5801/LH5801.cpp`'s `drlMerge`/`drrMerge` already implemented this reading (ported from source-level comparison against `pc1500emu` before this hardware test existed); the hardware run confirms that choice was correct.

---

#### DRR — Digit Rotate Right

**✅ CONFIRMED on real PC-1500A hardware** — see the DRL entry immediately above for the full discriminating-test table and provenance. With `a = 0x12` and `(Xreg) = 0x34` going in, DRR produces `a = 0x34`, mem `= 0x23` — same whole-byte-swap reading as DRL. (DRR's own memory-byte result happens to be identical under all three readings that were considered, so DRL's accumulator result did the actual discriminating; DRR was captured alongside it as a direct cross-check.)

**Transfer diagram** (right rotation between the accumulator and memory at Xreg, in units of 4 bits):
- `Mem[old]` (the entire old byte) → `a` (A becomes the whole old memory byte, low nibble included)
- `Mem[7:4]` (old) → `Mem[3:0]` (new) (memory's own old high nibble rotates down into its new low nibble)
- `a[3:0]` (old) → `Mem[7:4]` (new) (A's old low nibble becomes the new memory high nibble)
- `a[7:4]` (old) — discarded; not conserved anywhere

**No flag changes.** Only operates on `(Xreg)` or `#(Xreg)`.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `drr (x)` | ME0 | `0xD3` | 1 | 12 |
| `drr #(x)` | ME1 | `0xFD 0xD3` | 2 | 16 |

---

#### AEX — Accumulator Exchange Nibbles
Swaps the high and low 4-bit nibbles of the accumulator.
`a[7:4] ↔ a[3:0]`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `aex` | `0xF1` | 1 | 6 |

---

### CPU Control Instructions

#### SEC — Set Carry
Sets the carry flag. `1 → C`
**Flags:** C = 1.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `sec` | `0xFB` | 1 | 4 |

---

#### REC — Reset Carry
Resets the carry flag. `0 → C`
**Flags:** C = 0.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `rec` | `0xF9` | 1 | 4 |

---

#### SIE — Set Interrupt Enable
Sets the IE flag, enabling maskable and timer interrupts. `1 → IE`
**Flags:** IE = 1 (other flags unchanged).

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `sie` | `0xFD 0x81` | 2 | 8 |

---

#### RIE — Reset Interrupt Enable
Resets the IE flag, disabling maskable and timer interrupts. `0 → IE`
**Flags:** IE = 0 (other flags unchanged).

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `rie` | `0xFD 0xBE` | 2 | 8 |

---

#### SPU — Set PU Flip-Flop
Sets the general-purpose flip-flop PU. `1 → PU`
Used in the PC-1500 for ROM bank switching.
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `spu` | `0xE1` | 1 | 4 |

---

#### RPU — Reset PU Flip-Flop
Resets the general-purpose flip-flop PU. `0 → PU`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `rpu` | `0xE3` | 1 | 4 |

---

#### SPV — Set PV Flip-Flop
Sets the general-purpose flip-flop PV. `1 → PV`
Used in the PC-1500 for external device selection.
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `spv` | `0xA8` | 1 | 4 |

---

#### RPV — Reset PV Flip-Flop
Resets the general-purpose flip-flop PV. `0 → PV`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `rpv` | `0xB8` | 1 | 4 |

---

#### SDP — Set Display
Sets the DISP flip-flop, enabling the LCD display. `1 → DISP`
Causes the CPU's internal LCD backplate signals (H0–H7) to generate an on-pattern.
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `sdp` | `0xFD 0xC1` | 2 | 9 |

---

#### RDP — Reset Display
Resets the DISP flip-flop, disabling the LCD display. `0 → DISP`
Causes the CPU's internal LCD backplate signals to generate an off-pattern.
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `rdp` | `0xFD 0xC0` | 2 | 8 |

---

#### AM0 — Accumulator to Timer (bit 8 = 0)
Transfers A to the lower 8 bits of the 9-bit timer register TM. Bit 8 of TM is cleared.
`a → TM[7:0]`, `0 → TM[8]`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `am0` | `0xFD 0xCE` | 2 | 9 |

---

#### AM1 — Accumulator to Timer (bit 8 = 1)
Same as AM0, but bit 8 of TM is set.
`a → TM[7:0]`, `1 → TM[8]`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `am1` | `0xFD 0xDE` | 2 | 9 |

---

#### ATP — Accumulator to Port
Sends the contents of A onto the data bus. The CPU simultaneously asserts clock `Pφ`, which can be used as a latch clock for an external output port IC.
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `atp` | `0xFD 0xCC` | 2 | 9 |

---

#### ITA — Input to Accumulator
Reads the 8-bit input port (IN0–IN7) into the accumulator.
`IN0–IN7 → a`
**Flags:** Z changes.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `ita` | `0xFD 0xBA` | 2 | 9 |

---

#### CDV — Clear Divider
Clears (resets) the internal clock divider. Effectively resets the CPU clock timing.
`0 → divider`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `cdv` | `0xFD 0x8E` | 2 | 8 |

---

#### NOP — No Operation
Performs no operation. Equivalent to `sta VH` (storing A to the undocumented V-register high byte has no effect).
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `nop` | `0x38` | 1 | 5 |

---

#### HLT — Halt
Stops CPU instruction execution. Only the internal clock divider continues running. The CPU resumes automatically when an interrupt occurs.
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `hlt` | `0xFD 0xB1` | 2 | 9 |

---

#### OFF — Power Off (BF Flip-Flop Reset)
Resets the BF (battery-backed) flip-flop. On the PC-1500, this is used to signal a power-off request. The CPU checks the BFI input pin to resume.
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `off` | `0xFD 0x4C` | 2 | 8 |

---

### Jump Instructions

#### JMP — Unconditional Jump
Jumps to the absolute 16-bit address `pp`.
`i → PH`, `j → PL` (where `pp` = high byte `i`, low byte `j`)
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `jmp pp` | `0xBA a b` | 3 | 12 |

---

#### BCH — Branch Unconditional (Relative)
Jumps unconditionally by adding or subtracting the immediate offset `e` from the program counter.
Range: -255 < e < 255.
**No flag changes.**

| Format | Operation | Opcode | Bytes | Cycles |
|---|---|---|---|---|
| `bch+e` | P = P + e (forward) | `0x8E e` | 2 | 8 |
| `bch-e` | P = P - e (backward) | `0x9E e` | 2 | 9 |

---

#### BCS / BCR — Branch on Carry Set / Reset
Conditional relative branch based on the Carry flag.
**No flag changes.** Cycles: 8 if no branch, 10 (forward) or 11 (backward) if taken.

| Format | Condition | Opcode | Bytes |
|---|---|---|---|
| `bcs+e` | Branch forward if C = 1 | `0x83 e` | 2 |
| `bcs-e` | Branch backward if C = 1 | `0x93 e` | 2 |
| `bcr+e` | Branch forward if C = 0 | `0x81 e` | 2 |
| `bcr-e` | Branch backward if C = 0 | `0x91 e` | 2 |

---

#### BHS / BHR — Branch on Half-Carry Set / Reset
Conditional relative branch based on the Half-Carry flag.
**No flag changes.** Cycles: 8 if no branch, 10/11 if taken.

| Format | Condition | Opcode | Bytes |
|---|---|---|---|
| `bhs+e` | Branch forward if H = 1 | `0x87 e` | 2 |
| `bhs-e` | Branch backward if H = 1 | `0x97 e` | 2 |
| `bhr+e` | Branch forward if H = 0 | `0x85 e` | 2 |
| `bhr-e` | Branch backward if H = 0 | `0x95 e` | 2 |

---

#### BZS / BZR — Branch on Zero Set / Reset
Conditional relative branch based on the Zero flag.
**No flag changes.** Cycles: 8 if no branch, 10/11 if taken.

| Format | Condition | Opcode | Bytes |
|---|---|---|---|
| `bzs+e` | Branch forward if Z = 1 | `0x8B e` | 2 |
| `bzs-e` | Branch backward if Z = 1 | `0x9B e` | 2 |
| `bzr+e` | Branch forward if Z = 0 | `0x89 e` | 2 |
| `bzr-e` | Branch backward if Z = 0 | `0x99 e` | 2 |

---

#### BVS / BVR — Branch on Overflow Set / Reset
Conditional relative branch based on the Overflow flag.
**No flag changes.** Cycles: 8 if no branch, 10/11 if taken.

| Format | Condition | Opcode | Bytes |
|---|---|---|---|
| `bvs+e` | Branch forward if V = 1 | `0x8F e` | 2 |
| `bvs-e` | Branch backward if V = 1 | `0x9F e` | 2 |
| `bvr+e` | Branch forward if V = 0 | `0x8D e` | 2 |
| `bvr-e` | Branch backward if V = 0 | `0x9D e` | 2 |

---

#### LOP — Loop
Decrements UL by 1. If no borrow (UL was > 0), branches backward by `e`. If borrow (UL underflowed), falls through to the next instruction.
`ul - 1 → ul`; if no borrow: `p - e → p`
**No flag changes.**

This instruction is used to implement counted loops. Load UL with the loop count before the loop body, then place `lop` at the end.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `lop ul,e` | `0x88 e` | 2 | 8 (exit) / 11 (loop) |

---

### Subroutine and Vector Jump Instructions

#### SJP — Subroutine Jump (Call)
Pushes the return address onto the stack, then jumps to absolute address `pp`.
`PL → (s)`, `s-1 → s`, `PH → (s)`, `s-1 → s`, `i → PH`, `j → PL`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `sjp pp` | `0xBE a b` | 3 | 19 |

---

#### VEJ — Vector Subroutine Jump (1-byte)
Single-byte subroutine call. Pushes the return address, then jumps to the address stored at the vector table entry `(0xFF00 + operand)`.
The vector table occupies addresses `0xFFC0–0xFFF6` in the PC-1500 ROM.
There are 28 valid VEJ operands in the range `0xC0`–`0xFE` (even values only).
**Flags:** Z is reset.

**Syntax: `vej (nn)` — the operand is enclosed in parentheses but uses bare hex digits, with no `0x` prefix inside the parens.** e.g. `vej (F2)`, not `vej (0xF2)`.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `vej (nn)` | `nn` (where nn = C0..FE, even; no prefix inside parens) | 1 | 17 |

**PC-1500 VEJ Vector Table (partial -- ROM-defined subroutines):**

| Syntax | PC-1500 Function |
|---|---|
| `vej (C0)` | Load next token/character to U register |
| `vej (C2)` | Check if character in U matches argument; branch if not |
| `vej (C4)` | Check if next character in U matches argument; branch if not |
| `vej (C6)` | Decrement Y register by 2 (token) or 1 (character) |
| `vej (C8)` | Syntax check: jump forward if not end-of-command |
| `vej (CA)` | Transfer X register to variable at offset `b1` |
| `vej (CC)` | Load X register from variable address at offset `b1` |
| `vej (CE)` | Determine address of variable `b1`; branch if not numeric |
| `vej (D0)` | Convert AR-X to integer into U register; branch on overflow |
| `vej (D2)` | Reseed AR-X with integer or process CSI |
| `vej (D4)` | Transmit current processing status pointer |
| `vej (D6)` | Load address pointer from memory to AR-Y |
| `vej (D8)` | Check if program expires (Z=0 if so) |
| `vej (DA)` | Cache variable address from U register and length from AR-X |
| `vej (DC)` | Load CSI from AR-X |
| `vej (DE)` | Evaluate formula pointed to by Y; jump forward on error |
| `vej (E0)` | Error check if UH ≠ 0x00 |
| `vej (E2)` | Start of BASIC interpreter |
| `vej (E4)` | Output error 1, return to editor |
| `vej (E6)` | Transfer AR-X to AR-Y |
| `vej (E8)` | Convert AR-X to absolute BCD form |
| `vej (EA)` | Push AR-X one nibble left |
| `vej (EC)` | Clear arithmetic register X |
| `vej (EE)` | AR-X = AR-X + AR-U |
| `vej (F0)` | AR-X = AR-X + AR-Y (floating-point addition) |
| `vej (F2)` | Clear LCD display. **Does not reset cursor pointer at `0x7875`** — always follow with `ldi a,0x00` then `sta (CURSOR_PTR)`. |
| `vej (F4)` | Load U register with 16-bit value from address `w1` |
| `vej (F6)` | Transfer U register to address `w1` |
| `vej (F8)` | Maskable interrupt routine entry |
| `vej (FA)` | Timer interrupt routine entry |
| `vej (FC)` | Non-maskable interrupt routine entry (executes RTI) |
| `vej (FE)` | Reset routine entry |

---

#### VMJ — Vector 2-Byte Subroutine Jump
Two-byte vector call. Jumps to the address stored at `(0xFF00 + i)`. Immediate value `i` may be any even value from `0x00` to `0xF6`.
**Flags:** Z is reset.

**Syntax: `vmj 0xnn` — a plain byte immediate with a `0x` prefix, no parentheses.**
This differs from VEJ: VMJ takes a bare immediate operand, not a parenthesized argument.
Use `vmj 0x92`, not `vmj (0x92)`.

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `vmj 0xnn` | `0xCD 0xnn` | 2 | 20 |

---

#### VCS / VCR — Conditional Vector Jump on Carry
Vector subroutine jump conditional on the Carry flag. When the condition is false, falls through to the next instruction.
**Flags:** Z is reset if taken.
Cycles: 8 (not taken) / 21 (taken).

| Format | Condition | Opcode | Bytes |
|---|---|---|---|
| `vcs i` | Jump if C = 1 | `0xC3 i` | 2 |
| `vcr i` | Jump if C = 0 | `0xC1 i` | 2 |

---

#### VHS / VHR — Conditional Vector Jump on Half-Carry
Vector subroutine jump conditional on the Half-Carry flag.
**Flags:** Z is reset if taken.
Cycles: 8 (not taken) / 21 (taken).

| Format | Condition | Opcode | Bytes |
|---|---|---|---|
| `vhs i` | Jump if H = 1 | `0xC7 i` | 2 |
| `vhr i` | Jump if H = 0 | `0xC5 i` | 2 |

---

#### VZS / VZR — Conditional Vector Jump on Zero
Vector subroutine jump conditional on the Zero flag.
**Flags:** Z is reset if taken.
Cycles: 8 (not taken) / 21 (taken).

| Format | Condition | Opcode | Bytes |
|---|---|---|---|
| `vzs i` | Jump if Z = 1 | `0xCB i` | 2 |
| `vzr i` | Jump if Z = 0 | `0xC9 i` | 2 |

---

#### VVS — Conditional Vector Jump on Overflow Set
Vector subroutine jump if V = 1.
**Flags:** Z is reset if taken.
Cycles: 8 (not taken) / 21 (taken).

| Format | Condition | Opcode | Bytes |
|---|---|---|---|
| `vvs i` | Jump if V = 1 | `0xCF i` | 2 |

---

### Return Instructions

#### RTN — Return from Subroutine
Returns to the caller by popping the return address from the stack into P.
`s + 1 → s`, `(s) → PH`, `s + 1 → s`, `(s) → PL`
**No flag changes.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `rtn` | `0x9A` | 1 | 11 |

---

#### RTI — Return from Interrupt
Returns from an interrupt service routine. In addition to restoring P from the stack, also restores T (the status register) from the stack, restoring all flags to their pre-interrupt state.
`s + 1 → s`, `(s) → PH`, `s + 1 → s`, `(s) → PL`, `s + 1 → s`, `(s) → t`
**All flags restored from stack.**

| Format | Opcode | Bytes | Cycles |
|---|---|---|---|
| `rti` | `0x8A` | 1 | 14 |

---

## PC-1500 System Reference

### Key RAM Addresses

**Memory layout overview:**

| Range | Size | Purpose |
|---|---|---|
| `0x4000–0x47FF` | 2 KB | Standard user RAM (stock, CE-151, CE-159) |
| `0x4008–0x40C4` | 189 B | Reserve memory area |
| `0x40C5–0x47FF` | ~1.8 KB | BASIC program memory start |
| `0x7000–0x75FF` | 1.5 KB | Shadow RAM (mirrors 0x7600–0x77FF) |
| `0x7600–0x774F` | 336 B | Display buffer |
| `0x7650–0x77AF` | 352 B | Fixed string variables |
| `0x7800–0x784F` | 80 B | CPU stack |
| `0x7860–0x7BFF` | ~1 KB | System variables / BASIC state |
| `0x7A00–0x7A37` | 56 B | Floating-point arithmetic registers (ARX…ARS) |
| `0x7B10–0x7B5F` | 80 B | String buffer |
| `0x7B60–0x7BAF` | 80 B | Output buffer |
| `0x7BB0–0x7BFF` | 80 B | Input buffer |

**System variables (selected):**

| Label | Address | Description |
|---|---|---|
| `RAM_ST` | `0x4000` | Start of RAM (no expansion) |
| `RESMEM_ST` | `0x4008` | Reserve memory area start |
| `PRGMEM_ST` | `0x40C5` | Start of BASIC program memory |
| `RAM_END` | `0x47FF` | End of RAM (stock / CE-151 / CE-159) |
| `SHADOW_RAM` | `0x7000` | Shadow RAM start |
| `DISP_BUFF` | `0x7600` | Display buffer (7600–774F) |
| `STRING_VARS` | `0x7650` | Fixed string variables (7650–77AF) |
| `CPU_STACK` | `0x7800` | CPU stack area (7800–784F) |
| `KATAFLAGS` | `0x785D` | Katakana display flags |
| `BEEP_PTR` | `0x786B` | BEEP and RMT flags |
| `WAIT_CFG` | `0x7871` | WAIT setting |
| `CURSOR_ENA` | `0x7874` | Cursor enable flags |
| `CURSOR_PTR` | `0x7875` | Current display column number |
| `CHARPOS_LCD` | `0x7876` | Character position in display (INPUT statement) |
| `BEEP_FREQ` | `0x7878` | BEEP frequency |
| `DISPARAM` | `0x7880` | Display parameter (determines display at READY) |
| `CURVARADD_H/L` | `0x7883/0x7884` | Current variable address |
| `TRACE_ON` | `0x788D` | TRACE ON/OFF: 00=OFF, >0=ON |
| `USINGF` | `0x7895` | USING format flags |
| `VAR_START_H/L` | `0x7899/0x789A` | Start of variables in main memory |
| `ERL` | `0x789B` | Error code |
| `CURR_LINE_H/L` | `0x789C/0x789D` | Current executing line number |
| `FIXED_VARS` | `0x78C0` | Fixed variables area (78C0–79CF, 272 bytes) |
| `PU_PV` | `0x79D0` | PU/PV flag; ROM bank: 00=ROM1, 01=ROM2 |
| `OPN` | `0x79D1` | Open device: 60=LCD, 5C=CMT, 58=MGP, C4=LPRT, C0=COM |
| `UNDEF_REG_79FF` | `0x79FF` | LOCK mode: 00=LOCK, FF=UNLOCK |
| `ARX` | `0x7A00` | Floating-point accumulator (8 bytes) |
| `ARZ` | `0x7A08` | Scratch FP register (8 bytes) |
| `ARY` | `0x7A10` | Second FP operand (8 bytes) |
| `ARU` | `0x7A18` | Scratch FP register (8 bytes) |
| `ARV` | `0x7A20` | Scratch FP register (8 bytes) |
| `ARW` | `0x7A28` | Scratch FP register (8 bytes) |
| `ARS` | `0x7A30` | Temporary FP storage (8 bytes) |
| `B_STACK` | `0x7A38` | BASIC stack (7A38–7AFF, 200 bytes) |
| `RND_VAL` | `0x7B00` | Random number value (7B00–7B07) |
| `KEY_LAST` | `0x7B0F` | Last pressed key code |
| `STR_BUF` | `0x7B10` | String buffer (7B10–7B5F, 80 bytes) |
| `OUT_BUF` | `0x7B60` | Output buffer (7B60–7BAF, 80 bytes) |
| `IN_BUF` | `0x7BB0` | Input buffer (7BB0–7BFF, 80 bytes) |

### RAM Configurations by Model and Memory Module

Actual RAM start/end addresses depend on both the machine and which memory module (if any) is fitted. `MEM` is the value the BASIC `MEM` command reports with no program loaded.

**Empty machine (no memory module):**

| Model | Start | End | Size | MEM |
|---|---|---|---|---|
| PC-1500 | `0x4000` | `0x4800` | 2k | 1850 |
| PC-1500A | `0x4000` | `0x5800` | 6k | 5946 |
| PC-1600 (LH5803 side) | `0x4000` | `0x8000` | 16k | 11834 |
| PC-1600 (Z80 side) | `0xC000` | `0x10000` | 16k | 11834 |

**Machine plus CE-155 (8k module):**

| Model | Start | End | Size | MEM |
|---|---|---|---|---|
| PC-1500 | `0x3800` | `0x6000` | 10k | 10042 |
| PC-1500A | `0x3800` | `0x7000` | 14k | 14138 |
| PC-1600 (LH5803 side) | `0x2000` | `0x8000` | 24k | 20026 |

**Machine plus a 16k memory module (modern recreation):**

| Model | Start | End | Size |
|---|---|---|---|
| PC-1500 | `0x0000` | `0x4800` | 18k |
| PC-1500A | `0x0000` | `0x5800` | 22k |
| PC-1600 (LH5803 side) | `0x0000` | `0x8000` | 32k |

(Exact `NEW`/MEM figures depend on the specific module's own firmware reserve — see its own documentation.)

Find the actual RAM start address at runtime with `256 * PEEK(&7863)`.

**The `NEW &nnn` reservation formula:** `NEW 0` sets the start of BASIC memory to `[RAM start] + 0xC5` — the first 197 bytes of any RAM bank are reserved for BASIC's own data structures. To reserve additional space for a machine-language program (e.g. 100 bytes), the BASIC start must be `[RAM start] + 197 + 100`, e.g. `NEW &129` on a machine with the 16k module.

When a memory module with onboard firmware is fitted, that firmware needs its own reserve of bytes **on top of** the 197-byte BASIC reserve, so the minimum `NEW` offset is higher accordingly — see the module's own documentation for its specific minimum. A machine-language program loaded alongside it needs `[RAM start] + [module's firmware reserve] + [additional bytes for the program]`.

On the PC-1600, the start is not set with an absolute address, because the LH5803 and Z80 processors see the same physical memory at different address ranges. Instead, reserve an *amount*: 197 bytes plus whatever the assembly program needs (e.g. `NEW "S0:",&<n>`).

**Example — an 18-byte screen-reverse program**, minimum reservation per configuration:
- PC-1500 / CE-158: `NEW &38D7` (add 197 to the program size for the base BASIC reserve)
- PC-1500A / a memory module: `NEW` offset depends on the module's own firmware reserve (see the module's own documentation)
- PC-1600: `NEW "S0:",&D7` (add 197)

### Memory Management

**Key program and memory boundary pointers** (16-bit, big-endian, stored at 0x78xx–0x7Axx):

| Label | Address | Description |
|---|---|---|
| `RAM_ST` | `0x7860` | High byte of user-available RAM start |
| `BASPRG_ST` | `0x7865` | BASIC program start address |
| `BASPRG_END` | `0x7867` | BASIC program end address (used by `MEM`) |
| `BASPRG_EDT` | `0x7869` | Editor work pointer, used during line modification |
| `CURVARADD` | `0x7883` | Pointer to the variable currently being accessed |
| `CURVARTYPE` | `0x7885` | Type (byte) of the active variable |
| `DISP_CTRL` | `0x7880` | Display flags: controls LCD refresh and auto-off timers |
| `BREAK_STAT` | `0x7881` | BREAK-key interrupt / execution-pause status |
| `IN_BUF_PTR` | `0x7892` | Cursor into the `0x7Bxx` input buffer area |
| `TRACE_ON` | `0x788D` | Non-zero if `TRON` is active |
| `TRACE_PARAM` | `0x788E` | Vector used for trace output handling |
| `VAR_START` | `0x7899` | Start of dimensioned variables (grows downward from top of RAM) |
| `CURR_LINE` | `0x78A0` | Number of the BASIC line currently executing |
| `PREV_LINE` | `0x78A2` | Previous line number, used for error reporting and `CONT` |
| `ON_ERR_VEC` | `0x78A4` | 16-bit address of the `ON ERROR GOTO` handler |
| `SRCH_PTR` | `0x78A6` | Scratch workspace for program/variable scanning |
| `STK_FOR_GSB` | `0x78B8` | Current depth of the FOR-NEXT / GOSUB logic stack |
| `DATA_PTR` | `0x78BE` | Cursor into `DATA` statements |
| `RAM_END` | `0x7A13` / `0x7A33` | High byte of the physical RAM limit |
| `WARM_START` | `0x7A20` | Warm-start flag: `0x01` = warm start, else cold start |
| `STK_SAVE` | `0x7A21` | Stack pointer restored during warm start |

**Free memory formula** (equivalent to the BASIC `MEM` command):

```
Free Space = RAM_END − BASPRG_END
```

**Reading free memory in assembly:**

```asm
; Option 1: call the built-in MEM routine — result returned in u (16-bit)
sjp  0xDFEE          ; uh = high byte, ul = low byte of free bytes

; Option 2: read RAM_END high byte directly (PC-1500A / PC-2 variant)
ldi  xh, 0x7A
ldi  xl, 0x13
lda  (x)            ; a = high byte of RAM_END page
```

**Safe region for assembly data under BASIC:**

When an assembly routine runs as a BASIC subroutine (`CALL`), BASIC already occupies `BASPRG_ST` through `BASPRG_END`. The safe, unused region is:

```
[BASPRG_END + 1 .. VAR_START − 1]
```

To compute the start of this region in assembly:

```asm
; Read BASPRG_END (big-endian 16-bit at 0x7867/0x7868).
; There is no ldx (addr) form -- load each byte through a.
lda  (0x7867)
sta  xh
lda  (0x7868)
sta  xl

; Advance past the end marker to get first free byte
inc  x              ; x = BASPRG_END + 1  (safe data start, 16-bit, no flags)
; Store x or use directly as base pointer for user data
```

To protect a fixed block of assembly code at a known offset, use `NEW &<decimal_offset>` from BASIC before running your program. This sets `BASPRG_ST` to that offset, keeping the assembly code below the BASIC program area:

```
NEW &112            ; protect first 112 bytes from BASIC
```

**Warm vs. cold start detection:**

```asm
lda  (0x7A20)       ; load WARM_START flag
cpi  a,0x01
bzs  warm           ; 0x01 → warm start, program memory intact
                    ; else → cold start, memory wiped / unreliable
warm:
    ; ... safe to use existing program/variable state
```

**RAM size detection at reset:**
The ROM scans pages `0x00`–`0x6F` at every hardware reset, writing test patterns (`0x5A` / `0xA5`) and reading them back. The first page that fails marks the physical RAM limit, which is stored in `RAM_END`. This means `RAM_END` automatically reflects installed RAM: ~2 KB stock, or expanded with CE-151/CE-159/a modern recreation/etc.

**Cold-start "NEW0? :CHECK" prompt:** during the hardware-reset routine, the ROM checks the status byte at `0x7A20` (`WARM_START`). If it isn't `0x01`, or specific pointers in the `0x78–0x7A` page are zero, the system treats memory as unreliable (e.g. a RAM card was just swapped) and forces a cold start — displaying `NEW0? :CHECK` and requiring the user to acknowledge that program memory may be lost.

**`NEW` command side-effects on program memory:**

| Command | Effect |
|---|---|
| `NEW` (RUN mode) | Clears variables only; BASIC program preserved |
| `NEW` (PRO mode) | Clears BASIC program; variables preserved |
| `NEW` (RESERVE mode) | Clears the programmed reserve keys/text |
| `NEW 0` | Full reset to default program start (auto-detects internal vs. expansion RAM); wipes all memory |
| `NEW &<offset>` | Sets `BASPRG_ST` to a custom offset, protecting assembly code below it from BASIC; writes `0xFF` at the new start and resets `BASPRG_END`/`BASPRG_EDT`, then fully re-initializes the interpreter |

### I/O Registers (CE1 Peripheral Controller)

| Label | Address | Description |
|---|---|---|
| `PC1500_DIV_RESET` | `0xF004` | Divider reset |
| `PC1500_UREG_OUTP` | `0xF005` | U register output |
| `PC1500_SER_XFR` | `0xF006` | Serial transfer |
| `PC1500_F_REG` | `0xF007` | F register load/divider |
| `PC1500_PRT_C` | `0xF008` | Port C |
| `PC1500_G_REG` | `0xF009` | G register |
| `PC1500_MSK_REG` | `0xF00A` | Mask register |
| `PC1500_IF_REG` | `0xF00B` | Interrupt flag register |
| `PC1500_PRT_A_DIR` | `0xF00C` | Port A direction |
| `PC1500_PRT_B_DIR` | `0xF00D` | Port B direction |
| `PC1500_PRT_A` | `0xF00E` | Port A |
| `PC1500_PRT_B` | `0xF00F` | Port B |

### CE-150 Printer / Plotter Labels

RAM variables (ME0):

| Label | Address | Description |
|---|---|---|
| `USER_CTRX_H/L` | `0x79E0/0x79E1` | CE-150 pen X coordinate counter |
| `USER_CTRY_H/L` | `0x79E2/0x79E3` | CE-150 pen Y coordinate counter |
| `CURR_PEN` | `0x79EC` | Current pen: 00=up, 01=down |
| `PRNT_MODE` | `0x79F0` | Print mode: 00=TEXT, FF=GRAPH |
| `PRNT_COLOR` | `0x79F3` | COLOR setting (0–3) |
| `PRNT_CSIZE` | `0x79F4` | CSIZE setting (0–3) |

ROM entry points (ME1, via `sjp` or called by BASIC):

| Label | Address | Description |
|---|---|---|
| `PRINT_150` | `0xA781` | Print ASCII character (no LF) |
| `MOTOFF` | `0xA769` | Printer motor OFF |
| `MOTDRV` | `0xA8DD` | Motor drive, move pen |
| `LFEED` | `0xA951` | Line feed |
| `NLFEED` | `0xAA04` | Send N line feeds to printer |
| `PENUPDOWN` | `0xAAE3` | Pen up/down |
| `GRPHPREP` | `0xABEF` | Switch from text to graphics mode |
| `TEXT` | `0xACA6` | TEXT mode |
| `TEXTPREP` | `0xACD3` | Text mode preparation |
| `GRAPH` | `0xACD3` | GRAPH mode |
| `ROTATE` | `0xB15A` | ROTATE setting |
| `COLOR` | `0xB16A` | COLOR setting |
| `CSIZE` | `0xB180` | CSIZE setting |
| `LINE` | `0xB222` | Draw LINE |
| `RLINE` | `0xB224` | Draw RLINE (relative) |
| `LPRINT_150` | `0xB2EC` | LPRINT |
| `CSAVE_150` | `0xB8A6` | CSAVE to tape |
| `CLOAD_150` | `0xB8F9` | CLOAD from tape |
| `MERGE_150` | `0xB994` | MERGE from tape |
| `RMT` | `0xBEF9` | RMT (remote control) |
| `REMOTEON` | `0xBF11` | Remote ON |
| `REMOTEOFF` | `0xBF43` | Remote OFF |

### Calling Conventions

There is no hardware ABI. ROM routines use an ad-hoc convention:

- **Parameters:** passed in A, X, Y, U — specific to each routine (see ROM Subroutine Reference)
- **Return values:** typically in A (8-bit result) or X (16-bit result / pointer)
- **Register preservation:** not guaranteed; assume all registers modified unless documented otherwise. The ROM source documents modified registers per routine.
- **Stack:** S starts at `CPU_STACK + 0x4F` = `0x784F`. Each `psh Rreg` decrements S by 2; `psh a` by 1. Each `sjp` decrements S by 2 (return address).
- **Inline parameters:** many VMJ routines take 1–3 bytes of inline data immediately after the `CD nn` opcode, consumed by the subroutine itself. The return address on the stack already points past these bytes when RTN is executed.

### `CALL expression, variable` — BASIC Variable Passing

When BASIC invokes an assembly routine via `CALL addr, VAR`, BASIC marshals the variable into and optionally out of registers. The assembly routine does **not** access the BASIC variable directly.

#### Numeric variable (`VAR` is a numeric variable, range −32768 to 32767)

| Phase | What BASIC does | What the routine sees |
|---|---|---|
| Entry | Loads the variable's current value into **Xreg** | Xreg = variable value |
| Return (C=1) | Copies **Xreg** back into the variable | Routine sets Xreg to result, then `sec` / `rtn` |
| Return (C=0) | Variable is **not** updated | Routine sets `rec` / `rtn` for read-only use |

```asm
; BASIC: CALL &7800, N
; Entry: Xreg = value of N (−32768..32767)
; Return with carry set → Xreg written back to N
MY_ROUTINE:
    ; ... compute result in Xreg ...
    sec                 ; signal BASIC to write Xreg → N
    rtn

; Read-only variant — N is not modified
MY_READONLY:
    ; ... use Xreg, do not want writeback ...
    rec                 ; clear carry — BASIC leaves N unchanged
    rtn
```

#### Non-numeric (string) variable (`VAR` is a string variable)

| Phase | What BASIC does | What the routine sees |
|---|---|---|
| Entry | Loads **leading address** of the string buffer into **Xreg**; loads **size** of the variable into **A** | Xreg = address, A = allocated size |
| Return (C=1) | Copies **A** bytes from the address in **Xreg** into the string variable | Routine sets Xreg = source address, A = byte count, then `sec` / `rtn` |
| Return (C=0) | String variable is **not** updated | Routine sets `rec` / `rtn` |

```asm
; BASIC: CALL &7800, A$
; Entry: Xreg = address of A$ buffer, A = allocated size of A$
; Return with carry set → A bytes from (Xreg) are stored into A$
MY_STR_ROUTINE:
    ; ... Xreg already points to the string buffer ...
    ; ... write result bytes there, put length in A ...
    sec                 ; signal BASIC to update A$
    rtn
```

> **Note:** Using `CALL addr, VAR` where `VAR` is a string that has not been previously defined (dimensioned or assigned) will cause ERROR 7.

#### Summary table

| Variable type | Xreg on entry | A on entry | Writeback condition | What is written back |
|---|---|---|---|---|
| Numeric | Variable value (16-bit signed) | — | C=1 on RTN | Xreg → variable |
| String | Leading address of string buffer | Allocated size | C=1 on RTN | A bytes from (Xreg) → variable |

### VEJ Vector Table (ROM-defined, 0xFFC0–0xFFFE)

The VEJ instruction jumps to the address stored at `0xFF00 + operand`. Valid operands: even values 0xC0–0xFE (28 entries).
**Syntax: `vej (nn)` — plain hex digits in parentheses, no `0x` prefix inside the parens.**

| Syntax | ROM Function |
|---|---|
| `vej (C0)` | Load next token/character into U register |
| `vej (C2)` | Check if character in U matches inline arg; branch if not |
| `vej (C4)` | Check if next character in U matches inline arg; branch if not |
| `vej (C6)` | Decrement Y by 2 (token) or 1 (character) |
| `vej (C8)` | Syntax check: jump forward if not end-of-command |
| `vej (CA)` | Transfer X to variable at offset b1 |
| `vej (CC)` | Load X from variable address at offset b1 |
| `vej (CE)` | Determine address of variable b1; branch if not numeric |
| `vej (D0)` | Convert AR-X to integer into U; branch on overflow |
| `vej (D2)` | Reseed AR-X with integer or process CSI |
| `vej (D4)` | Transmit current processing status pointer |
| `vej (D6)` | Load address pointer from memory to AR-Y |
| `vej (D8)` | Check if program expires (Z=0 if so) |
| `vej (DA)` | Cache variable address from U and length from AR-X |
| `vej (DC)` | Load CSI from AR-X |
| `vej (DE)` | Evaluate formula pointed to by Y; jump forward on error |
| `vej (E0)` | Error check: branch if UH ≠ 0x00 |
| `vej (E2)` | Start of BASIC interpreter |
| `vej (E4)` | Output error 1, return to editor |
| `vej (E6)` | Transfer AR-X to AR-Y |
| `vej (E8)` | Convert AR-X to absolute BCD form |
| `vej (EA)` | Push AR-X one nibble left |
| `vej (EC)` | Clear arithmetic register X (ARX = 0) |
| `vej (EE)` | AR-X = AR-X + AR-U |
| `vej (F0)` | AR-X = AR-X + AR-Y (floating-point addition) |
| `vej (F2)` | Clear LCD display. **Does not reset cursor pointer at `0x7875`** — always follow with `ldi a,0x00` then `sta (CURSOR_PTR)`. |
| `vej (F4)` | Load U with 16-bit value from address w1 |
| `vej (F6)` | Transfer U to address w1 |
| `vej (F8)` | Maskable interrupt routine entry |
| `vej (FA)` | Timer interrupt routine entry |
| `vej (FC)` | Non-maskable interrupt routine entry (executes RTI) |
| `vej (FE)` | Reset routine entry |

---

## ROM Subroutine Reference

The PC-1500 ROM exposes subroutines via three mechanisms:
- **`vmj 0xnn`:** Two-byte call `CD nn`; vectors at `0xFF00+nn`. Valid: even `0x00–0xBE`. Syntax: plain byte immediate with a `0x` prefix, no parentheses.
- **`vej (nn)`:** Single-byte opcode `nn`; vectors at `0xFF00+nn`. Valid: even `0xC0–0xFE`. Syntax: hex digits in parentheses, no `0x` prefix inside the parens. (See VEJ Vector Table above.)
- **`sjp 0xnnnn`:** Direct call to fixed ROM address (math routines).

### Inline Parameter Convention

Many routines consume inline bytes placed immediately after the call opcode. The return address on the stack points past those bytes; RTN resumes at the correct location. Write inline parameter bytes directly with `.db`:

```asm
    vmj  0x00            ; CD 00 -- range-check ul vs [P1..P2]
    .db 0x20           ; P1 -- lower bound
    .db 0x7E           ; P2 -- upper bound
    .db OUT_OF_RANGE-.-1  ; P3 -- relative forward branch if out of range
    ; falls through here if ul in [P1..P2]
OUT_OF_RANGE:
```

### Arithmetic Register (AR-X) Format

AR-X, AR-Y, AR-Z, AR-U, AR-V, AR-W, AR-S are 8-byte BCD float structures at `0x7A00–0x7A37`. Most math calls require `xh = yh = 0x7A` on entry — set with `vmj(0x54)`.

**Numeric format:**

| Offset | Address | Content |
|---|---|---|
| +0 | `7A00` | Exponent |
| +1 | `7A01` | Sign: `0x00`=positive, `0x80`=negative |
| +2–+7 | `7A02–7A07` | BCD mantissa, 12 digits MSB first |

**Character string info (CSI):** marker `0xD0` at `7A04`, then H:L address at `7A05:7A06`, length at `7A07`.

**Binary integer:** marker `0xB2` at `7A04`, value at `7A05:7A06`.

### VMJ Subroutine Table

> **Syntax reminder:** `vmj 0xnn` (plain byte immediate, `0x` prefix, no parentheses). Example: `vmj 0x92`, not `vmj (0x92)`. The "VMJ" column below shows the vector number as `(0xxx)` for readability, but in source code always write `vmj 0xxx`.

#### Syntax / Token Parsing

| VMJ | Addr | Description | Syntax | Entry | Modified |
|---|---|---|---|---|---|
| `(0x00)` | `0xDCB7` | Range-check UL ∈ [P1..P2]; branch P3-relative if out | `CD 00 P1 P2 P3` | U=token/char | X, A |
| `(0x02)` | `0xDCB6` | Like (0x00) but first loads next token via (0xC0) | `CD 02 P1 P2 P3` | Y→BASIC mem | X, Y, A |
| `(0x04)` | `0xDCC6` | Check UL for EOC (0x3A) or EOL (0x0D); branch P1 if neither | `CD 04 P1` | U=char | X, A; C=1 if EOC |
| `(0x0C)` | `0xDE97` | Get string length at Y; load AR-X with CSI | `CD 0C` | Y→string | X, Y, U, A |
| `(0x0E)` | `0xD461` | Find variable address from coded name in U; P1=type (58=all, 68=numeric, 40=string); P2=error branch | `CD 0E P1 P2` | U=var name, Y→indices | X, Y, U, A |
| `(0x1A)` | `0xD2E6` | Search BASIC line, set memory-map params | `CD 1A` | — | X, Y, U, A |
| `(0x1C)` | `0xFA89` | Find BASIC command start from token in U, using token table at X | `CD 1C` | U=token, X→table | — |
| `(0x20)` | `0xDF72` | Advance Y to next line number (max 77 bytes); Z=1 if within limit | `CD 20` | Y→BASIC | X, Y, U, A |
| `(0x22)` | `0xDF63` | Load next token/char from BASIC into U; load AR-X CSI if string follows | `CD 22` | Y→BASIC | X, Y, U, AR-X; C=1 if string |
| `(0x26)` | `0xDB87` | Check AR-X: branch P1 if BCD (not string); C=0 if BCD | `CD 26 P1` | AR-X=value | X, UH, A |
| `(0x28)` | `0xDBB1` | Check variable dimensionality (0x788C); branch P1 if 2D; C=1 if 1D | `CD 28 P1` | — | X, UH, A |
| `(0x34)` | `0xDF23` | Multi-branch: search A in inline char table; branch to paired offset on match | `CD 34 P1 P2 P3 P4 P5…` | A=char, UH=token flag | X, A; Y/U unchanged |
| `(0x3C)` | `0xFA74` | Find token table for current device (A=(OPN) doubled) | `CD 3C` | A=(OPN) | X, A; C=1 if found |
| `(0xCE)` | `0xD45D` | Find variable address from name at Y-area; same params as (0x0E) | `CE P1 P2` | Y→var name | same as (0x0E) |
| `(0xD2)` | `0xDD1A` | Dispatch on AR-X type: BCD→continue, binary→call (0x10), string→branch P1 | `D2 P1 P2` | AR-X | X, U, A |

#### Variable / Memory Access

| VMJ | Addr | Description | Syntax | Entry | Modified |
|---|---|---|---|---|---|
| `(0x06)` | `0xD065` | Pop 16-bit address from BASIC stack (0x7882) into U; update stack pointer | `CD 06` | — | X, U, A; (0x7882) |
| `(0x0A)` | `0xDE5E` | Decode variable name/address from X into AR-X and A; reads numeric value if numeric var | `CD 0A` | X=var name or addr | all except Y |
| `(0x10)` | `0xDD2D` | Convert U to format per P1: 0x00=BCD→AR-X, 0x40=ASCII→(Y), 0x80=signed int→AR-X, 0xE0=3-digit | `CD 10 P1` | U=int | AR-X, all CPU regs |
| `(0x16)` | `0xDFF5` | Compute distance from X to BASIC program end | `CD 16` | X=addr | U, A |
| `(0x24)` | `0xDEAF` | Load CSI into AR-X[7A04–7A07] from X=address, A=length | `CD 24` | X=addr, A=len | U, A=0xD0 |
| `(0x2A)` | `0xD03E` | Copy system message from ROM page 0xC3xx to Y-buffer; P1=src low byte, P2=count | `CD 2A P1 P2` | Y→dest | X, Y, U, A |
| `(0x30)` | `0xDC16` | Decrement BASIC stack pointer (0x7882) by 8; save AR-X to stack | `CD 30` | — | X, UL=0xFF, A |
| `(0x32)` | `0xD071` | Push U (16-bit address) onto BASIC stack; increment (0x7882) by 2 | `CD 32` | U=addr | X, A |
| `(0x36)` | `0xDFOF` | Find string literal or string variable at Y; load AR-X CSI | `CD 36` | Y→input buf or BASIC | X, Y, U, A; C=1 if found |
| `(0x38)` | `0xCE9F` | Get reserve memory start address into X (L-byte always 0x08) | `CD 38` | — | X=reserve start, UH=0x18, A |
| `(0x3A)` | `0xCFFB` | Initialize FOR/GOSUB stack pointers and 0x788A, 0x7B0E | `CD 3A` | — | (0x788A)=0x00, (0x7890)=0x38, (0x7891)=0xFF |

#### Arithmetic

| VMJ | Addr | Description | Syntax | Entry | Modified |
|---|---|---|---|---|---|
| `(0x50)` | `0xDA71` | 16×16-bit integer multiply U×Y → X:Y; C=1 if result > 16 bits | `CD 50` | U, Y=integers | X, Y, U, A |
| `(0x52)` | `0xF663` | Normalize AR-X (exponent/mantissa align); A=sign. Error 0x19→UH+C if overflow | `CD 52` | A=sign, AR-X=raw result | X, Y, U, A |
| `(0x54)` | `0xF7B0` | Set XH=YH=0x7A — required before most AR math calls | `CD 54` | — | XH=0x7A, YH=0x7A only |
| `(0x56)` | `0xF7B0` | Copy 8 bytes (XH:00–07) → (YH:00–07); if both→7Axx: AR-Y→AR-X | `CD 56` | X, Y→areas | XL=0x18, YL=0x08, UL=0xFF |
| `(0x58)` | `0xF084` | Division: AR-X = AR-X / AR-Y; div/0 → UH=0x1A, C=1 | `CD 58` | AR-X, AR-Y, XH=YH=0x7A | X=0x7A00, Y=0x7A08, U, A |
| `(0x5E)` | `0xF7A7` | Transfer RNG value (0x7B01–0x7B07) to AR-X | `CD 5E` | YH=0x7A | X=0x7A08, Y, UL |
| `(0x5C)` | `0xF61B` | Generate random number | `CD 5C` | — | — |
| `(0x60)` | `0xF6B4` | Split AR-X into integer (AR-X) and fractional (AR-Y) parts | `CD 60` | XH=YH=0x7A | X=0x7A08, Y=0x7A18, U, A=exp |
| `(0x62)` | `0xF88B` | Clear AR-Y; load 0.6 into AR-Y; C=1 | `CD 62` | XH=YH=0x7A | X, YL=0x13, UL=0xFF, A=0xF5 |
| `(0x64)` | `0xF7B5` | Swap AR-X ↔ AR-S | `CD 64` | XH=YH=0x7A | X=0x7A08, Y=0x7A38, U, A |
| `(0x66)` | `0xF7B9` | Swap AR-X ↔ AR-Y | `CD 66` | XH=YH=0x7A | X=0x7A08, Y=0x7A18, U, A |
| `(0x68)` | `0xF715` | Copy 8 bytes (XH:30–38) → (YH:10–18); if 7Axx: AR-S→AR-Y | `CD 68` | X, Y | XL=0x38, YL=0x18, UL=0xFF |
| `(0x6A)` | `0xF88F` | Write 1.0 to AR-Y; set C=1 | `CD 6A` | XH=YH=0x7A | X=0x7AEF, Y=0x7A13, UL=0xFF, A=0xEC |
| `(0x6C)` | `0xF6FB` | Load sign of AR-X into A; make AR-X absolute | `CD 6C` | X→7Axx | XL=0x01, A=sign |
| `(0x6E)` | `0xF080` | AR-X = 1/AR-X; AR-X=0 → UH=0x26, C=1 | `CD 6E` | AR-X, X/Y→7Axx | X=0x7A00, Y=0x7A08, AR-Y, AR-Z, U=0x0005, A |
| `(0x70)` | `0xF747` | Clear sign+mantissa of AR-Y (7 bytes at XH+0x11) | `CD 70` | X→7Axx | X=0x7A18, UL=0xFF, A=0x00 |
| `(0x72)` | `0xF7CE` | Add decimal mantissa at Y to AR-X (no overflow/sign check) | `CD 72` | X→7Axx, Y free | X, Y, U, A |
| `(0x74)` | `0xF775` | Shift AR (xx01–xx07) right one nibble; XH selects page | `CD 74` | XH=page | X=xx07, A=prev(xx07) |
| `(0x76)` | `0xF75F` | Clear AR (xx01–xx07) to 0x00; XH selects page | `CD 76` | XH=page | X=xx08, A=0x00 |
| `(0x78)` | `0xF72F` | Copy AR sign+mantissa (XH:01–07) → (YH:09–0F) | `CD 78` | X, Y | X=XH08, Y=YH10 |
| `(0x7A)` | `0xF7DD` | Subtract AR-X and AR-Y mantissas; exponent ignored | `CD 7C` then `7A` | XH=YH=0x7A | X=0x7A00, Y=0x7A10, A=sign |
| `(0x7C)` | `0xF6E6` | XOR signs of AR-X and AR-Y; set both signs to positive | `CD 7C` | XH=YH=0x7A | X=0x7A00, Y=0x7A10, A=XOR |
| `(0x7E)` | `0xF6E6` | Multiply: AR-X = AR-X × AR-Y; overflow → V flag | `CD 7E` | AR-X, AR-Y, XH=YH=0x7A | X=0x7A00, Y=0x7A09, U, AR-W/V/U/Z |
| `(0x80)` | `0xF707` | Copy AR-X → AR-S | `CD 80` | — | X=0x7A08, Y=0x7A38; UH, A preserved |
| `(0x82)` | `0xF729` | Copy AR-X sign+mantissa → AR-Y | `CD 82` | XH=YH=0x7A | X=0x7A08, Y=0x7A18, U |
| `(0x96)` | `0xEA78` | Format AR-X for USING output | `CD 96` | AR-X, USING params | X, Y, U, A |
| `(0x9E)` | `0xE4A0` | Compare string at Y with CSI in AR-Y; if equal, AR-X=1 and Z=0 | `CD 9E` | Y→string1, AR-Y=CSI | X, Y, U, A |

#### Display

| VMJ | Addr | Description | Syntax | Entry | Modified |
|---|---|---|---|---|---|
| `(0x42)` | `0xCA58` | Return to RUN/input mode; init stacks, clear LCD, show prompt | `CD 42` | — | — |
| `(0x84)` | `0xEF00` | Disable blinking cursor | `CD 84` | — | (0x787C) bits 0,1 cleared |
| `(0x88)` | `0xEDF6` | Write bit pattern A to LCD matrix column at X (bits 0–6 shown) | `CD 88` | X→col, A=bits | X=next col, UH=pattern, A |
| `(0x8A)` | `0xED5B` | Display ASCII char A at matrix column X; bit 7 selects extended charset | `CD 8A` | X→col, A=char | X+=6, A, U |
| `(0x8C)` | `0xEE1F` | Compute matrix column address from cursor pointer (0x7875) | `CD 8C` | (0x7875)=0–0x9C | X=col addr, A |
| `(0x8E)` | `0xEDB1` | Increment cursor pointer (0x7875); clamp at 0x9C; C=1 if clamped | `CD 8E` | — | (0x7875), A=new value, C |
| `(0x90)` | `0xEDAB` | Load cursor pointer (0x7875) into A; C=1 if > 0x9C | `CD 90` | — | A=cursor, C |
| `(0x92)` | `0xED00` | Display text at cursor: U=text address, A=char count; C=1 if display full. **Call exactly once per display update** — multiple sequential calls corrupt display state. Build the entire string in a buffer first, then call once. | `CD 92` | (0x7875)=cursor, U=text, A=count | X=next col, U=last ptr, A |
| `(0x94)` | `0xEC5C` | Copy string (X=addr, UL=length) to output buffer; C=1 if overflow | `CD 94` | X=addr, UL=len | X, Y=next free buf, C |

#### OS / System Control

| VMJ | Addr | Description | Syntax | Entry | Modified |
|---|---|---|---|---|---|
| `(0x12)` | `0xDF93` | Get BASIC program start address into X | `CD 12` | — | X=prog start, A=XH |
| `(0x14)` | `0xDFFA` | Get BASIC program start address (X) and length (U) | `CD 14` | — | X, U, A |
| `(0x18)` | `0xDF80` | Update memory-map for last processed instruction; if C=1 on entry, set bit 7 in YH | `CD 18` | Y→BASIC, C | X, Y, U, A |
| `(0x1E)` | `0xFB2A` | PV-Banking control; A bit 0=1 activates banking; updates (0x79D0) | `CD 1E` | A=control | A=0xFE |
| `(0x3E)` | `0xFB9B` | Trace | `CD 3E` | — | — |
| `(0x40)` | `0xC401` | Enter BASIC interpreter | `CD 40` | — | — |
| `(0x48)` | `0xDCF9` | Return from subroutine; skip inline params via stack-stored distance byte | `CD 48` | stack=return+dist | X, A |
| `(0x4A)` | `0xDCFD` | Like (0x48) but saves/restores Y | `CD 4C` | stack=return+dist+Y | X, Y, A |
| `(0x4C)` | `0xDCE9` | Return from subroutine past last inline param | `CD 4C` | stack=return past params | X, A |
| `(0x4E)` | `0xDCED` | Like (0x4A)+(0x4C): return + restore Y | `CD 4E` | — | X, Y, A |
| `(0x5A)` | `0xE573` | Timer IC mode select via I/O port (C0/C1/C2 = A bits 3–5) | `CD 5A` | A=mode | U, Y=0xF008, A |
| `(0xA0)` | `0xE234` | PV-Banking: activate if (0x79D0) bit 0=1 | `CD A0` | — | Z may change |
| `(0xA2)` | `0xE655` | Beep toggle (checks 0x786B bit 0); C=1 if beep now OFF | `CD A2` | — | C |
| `(0xA6)` | `0xE451` | Test BREAK/ON key (bit 1 of 0xF00B); Z=0 if pressed, Z=1 if not pressed | `CD A6` | — | Z |
| `(0xAC)` | `0xE88C` | Delay U × 15.625 ms; Break key can abort early | `CD AC` | U=count | U=0x00FF, A |
| `(0xB2)` | `0xB897` | Set Z=1 if U=0xFFFF | `CD B2` | U | Z |
| `(0xBA)` | `0xF763` | Clear memory block; X=start, UL=count−1 | `CD BA` | X=start, UL=count−1 | X=first byte after, UL=0xFF, A=0x00 |
| `(0xBC)` | `0xE4B7` | Find next lower token table in 0x8000–0xC000 from X | `CD BC` | X→area | X, UH, A |
| `(0xBE)` | `0xE4A8` | Find topmost token table in 0x8000–0xC000; UH=2 if CE-150, 1 if CE-158; C=1 if found | `CD BE` | — | X, UH, A |

#### BASIC Interpreter

| VMJ | Addr | Description | Syntax | Entry | Modified |
|---|---|---|---|---|---|
| `(0xD4)` | `0xDEE3` | Set BASIC execution pointer; P1=0xAC=current line, 0xB2=error info | `D4 P1` | Y=BASIC addr | X, U=0x78AC |
| `(0xD6)` | `0xDED1` | Load Y with new BASIC addr from memory-map area; P1=source area low byte | `D6 P1` | — | X, Y, U, A |
| `(0xD8)` | `0xDF3B` | Check if BASIC program running; Z=1 if NOT running | `D8` | — | A |
| `(0xDA)` | `0xC00E` | Cache variable address from U and length from AR-X to 0x7883–0x7885 | `DA` | U=var addr | A |
| `(0xDC)` | `0xDEBC` | Load X from AR-X CSI address (7A05:7A06); length/flag → A/UL | `DC` | AR-X=CSI | X, U, A |
| `(0xE0)` | `0xCD8B` | Output ERROR 1; return to RUN mode | `E0` | — | — |
| `(0xE2)` | `0xC400` | BASIC interpreter entry | `E2` | — | — |
| `(0xE4)` | `0xCD89` | Output ERROR from UH; return to RUN mode | `E4` | UH=error code | — |

#### Tape / CMT (Rarely useful from assembly)

| VMJ | Addr | Description |
|---|---|---|
| `(0xA4)` | `0xB888` | Load character from tape |
| `(0xA8)` | `0xB88B` | Save character to tape |
| `(0xAA)` | `0xBD3C` | File transfer to/from tape |
| `(0xAE)` | `0xB891` | Compare checksum of received data |
| `(0xB0)` | `0xBCE8` | Load/receive program header from tape |
| `(0xB6)` | `0xB89D` | Create tape program header |
| `(0xB8)` | `0xB8A0` | Syntax check cassette "-1" operation; update RMT param (0x7879) |

### Absolute ROM Math Routines

Called via `sjp 0xaddr`. Require XH=YH=0x7A (`vmj(0x54)`) and AR-X (or AR-X+AR-Y) to contain BCD float values. Results in AR-X; error code in UH on failure.

| Address | Function | Entry | Returns |
|---|---|---|---|
| `0xF161` | LOG (base 10) | AR-X = float | AR-X = log₁₀(AR-X) |
| `0xF165` | LN (natural log) | AR-X = float | AR-X = ln(AR-X) |
| `0xF1CB` | EXP (eˣ) | AR-X = float | AR-X = e^AR-X |
| `0xF1D4` | — (not documented) | — | — |
| `0xF391` | COS | AR-X = angle | AR-X = cos(AR-X) |
| `0xF39E` | TAN | AR-X = angle | AR-X = tan(AR-X) |
| `0xF3A2` | SIN | AR-X = angle | AR-X = sin(AR-X) |
| `0xF492` | ACS (arccos) | AR-X = value | AR-X = arccos(AR-X) |
| `0xF496` | ATN (arctan) | AR-X = value | AR-X = arctan(AR-X) |
| `0xF49A` | ASN (arcsin) | AR-X = value | AR-X = arcsin(AR-X) |
| `0xF531` | DEG→RAD | AR-X = degrees | AR-X = radians |
| `0xF564` | DMS | AR-X = decimal degrees | AR-X = degrees/minutes/seconds |
| `0xF59D` | SGN | AR-X = float | AR-X = sign: +1, 0, or −1 |
| `0xF5BE` | INT | AR-X = float | AR-X = integer part (truncated) |
| `0xEFB6` | — (not documented) | — | — |
| `0xF0E9` | — (not documented) | — | — |

---

## Common Assembler Macros

Recurring address-arithmetic and inline-byte idioms, written as plain sdas expressions/directives (see Standard Library Macros above for the bank-switch pair):

| Idiom | sdas expression |
|---|---|
| High byte of `label` | `(label)>>8` |
| Low byte of `label` | `(label)&0xFF` |
| Forward relative branch offset | `.db label-.-1` |
| Raw byte | `.db n8` |
| Low byte of a 16-bit constant | `.db (n16)&0xFF` |
| Character literal | `.db ch` |
| 16-bit word | `.dw n16` |
| HIGH_BANK (switch to ME1) | `spu` then `spv` |
| LOW_BANK (switch to ME0) | `rpu` then `spv` |

---

## Appendix: Converting a TASM Source to sdas

Older PC-1500 sources (e.g. from `Sharp_CE-158`-style repos) are often written for TASM (`tasm5801.tab`): uppercase mnemonics/registers, `$`-prefixed hex, `.EQU`/`.ORG`/`.DB`/`.BYTE`/`.DW`/`.WORD`/`.TEXT`/`.ASCII`, no segment concept, trailing `.END`. `pc1500disasm --mode convert` rewrites such a file to sdas automatically:

```sh
pc1500disasm --mode convert old_source.asm -o old_source.sdas.asm
```

It handles the directive/hex/case rewrite above, and renames three TASM mnemonics that alias LH5801 opcodes under Z80/8080-familiar names with no sdas equivalent — `CALL`/`RET`/`SCF` → `sjp`/`rtn`/`sec` — as a real rename, not a case fold. A trailing `.END` is dropped (sdas has no such directive; a real `sdaslh5801` build rejects one). Only the first `.ORG` in a file gets wrapped in the synthesized `.area CODE (ABS)` header — a second `.ORG` (multi-segment TASM source) is a warning, not a full conversion.

**Not handled** — these need a real preprocessor/macro-expander, not a syntax rewrite, and are reported as errors: `#include`/`#define`/`#ifdef` preprocessor directives, `.EXPORT` (cross-module linking), `MACRO`/`ENDM` blocks. An unrecognized mnemonic/directive is passed through unchanged with a warning — always check the converted output actually assembles with `sdaslh5801` before trusting it.

---

## Writing a User Guide for Assembly Programs

A PC-1500 assembly program invoked from BASIC (`CALL &addr`) is opaque to the user without documentation. Write the user guide before implementation — it defines the interface contract the code must satisfy.

### What the User Guide Must Cover

1. **Purpose** — one paragraph: what the program does, what problem it solves.
2. **Installation** — how to load into RAM (POKE sequence, `CLOADM`, or tape); which address range it occupies; whether it survives a `NEW` command (it will not if it lives in BASIC program memory).
3. **Invocation** — exact BASIC command(s): e.g., `CALL &7800` or `CALL &7800,x`; any setup required before calling (variable values, mode).
4. **Parameters and return values** — if called via `CALL addr,x`: what X must contain on entry; what X, Y, A contain on return; which BASIC variables are modified.
5. **Keyboard controls** — if interactive: key-by-key table of what each key does.
6. **Display layout** — description of what appears on the 26-character LCD; any special characters or cursor behavior.
7. **Error conditions** — what happens on invalid input; how the user recovers.
8. **Memory map** — start address, end address, total bytes; any fixed RAM locations used that could conflict with BASIC variables.
9. **Known limitations** — what the program cannot do; edge cases; ROM version dependencies (A01 vs A03/A04).
10. **Example session** — short walkthrough: what the user types, what appears on screen.

### Documentation Template

Place this template as a comment block at the top of the `.asm` source file:

```asm
;==============================================================================
; PROGRAM:     <Name>
; VERSION:     1.0
; DATE:        <YYYY-MM-DD>
; AUTHOR:      <Author>
;------------------------------------------------------------------------------
; PURPOSE:
;   <One paragraph describing what the program does and what problem it solves.>
;
; INSTALLATION:
;   Load via: POKE sequence / CLOADM / tape
;   Address range: 0x<start> – 0x<end>  (<N> bytes)
;   Survives NEW: No / Yes (if loaded above BASIC program area)
;
; INVOCATION:
;   CALL &<addr>
;   or: CALL &<addr>,x   (x = <description of entry value>)
;
; PARAMETERS:
;   Entry:  x = <value of numeric VAR, or address of string VAR>
;           a = <allocated size of string VAR, or not used for numeric>
;   Return: x = <result (numeric) or source address (string)>
;           a = <byte count to write back (string only)>
;           C = 1 → BASIC writes Xreg back to VAR; C = 0 → VAR unchanged
;   Modified BASIC variables: <none / list>
;
; KEYBOARD CONTROLS:
;   <key>  : <action>
;   <key>  : <action>
;
; DISPLAY:
;   <Description of LCD layout, e.g.:>
;   Columns 1-10: <field>    Columns 11-26: <field>
;
; ERROR CONDITIONS:
;   <condition> : <result / recovery>
;
; MEMORY MAP:
;   0x<start> – 0x<end>  Code (<N> bytes)
;   0x<start> – 0x<end>  Data / variables (<N> bytes)
;
; KNOWN LIMITATIONS:
;   - <limitation 1>
;   - <limitation 2>
;
; EXAMPLE:
;   > CALL &7800
;   <what appears on screen>
;   <user presses key, what happens next>
;
; ROM VERSION:
;   Tested on A03/A04. May differ on A01 (see #IFNDEF blocks in source).
;==============================================================================
```

### In-Source Documentation Conventions

Consistent with the PC-1500 ROM disassembly conventions used throughout this project:

- **Subroutine header:** 80-character `; ---...---` separator, address (if known), name, one-line description.
- **Entry/exit contract:** `; Entry parameters:` / `; Modified registers:` / `; Error conditions:` blocks before each subroutine.
- **Inline comments:** on any instruction where the intent is not immediately obvious from the mnemonic and operand.
- **Markers:** `; TODO:` for deferred work, `; FIXME:` for known bugs or wrong behavior.

Example:

```asm
;------------------------------------------------------------------------------
; MY_ROUTINE (0x7800)
; Brief: Display the value in a as two hex digits on the LCD.
;
; Entry parameters:
;   a = byte to display
;   x = pointer to matrix column (from vmj(0x8C))
;
; Modified registers:
;   x, a, u
;
; Error conditions:
;   None.
;------------------------------------------------------------------------------
MY_ROUTINE:
    psh  u              ; save u
    ; ... implementation ...
    pop  u
    rtn
```

### Integration with the Assembly Project

The user guide is a deliverable alongside the `.asm` source, not an afterthought:

- **Draft the guide before writing code.** The "Invocation" and "Parameters" sections define the entry-point contract the assembly code must satisfy.
- **The "Memory map" section forces address allocation decisions before coding begins** — avoids conflicts with BASIC variables or other loaded programs.
- **The "Known limitations" section drives test cases** — each limitation should be verified as an edge case during testing.
- **Keep the guide in sync with the code** — if the interface changes during implementation, update the guide comment block first.
