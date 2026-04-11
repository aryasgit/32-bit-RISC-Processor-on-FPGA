// ============================================================
// Direct-Mapped Instruction Cache
// ============================================================
// Author:   Aryaman Gupta
// Project:  Enhanced 32-bit RISC Processor (Spring 2026)
//
// Parameters:
//   - 16 cache lines (INDEX = bits [5:2], 4 bits)
//   - 1 word (32 bits) per line
//   - TAG = bits [31:6] (26 bits)
//   - 2 offset bits (bits [1:0]) are always ignored for word accesses
//
// Ports:
//   clk, rst      - standard clock and reset
//   cpu_addr      - 32-bit address from the PC (which instruction to fetch)
//   cache_hit     - OUTPUT: 1 if we have the instruction, 0 if miss
//   instr_out     - OUTPUT: the instruction data (valid only when cache_hit=1)
//   mem_data_in   - data coming back FROM main memory on a miss
//   mem_data_valid- 1 when mem_data_in is ready
//   mem_rd_en     - OUTPUT: 1 to request data from main memory
//   stall         - OUTPUT: 1 to freeze the pipeline during a miss
//   miss_count    - OUTPUT: running count of cache misses (for perf counters)
//   hit_count     - OUTPUT: running count of cache hits
// ============================================================

module icache (
    input  wire        clk,
    input  wire        rst,
    
    // --- Interface with CPU (Fetch stage) ---
    input  wire [31:0] cpu_addr,      // byte address to fetch instruction from
    output reg         cache_hit,     // 1 = hit, instruction ready this cycle
    output reg  [31:0] instr_out,     // instruction to send to pipeline
    output reg         stall,         // 1 = tell pipeline to stall
    
    // --- Interface with Main Memory ---
    input  wire [31:0] mem_data_in,   // instruction data from memory
    input  wire        mem_data_valid, // 1 = mem_data_in is ready
    output reg         mem_rd_en,     // 1 = request memory read
    
    // --- Performance Counter Outputs ---
    output reg  [31:0] miss_count,    // total cache misses so far
    output reg  [31:0] hit_count      // total cache hits so far
);

    // =============================================
    // Cache Storage Arrays
    // 16 lines, each holding:
    //   - valid_bit: is there valid data here?
    //   - tag: which memory address does this line belong to?
    //   - data: the actual 32-bit instruction
    // =============================================
    reg        valid [0:15]; // valid bit for each of 16 lines
    reg [25:0] tag   [0:15]; // 26-bit tag for each line
    reg [31:0] data  [0:15]; // 32-bit instruction data for each line
    
    // =============================================
    // Address Decomposition
    // Break the 32-bit address into its parts
    // =============================================
    wire [1:0]  offset = cpu_addr[1:0];  // bits [1:0]  — always 00 for word access
    wire [3:0]  index  = cpu_addr[5:2];  // bits [5:2]  — selects which of 16 lines
    wire [25:0] addr_tag = cpu_addr[31:6]; // bits [31:6] — identifies which block
    
    // =============================================
    // Hit Detection (Combinational Logic)
    // Check if the current address is in cache
    // =============================================
    wire hit_detect = valid[index] && (tag[index] == addr_tag);
    // EXPLANATION:
    //   valid[index]          → is there anything in this slot?
    //   tag[index] == addr_tag → is it the RIGHT data for this address?
    //   Both must be true for a cache hit
    
    // State machine for handling misses
    localparam IDLE    = 2'b00; // normal operation
    localparam MISS    = 2'b01; // miss detected, waiting for memory
    localparam FILL    = 2'b10; // data arrived, filling cache
    reg [1:0] state;
    
    // Save address at time of miss
    reg [31:0] miss_addr;
    
    integer j;
    
    always @(posedge clk) begin
        if (rst) begin
            // On reset: invalidate all cache lines, clear counters
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
        end else begin
        
            case (state)
            
                IDLE: begin
                    // Check cache every cycle
                    if (hit_detect) begin
                        // *** CACHE HIT ***
                        // Instruction is in cache, serve it immediately
                        cache_hit <= 1'b1;
                        instr_out <= data[index];  // grab from cache array
                        stall     <= 1'b0;         // no stall needed
                        mem_rd_en <= 1'b0;
                        hit_count <= hit_count + 1; // increment hit counter
                    end else begin
                        // *** CACHE MISS ***
                        // Instruction NOT in cache; must fetch from memory
                        cache_hit  <= 1'b0;
                        instr_out  <= 32'h0000_0000; // NOP output during stall
                        stall      <= 1'b1;          // FREEZE the pipeline!
                        mem_rd_en  <= 1'b1;          // ask memory for data
                        miss_addr  <= cpu_addr;       // remember which address
                        miss_count <= miss_count + 1; // increment miss counter
                        state      <= MISS;            // go to MISS state
                    end
                end
                
                MISS: begin
                    // Waiting for main memory to respond
                    // Keep stalling the pipeline
                    stall     <= 1'b1;
                    mem_rd_en <= 1'b0; // request already sent
                    cache_hit <= 1'b0;
                    
                    if (mem_data_valid) begin
                        // Memory has responded! Fill the cache line.
                        state <= FILL;
                    end
                end
                
                FILL: begin
                    // Write the new data into the cache
                    valid[miss_addr[5:2]] <= 1'b1;          // mark line as valid
                    tag  [miss_addr[5:2]] <= miss_addr[31:6]; // store the tag
                    data [miss_addr[5:2]] <= mem_data_in;    // store the instruction
                    
                    // Now serve the instruction to the CPU
                    instr_out <= mem_data_in;
                    cache_hit <= 1'b1;
                    stall     <= 1'b0; // UN-STALL the pipeline!
                    state     <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule