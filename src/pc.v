// Program Counter module
// Holds the address of the NEXT instruction to fetch
// Priority: Reset > Branch Redirect > Stall > Sequential Fetch

module pc (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,        // 1 = freeze PC (cache miss or structural stall)
    input  wire        branch_taken, // 1 = jump to branch address
    input  wire [31:0] branch_addr,  // address to jump to on branch
    output reg  [31:0] pc_out        // current PC value
);

    always @(posedge clk) begin
        if (rst) begin
            pc_out <= 32'b0;            // on reset, start at address 0
        end else if (branch_taken) begin
            // Branch ALWAYS wins, even over stall.
            // This ensures a mispredict redirect breaks a wrong-path cache miss.
            pc_out <= branch_addr;
        end else if (!stall) begin
            // Only advance if not stalled
            pc_out <= pc_out + 32'd4;   // next instruction (each is 4 bytes)
        end
        // Implicit else: if stall=1 and branch=0, pc_out stays exactly the same
    end

endmodule