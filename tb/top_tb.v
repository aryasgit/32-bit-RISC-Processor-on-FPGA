`timescale 1ns / 1ps

module top_tb;

    reg  clk;
    reg  rst;
    reg  dump_en;
    wire uart_tx_pin;

    // all locals at module level — Verilog-2001 rule
    integer t;
    real    hits, misses;

    top DUT (
        .clk        (clk),
        .rst        (rst),
        .dump_en    (dump_en),
        .uart_tx_pin(uart_tx_pin)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/top_tb.vcd");
        $dumpvars(0, top_tb);
        $dumpvars(0, top_tb.DUT);
    end

    task check;
        input        condition;
        input [255:0] name;
        begin
            if (condition) $display("  [PASS] %s", name);
            else           $display("  [FAIL] %s", name);
        end
    endtask

    initial begin
        $display("================================================");
        $display("  Top-Level Smoke Test - Aryaman Gupta");
        $display("================================================");

        rst     = 1;
        dump_en = 0;

        repeat(5) @(posedge clk);
        rst = 0;

        $display("\n--- Phase 1: Run 60 cycles ---");
        repeat(200) @(posedge clk);
        #1;
        check(DUT.u_perf.cycle_count > 0,  "cycle_count > 0 after 60 cycles");
        check(DUT.u_icache.miss_count > 0, "Cache had at least one miss");
        check(DUT.u_perf.hit_count  > 0, "Cache had at least one hit");

        $display("\n--- Phase 2: Trigger dump_en -> UART starts ---");
        @(posedge clk); #2;
        dump_en = 1;
        @(posedge clk); #2;
        dump_en = 0;

        t = 0;
        while (uart_tx_pin == 1 && t < 20) begin
            @(posedge clk);
            t = t + 1;
        end
        #1;
        check(uart_tx_pin == 0, "UART tx_pin LOW (start bit) after dump_en");

        $display("\n--- Phase 3: Final counter values ---");
        repeat(10) @(posedge clk); #1;
        $display("  cycle_count  = %0d", DUT.u_perf.cycle_count);
        $display("  hit_count    = %0d", DUT.u_icache.hit_count);
        $display("  miss_count   = %0d", DUT.u_icache.miss_count);
        $display("  stall_count  = %0d", DUT.u_perf.stall_count);

        $display("\n--- Phase 4: Hit rate ---");
        hits   = DUT.u_icache.hit_count;
        misses = DUT.u_icache.miss_count;
        if ((hits + misses) > 0)
            $display("  Hit rate = %.1f%%  (%.0f hits / %.0f total)",
                     100.0 * hits / (hits + misses), hits, hits + misses);
        else
            $display("  No cache accesses recorded.");

        $display("\n================================================");
        $display("  Smoke test complete.");
        $display("================================================");

        #200; $finish;
    end

    initial begin
        $monitor("t=%0t | PC=%h | stall=%b | hit=%b | misses=%0d | hits=%0d",
                 $time,
                 DUT.pc_out,
                 DUT.stall,
                 DUT.cache_hit,
                 DUT.u_icache.miss_count,
                 DUT.u_icache.hit_count);
    end

endmodule