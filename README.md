# UART Transmitter Module (VHDL)

This project implements a UART transmitter (`uart_tx`) written in VHDL, developed as part of the Integrated Systems Design II course at PUCRS.

The module was designed to send 8-bit parallel data over a UART serial interface, with a configurable baud rate (9600, 19200, 28800, or 57600 bps). A finite state machine (FSM) handles the transmission, including start, data, and stop bits.

### Main features

- Clock: 100 MHz (`clock_in`)
- Parallel input: 8-bit (`data_p_in`)
- Enable input: `data_p_en_in`
- Baud rate select: 2-bit input (`uart_rate_tx_sel`)
- Serial output: `uart_data_tx`
- Synchronous reset (`reset_in`)

### Tools used

- ModelSim (for simulation)
- Cadence Genus (for synthesis, timing, area, and power analysis)

### Notes

During development, I also experimented with adding a FIFO module from an earlier project to improve the design, but for the formal delivery, I focused on the simpler transmitter implementation.

The repository includes the VHDL source, testbenches, simulation scripts, constraints, and synthesis reports.

