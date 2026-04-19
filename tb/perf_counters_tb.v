`timescale 1ns / 1ps

module perf_counters_tb;

    reg clk, rst;
    reg cache_hit_event, cache_miss_event;
    reg stall_event, branch_mispredict;
    reg dump_en;

    wire [31:0] cycle_count, hit_count, miss_count;
    wire [31:0] stall_count, mispredict_count;
    wire [31:0] snap_cycles, snap_hits, snap_misses;
    wire [31:0] snap_stalls, snap_mispredicts;
    wire        snap_valid;

    perf_counters DUT (
        .clk              (clk),
        .rst              (rst),
        .cache_hit_event  (cache_hit_event),
        .cache_miss_event (cache_miss_event),
        .stall_event      (stall_event),
        .branch_mispredict(branch_mispredict),
        .dump_en          (dump_en),
        .cycle_count      (cycle_count),
        .hit_count        (hit_count),
        .miss_count       (miss_count),
        .stall_count      (stall_count),
        .mispredict_count (mispredict_count),
        .snap_cycles      (snap_cycles),
        .snap_hits        (snap_hits),
        .snap_misses      (snap_misses),
        .snap_stalls      (snap_stalls),
        .snap_mispredicts (snap_mispredicts),
        .snap_valid       (snap_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/perf_counters_tb.vcd");
        $dumpvars(0, perf_counters_tb);
    end

    // prints actual vs expected so you can see exact values on failure
    task check_eq;
        input [31:0] actual;
        input [31:0] expected;
        input [255:0] name;
        begin
            if (actual == expected)
                $display("  [PASS] %s (= %0d)", name, actual);
            else
                $display("  [FAIL] %s (expected %0d, got %0d)", name, expected, actual);
        end
    endtask

    task check_true;
        input        cond;
        input [255:0] name;
        begin
            if (cond) $display("  [PASS] %s", name);
            else      $display("  [FAIL] %s", name);
        end
    endtask

    initial begin
        $display("================================================");
        $display("  perf_counters Testbench - Aryaman Gupta");
        $display("================================================");

        // initialise all inputs
        rst              = 1;
        cache_hit_event  = 0;
        cache_miss_event = 0;
        stall_event      = 0;
        branch_mispredict= 0;
        dump_en          = 0;

        // hold reset 4 cycles
        @(posedge clk); @(posedge clk);
        @(posedge clk); @(posedge clk);
        rst = 0;
        // wait at negedge to be safely between clock edges
        @(negedge clk); @(negedge clk);

        // ── TEST 1: cycle_count is nonzero and ticking ────────
        $display("\n--- Test 1: Cycle counter is running ---");
        @(negedge clk); #1;
        check_true(cycle_count > 0, "cycle_count > 0 after reset released");
        @(negedge clk); @(negedge clk); @(negedge clk); @(negedge clk); #1;
        check_true(cycle_count > 4, "cycle_count > 4 after more cycles");

        // ── TEST 2: one cache hit ─────────────────────────────
        $display("\n--- Test 2: Cache hit event ---");
        // sample at negedge (mid-cycle) — safe from NBAs
        @(negedge clk); #1;
        $display("  hit_count before = %0d", hit_count);

        // fire event: go to posedge, set HIGH, next posedge clears
        @(posedge clk); #2; cache_hit_event = 1;
        @(posedge clk); #2; cache_hit_event = 0;
        // wait 3 more cycles then sample at negedge
        @(posedge clk); @(posedge clk); @(posedge clk);
        @(negedge clk); #1;
        $display("  hit_count after  = %0d", hit_count);
        check_eq(hit_count, 1, "hit_count == 1");

        // ── TEST 3: one cache miss ────────────────────────────
        $display("\n--- Test 3: Cache miss event ---");
        @(posedge clk); #2; cache_miss_event = 1;
        @(posedge clk); #2; cache_miss_event = 0;
        @(posedge clk); @(posedge clk); @(posedge clk);
        @(negedge clk); #1;
        check_eq(miss_count, 1, "miss_count == 1");

        // ── TEST 4: stall for 3 cycles ────────────────────────
        $display("\n--- Test 4: Stall event (3 cycles) ---");
        @(posedge clk); #2; stall_event = 1;
        @(posedge clk); @(posedge clk); @(posedge clk);
        #2; stall_event = 0;
        @(posedge clk); @(posedge clk);
        @(negedge clk); #1;
        check_eq(stall_count, 3, "stall_count == 3");

        // ── TEST 5: branch mispredict ─────────────────────────
        $display("\n--- Test 5: Branch mispredict ---");
        @(posedge clk); #2; branch_mispredict = 1;
        @(posedge clk); #2; branch_mispredict = 0;
        @(posedge clk); @(posedge clk); @(posedge clk);
        @(negedge clk); #1;
        check_eq(mispredict_count, 1, "mispredict_count == 1");

        // ── TEST 6: snapshot ──────────────────────────────────
        $display("\n--- Test 6: Snapshot on dump_en ---");
        // fire dump_en for 1 cycle
        @(posedge clk); #2; dump_en = 1;
        @(posedge clk); #2; dump_en = 0;
        // wait 2 cycles for snap_valid_next to propagate
        @(posedge clk); @(posedge clk);
        @(negedge clk); #1;

        check_true(snap_valid == 1,          "snap_valid HIGH");
        check_eq(snap_hits,   hit_count,     "snap_hits == hit_count");
        check_eq(snap_misses, miss_count,    "snap_misses == miss_count");
        check_eq(snap_stalls, stall_count,   "snap_stalls == stall_count");
        check_eq(snap_mispredicts, mispredict_count, "snap_mispredicts == mispredict_count");

        // ── TEST 7: snap_valid clears ─────────────────────────
        $display("\n--- Test 7: snap_valid clears ---");
        @(posedge clk); @(posedge clk);
        @(negedge clk); #1;
        check_true(snap_valid == 0, "snap_valid LOW after pulse");

        // ── TEST 8: multiple hits and misses ──────────────────
        $display("\n--- Test 8: 3 more hits and 2 more misses ---");
        // 3 hits
        @(posedge clk); #2; cache_hit_event = 1;
        @(posedge clk); #2; cache_hit_event = 0;
        @(posedge clk); #2; cache_hit_event = 1;
        @(posedge clk); #2; cache_hit_event = 0;
        @(posedge clk); #2; cache_hit_event = 1;
        @(posedge clk); #2; cache_hit_event = 0;
        // 2 misses
        @(posedge clk); #2; cache_miss_event = 1;
        @(posedge clk); #2; cache_miss_event = 0;
        @(posedge clk); #2; cache_miss_event = 1;
        @(posedge clk); #2; cache_miss_event = 0;
        // settle
        @(posedge clk); @(posedge clk); @(posedge clk);
        @(negedge clk); #1;
        // started at hit=1, miss=1 → now should be hit=4, miss=3
        check_eq(hit_count,  4, "hit_count == 4 (1 original + 3 new)");
        check_eq(miss_count, 3, "miss_count == 3 (1 original + 2 new)");

        // snapshot and verify
        @(posedge clk); #2; dump_en = 1;
        @(posedge clk); #2; dump_en = 0;
        @(posedge clk); @(posedge clk);
        @(negedge clk); #1;
        check_eq(snap_hits,   4, "snap_hits == 4");
        check_eq(snap_misses, 3, "snap_misses == 3");

        $display("\n================================================");
        $display("  Testbench complete.");
        $display("================================================");
        $display("\n  Final counter values:");
        $display("  cycle_count      = %0d", cycle_count);
        $display("  hit_count        = %0d", hit_count);
        $display("  miss_count       = %0d", miss_count);
        $display("  stall_count      = %0d", stall_count);
        $display("  mispredict_count = %0d", mispredict_count);

        #50; $finish;
    end

endmodule