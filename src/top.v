// ============================================================
// Top-Level Integration
// ============================================================
// Author:   Aryaman Gupta
// Wires together: PC → ICache → Pipeline → PerfCounters → UART
// ============================================================

module top (
    input  wire clk,
    input  wire rst,
    input  wire dump_en,       // button/signal to dump perf counters
    output wire uart_tx_pin   // connect to FPGA's TX pin (or monitor in sim)
);

    // ===== Internal Wires =====
    wire [31:0] pc_out;
    wire        cache_hit;
    wire [31:0] instr_from_cache;
    wire        stall;
    wire [31:0] mem_data;
    wire        mem_valid;
    wire        mem_rd_en;
    wire [31:0] miss_count_wire, hit_count_wire;
    
    // Perf counter snapshot wires
    wire [31:0] snap_cycles, snap_hits, snap_misses, snap_stalls, snap_mispredicts;
    wire        snap_valid;
    
    // From branch predictor (Shashwat's module — stubbed here as 0)
    wire        branch_taken = (pc_out == 32'h00000014) && !stall;   // TODO: connect Shashwat's output
    wire [31:0] branch_addr  = 32'h00000000;  // TODO: connect Shashwat's output
    wire        branch_mispredict = 1'b0; // TODO
    
    // ===== Module Instantiations =====
    
    pc u_pc (
        .clk         (clk),
        .rst         (rst),
        .stall       (stall),
        .branch_taken(branch_taken),
        .branch_addr (branch_addr),
        .pc_out      (pc_out)
    );
    
    instr_mem u_imem (
        .clk        (clk),
        .rst        (rst),
        .addr       (pc_out),
        .rd_en      (mem_rd_en),
        .data_out   (mem_data),
        .data_valid (mem_valid)
    );
    
    icache u_icache (
        .clk           (clk),
        .rst           (rst),
        .cpu_addr      (pc_out),
        .cache_hit     (cache_hit),
        .instr_out     (instr_from_cache),
        .stall         (stall),
        .mem_data_in   (mem_data),
        .mem_data_valid(mem_valid),
        .mem_rd_en     (mem_rd_en),
        .miss_count    (miss_count_wire),
        .hit_count     (hit_count_wire)
    );
    
    perf_counters u_perf (
        .clk              (clk),
        .rst              (rst),
        .cache_hit_event  (cache_hit),
        .cache_miss_event (!cache_hit && stall),
        .stall_event      (stall),
        .branch_mispredict(branch_mispredict),
        .dump_en          (dump_en),
        .cycle_count      (),
        .hit_count        (),
        .miss_count       (),
        .stall_count      (),
        .mispredict_count (),
        .snap_cycles      (snap_cycles),
        .snap_hits        (snap_hits),
        .snap_misses      (snap_misses),
        .snap_stalls      (snap_stalls),
        .snap_mispredicts (snap_mispredicts),
        .snap_valid       (snap_valid)
    );
    
    uart_perf_sender u_uart (
        .clk            (clk),
        .rst            (rst),
        .snap_valid     (snap_valid),
        .snap_cycles    (snap_cycles),
        .snap_hits      (snap_hits),
        .snap_misses    (snap_misses),
        .snap_stalls    (snap_stalls),
        .snap_mispredicts(snap_mispredicts),
        .uart_tx_pin    (uart_tx_pin),
        .send_done      ()
    );

endmodule