// ============================================================
// On-Chip Performance Counters
// ============================================================
// Author:   Aryaman Gupta
//
// Counts:
//   1. Total clock cycles since reset
//   2. Cache hits (from icache module)
//   3. Cache misses (from icache module)
//   4. Pipeline stall cycles (when stall=1)
//   5. Branch mispredictions (from Shashwat's branch predictor)
//
// Outputs a "snapshot" of all counters when dump_en is pulsed high.
// The snapshot feeds into the UART transmitter.
// ============================================================

module perf_counters (
    input  wire        clk,
    input  wire        rst,
    
    // Event inputs (from other modules)
    input  wire        cache_hit_event,   // pulse from icache on a hit
    input  wire        cache_miss_event,  // pulse from icache on a miss
    input  wire        stall_event,       // 1 when pipeline is stalled
    input  wire        branch_mispredict,  // from Shashwat's module
    
    // Control
    input  wire        dump_en,           // 1 = latch snapshot for UART
    
    // Counter outputs (live values)
    output reg  [31:0] cycle_count,
    output reg  [31:0] hit_count,
    output reg  [31:0] miss_count,
    output reg  [31:0] stall_count,
    output reg  [31:0] mispredict_count,
    
    // Snapshot outputs (for UART — latched at dump_en pulse)
    output reg  [31:0] snap_cycles,
    output reg  [31:0] snap_hits,
    output reg  [31:0] snap_misses,
    output reg  [31:0] snap_stalls,
    output reg  [31:0] snap_mispredicts,
    output reg         snap_valid         // 1 = snapshot ready, send via UART
);

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
        end else begin
            // Always counting
            cycle_count <= cycle_count + 1;
            
            if (cache_hit_event)  hit_count        <= hit_count        + 1;
            if (cache_miss_event) miss_count       <= miss_count       + 1;
            if (stall_event)      stall_count      <= stall_count      + 1;
            if (branch_mispredict) mispredict_count <= mispredict_count + 1;
            
            // Snapshot: latch all counters when dump_en pulses
            snap_valid <= 1'b0; // default: not valid
            if (dump_en) begin
                snap_cycles      <= cycle_count;
                snap_hits        <= hit_count;
                snap_misses      <= miss_count;
                snap_stalls      <= stall_count;
                snap_mispredicts <= mispredict_count;
                snap_valid       <= 1'b1; // signal UART to start transmitting
            end
        end
    end
endmodule