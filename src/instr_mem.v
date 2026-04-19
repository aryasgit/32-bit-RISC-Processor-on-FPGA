module instr_mem (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] addr,
    input  wire        rd_en,
    output reg  [31:0] data_out,
    output reg         data_valid
);
    (* ram_style = "block" *) reg [31:0] mem [0:63];
    
    reg [1:0]  delay_cnt;
    reg [31:0] saved_addr;
    
    initial begin
        $readmemh("/home/shashwat/program.mem", mem);
    end
    
    always @(posedge clk) begin
        if (rst) begin
            delay_cnt  <= 0;
            data_valid <= 0;
            data_out   <= 32'h0;
        end else if (rd_en && delay_cnt == 0) begin
            delay_cnt  <= 2;
            saved_addr <= addr;
            data_valid <= 0;
        end else if (delay_cnt > 0) begin
            delay_cnt <= delay_cnt - 1;
            if (delay_cnt == 1) begin
                data_out   <= mem[saved_addr[7:2]];
                data_valid <= 1;
            end else begin
                data_valid <= 0;
            end
        end else begin
            data_valid <= 0;
        end
    end
endmodule