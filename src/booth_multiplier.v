module booth_multiplier(
    input wire clk,
    input wire rst,
    input wire start,
    input wire signed [31:0] multiplicand,
    input wire signed [31:0] multiplier,

    output reg signed [63:0] product,
    output reg busy,
    output reg done
);

reg signed [32:0] A, M;
reg signed [31:0] Q;
reg Q_1;
reg [5:0] count;

reg [1:0] state;
localparam IDLE=2'd0, RUN=2'd1, DONE=2'd2;

reg signed [32:0] A_next;
reg signed [65:0] temp;

always @(posedge clk) begin
    if(rst) begin
        A<=0; M<=0; Q<=0; Q_1<=0;
        count<=0;
        product<=0;
        busy<=0;
        done<=0;
        state<=IDLE;
    end else begin
        done <= 1'b0;

        case(state)

        IDLE: begin
            busy <= 1'b0;
            if(start) begin
                A <= 0;
                M <= {multiplicand[31], multiplicand};
                Q <= multiplier;
                Q_1 <= 0;
                count <= 32;
                busy <= 1'b1;
                state <= RUN;
            end
        end

        RUN: begin
            A_next = A;

            case({Q[0],Q_1})
                2'b01: A_next = A + M;
                2'b10: A_next = A - M;
                default: A_next = A;
            endcase

            temp = {A_next,Q,Q_1};
            temp = $signed(temp) >>> 1;

            {A,Q,Q_1} <= temp;

            count <= count - 1'b1;

            if(count == 1)
                state <= DONE;
        end

        DONE: begin
            product <= {A[31:0],Q};
            busy <= 1'b0;
            done <= 1'b1;
            state <= IDLE;
        end

        endcase
    end
end

endmodule



