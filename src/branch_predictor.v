// ===== FILE: branch_predictor.v =====
module branch_predictor (
  input wire clk,
  input wire rst,
  input wire [31:0] fetch_pc, 
  output reg predict_taken,
  output reg [31:0] target_addr, 
  input wire ex_branch_valid,
  input wire ex_branch_taken, 
  input wire [31:0] ex_branch_target, 
  input wire [31:0] ex_pc,
  output wire mispredict_pulse
);

  localparam SNT = 2'b00;
  localparam WNT = 2'b01;
  localparam WT = 2'b10;
  localparam ST = 2'b11;

  reg [1:0] bht_state [0:15];
  reg [31:0] btb_addr [0:15];
  reg btb_valid [0:15];
  integer i;

  wire [3:0] fetch_idx = fetch_pc[5:2];
  wire [3:0] ex_idx = ex_pc [5:2];

  // Combinatorial mispredict detection
  assign mispredict_pulse = ex_branch_valid && (
      (bht_state[ex_idx] >= WT && !ex_branch_taken) || 
      (bht_state[ex_idx] <= WNT && ex_branch_taken)
  );

  always @(*) begin 
    predict_taken = 1'b0;
    target_addr = 32'h00000000;
    if (btb_valid[fetch_idx]) begin
      if (bht_state[fetch_idx] == WT || bht_state[fetch_idx] == ST) begin
        predict_taken = 1'b1;
        target_addr = btb_addr[fetch_idx];
      end 
    end
  end 

  always @(posedge clk) begin 
    if(rst) begin 
      for (i=0; i<16; i=i+1) begin
        bht_state[i] <= SNT;
        btb_addr[i] <= 32'b0;
        btb_valid[i] <= 1'b0;
      end
    end else if(ex_branch_valid) begin
      btb_valid[ex_idx] <= 1'b1;
      btb_addr[ex_idx] <= ex_branch_target;

      if(ex_branch_taken) begin
        if(bht_state[ex_idx] != ST)
          bht_state[ex_idx] <= bht_state[ex_idx] + 1'b1;
      end else begin
        if(bht_state[ex_idx] != SNT)
          bht_state[ex_idx] <= bht_state[ex_idx] - 1'b1;
      end
    end
  end
endmodule