IVERILOG ?= iverilog
VVP ?= vvp
YOSYS ?= yosys
VERILATOR ?= verilator

.PHONY: sim lint synth clean

sim: build/tb_sync_fifo.vvp
	$(VVP) $<

build/tb_sync_fifo.vvp: rtl/sync_fifo.v tb/tb_sync_fifo.sv
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s tb_sync_fifo -o $@ $^

lint:
	$(VERILATOR) --lint-only -Wall --top-module sync_fifo rtl/sync_fifo.v

synth:
	$(YOSYS) -p 'read_verilog rtl/sync_fifo.v; synth -top sync_fifo -noabc; select -assert-none t:$$_DLATCH_*; check -assert'

clean:
	rm -rf build
