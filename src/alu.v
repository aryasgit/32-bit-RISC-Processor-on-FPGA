module alu(
    input wire [31:0] A,
    input wire [31:0] B,
    input wire [3:0] sel,
    output reg [31:0] Y,
    output wire zero
);

always @(*) begin
    case(sel)
        4'd0: Y = A + B;
        4'd1: Y = A - B;
        4'd2: Y = A & B;
        4'd3: Y = A | B;
        4'd4: Y = (A < B) ? 32'd1 : 32'd0;
        4'd5: Y = B << A[4:0];
        4'd6: Y = B >> A[4:0];
        default: Y = 32'd0;
    endcase
end

assign zero = (Y==0);

endmodule

