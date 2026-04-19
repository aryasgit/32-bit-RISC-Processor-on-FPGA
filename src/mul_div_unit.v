module mul_div_unit(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [1:0] op,
    input wire signed [31:0] A,
    input wire signed [31:0] B,
    output reg signed [63:0] result,
    output reg busy,
    output reg done
);

// Latch inputs on the cycle start fires so forwarded
// values are stable before Booth/divider begins
reg signed [31:0] A_latched, B_latched;
reg [1:0]         op_latched;
reg               mul_start, div_start;

wire signed [63:0] mul_out;
wire               mul_busy, mul_done;
wire signed [31:0] div_q, div_r;
wire               div_busy, div_done;

booth_multiplier MUL(
    .clk         (clk),
    .rst         (rst),
    .start       (mul_start),
    .multiplicand(A_latched),
    .multiplier  (B_latched),
    .product     (mul_out),
    .busy        (mul_busy),
    .done        (mul_done)
);

divider DIV(
    .clk      (clk),
    .rst      (rst),
    .start    (div_start),
    .dividend (A_latched),
    .divisor  (B_latched),
    .quotient (div_q),
    .remainder(div_r),
    .busy     (div_busy),
    .done     (div_done)
);

always @(posedge clk) begin
    if (rst) begin
        A_latched  <= 32'b0;
        B_latched  <= 32'b0;
        op_latched <= 2'b0;
        mul_start  <= 1'b0;
        div_start  <= 1'b0;
        result     <= 64'b0;
        busy       <= 1'b0;
        done       <= 1'b0;
    end else begin
        mul_start <= 1'b0;
        div_start <= 1'b0;
        done      <= 1'b0;

        if (start && !busy) begin
            // Latch the forwarded operands on this cycle
            A_latched  <= A;
            B_latched  <= B;
            op_latched <= op;
            busy       <= 1'b1;
            // Start fires one cycle later via the latched op
            // so Booth/divider receives stable values
        end

        // One cycle after start: kick off the right unit
        // using latched op so we don't depend on is_mul/is_div
        // still being valid (pipeline is stalled so they are,
        // but latched op is cleaner)
        if (busy && !mul_busy && !div_busy && !mul_done && !div_done
            && mul_start == 1'b0 && div_start == 1'b0) begin
            if (op_latched == 2'b01) mul_start <= 1'b1;
            if (op_latched == 2'b10) div_start <= 1'b1;
        end

        if (mul_done) begin
            result <= mul_out;
            busy   <= 1'b0;
            done   <= 1'b1;
        end

        if (div_done) begin
            result <= {div_r, div_q};
            busy   <= 1'b0;
            done   <= 1'b1;
        end
    end
end

endmodule