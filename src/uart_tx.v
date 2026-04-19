// ============================================================
// UART Transmitter (1 byte at a time)
// ============================================================
module uart_tx (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data_in,   
    input  wire       tx_start,  
    output reg        tx_pin,    
    output reg        tx_done,   
    output wire       tx_busy    
);
    // Baud rate divider: at 100MHz, 10416 clocks per bit
    localparam CLKS_PER_BIT = 10416;
    
    localparam S_IDLE  = 3'd0;
    localparam S_START = 3'd1;
    localparam S_DATA  = 3'd2;
    localparam S_STOP  = 3'd3;
    localparam S_DONE  = 3'd4;
    
    reg [2:0]  state;
    reg [13:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  tx_data;
    
    assign tx_busy = (state != S_IDLE);
    
    always @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            tx_pin  <= 1'b1; 
            tx_done <= 1'b0;
            clk_cnt <= 0;
            bit_idx <= 0;
        end else begin
            tx_done <= 1'b0; 
            
            case (state)
                S_IDLE: begin
                    tx_pin <= 1'b1; 
                    if (tx_start) begin  
                        tx_data <= data_in; 
                        state   <= S_START;
                        clk_cnt <= 0;
                    end
                end
                
                S_START: begin
                    tx_pin <= 1'b0; 
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        bit_idx <= 0;
                        state   <= S_DATA;
                    end else
                        clk_cnt <= clk_cnt + 1;
                end
                
                S_DATA: begin
                    tx_pin <= tx_data[bit_idx]; 
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        if (bit_idx == 7) begin 
                            state <= S_STOP;
                        end else
                            bit_idx <= bit_idx + 1;
                    end else
                        clk_cnt <= clk_cnt + 1;
                end
                
                S_STOP: begin
                    tx_pin <= 1'b1; 
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        state   <= S_DONE;
                        clk_cnt <= 0;
                    end else
                        clk_cnt <= clk_cnt + 1;
                end
                
                S_DONE: begin
                    tx_done <= 1'b1; 
                    state   <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule


// ============================================================
// UART Performance Data Sender
// ============================================================
module uart_perf_sender (
    input  wire        clk,
    input  wire        rst,
    input  wire        snap_valid,     
    input  wire [31:0] snap_cycles,
    input  wire [31:0] snap_hits,
    input  wire [31:0] snap_misses,
    input  wire [31:0] snap_stalls,
    input  wire [31:0] snap_mispredicts,
    output wire        uart_tx_pin,    
    output reg         send_done       
);
    // Pack all values into a 192-bit shift register (24 bytes total)
    // 4 bytes magic header + 20 bytes data
    reg [191:0] payload;
    reg [4:0]   byte_idx;   // counts up to 24
    reg         sending;
    reg [7:0]   current_byte;
    reg         tx_start;
    wire        tx_done;
    wire        tx_busy;
    
    uart_tx u_uart (
        .clk      (clk),
        .rst      (rst),
        .data_in  (current_byte),
        .tx_start (tx_start),
        .tx_pin   (uart_tx_pin),
        .tx_done  (tx_done),
        .tx_busy  (tx_busy)
    );
    
    always @(posedge clk) begin
        if (rst) begin
            sending      <= 0;
            byte_idx     <= 0;
            tx_start     <= 0;
            send_done    <= 0;
            current_byte <= 0;
        end else begin
            tx_start  <= 0;
            send_done <= 0;
            
            if (snap_valid && !sending) begin
                // Latch header + all 5 counters as bytes MSB-first
                payload <= {32'hDEADBEEF, snap_cycles, snap_hits, snap_misses, snap_stalls, snap_mispredicts};
                byte_idx <= 0;
                sending  <= 1;
            end
            
            if (sending && !tx_busy && !tx_start) begin
                if (byte_idx < 24) begin 
                    // Send next byte (MSB of payload = first byte)
                    current_byte <= payload[191:184];
                    payload      <= {payload[183:0], 8'b0}; // shift left
                    tx_start     <= 1;
                    byte_idx     <= byte_idx + 1;
                end else begin
                    sending   <= 0;
                    send_done <= 1;
                end
            end
        end
    end
endmodule