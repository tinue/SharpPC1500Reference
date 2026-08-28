# Sharp PC-1500 ROM Pointers (BASIC Interpreter)

This document lists the critical memory pointers and system variables discovered during the analysis of the `PC-1500_ROM-A0x.lh5801.asm` firmware. 

### Byte Order Convention
On the PC-1500 (LH5801 CPU), 16-bit pointers are typically stored in **Big-Endian** order within the system RAM ($78xx - $7Axx).
*   The **High Byte** is stored at the primary address listed below (e.g., `ADDR`).
*   The **Low Byte** is stored at the following address (`ADDR + 1`).

## 1. Program Management Pointers
These pointers define the boundaries of the BASIC program in memory.

| Pointer | Start Address | Description |
| :--- | :--- | :--- |
| `BASPRG_ST` | `$7865` | **Program Start:** Address where the BASIC program begins. |
| `BASPRG_END` | `$7867` | **Program End:** Address where the BASIC program ends. Used by `MEM`. |
| `BASPRG_EDT` | `$7869` | **Edit Pointer:** Used by the editor during line modification. |

## 2. Variable and Data Storage
These pointers manage dynamic memory for variables and the `DATA` statement cursor.

| Pointer | Start Address | Description |
| :--- | :--- | :--- |
| `CURVARADD` | `$7883` | **Current Variable:** Pointer to the variable currently being accessed. |
| `CURVARTYPE` | `$7885` | **Variable Type:** (Byte) Stores the type of the active variable. |
| `VAR_START` | `$7899` | **Variable Boundary:** The starting address of dimensioned variables (growing downwards from the top of RAM). |
| `DATA_PTR` | `$78BE` | **DATA Cursor:** Tracks the current position in `DATA` statements. |

## 3. Interpreter State and Flow
Variables tracking the execution state of the BASIC interpreter.

| Pointer | Start Address | Description |
| :--- | :--- | :--- |
| `CURR_LINE` | `$78A0` | **Current Line:** Number of the BASIC line currently executing. |
| `PREV_LINE` | `$78A2` | **Previous Line:** Used for error reporting and `CONT`. |
| `TRACE_ON` | `$788D` | **Trace Flag:** (Byte) Non-zero if `TRON` is active. |
| `TRACE_PARAM` | `$788E` | **Trace Vector:** Vector used for trace output handling. |

## 4. Memory Limits and Status
| Pointer | Start Address | Description |
| :--- | :--- | :--- |
| `RAM_ST` | `$7863` | **RAM Start:** High byte (page) of the first valid user-RAM address; low byte is implicitly `$00`. Hardware-verified: reads `&40` on a stock PC-1500A (RAM starts at `&4000`) and `&00` with a 16 KB expansion module in the low window. Matches the `256 * PEEK(&7863)` formula in `PC-1500-Address-Decoding.md` §5.4, and sits directly below `RAM_END` at `$7864`. (An earlier revision of this table listed `$7860` here with no confirmed backing — corrected.) |
| `RAM_END` | `$7864` / `$7A13` / `$7A33` | **RAM End:** High byte (page) of the first *invalid* address — the physical RAM limit. The working pointer used by ROM `MEM` logic and by `examples/memtest_bank.asm` is `$7864`, sitting one byte above `RAM_ST`; `$7A13` / `$7A33` are the PC-1500A / PC2 copies. |
| `WARM_START` | `$7A20` | **Warm Start Flag:** Must be `$01` for the system to skip the "NEW0?" cold start. |
| `STK_SAVE` | `$7A21` | **Stack Save:** 16-bit pointer used to restore the system stack during a warm start. |

## 5. Additional System Variables
These variables control interpreter behavior and temporary states.

| Pointer | Start Address | Description |
| :--- | :--- | :--- |
| `DISP_CTRL` | `$7880` | **Display Flags:** Controls LCD refresh and auto-off timers. |
| `BREAK_STAT` | `$7881` | **Break Status:** Tracks BREAK key interrupts and execution pauses. |
| `IN_BUF_PTR` | `$7892` | **Input Buffer Cursor:** Points to the current character in the `$7Bxx` input area. |
| `ON_ERR_VEC` | `$78A4` | **Error Vector:** 16-bit address for the `ON ERROR GOTO` handler. |
| `SRCH_PTR` | `$78A6` | **ROM Search Pointer:** Temporary workspace for program/variable scanning. |
| `STK_FOR_GSB` | `$78B8` | **Logic Stack Pointer:** Current depth of the FOR-NEXT and GOSUB stacks. |

## 6. RAM Detection Process (Reset)
The PC-1500 determines the value of `RAM_END` dynamically during every hardware reset (at ROM address `$E000`). 

1. **Scanning:** The ROM scans memory pages from `$00` up to `$6F`.
2. **Write/Read Test:** At the start of each page, it attempts to write and read back test patterns (`$5A` and `$A5`).
3. **Limit Identification:** The first page that fails the test is identified as the physical memory limit.
4. **Storage:** The highest successful page address is stored in the `RAM_END` system variable.

## 6. Accessing Memory Info in Assembly
User assembly programs can retrieve memory information in two ways:

### Direct Pointer Access
Read the high byte directly from the system variable:
```assembly
; For PC-1500A / PC2:
LDI  XH, $7A
LDI  XL, $13
LDA  (X)        ; Acc = High byte of RAM limit
```

### Calling ROM Routines
Call the built-in memory calculation routine to get the number of free bytes returned in the `U` register pair:
```assembly
SJP  $DFEE      ; Call MEM_IN_UREG
; Result: UH = high byte, UL = low byte
```

## 7. Memory Calculation Formula (MEM)
The `MEM` command value is derived using the logic found at address `$DFEE`:

1. Load `BASPRG_END` ($7867).
2. Calculate `X = BASPRG_END + 1`.
3. Calculate `Result = RAM_END - X + 1`.

**Simplified Logic:** `Free Space = RAM_END - BASPRG_END`.

## 8. Cold Start and "NEW0? :CHECK"
The message `NEW0? :CHECK` is displayed by the `COLD_START` routine (`$C9E4`) when the system detects that the memory state is unreliable or has changed.

### When exactly is this error shown?
During the Hardware Reset routine (`$E000`), the system performs several checks:
1. **Memory Patterns:** It verifies that expected values exist in the system RAM (page `$78-$7A`).
2. **Status Check:** It checks a status byte at `$7A20`. If this byte is not `$01`, or if specific pointers in that page are zero, the system assumes the memory is "dirty" or a RAM card was recently swapped.
3. **Trigger:** If these checks fail, the system jumps to `COLD_START`, which displays the prompt. This forces the user to acknowledge that the previous program memory may be lost or needs to be re-initialized.

## 9. The NEW Command Behavior
The `NEW` command (`$C80A`) behaves differently depending on the active system mode and whether an argument is provided.

### 9.1 NEW (No Arguments)
The effect depends on the current computer mode:

*   **RUN Mode:** **Clears Variables.** It deletes all dimensioned and simple variables but preserves the BASIC program in memory.
*   **PRO Mode:** **Clears Program.** It deletes the BASIC program lines but typically preserves the variables.
*   **RESERVE Mode:** **Clears Reserve Area.** It clears the programmed reserve keys/text.

### 9.2 NEW <Address> (e.g., NEW 0, NEW &112)
If any argument is provided, the command performs a destructive memory reset regardless of the mode:
1. **Program Pointer Update:** It updates the `BASPRG_ST` (Program Start) to the provided address.
   *   `NEW 0`: Resets to the default start address (detecting internal vs. expansion RAM).
   *   `NEW &112`: Sets a custom start offset, often used to protect assembly code from BASIC.
2. **Memory Wipe:** It writes `$FF` to the new program start and resets all boundaries (`BASPRG_END`, `BASPRG_EDT`).
3. **Full System Init:** Performs a full re-initialization of the interpreter and system variables.
