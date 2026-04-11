// Instruction Memory (the "slow" main memory that your cache speeds up)
// In a real FPGA this would be block RAM, with multiple cycle latency
// We simulate a 2-cycle latency to make cache misses realistic

module instr_mem (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] addr,       // byte address of instruction to fetch
    input  wire        rd_en,      // 1 = start a read (cache miss triggered this)
    output reg  [31:0] data_out,   // instruction data returned
    output reg         data_valid  // 1 = data_out is ready this cycle
);
    // 64 words of instruction memory (256 bytes)
    // In testbench, we'll pre-load this with MIPS machine code
    reg [31:0] mem [0:63];
    
    // 2-cycle latency counter (simulates slow memory)
    reg [1:0] delay_cnt;
    reg [31:0] saved_addr;
    
    integer i;
    initial begin
        // Initialize memory with NOPs (all zeros)
        for (i = 0; i < 64; i = i + 1)
            mem[i] = 32'h0000_0000; // NOP
        
        // A tiny MIPS program: add $t0,$zero,$zero; add $t1,$zero,$zero;
        // addi $t0,$t0,5; addi $t1,$t1,3; add $t2,$t0,$t1
        // These are pre-assembled machine code words
        mem[0]  = 32'h00004020; // add $t0, $zero, $zero
        mem[1]  = 32'h00004820; // add $t1, $zero, $zero
        mem[2]  = 32'h21080005; // addi $t0, $t0, 5
        mem[3]  = 32'h21290003; // addi $t1, $t1, 3
        mem[4]  = 32'h01095020; // add $t2, $t0, $t1
        mem[5]  = 32'h08000005; // j 5 (infinite loop at end)
    end
    
    always @(posedge clk) begin
        if (rst) begin
            delay_cnt  <= 0;
            data_valid <= 0;
            data_out   <= 0;
        end else if (rd_en && delay_cnt == 0) begin
            // New read request — start 2-cycle delay
            delay_cnt  <= 2;
            saved_addr <= addr;
            data_valid <= 0;
        end else if (delay_cnt > 0) begin
            delay_cnt <= delay_cnt - 1;
            if (delay_cnt == 1) begin
                // Deliver data on final cycle
                data_out   <= mem[saved_addr[7:2]]; // word-addressed: divide by 4
                data_valid <= 1;
            end else begin
                data_valid <= 0;
            end
        end else begin
            data_valid <= 0;
        end
    end
endmodule