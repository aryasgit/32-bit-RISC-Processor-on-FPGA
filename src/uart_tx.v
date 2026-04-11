// ============================================================
// UART Transmitter (1 byte at a time)
// ============================================================
// Author:   Aryaman Gupta
//
// Protocol:
//   Start bit (LOW) → 8 data bits (LSB first) → Stop bit (HIGH)
//   Baud rate: 9600 bps at 100 MHz clock
//   Clocks per bit = 100_000_000 / 9600 = 10416
//
// Usage:
//   1. Set data_in to the byte you want to send
//   2. Pulse tx_start HIGH for 1 clock cycle
//   3. Wait for tx_done to go HIGH (byte fully sent)
//   4. tx_pin is the serial output wire
// ============================================================

module uart_tx (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data_in,   // byte to transmit
    input  wire       tx_start,  // pulse HIGH for 1 cycle to start sending
    output reg        tx_pin,    // the serial output bit (connect to FPGA TX pin)
    output reg        tx_done,   // HIGH for 1 cycle when byte is fully sent
    output wire       tx_busy    // HIGH while transmitting
);
    // Baud rate divider: at 100MHz, 10416 clocks per bit
    localparam CLKS_PER_BIT = 10416;
    
    // State machine states
    localparam S_IDLE  = 3'd0;
    localparam S_START = 3'd1; // sending start bit (LOW)
    localparam S_DATA  = 3'd2; // sending 8 data bits
    localparam S_STOP  = 3'd3; // sending stop bit (HIGH)
    localparam S_DONE  = 3'd4; // done, pulse tx_done
    
    reg [2:0]  state;
    reg [13:0] clk_cnt;    // counts up to CLKS_PER_BIT
    reg [2:0]  bit_idx;    // which bit we're on (0–7)
    reg [7:0]  tx_data;    // latched copy of data_in
    
    assign tx_busy = (state != S_IDLE);
    
    always @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            tx_pin  <= 1'b1; // idle line is HIGH
            tx_done <= 1'b0;
            clk_cnt <= 0;
            bit_idx <= 0;
        end else begin
            tx_done <= 1'b0; // default: not done
            
            case (state)
                S_IDLE: begin
                    tx_pin <= 1'b1;       // line stays HIGH when idle
                    if (tx_start) begin  // start command received?
                        tx_data <= data_in; // latch the byte
                        state   <= S_START;
                        clk_cnt <= 0;
                    end
                end
                
                S_START: begin
                    tx_pin <= 1'b0; // START BIT: pull line LOW
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        bit_idx <= 0;
                        state   <= S_DATA;
                    end else
                        clk_cnt <= clk_cnt + 1;
                end
                
                S_DATA: begin
                    tx_pin <= tx_data[bit_idx]; // send 1 bit at a time, LSB first
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        if (bit_idx == 7) begin // all 8 bits sent?
                            state <= S_STOP;
                        end else
                            bit_idx <= bit_idx + 1;
                    end else
                        clk_cnt <= clk_cnt + 1;
                end
                
                S_STOP: begin
                    tx_pin <= 1'b1; // STOP BIT: return line HIGH
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        state   <= S_DONE;
                        clk_cnt <= 0;
                    end else
                        clk_cnt <= clk_cnt + 1;
                end
                
                S_DONE: begin
                    tx_done <= 1'b1; // signal: byte fully transmitted
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
// Wraps uart_tx to send all 5 performance counter values
// Each value is 4 bytes → 20 bytes total per snapshot
// Sends them byte by byte, MSB first per 32-bit value
// ============================================================

module uart_perf_sender (
    input  wire        clk,
    input  wire        rst,
    input  wire        snap_valid,     // from perf_counters: start sending
    input  wire [31:0] snap_cycles,
    input  wire [31:0] snap_hits,
    input  wire [31:0] snap_misses,
    input  wire [31:0] snap_stalls,
    input  wire [31:0] snap_mispredicts,
    output wire        uart_tx_pin,    // serial output
    output reg         send_done       // HIGH when all 20 bytes sent
);
    // Pack all 5 values into a 160-bit shift register (20 bytes)
    reg [159:0] payload;
    reg [4:0]   byte_idx;   // which of 20 bytes we're sending
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
                // Latch all 5 counters as bytes MSB-first
                payload <= {snap_cycles, snap_hits, snap_misses, snap_stalls, snap_mispredicts};
                byte_idx <= 0;
                sending  <= 1;
            end
            
            if (sending && !tx_busy && !tx_start) begin
                if (byte_idx < 20) begin
                    // Send next byte (MSB of payload = first byte)
                    current_byte <= payload[159:152];
                    payload      <= {payload[151:0], 8'b0}; // shift left
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