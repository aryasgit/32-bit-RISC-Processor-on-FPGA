// ============================================================
// Testbench for icache.v
// ============================================================
// What we test:
//  1. On first access to an address → MISS, stall goes high
//  2. After memory fills the cache → stall drops, instruction appears
//  3. Second access to same address → HIT (no stall!)
//  4. Access to different addresses → fill multiple cache lines
//  5. Re-access previously seen address → HIT
// ============================================================

`timescale 1ns / 1ps  // time unit / precision for simulation

module icache_tb;

    // ===== Signals to drive the DUT (Device Under Test) =====
    reg         clk;
    reg         rst;
    reg  [31:0] cpu_addr;
    reg  [31:0] mem_data_in;
    reg         mem_data_valid;
    
    // ===== Signals FROM the DUT =====
    wire        cache_hit;
    wire [31:0] instr_out;
    wire        stall;
    wire        mem_rd_en;
    wire [31:0] miss_count;
    wire [31:0] hit_count;
    
    // ===== Instantiate the cache (DUT) =====
    icache DUT (
        .clk           (clk),
        .rst           (rst),
        .cpu_addr      (cpu_addr),
        .cache_hit     (cache_hit),
        .instr_out     (instr_out),
        .stall         (stall),
        .mem_data_in   (mem_data_in),
        .mem_data_valid(mem_data_valid),
        .mem_rd_en     (mem_rd_en),
        .miss_count    (miss_count),
        .hit_count     (hit_count)
    );
    
    // ===== Clock generation: 10ns period = 100 MHz =====
    initial clk = 0;
    always #5 clk = ~clk; // toggle every 5ns → 10ns period
    
    // ===== VCD dump — this creates the waveform file for GTKWave =====
    initial begin
        $dumpfile("sim/icache_tb.vcd"); // output file
        $dumpvars(0, icache_tb);        // dump ALL signals in this module
    end
    
    // ===== Task: simulate memory responding to a read request =====
    // This mimics what the instr_mem module would do
    task mem_respond;
        input [31:0] data;
        begin
            @(posedge clk); #1; // wait 1 cycle
            @(posedge clk); #1; // wait 2 cycles (2-cycle memory latency)
            mem_data_in    = data;
            mem_data_valid = 1;
            @(posedge clk); #1;
            mem_data_valid = 0;
        end
    endtask
    
    // ===== Task: check a condition and print PASS or FAIL =====
    task check;
        input         condition;
        input [127:0] test_name; // string as bit vector (Verilog style)
        begin
            if (condition)
                $display("  [PASS] %s", test_name);
            else
                $display("  [FAIL] %s", test_name);
        end
    endtask
    
    // ===== Main test sequence =====
    initial begin
        $display("============================================");
        $display("  iCache Testbench — Aryaman Gupta");
        $display("============================================");
        
        // Initialize all inputs
        rst           = 1;
        cpu_addr      = 32'h0;
        mem_data_in   = 32'h0;
        mem_data_valid = 0;
        
        // Apply reset for 2 cycles
        @(posedge clk); @(posedge clk);
        rst = 0;
        @(posedge clk);
        
        // =====================
        // TEST 1: First access — should MISS
        // =====================
        $display("\n--- Test 1: Cold miss at address 0x00000000 ---");
        cpu_addr = 32'h0000_0000;
        @(posedge clk);
        #1; // small delay to let combinational logic settle
        check(!cache_hit, "Should be a MISS on first access");
        check(stall,      "Pipeline should be stalled");
        check(mem_rd_en,  "Memory read should be requested");
        
        // Simulate memory responding with instruction 0xDEADBEEF
        fork
            mem_respond(32'hDEAD_BEEF);
        join
        
        @(posedge clk); #1;
        check(!stall,                      "Stall should be released after fill");
        check(cache_hit,                   "Should be a HIT after fill");
        check(instr_out == 32'hDEAD_BEEF, "Correct instruction returned");
        
        // =====================
        // TEST 2: Second access to same address — should HIT
        // =====================
        $display("\n--- Test 2: Second access to 0x00000000 (should hit) ---");
        @(posedge clk); #1;
        check(cache_hit,                   "Should be a HIT (already in cache)");
        check(!stall,                      "No stall on cache hit");
        check(instr_out == 32'hDEAD_BEEF, "Same instruction returned");
        
        // =====================
        // TEST 3: Different address — another miss
        // =====================
        $display("\n--- Test 3: New address 0x00000010 ---");
        cpu_addr = 32'h0000_0010; // different cache line (index=4)
        @(posedge clk); #1;
        check(!cache_hit, "MISS on new address");
        check(stall,      "Stall on miss");
        
        fork
            mem_respond(32'hCAFE_BABE);
        join
        
        @(posedge clk); #1;
        check(instr_out == 32'hCAFE_BABE, "Correct instruction for new address");
        
        // =====================
        // TEST 4: Return to address 0 — should still be in cache
        // =====================
        $display("\n--- Test 4: Return to 0x00000000 (should still hit) ---");
        cpu_addr = 32'h0000_0000;
        @(posedge clk); #1;
        check(cache_hit,                   "HIT on return to cached address");
        check(instr_out == 32'hDEAD_BEEF, "Original instruction still in cache");
        
        // =====================
        // TEST 5: Check hit/miss counters
        // =====================
        $display("\n--- Test 5: Performance counter check ---");
        $display("  Miss count: %0d (expected ~2)", miss_count);
        $display("  Hit count:  %0d (expected ~3)", hit_count);
        
        $display("\n============================================");
        $display("  Testbench complete.");
        $display("============================================");
        
        #100;
        $finish; // end simulation
    end
    
    // Optional: print signal values every clock for debugging
    initial begin
        $monitor("t=%0t | addr=%h | hit=%b | stall=%b | instr=%h | misses=%0d | hits=%0d",
                 $time, cpu_addr, cache_hit, stall, instr_out, miss_count, hit_count);
    end

endmodule