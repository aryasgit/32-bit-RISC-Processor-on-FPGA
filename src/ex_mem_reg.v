module ex_mem_reg(
    input  wire        clk, rst,
    input  wire [31:0] alu_in,
    input  wire [4:0]  rd_in,
    input  wire        reg_write_in,
    // New MEM control signals
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        mem_to_reg_in,
    input  wire [31:0] rt_data_in,
    
    output reg  [31:0] alu_out,
    output reg  [4:0]  rd_out,
    output reg         reg_write_out,
    // New MEM control outputs
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         mem_to_reg_out,
    output reg  [31:0] rt_data_out
);
    always @(posedge clk) begin
        if (rst) begin
            alu_out        <= 0; rd_out <= 0; reg_write_out <= 0;
            mem_read_out   <= 0; mem_write_out <= 0;
            mem_to_reg_out <= 0; rt_data_out <= 0;
        end else begin
            alu_out        <= alu_in;
            rd_out         <= rd_in;
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            rt_data_out    <= rt_data_in;
        end
    end
endmodule


