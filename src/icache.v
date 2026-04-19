// ============================================================
// Direct-Mapped Instruction Cache - Optimized for 0-cycle hit
// Author:   Aryaman Gupta
// ============================================================

module icache (
    input  wire        clk,
    input  wire        rst,

    // CPU interface
    input  wire [31:0] cpu_addr,
    output reg         cache_hit,
    output reg  [31:0] instr_out,
    output reg         stall,

    // Memory interface
    input  wire [31:0] mem_data_in,
    input  wire        mem_data_valid,
    output reg         mem_rd_en,

    // Performance counters
    output reg  [31:0] miss_count,
    output reg  [31:0] hit_count
);

    // Cache storage (unpacked arrays)
    reg        valid [0:15];
    reg [25:0] tag   [0:15];
    reg [31:0] data  [0:15];

    // States
    localparam IDLE  = 2'd0;
    localparam MISS  = 2'd1;

    reg        state;
    reg [31:0] miss_addr;

    // Combinatorial signals for 0-cycle hit detection
    reg        hit_comb;
    reg [31:0] instr_comb;

    // FIX: Combinatorial hit detection to eliminate 1-cycle lag 
    always @(*) begin
        if (valid[cpu_addr[5:2]] && (tag[cpu_addr[5:2]] == cpu_addr[31:6])) begin
            hit_comb   = 1'b1;
            instr_comb = data[cpu_addr[5:2]];
        end else begin
            hit_comb   = 1'b0;
            instr_comb = 32'h0;
        end
    end

    integer j;
    always @(posedge clk) begin
        if (rst) begin
            for (j = 0; j < 16; j = j + 1) begin
                valid[j] <= 1'b0;
                tag[j]   <= 26'b0;
                data[j]  <= 32'b0;
            end
            cache_hit  <= 0;
            instr_out  <= 0;
            stall      <= 0;
            mem_rd_en  <= 0;
            miss_count <= 0;
            hit_count  <= 0;
            state      <= IDLE;
            miss_addr  <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (hit_comb) begin
                        cache_hit <= 1'b1;
                        instr_out <= instr_comb;
                        stall     <= 1'b0;
                        mem_rd_en <= 1'b0;
                        // Fixed: Increment hit_count simply when a hit occurs 
                        hit_count <= hit_count + 1;
                    end else begin
                        // MISS: Trigger memory fetch 
                        cache_hit  <= 1'b0;
                        instr_out  <= 32'h0;
                        stall      <= 1'b1;
                        mem_rd_en  <= 1'b1;
                        miss_addr  <= cpu_addr;
                        miss_count <= miss_count + 1;
                        state      <= MISS;
                    end
                end

                MISS: begin
                    stall     <= 1'b1;
                    cache_hit <= 1'b0;
                    mem_rd_en <= 1'b0;

                    if (mem_data_valid) begin
                        // Fill cache immediately when data arrives 
                        valid[miss_addr[5:2]] <= 1'b1;
                        tag  [miss_addr[5:2]] <= miss_addr[31:6];
                        data [miss_addr[5:2]] <= mem_data_in;
                        
                        instr_out <= mem_data_in; 
                        cache_hit <= 1'b1;
                        stall     <= 1'b0; 
                        state     <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule