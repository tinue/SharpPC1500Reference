# PC-1600 Built-in Serial Port — Wiring Notes

> Extracted from the "PC-1600: USB Serial Adapter" section of
> `sharp-pocket-computer/SharpCommunicator/HardwareNotes.md` (in the separate, public
> `sharp-pocket-computer` repository — [github.com/tinue/sharp-pocket-computer](https://github.com/tinue/sharp-pocket-computer),
> not part of this repository — left unchanged there). That file's "PC-1500/A:
> CE-158X" section was not copied — it documents a modern third-party clone board, not
> original Sharp hardware. Referenced photos (`pictures/Pin_Adapter.jpg`,
> `pictures/Calculator.jpg`) remain in the original repository.

The Sharp PC-1600 has a serial device built in. It uses fairly standard 5V logic, and can be interfaced
with currently available FTDI adapters. When using an original (non-cloned) FTDI adapter, no additional
logic chips or inverters are required.

Components used:

- 1mm pins, bent 90 degrees
- A small board for soldering the pins. Search for "1.27mm 2.54mm Adapter Board" on the merchant site of your choice.
  While no 15 pin boards were found, 12 pins are enough for the signals that are required.
- USB/UART cable: "FTDI TTL-232R-5V-WE", i.e. 5V logic and wire ends.

Before the USB / UART adapter can be used, it needs to be reprogrammed using a Windows
machine. The signals of the RX, TX, RTS and CTS pins need to be inverted. This
can be done with a utility provided by FTDI. This is a one-time operation, because the
change is persistent even after unplugging the cable.

The wiring is as follows (pin 1 is the rightmost pin of the PC-1600's 15-pin serial connector):

| Pin | Signal PC-1600 | Connect this cable of the USB/UART | USB/UART wire color |
|-----|----------------|------------------------------------|---------------------|
| 2   | TX             | RX                                 | yellow              |
| 3   | RX             | TX                                 | orange              |
| 4   | RTS            | CTS                                | brown               |
| 5   | CTS            | RTS                                | green               |
| 7   | TX             | Ground                             | black               |

Note: Do not connect the red cable (5V) of the adapter.

## Problem with Apple Silicon Mac

On a Mac with the Apple Silicon chip, the USB UART Adapter does not work as it should,
probably due to a bug in the driver. The protocol that is used for flow control
is "RTS/CTS". In this, the sender (i.e. the Mac) requests to send a byte by raising
the RTS line ("request to send"). Then it is supposed to wait until the receiver
(the PC-1600) acknowledges readiness by raising the CTS line ("clear to send").
However, the Mac does not wait and starts to send right away, and the data
is lost. The other direction (PC-1600 to Mac) works fine.

As a workaround: build the transfer tool on the Mac and send it to a Raspberry Pi via `scp`.
The PC-1600 is connected to the Raspberry Pi, and sending / receiving happens
on the Raspberry Pi via a remote `ssh` session from the Mac.
