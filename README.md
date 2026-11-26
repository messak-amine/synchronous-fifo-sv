# Synchronous FIFO in Verilog

This single-clock FIFO stores eight 8-bit words by default. The RTL uses a circular buffer with a registered read output. A self-checking SystemVerilog testbench verifies FIFO ordering, status outputs, and request handling at full and empty.

## Architecture

```text
                  write_ptr       read_ptr
                      |              |
                      v              v
data_in --------> [ FIFO storage ] -------> [ read register ] --> data_out
accepted read ----------------------------> [ valid register ] -> rd_valid
accepted read/write --> [ occupancy counter ] --> count --> full / empty
```

| Signal | Direction | Description |
| --- | --- | --- |
| `clk` | Input | Rising-edge clock for all state updates |
| `rst_n` | Input | Active-low synchronous reset |
| `wr_en`, `rd_en` | Input | Write and read requests |
| `data_in` | Input | `WIDTH`-bit word to enqueue |
| `data_out` | Output | Registered `WIDTH`-bit word from the last accepted read |
| `full`, `empty` | Output | Asserted when `count == DEPTH` or `count == 0`, respectively |
| `count` | Output | Number of stored words, from zero through `DEPTH` |
| `rd_valid` | Output | High after each edge that accepts a read |

Set `WIDTH` to a positive integer and `DEPTH` to a power of two of at least two. Pointer width is `$clog2(DEPTH)`, so the pointers wrap naturally. The counter uses `$clog2(DEPTH+1)` bits to represent full capacity.

A write is accepted when `wr_en` is high and the FIFO has space. A read is accepted when `rd_en` is high and the FIFO contains data. Both decisions use the flags immediately before the rising edge.

| FIFO before edge with both requests high | Accepted | Count change |
| --- | --- | --- |
| Empty | Write only | +1 |
| Partially filled | Read and write | 0 |
| Full | Read only | −1 |

Each accepted operation advances its own pointer. A rejected read leaves `data_out` unchanged and clears `rd_valid`. Reset takes priority, clears the pointers, count, read register and valid flag, and logically empties the FIFO. The storage contents are ignored until overwritten by accepted writes.

## Verification

The driver changes requests on the falling edge. The scoreboard models FIFO order with a shifting array and computes expected results from its own occupancy. The monitor samples DUT outputs after the rising edge and nonblocking updates. Immediate assertions compare `data_out`, `rd_valid`, `count`, `full`, and `empty` and call `$fatal` on a mismatch.

Directed stimulus covers initial reset, single and multiple word ordering, fill and drain, rejected requests, simultaneous requests at all three occupancy conditions, pointer wraparound, and reset with stored data. The testbench checks that the directed phase exercises these corner cases, then uses `$urandom` with seed `32'h31415926` for 256 mixed request cycles. Repeated runs with the same simulator reproduce the sequence.

## Run locally

Run these commands from the repository root. Icarus Verilog compiles the Verilog RTL and SystemVerilog testbench in SystemVerilog 2012 mode. Yosys synthesizes the RTL to generic cells and checks the netlist. GitHub Actions runs the simulation and synthesis commands on Linux.

```sh
make sim
make synth
make lint                     # Requires Verilator
gtkwave build/sync_fifo.vcd   # Optional waveform analysis
make clean
```

On Windows, run `run.bat` from Command Prompt with `iverilog` and `vvp` on PATH. It generates the same VCD under `build/`.

## Repository layout

- `rtl/sync_fifo.v` contains the synthesizable FIFO.
- `tb/tb_sync_fifo.sv` contains the stimulus, scoreboard, and assertions.
- `Makefile` and `run.bat` run the local tools.
- `.github/workflows/ci.yml` runs the Linux checks.
