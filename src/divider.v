module divider(
    input wire clk,
    input wire rst,
    input wire start,
    input wire signed [31:0] dividend,
    input wire signed [31:0] divisor,

    output reg signed [31:0] quotient,
    output reg signed [31:0] remainder,
    output reg busy,
    output reg done
);

reg [63:0] temp;
reg [31:0] divisor_abs;
reg sign_q, sign_r;
reg [5:0] count;

reg [1:0] state;
localparam IDLE=2'd0, RUN=2'd1, DONE=2'd2;

always @(posedge clk) begin
    if(rst) begin
        quotient<=0;
        remainder<=0;
        busy<=0;
        done<=0;
        temp<=0;
        count<=0;
        state<=IDLE;
    end else begin
        done <= 1'b0;

        case(state)

        IDLE: begin
            busy <= 1'b0;
            if(start) begin
                sign_q <= dividend[31] ^ divisor[31];
                sign_r <= dividend[31];

                temp <= {32'd0, dividend[31] ? -dividend : dividend};
                divisor_abs <= divisor[31] ? -divisor : divisor;

                count <= 32;
                busy <= 1'b1;
                state <= RUN;
            end
        end

        RUN: begin
            temp = temp << 1;
            temp[63:32] = temp[63:32] - divisor_abs;

            if(temp[63]) begin
                temp[63:32] = temp[63:32] + divisor_abs;
                temp[0] = 1'b0;
            end else begin
                temp[0] = 1'b1;
            end

            count <= count - 1'b1;

            if(count == 1)
                state <= DONE;
        end

        DONE: begin
            quotient  <= sign_q ? -temp[31:0]  : temp[31:0];
            remainder <= sign_r ? -temp[63:32] : temp[63:32];
            busy <= 1'b0;
            done <= 1'b1;
            state <= IDLE;
        end

        endcase
    end
end

endmodule


