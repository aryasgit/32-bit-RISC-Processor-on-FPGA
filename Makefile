all: sim

sim:
	iverilog -o sim/icache_sim tb/icache_tb.v src/icache.v -Wall
	vvp sim/icache_sim

wave:
	open -a GTKWave sim/icache_tb.vcd

clean:
	rm -f sim/*.vcd sim/icache_sim