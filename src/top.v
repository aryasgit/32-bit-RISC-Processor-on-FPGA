// ============================================================
// Top-Level Integration
// ============================================================
// Wires together: PC → ICache → Pipeline → PerfCounters → UART
// ============================================================

module top (
    input  wire clk,
    input  wire rst,
    input  wire dump_en,
    output wire uart_tx_pin
);

    // ===== Internal Wires =====
    wire [31:0] pc_out;
    wire        cache_hit;
    wire [31:0] instr_from_cache;
    wire        stall; // ICache stall
    wire [31:0] mem_data;
    wire        mem_valid;
    wire        mem_rd_en;
    
    wire        actual_branch_taken;
    wire [31:0] actual_branch_addr;
    wire        id_is_branch_wire;
    wire [31:0] id_pc_wire;
    wire        branch_mispredict;
    wire        datapath_stall; // Hazard stall from Datapath

    // Performance counter snapshot wires
    wire [31:0] snap_cycles, snap_hits, snap_misses, snap_stalls, snap_mispredicts;
    wire        snap_valid;

    // EX/MEM/WB wires - replacing stubs
    wire [31:0] ex_rs_data_w, ex_rt_data_w, ex_imm32_w;
    wire [4:0]  ex_rs_w, ex_rt_w, ex_rd_w, ex_shamt_w;
    wire [5:0]  ex_funct_w;
    wire        ex_reg_dst_w, ex_alu_src_w, ex_mem_read_w;
    wire        ex_mem_write_w, ex_mem_to_reg_w, ex_reg_write_w;
    wire [1:0]  ex_alu_op_w;
    wire [1:0]  forward_a_w, forward_b_w;
    wire        stall_muldiv;

    wire [31:0] exmem_alu_result;
    wire [4:0]  exmem_rd;
    wire        exmem_reg_write;

    wire [31:0] memwb_write_data;
    wire [4:0]  memwb_rd;
    wire        memwb_reg_write;
    
    wire [31:0] miss_count_wire, hit_count_wire;
    wire [31:0] ex_alu_result_w;
    wire [4:0]  ex_write_reg_w;
    wire        ex_reg_write_out_w;

    // --> NEW WIRES ADDED FOR DATA MEMORY INTEGRATION <--
    wire        ex_mem_read_out_w, ex_mem_write_out_w, ex_mem_to_reg_out_w;
    wire        exmem_mem_read, exmem_mem_write, exmem_mem_to_reg;
    wire [31:0] exmem_rt_data;
    wire [31:0] data_mem_read_data;

    // Fixed: Complete Datapath instantiation 
    datapath u_datapath (
        .clk              (clk),
        .rst              (rst),
        .predictor_flush  (branch_mispredict && !datapath_stall),
        .icache_stall     (stall | stall_muldiv), // <-- FIXED: Added stall_muldiv
        .instr_from_cache (instr_from_cache),
        .pc_out           (pc_out),
        .branch_taken     (actual_branch_taken),
        .branch_addr      (actual_branch_addr),
        .pipeline_stall   (datapath_stall),
        .id_is_branch_o   (id_is_branch_wire),
        .id_pc_o          (id_pc_wire),

        // Now connected to real EX/MEM/WB wires
        .exmem_reg_write  (exmem_reg_write),
        .exmem_rd         (exmem_rd),
        .exmem_alu_result (exmem_alu_result),
        .memwb_reg_write  (memwb_reg_write),
        .memwb_rd         (memwb_rd),
        .memwb_write_data (memwb_write_data),

        // EX outputs now routed to execute_stage
        .ex_pc_plus4      (),
        .ex_rs_data_o     (ex_rs_data_w),
        .ex_rt_data_o     (ex_rt_data_w),
        .ex_imm32_o       (ex_imm32_w),
        .ex_rs_o          (ex_rs_w),
        .ex_rt_o          (ex_rt_w),
        .ex_rd_o          (ex_rd_w),
        .ex_funct_o       (ex_funct_w),
        .ex_shamt_o       (ex_shamt_w),
        .ex_reg_dst_o     (ex_reg_dst_w),
        .ex_alu_src_o     (ex_alu_src_w),
        .ex_alu_op_o      (ex_alu_op_w),
        .ex_mem_read_o    (ex_mem_read_w),
        .ex_mem_write_o   (ex_mem_write_w),
        .ex_branch_o      (),
        .ex_mem_to_reg_o  (ex_mem_to_reg_w),
        .ex_reg_write_o   (ex_reg_write_w),
        .forward_a        (forward_a_w),
        .forward_b        (forward_b_w)
    );
    
    execute_stage u_ex (
        .clk          (clk),
        .rst          (rst),
        .ex_rs_data   (ex_rs_data_w),
        .ex_rt_data   (ex_rt_data_w),
        .ex_imm32     (ex_imm32_w),
        .ex_rs        (ex_rs_w),
        .ex_rt        (ex_rt_w),
        .ex_rd        (ex_rd_w),
        .ex_funct     (ex_funct_w),
        .ex_shamt     (ex_shamt_w), // Needed for shift logic
        .ex_reg_dst   (ex_reg_dst_w),
        .ex_alu_src   (ex_alu_src_w),
        .ex_alu_op    (ex_alu_op_w),
        .ex_reg_write (ex_reg_write_w),
        .ex_mem_read  (ex_mem_read_w),
        .ex_mem_write (ex_mem_write_w),
        .ex_mem_to_reg(ex_mem_to_reg_w),
        .forward_a    (forward_a_w),
        .forward_b    (forward_b_w),
        .exmem_result (exmem_alu_result),
        .memwb_result (memwb_write_data),
        .stall_muldiv (stall_muldiv),
        .alu_result   (ex_alu_result_w),
        .write_reg    (ex_write_reg_w),
        .reg_write_o  (ex_reg_write_out_w),
        .mem_read_o   (ex_mem_read_out_w),  // <-- FIXED: Routed to ex_mem_reg
        .mem_write_o  (ex_mem_write_out_w), // <-- FIXED: Routed to ex_mem_reg
        .mem_to_reg_o (ex_mem_to_reg_out_w) // <-- FIXED: Routed to ex_mem_reg
    );

    ex_mem_reg u_exmem (
        .clk          (clk),
        .rst          (rst),
        .alu_in       (ex_alu_result_w),
        .rd_in        (ex_write_reg_w),
        .reg_write_in (ex_reg_write_out_w),
        .mem_read_in  (ex_mem_read_out_w),  // <-- ADDED
        .mem_write_in (ex_mem_write_out_w), // <-- ADDED
        .mem_to_reg_in(ex_mem_to_reg_out_w),// <-- ADDED
        .rt_data_in   (ex_rt_data_w),       // <-- ADDED (Data to be stored for SW)

        .alu_out      (exmem_alu_result),
        .rd_out       (exmem_rd),
        .reg_write_out(exmem_reg_write),
        .mem_read_out (exmem_mem_read),     // <-- ADDED
        .mem_write_out(exmem_mem_write),    // <-- ADDED
        .mem_to_reg_out(exmem_mem_to_reg),  // <-- ADDED
        .rt_data_out  (exmem_rt_data)       // <-- ADDED
    );

    // --> NEW: Data Memory Instantiation <--
    data_mem u_dmem (
        .clk        (clk),
        .mem_read   (exmem_mem_read),
        .mem_write  (exmem_mem_write),
        .addr       (exmem_alu_result),
        .write_data (exmem_rt_data),
        .read_data  (data_mem_read_data)
    );

    mem_wb_reg u_memwb (
        .clk          (clk),
        .rst          (rst),
        .alu_in       (exmem_alu_result),    // <-- FIXED: Port renamed to match mem_wb_reg.v
        .mem_data_in  (data_mem_read_data),  // <-- ADDED: Data from memory for LW
        .mem_to_reg_in(exmem_mem_to_reg),    // <-- ADDED: Mux selector
        .rd_in        (exmem_rd),
        .reg_write_in (exmem_reg_write),
        .data_out     (memwb_write_data),
        .rd_out       (memwb_rd),
        .reg_write_out(memwb_reg_write)
    );

    branch_predictor u_brped (
        .clk              (clk), 
        .rst              (rst),
        .fetch_pc         (pc_out),
        .ex_branch_valid  (id_is_branch_wire), 
        .ex_pc            (id_pc_wire),
        .ex_branch_taken  (actual_branch_taken),
        .ex_branch_target (actual_branch_addr),
        .mispredict_pulse (branch_mispredict)
    );

    // Fixed: PC now stalled by ICache, Datapath Hazards, AND MUL/DIV unit
    pc u_pc (
        .clk         (clk),
        .rst         (rst),
        .stall       (stall | datapath_stall | stall_muldiv), // <-- FIXED STALL
        .branch_taken(actual_branch_taken), 
        .branch_addr (actual_branch_addr),  
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
    
    reg dump_en_prev;
    always @(posedge clk) begin
        if (rst) dump_en_prev <= 1'b0;
        else     dump_en_prev <= dump_en;
    end
    wire dump_pulse = dump_en && !dump_en_prev;
    // --------------------------------

    perf_counters u_perf (
        .clk              (clk),
        .rst              (rst),
        .cache_hit_event  (cache_hit),
        .cache_miss_event (!cache_hit && stall),
        .stall_event      (stall),
        .branch_mispredict(branch_mispredict),
        .dump_en          (dump_pulse),
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
        .clk             (clk),
        .rst             (rst),
        .snap_valid      (snap_valid),
        .snap_cycles     (snap_cycles),
        .snap_hits       (snap_hits),
        .snap_misses     (snap_misses),
        .snap_stalls     (snap_stalls),
        .snap_mispredicts(snap_mispredicts),
        .uart_tx_pin     (uart_tx_pin),
        .send_done       ()
    );

endmodule
