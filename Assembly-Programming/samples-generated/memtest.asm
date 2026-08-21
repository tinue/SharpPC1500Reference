;==============================================================================
; PROGRAM:     MEMTEST
; VERSION:     1.4
; DATE:        2026-03-14
; AUTHOR:
;------------------------------------------------------------------------------
; PURPOSE:
;   Tests free RAM (the region between BASIC program end and the BASIC variable
;   area) using four alternating bit patterns: $55, $AA, $FF, $00.  Runs a
;   user-specified number of complete passes over the region.  Reports
;   "RAM test passed" on the LCD if every byte survives every pass, or
;   "RAM test failed" if a mismatch is detected.
;
; INSTALLATION:
;   Address range: $7C01 - $7D6F  (approx 367 bytes)
;
;   PC-1500A -- $7C01-$7FFF is a free area that BASIC never uses for programs
;   or variables.  No NEW command is required before loading; the code is safe
;   from BASIC interference and will not be overwritten.
;
;   PC-1500 (non-A) -- this area does not exist on the non-A model.  Always
;   enter NEW &31745 (decimal of $7C01) before loading so that BASIC reserves
;   the region and the test excludes the program image.
;
;   Assemble:
;     tasm -5801 -x7 -g3 memtest.asm memtest.bin
;
;   Transfer to PC-1500(A) -- on the computer:
;     java -jar SharpDataExchange.jar put --device pc1500a \
;          --start-address 7C01 memtest.bin
;   On the PC-1500(A), issue this first, then start the put command:
;     SETDEV U1,CI,CO
;     CLOADM
;
;   Survives NEW: Yes (PC-1500A -- lives in free area above $7BFF)
;
; INVOCATION:
;   CALL &7C01, N
;
; PARAMETERS:
;   Entry:  X = N = number of passes to run (numeric variable, 1..255)
;             Only the low byte of N is used; values 256+ are treated as
;             their low byte (e.g. 256 -> 0 -> rejected as zero passes).
;           A = not used
;   Return: X = 0  success -- all passes passed
;           X = 1  failure -- at least one byte failed
;           X = 2  N was zero -- no test was run; display unchanged
;           X = 3  aborted -- Break key was pressed during the test
;           C = 1  always (BASIC writes X back to N)
;   Modified BASIC variables: N (receives 0, 1, 2, or 3)
;
; DISPLAY:
;   Progress:    Pass: &XX, Bytes: &YYYY
;                  XX   = current pass number (hex, 01..FF)
;                  YYYY = number of bytes under test (hex, 0000..FFFF)
;   Success:     RAM test passed  (held 2 seconds before return)
;   Failure:     RAM test failed  (held 2 seconds before return)
;   Aborted:     no display change (Break pressed; last progress display remains)
;   Zero passes: no change
;
; MEMORY MAP:
;   $7C01 - $7CFF  Code
;   $7D00 - $7D6F  Read-only data + uninitialised variables (approx)
;
; KNOWN LIMITATIONS:
;   - Tests the region [BASPRG_END+1 .. VAR_START-1].  On PC-1500 (non-A)
;     enter NEW &31745 before loading so the program image is excluded.
;   - BASIC variables (if any) live near the top of RAM and will be
;     overwritten during the test -- acceptable since the caller re-reads N.
;   - Pass count is limited to 255 (only the low byte of N is used).
;   - Does not check for an empty test region (zero free bytes).
;   - 2-second hold uses VMJ ($AC); Break key may abort the delay early.
;
; EXAMPLE:
;   10 N=4
;   20 CALL &7C01,N
;   30 IF N=0 THEN PRINT "OK"
;   40 IF N=1 THEN PRINT "FAIL"
;   50 IF N=2 THEN PRINT "NO PASSES"
;   60 IF N=3 THEN PRINT "ABORTED"
;
; ROM VERSION:
;   Tested on A03/A04.
;==============================================================================

;------------------------------------------------------------------------------
; System addresses
;------------------------------------------------------------------------------
CURSOR_PTR   .EQU $7875      ; 1 byte: current LCD column position (0..$9C)
BASPRG_ENDH  .EQU $7867      ; 16-bit pointer to end of BASIC program (big-endian)
BASPRG_ENDL  .EQU $7868
VAR_STARTH   .EQU $7899      ; 16-bit pointer to start of variable area (big-endian)
VAR_STARTL   .EQU $789A

;------------------------------------------------------------------------------
; Data area addresses  (defined as labels at end of file; no fixed EQU)
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Entry point
;
; Entry:  Xreg = pass count (BASIC marshals the numeric variable into Xreg)
;------------------------------------------------------------------------------
    .org $7C01

MEMTEST:
    ;------------------------------------------------------------------
    ; 1. Reject zero passes
    ;------------------------------------------------------------------
    ; Only the low byte of the pass count is used (1..255).
    ; Reject if XL == 0 (handles N=0 and N=256, 512, etc.).
    LDI     A, $00
    CPA     XL          ; flags = $00 - XL
    BZR     COUNT_OK    ; XL != 0 -> count is nonzero, proceed
    ; Count is zero -- mark as "not run" and return.
    LDI     XH, $00
    LDI     XL, $02
    SCF                 ; carry set -> BASIC writes X register back to variable
    RTN

COUNT_OK:
    ;------------------------------------------------------------------
    ; 2. Save pass count to memory (low byte only, 1..255)
    ;------------------------------------------------------------------
    LDA  XL
    STA  (PASS_CNTL)

    ;------------------------------------------------------------------
    ; 3. Compute test range
    ;
    ;   TST_START = BASPRG_END + 1
    ;   TST_END   = VAR_START - 1
    ;
    ; BASPRG_END is a 16-bit big-endian pointer in system RAM.
    ;------------------------------------------------------------------

    ; --- TST_START = BASPRG_END + 1 ---
    LDA  (BASPRG_ENDH)
    STA  XH
    LDA  (BASPRG_ENDL)
    STA  XL
    INC  X                  ; X = BASPRG_END + 1  (16-bit, no flags)
    LDA  XH
    STA  (TST_STARTH)
    LDA  XL
    STA  (TST_STARTL)

    ; --- TST_END = Start of variable area - 1 ---
    LDA (VAR_STARTH)
    STA XH
    LDA (VAR_STARTL)
    STA XL
    DEC X
    LDA XH
    STA (TST_ENDH)
    LDA XL
    STA (TST_ENDL)

    ;------------------------------------------------------------------
    ; 3b. Compute BYTE_CNT = TST_END - TST_START + 1  (byte count)
    ;------------------------------------------------------------------
    SEC
    LDA  (TST_ENDL)
    SBC  (TST_STARTL)       ; A = TST_ENDL - TST_STARTL (C carries)
    STA  XL
    LDA  (TST_ENDH)
    SBC  (TST_STARTH)       ; A = TST_ENDH - TST_STARTH - NOT(C)
    STA  XH
    INC  X                  ; +1: inclusive range
    LDA  XH
    STA  (BYTE_CNTH)
    LDA  XL
    STA  (BYTE_CNTL)

    ;------------------------------------------------------------------
    ; 3c. Initialise pass counter
    ;------------------------------------------------------------------
    LDI  A,$00
    STA  (PASS_NUML)

    ;------------------------------------------------------------------
    ; 4. Pass loop  (8-bit PASS_CNT, decremented after each full pass)
    ;------------------------------------------------------------------
PASS_LOOP:
    ;------------------------------------------------------------------
    ; 4a. Increment PASS_NUM and show progress
    ;------------------------------------------------------------------
    LDA  (PASS_NUML)
    INC  A
    STA  (PASS_NUML)
    SJP  SHOW_PROGRESS

    ;------------------------------------------------------------------
    ; 5. Pattern loop -- 4 patterns from PAT_TABLE
    ;    Y  = pointer walking through PAT_TABLE
    ;    UL = LOP counter (4 -> 1)
    ;    PSH/POP wraps the inner write/verify phases so Y and UL survive.
    ;------------------------------------------------------------------
    LDI  YH, (PAT_TABLE)>>8
    LDI  YL, (PAT_TABLE)&$FF
    LDI  UL, 3

PAT_LOOP:
    LIN  Y                  ; A = current pattern, Y++
    STA  (PAT_NOW)          ; save pattern for inner loops
    PSH  Y                  ; save pattern-table pointer
    PSH  U                  ; save UL loop counter

    ;------------------------------------------------------------------
    ; 5a. Write phase: fill [TST_START .. TST_END] with PAT_NOW
    ;------------------------------------------------------------------
    LDA  (TST_STARTH) \ STA  XH
    LDA  (TST_STARTL) \ STA  XL

WRITE_LOOP:
    LDA  (PAT_NOW)
    STA  (X)
    ; Check X == TST_END  (end of region, last byte just written)
    LDA  XH
    CPA  (TST_ENDH)         ; Z=1 if XH matches
    BZR  WRITE_INC          ; Z=0: XH differs, not done
    LDA  XL
    CPA  (TST_ENDL)         ; Z=1 if XL also matches
    BZR  WRITE_INC          ; Z=0: same high byte but different low byte
    BCH  WRITE_DONE         ; X == TST_END: finished writing
WRITE_INC:
    INC  X
    BCH  WRITE_LOOP
WRITE_DONE:
    ;------------------------------------------------------------------
    ; 5b. Verify phase: read back [TST_START .. TST_END], compare PAT_NOW
    ;------------------------------------------------------------------
    LDA  (TST_STARTH) \ STA  XH
    LDA  (TST_STARTL) \ STA  XL

VERIFY_LOOP:
    LDA  (X)                ; read byte under test
    CPA  (PAT_NOW)          ; C=1 if (X)>=pattern; Z=1 if equal
    BZR  VERIFY_FAIL        ; Z=0: mismatch -> fail
    ; Check X == TST_END
    LDA  XH
    CPA  (TST_ENDH)
    BZR  VERIFY_INC
    LDA  XL
    CPA  (TST_ENDL)
    BZR  VERIFY_INC
    BCH  VERIFY_DONE
VERIFY_INC:
    INC  X
    BCH  VERIFY_LOOP
VERIFY_DONE:
    ;------------------------------------------------------------------
    ; 5c. Check for Break key (once per pattern = 4x per pass)
    ;------------------------------------------------------------------
    VMJ  $A6                ; Z=0 if Break/ON key pressed (guide may be inverted)
    BZR  PAT_BREAK          ; Z=0 -> pressed -> exit cleanly

    ;------------------------------------------------------------------
    ; 5d. Pattern sub-loop control
    ;------------------------------------------------------------------
    POP  U                  ; restore UL
    POP  Y                  ; restore Y (points to next pattern)
    LOP  UL, PAT_LOOP       ; UL--; branch back if UL > 0

    ;------------------------------------------------------------------
    ; 6. Decrement 8-bit PASS_CNT; loop if not zero
    ;------------------------------------------------------------------
    SEC                     ; C=1: no borrow bias for SBI
    LDA  (PASS_CNTL)
    SBI  A,$01              ; A = PASS_CNTL - 1
    STA  (PASS_CNTL)
    BZR  PASS_LOOP          ; not zero -> another pass
    BCH  MT_SUCCESS         ; zero -> all passes done -> success

    ;------------------------------------------------------------------
    ; 7. BREAK: balance stack from PAT_LOOP, return X=3 (no message)
    ;------------------------------------------------------------------
PAT_BREAK:
    POP  U                  ; discard PSH U from PAT_LOOP (balances stack)
    POP  Y                  ; discard PSH Y from PAT_LOOP

MT_BREAK:
    LDI  XH,$00
    LDI  XL,$03             ; 3 = aborted by Break key
    SEC
    RTN

    ;------------------------------------------------------------------
    ; 9. SUCCESS: display "RAM test passed", hold 2 s, return X=0
    ;------------------------------------------------------------------
MT_SUCCESS:
    VEJ  (F2)               ; clear LCD
    LDI  A,$00
    STA  (CURSOR_PTR)       ; cursor to column 0
    LDI  UH,(MSG_OK)>>8
    LDI  UL,(MSG_OK)&$FF
    LDI  A,15
    VMJ  $92                ; display "RAM test passed" (15 chars) at cursor
    SJP  DELAY_2S
    LDI  XH,$00
    LDI  XL,$00
    SEC                     ; C=1: BASIC writes X back to variable
    RTN

    ;------------------------------------------------------------------
    ; VERIFY_FAIL: save the failing address, fall into MT_FAIL (10)
    ;------------------------------------------------------------------
VERIFY_FAIL:
    POP  U                  ; discard PSH U from PAT_LOOP (balances stack)
    POP  Y                  ; discard PSH Y from PAT_LOOP
    LDA  XH
    STA  (FAIL_ADDRH)
    LDA  XL
    STA  (FAIL_ADDRL)
    ; fall through to MT_FAIL

    ;------------------------------------------------------------------
    ; 10. FAIL: display "RAM test failed", hold 2 s, return X=1
    ;------------------------------------------------------------------
MT_FAIL:
    VEJ  (F2)               ; clear LCD
    LDI  A,$00
    STA  (CURSOR_PTR)       ; cursor to column 0
    LDI  UH,(MSG_FAIL)>>8
    LDI  UL,(MSG_FAIL)&$FF
    LDI  A,15
    VMJ  $92                ; display "RAM test failed" (15 chars) at cursor
    SJP  DELAY_2S
    LDI  XH,$00
    LDI  XL,$01
    SEC
    RTN

    ;------------------------------------------------------------------
    ; 9. ZERO PASSES: return X=2, no display change
    ;------------------------------------------------------------------
MT_ZERO_PASSES:
    LDI  XH,$00
    LDI  XL,$02
    SEC
    RTN

;==============================================================================
; BYTE_TO_HEX
;
; Converts byte in A to two ASCII hex characters, stored at [X] and [X+1].
; On return X has been advanced by 2.
;
; Entry:  A = byte to convert
;         X = destination address
; Exit:   [X]   = high nibble ASCII ('0'..'9' / 'A'..'F')
;         [X+1] = low  nibble ASCII
;         X advanced by 2
; Modified: A, X, Y (Y saved and restored internally)
;==============================================================================
BYTE_TO_HEX:
    PSH  A                  ; save full byte
    ; High nibble: shift right 4 (SHR fills bit7 with 0, shifts into C)
    SHR \ SHR \ SHR \ SHR  ; A = bits 7-4 of original (high nibble)
    SJP  NIB_TO_ASCII
    SIN  X                  ; (X) = ASCII char, X++
    ; Low nibble
    POP  A
    ANI  A,$0F              ; A = bits 3-0 (low nibble); C unchanged but unused
    SJP  NIB_TO_ASCII
    SIN  X                  ; (X) = ASCII char, X++
    RTN

;==============================================================================
; NIB_TO_ASCII
;
; Converts a nibble (0-15) in A to its ASCII hex character via lookup table.
;
; Entry:  A = nibble (0-15)
; Exit:   A = ASCII character ('0'..'9' or 'A'..'F')
; Modified: A, Y (Y saved and restored)
;==============================================================================
NIB_TO_ASCII:
    PSH  Y
    LDI  YH,(NIB_TABLE)>>8
    LDI  YL,(NIB_TABLE)&$FF
    ADR  Y                  ; Y = NIB_TABLE + A  (ADR ignores input carry)
    LDA  (Y)                ; A = NIB_TABLE[nibble]
    POP  Y
    RTN

;==============================================================================
; SHOW_PROGRESS
;
; Clears the LCD and displays the current pass status:
;   "Pass: &XX, Bytes: &YYYY"  (23 chars)
;   XX   = current pass number (PASS_NUML, 2 hex chars)
;   YYYY = number of bytes under test (BYTE_CNTH:BYTE_CNTL, 4 hex chars)
;
; Builds the entire 24-char string in DISP_BUF first, then calls VMJ $92 once.
;
; Modified: A, X, Y, U  (no stack imbalance on return)
;==============================================================================
SHOW_PROGRESS:
    VEJ  (F2)               ; clear LCD
    LDI  A,$00
    STA  (CURSOR_PTR)       ; cursor to column 0

    ; X = write pointer into DISP_BUF
    LDI  XH,(DISP_BUF)>>8
    LDI  XL,(DISP_BUF)&$FF

    ; --- Copy "Pass: &" (7 bytes) into DISP_BUF ---
    LDI  YH,(MSG_PASS)>>8
    LDI  YL,(MSG_PASS)&$FF
    LDI  UL,6
SPRG_CP1:
    LIN  Y
    SIN  X
    LOP  UL,SPRG_CP1

    ; --- Pass number: 2 hex chars from PASS_NUML ---
    LDA  (PASS_NUML)
    SJP  BYTE_TO_HEX        ; writes 2 hex chars at [X], X += 2

    ; --- Copy ", Bytes: &" (10 bytes) into DISP_BUF ---
    LDI  YH,(MSG_BYTES)>>8
    LDI  YL,(MSG_BYTES)&$FF
    LDI  UL,9
SPRG_CP2:
    LIN  Y
    SIN  X
    LOP  UL,SPRG_CP2

    ; --- Byte count: 4 hex chars (high byte then low byte) ---
    LDA  (BYTE_CNTH)
    SJP  BYTE_TO_HEX        ; writes high 2 hex chars, X += 2
    LDA  (BYTE_CNTL)
    SJP  BYTE_TO_HEX        ; writes low  2 hex chars, X += 2

    ; --- Display "Pass: &XX, Bytes: &YYYY" = 23 chars ---
    LDI  UH,(DISP_BUF)>>8
    LDI  UL,(DISP_BUF)&$FF
    LDI  A,23
    VMJ  $92

    RTN

;==============================================================================
; DELAY_2S
;
; Waits approximately 2 seconds using the ROM delay routine.
; VMJ ($AC): delay = U * 15.625 ms.  128 * 15.625 ms = 2000 ms.
; Break key may abort the delay early.
;
; Modified: U, A
;==============================================================================
DELAY_2S:
    LDI  UH,$00
    LDI  UL,$80             ; 128 * 15.625 ms = 2000 ms
    VMJ  $AC
    RTN

;==============================================================================
; Read-only data  (placed contiguously after code -- no .org gaps)
;==============================================================================
PAT_TABLE:
    .BYTE $55,$AA,$FF,$00   ; four test patterns

MSG_OK:
    .TEXT "RAM test passed" ; 15 bytes, no terminator (length passed explicitly)

MSG_FAIL:
    .TEXT "RAM test failed" ; 15 bytes

MSG_PASS:
    .TEXT "Pass: &"         ; 7 bytes

MSG_BYTES:
    .TEXT ", Bytes: &"      ; 10 bytes

NIB_TABLE:
    .TEXT "0123456789ABCDEF"

;==============================================================================
; Uninitialised variables  (placeholder .BYTE 0; values written at runtime)
;==============================================================================
PAT_NOW:    .BYTE $00               ; current pattern being applied
PASS_CNTL:  .BYTE $00               ; remaining pass count (1..255)
TST_STARTH: .BYTE $00               ; test region start address, high byte
TST_STARTL: .BYTE $00               ; test region start address, low byte
TST_ENDH:   .BYTE $00               ; test region end address, high byte
TST_ENDL:   .BYTE $00               ; test region end address, low byte
FAIL_ADDRH: .BYTE $00               ; first failing address, high byte
FAIL_ADDRL: .BYTE $00               ; first failing address, low byte
BYTE_CNTH:  .BYTE $00               ; byte count of test region, high
BYTE_CNTL:  .BYTE $00               ; byte count of test region, low
PASS_NUML:  .BYTE $00               ; current pass number (1..255)
DISP_BUF:  .BYTE $00,$00,$00,$00,$00,$00,$00,$00 ; SHOW_PROGRESS: display build buffer
           .BYTE $00,$00,$00,$00,$00,$00,$00,$00 ; (24 bytes: "Pass: &XX, Bytes: &YYYY" = 23)
           .BYTE $00,$00,$00,$00,$00,$00,$00,$00

    .END
