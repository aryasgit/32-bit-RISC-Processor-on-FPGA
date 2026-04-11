// Program Counter module
// Holds the address of the NEXT instruction to fetch
// On each clock edge, it either:
//   - Keeps the same address (if stalled due to cache miss)
//   - Jumps to branch address (if branch taken)
//   - Advances by 4 (PC+4, normal sequential execution)

module pc (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,        // 1 = freeze PC (cache miss stall)
    input  wire        branch_taken, // 1 = jump to branch address
    input  wire [31:0] branch_addr,  // address to jump to on branch
    output reg  [31:0] pc_out        // current PC value
);
    always @(posedge clk) begin
        if (rst)
            pc_out <= 32'b0;           // on reset, start at address 0
        else if (!stall) begin           // only advance if not stalled
            if (branch_taken)
                pc_out <= branch_addr;  // jump!
            else
                pc_out <= pc_out + 4;  // next instruction (each is 4 bytes)
        end
        // if stall=1, pc_out stays the same (implicit: no else clause)
    end
endmodule