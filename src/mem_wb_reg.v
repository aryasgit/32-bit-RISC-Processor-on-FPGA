module mem_wb_reg(
    input  wire        clk, rst,
    input  wire [31:0] alu_in,        
    input  wire [31:0] mem_data_in,   // Data from data_mem
    input  wire        mem_to_reg_in, // 1 = use mem_data, 0 = use alu_data
    input  wire [4:0]  rd_in,
    input  wire        reg_write_in,
    
    output reg  [31:0] data_out,
    output reg  [4:0]  rd_out,
    output reg         reg_write_out
);
    always @(posedge clk) begin
        if (rst) begin
            data_out <= 0; rd_out <= 0; reg_write_out <= 0;
        end else begin
            // Multiplex the correct data back to the register file
            data_out      <= mem_to_reg_in ? mem_data_in : alu_in;
            rd_out        <= rd_in;
            reg_write_out <= reg_write_in;
        end
    end
endmodule