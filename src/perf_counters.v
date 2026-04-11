// ============================================================
// On-Chip Performance Counters
// ============================================================
// Author:   Aryaman Gupta
//
// Fix: snap_valid now holds HIGH for 2 cycles after dump_en
// so the UART sender and testbench can reliably catch it.
// ============================================================

module perf_counters (
    input  wire        clk,
    input  wire        rst,

    // Event inputs
    input  wire        cache_hit_event,
    input  wire        cache_miss_event,
    input  wire        stall_event,
    input  wire        branch_mispredict,

    // Control
    input  wire        dump_en,

    // Live counter outputs
    output reg  [31:0] cycle_count,
    output reg  [31:0] hit_count,
    output reg  [31:0] miss_count,
    output reg  [31:0] stall_count,
    output reg  [31:0] mispredict_count,

    // Snapshot outputs (latched at dump_en)
    output reg  [31:0] snap_cycles,
    output reg  [31:0] snap_hits,
    output reg  [31:0] snap_misses,
    output reg  [31:0] snap_stalls,
    output reg  [31:0] snap_mispredicts,
    output reg         snap_valid
);

    // 2-cycle snap_valid pulse: set on dump_en, cleared one cycle later
    reg snap_valid_next;

    always @(posedge clk) begin
        if (rst) begin
            cycle_count      <= 32'b0;
            hit_count        <= 32'b0;
            miss_count       <= 32'b0;
            stall_count      <= 32'b0;
            mispredict_count <= 32'b0;
            snap_cycles      <= 32'b0;
            snap_hits        <= 32'b0;
            snap_misses      <= 32'b0;
            snap_stalls      <= 32'b0;
            snap_mispredicts <= 32'b0;
            snap_valid       <= 1'b0;
            snap_valid_next  <= 1'b0;
        end else begin

            // ── always counting ──────────────────────────────
            cycle_count <= cycle_count + 1;

            if (cache_hit_event)   hit_count        <= hit_count        + 1;
            if (cache_miss_event)  miss_count       <= miss_count       + 1;
            if (stall_event)       stall_count      <= stall_count      + 1;
            if (branch_mispredict) mispredict_count <= mispredict_count + 1;

            // ── snapshot logic ────────────────────────────────
            // snap_valid stays HIGH for 2 cycles:
            //   cycle N:   dump_en=1  → latch counters, snap_valid_next=1
            //   cycle N+1: snap_valid=1 (from snap_valid_next), clear next
            //   cycle N+2: snap_valid=0
            snap_valid      <= snap_valid_next;
            snap_valid_next <= 1'b0;          // default: clear

            if (dump_en) begin
                snap_cycles      <= cycle_count;
                snap_hits        <= hit_count;
                snap_misses      <= miss_count;
                snap_stalls      <= stall_count;
                snap_mispredicts <= mispredict_count;
                snap_valid_next  <= 1'b1;     // will make snap_valid HIGH next cycle
            end

        end
    end

endmodule