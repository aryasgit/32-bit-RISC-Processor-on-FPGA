module execute_stage(
    input wire clk,
    input wire rst,
    input wire [31:0] ex_rs_data,
    input wire [31:0] ex_rt_data,
    input wire [31:0] ex_imm32,
    input wire [4:0] ex_rs,
    input wire [4:0] ex_rt,
    input wire [4:0] ex_rd,
    input wire [5:0] ex_funct,
    input wire [4:0] ex_shamt,

    input wire ex_reg_dst,
    input wire ex_alu_src,
    input wire [1:0] ex_alu_op,
    input wire ex_reg_write,
    input wire ex_mem_read,
    input wire ex_mem_write,
    input wire ex_mem_to_reg,
    input wire [1:0] forward_a,
    input wire [1:0] forward_b,
    input wire [31:0] exmem_result,
    input wire [31:0] memwb_result,

    output wire stall_muldiv,
    output wire [31:0] alu_result,
    output wire [4:0] write_reg,
    output wire reg_write_o,
    output wire mem_read_o,
    output wire mem_write_o,
    output wire mem_to_reg_o
);

// Forwarding muxes
wire [31:0] srcA =
    (forward_a==2'b10) ? exmem_result :
    (forward_a==2'b01) ? memwb_result :
    ex_rs_data;

wire [31:0] srcB_pre =
    (forward_b==2'b10) ? exmem_result :
    (forward_b==2'b01) ? memwb_result :
    ex_rt_data;

wire [31:0] srcB = ex_alu_src ? ex_imm32 : srcB_pre;

// MUL/DIV detection
wire is_mul = (ex_alu_op==2'b10 && ex_funct==6'h18);
wire is_div = (ex_alu_op==2'b10 && ex_funct==6'h1A);
wire is_muldiv = is_mul | is_div;

// Shift instruction detection - sll=0x00, srl=0x02 use shamt not rs
wire is_shift = (ex_alu_op==2'b10 &&
                (ex_funct==6'h00 || ex_funct==6'h02));

// Route shamt as srcA for shift instructions
wire [31:0] shift_srcA  = {27'b0, ex_shamt};
wire [31:0] actual_srcA = is_shift ? shift_srcA : srcA;

// ALU operation select
wire [3:0] alu_sel =
    (ex_alu_op==2'b00) ? 4'd0 :   // LW/SW: add
    (ex_alu_op==2'b01) ? 4'd1 :   // BEQ/BNE: subtract
    (ex_funct==6'h20)  ? 4'd0 :   // add
    (ex_funct==6'h22)  ? 4'd1 :   // sub
    (ex_funct==6'h24)  ? 4'd2 :   // and
    (ex_funct==6'h25)  ? 4'd3 :   // or
    (ex_funct==6'h2A)  ? 4'd4 :   // slt
    (ex_funct==6'h00)  ? 4'd5 :   // sll
    (ex_funct==6'h02)  ? 4'd6 :   // srl
    4'd0;

// ALU instance
wire [31:0] alu_y;
wire zero_unused;

alu UALU(
    .A   (actual_srcA),
    .B   (srcB),
    .sel (alu_sel),
    .Y   (alu_y),
    .zero(zero_unused)
);

// MUL/DIV unit
wire [63:0] muldiv_out;
wire        muldiv_busy;
wire        muldiv_done;

mul_div_unit UMD(
    .clk   (clk),
    .rst   (rst),
    .start (is_muldiv),
    .op    (is_mul ? 2'b01 : (is_div ? 2'b10 : 2'b00)),
    .A     (srcA),
    .B     (srcB_pre),
    .result(muldiv_out),
    .busy  (muldiv_busy),
    .done  (muldiv_done)
);

// Latch MUL/DIV result when done fires so it stays stable
// through the ex_mem_reg and mem_wb_reg pipeline stages
reg [31:0] muldiv_result_latched;
always @(posedge clk) begin
    if (rst)
        muldiv_result_latched <= 32'b0;
    else if (muldiv_done)
        muldiv_result_latched <= muldiv_out[31:0];
end

assign stall_muldiv = muldiv_busy;

assign alu_result = is_muldiv ? muldiv_result_latched : alu_y;

assign write_reg    = ex_reg_dst ? ex_rd : ex_rt;
assign reg_write_o  = ex_reg_write;
assign mem_read_o   = ex_mem_read;
assign mem_write_o  = ex_mem_write;
assign mem_to_reg_o = ex_mem_to_reg;

endmodule