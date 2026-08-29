# PC-1600 Serial (RS-232C / SIO) — BASIC commands + IOCS routines

Part 1 is the BASIC-level command reference. Part 2 is the machine-language IOCS routine
set (TRM §3.6.3). The line-signal hardware (TC8576F, PRIM, level shifter) is in
`PC-1600-Serial-Hardware-Notes.md`. The comms data format is deferred by TRM §3.6.2 to
§5.7 (pending).

---

## Part 1 — BASIC commands relevant to serial communication

### INIT

Sets the receive buffer size. Default is 40 bytes after power on.

`INIT "COM1:" <buffer>`

- buffer: Size of the buffer in bytes.

Example: `INIT "COM1:",4096`

### SETCOM

Sets the protocol settings for the serial port.

`SETCOM "COM1:",[BR],[WL],[PR],[ST],[XO],[SI]`

- BR: Baud rate (50 - 38400)
- WL: Word length (5-8 bits)
- PR: Parity (E, O, N)
- ST: Stop Bits (1 or 2)
- XO: XON / XOFF (X = Yes, N = no)
- SI: Shift in/out protocol (S = yes, N = no)

Example: `SETCOM "COM1:", 9600,8,N,1,N,N`

### OUTSTAT

Force-sets the state of the control signals for the serial port.

`OUTSTAT "COM1:" [,setting]`

- setting means:

|   | RTS  | DTR  |
|---|------|------|
| 0 | high | high |
| 1 | high | low  |
| 2 | low  | high |
| 3 | low  | low  |

Example: `OUTSTAT "COM1:"`, i.e. without setting, to make RTS/DTR work
dynamically.

### INSTAT

Returns the current settings of the control signals for the serial port.

`INSTAT "COM1:"`

The state is returned as an integer, with each bit representing a signal.
Values are inversed, i.e. `0` means `high`, and `1` means `low`.

| Bit | 7      | 6      | 5  | 4   | 3  | 2   | 1   | 0   |
|-----|--------|--------|----|-----|----|-----|-----|-----|
|     | unused | unused | CI | DSR | CD | CTS | RTS | DTR |

Example: `PRINT INSTAT "COM1:"`: Prints the current state

### SNDSTAT

Sets the send handshake protocol, and the timeout for the serial port.

`SNDSTAT "COM1:",<protocol>[,<timeout>]`

- Timeout is between 0 and 255, in units of 0.5 seconds. 0 disables the timeout.
- Protocol is as follows:

| Bit | 7   | 6   | 5   | 4   | 3  | 2   | 1   | 0   |
|-----|-----|-----|-----|-----|----|-----|-----|-----|
|     | n/a | n/a | n/a | DSR | CD | CTS | n/a | n/a |

- Bit = `1` means "ignore"
- Bit = `0` means "set high"

Examples:

- `SNDSTAT "COM1:",24`: Enables CTS (what we need for this project)
- `SNDSTAT "COM1:",28`: Disable all flow control.

### RCVSTAT

Sets the receive handshake protocol and the timeout for the serial port

`RCVSTAT "COM1:",<protocol>[,<timeout>]`

- Timeout is between 0 and 255, in units of 0.5 seconds. 0 disables the timeout.
- Protocol is as follows:

| Bit | 7   | 6   | 5   | 4   | 3  | 2   | 1   | 0   |
|-----|-----|-----|-----|-----|----|-----|-----|-----|
|     | n/a | n/a | n/a | DSR | CD | CTS | n/a | n/a |

- Bit = `1` means "ignore"
- Bit = `0` means "must be high"

Examples:

- `RCVSTAT "COM1:",24`: Enables CTS handshake (what we need for this project)
- `SNDRCVSTAT "COM1:",28`: Disable all flow control.

Note: The manual mentions _Note that bits 1,2,6,7, and 8 are not used; set them to 0._  
However, most of the examples
found online, and even in the manual itself, set one of more of these bits to 1. As a result, one can find
different numbers for "enable CTS", such as 59. This number also works, but 24 would be correct according to
the manual.

### SETDEV

Specifies the serial port as input and output for some Basic commands.
`SETDEV` without parameters releases the port and resets input / optput to
keyboard / printer.

`SETDEV "COM1:"[,KI][,PO]`

- ,KI: Sets COM1: as device for the command `INPUT`.
- ,PO: Sets COM1: as device for the commands `LPRINT`, `LLIST` and `LFILES`.

Example: `SETDEV "COM1:",KI,PO`: Redirects both input and output to COM1

### PCONSOLE

Set the line length and end of line code for communication through the serial port.

`PCONSOLE "COM1:",[line length],[EOL code]`

- Line length: 16-255 (0 means no limit)
- EL Code: 0 = CR, 1 = LF, 2 = CR/LF

Example: `PCONSOLE "COM1:",80,2`: Set the line length to 80 chars, and use CR/LF
(i.e. Windows style) for the line ending.

### SAVE

Save a program via serial port.

`SAVE "<COM1:>"[,A]`

- A: ASCII format (instead of compressed binary format)

### LOAD

Loads a program from serial port.

`LOAD "<COM1:>"[,R]`

- R: Auto-starts the program after loading.

---

## Part 2 — Serial IOCS routines (TRM §3.6.3)

**Calling convention:** (1) IOCS number → **C register**; (2) if a channel is needed,
channel number → **D register** (`00H` = `"COM:"`, `01H` = `"COM1:"`, `02H` = `"COM2:"`);
(3) `CALL 01D8H`. Most routines clobber only `AF` and `AF'`. Channel-parameter routines
that take `D` are "RS-232C only" where noted.

| Name | IOCS # | Function | Params | Return |
|---|---|---|---|---|
| **CWCOM** | 01H | set the communication parameters | HL = param-block address, D = channel | — |
| **CRCOM** | 02H | get the comm-param-block address | D = channel | DE = address |
| **CSNDA** | 03H | send one byte on the channel | A = byte | on error: A = error byte (b0 = timeout, b1 = BREAK pressed), error bit set |
| **CRCVA** | 04H | receive one byte; **waits** if the buffer is empty | — | A = byte; CF = 1 on error |
| **CRCV1** | 07H | receive one byte; **no wait** | — | A = byte; ZF = 1 if buffer empty; CF = 1 on error |
| **CSETHS** | 0EH | drive RS and ER high (auto-handshake mode) | — | — |
| **CRESHS** | 0FH | drive RS and ER low (auto-handshake mode) | — | — |
| **CWOUTS** | 10H | set the outgoing control-signal (RS, ER) state | D = channel (RS-232C only), E: b0 = ER, b1 = RS, **b7** = 0 → auto-handshake / 1 → RS·ER follow b1·b0 | — (clobbers DE too) |
| **CRCTRL** | 11H | read the control-signal status | D = channel (RS-232C only) | A, in BASIC `INSTAT` format: b0 ER, b1 RS, b2 CS, b3 CD, b4 IR, b5 CI (bit = 0 → signal high, bit = 1 → low) |
| **CWDEV** | 12H | select a channel and set its I/O-device parameters | A: b0 = KI (input), b2 = PO (print out), b6 = 0 → COM1 / 1 → COM2 | — |
| **CRDEV** | 13H | read the current channel and its device parameters | — | A: b0 KI, b2 PO, b6 (0 = COM1 / 1 = COM2), b7 (0 = CLOSE / 1 = OPEN) |
| **CESND** | 14H | allow sending only while the named incoming signals are high | D = channel (RS-232C only), E: b2 = CS, b3 = CD, b4 = DR (**set a bit to 0 to require that signal**), B = timeout 0–255 in units of 0.5 s (0 = wait forever) | — |
| **CERCV** | 15H | allow receiving only while the named incoming signals are high | as CESND | — |
| **CSBRK** | 16H | send a requested number of break characters | (count) | — |
| **CSRCVB** | 17H | reserve a receive buffer in memory | HL = size: `0000H` → default 40 bytes, else `0050H`–`3FFFH` | A = 00H ok / non-zero = error. Also clears the send + receive buffers and the error flags. |
| **CCLRSB** | 1BH | initialise the send work area | — | — |
| **CCLRRB** | 1CH | clear the receive buffer and error flags | — | — |

### CWCOM parameter block

| Off | Contents |
|---|---|
| +0, +1 | baud-rate divisor = **76800 / baud rate**, little-endian |
| +2 | parameter byte — b0: stop bits (0 = 1, 1 = 2); **b3:b2** char length (`00`→5, `01`→6, `10`→7, `11`→8); b4: parity check enable; b5: parity (0 = odd, 1 = even); b6: XON/XOFF control enable; b7: SIN/SOUT (shift-in/out) control enable |

The BASIC `SETCOM` / `SNDSTAT` / `RCVSTAT` / `OUTSTAT` / `INSTAT` commands (Part 1) are
the high-level face of these routines and the same parameter/status bit layouts.