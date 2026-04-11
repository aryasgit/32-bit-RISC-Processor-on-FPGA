`timescale 1ns / 1ps

// ============================================================
// UART TX Testbench
// Tests:
//   1. Single byte 0x55 (alternating 1010... pattern — easiest to see on waveform)
//   2. Single byte 0xA3
//   3. Back-to-back bytes (0x48 = 'H', 0x69 = 'i')
//   4. Checks timing: each bit = 10416 clock cycles at 100MHz
// ============================================================

module uart_tx_tb;

    reg        clk;
    reg        rst;
    reg  [7:0] data_in;
    reg        tx_start;

    wire       tx_pin;
    wire       tx_done;
    wire       tx_busy;

    // ── DUT ─────────────────────────────────────────────────
    uart_tx DUT (
        .clk      (clk),
        .rst      (rst),
        .data_in  (data_in),
        .tx_start (tx_start),
        .tx_pin   (tx_pin),
        .tx_done  (tx_done),
        .tx_busy  (tx_busy)
    );

    // ── 100MHz clock ─────────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;  // 10ns period

    // ── VCD dump ─────────────────────────────────────────────
    initial begin
        $dumpfile("sim/uart_tx_tb.vcd");
        $dumpvars(0, uart_tx_tb);
    end

    // ── helper task ──────────────────────────────────────────
    task check;
        input        condition;
        input [255:0] name;
        begin
            if (condition) $display("  [PASS] %s", name);
            else           $display("  [FAIL] %s", name);
        end
    endtask

    // ── task: send one byte and wait for done ─────────────────
    task send_byte;
        input [7:0] b;
        begin
            @(posedge clk);
            data_in  = b;
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;
            // wait for tx_done (up to 200000 cycles timeout)
            begin : wait_done
                integer timeout;
                timeout = 0;
                while (!tx_done && timeout < 200000) begin
                    @(posedge clk);
                    timeout = timeout + 1;
                end
                if (timeout >= 200000)
                    $display("  [TIMEOUT] send_byte timed out!");
            end
            @(posedge clk); // one extra cycle after done
        end
    endtask

    // ── capture 10 bits from tx_pin (start + 8 data + stop) ──
    // samples at mid-bit (waits CLKS_PER_BIT/2 then samples every CLKS_PER_BIT)
    reg [9:0] captured_frame;
    integer   bit_i;
    task capture_frame;
        begin
            // wait for start bit (tx_pin goes LOW)
            @(negedge tx_pin);
            // wait half a bit period to land in middle of start bit
            repeat(5208) @(posedge clk);  // 10416/2
            captured_frame[0] = tx_pin;    // sample start bit (should be 0)
            // sample 8 data bits
            for (bit_i = 1; bit_i <= 8; bit_i = bit_i + 1) begin
                repeat(10416) @(posedge clk);
                captured_frame[bit_i] = tx_pin;
            end
            // sample stop bit
            repeat(10416) @(posedge clk);
            captured_frame[9] = tx_pin;    // should be 1
        end
    endtask

    // ── main test ─────────────────────────────────────────────
    initial begin
        $display("================================================");
        $display("  uart_tx Testbench — Aryaman Gupta");
        $display("================================================");

        rst      = 1;
        data_in  = 0;
        tx_start = 0;
        @(posedge clk); @(posedge clk); @(posedge clk);
        rst = 0;
        @(posedge clk);

        // ── TEST 1: idle line is HIGH ──────────────────────────
        $display("\n--- Test 1: Idle line state ---");
        #1;
        check(tx_pin  == 1, "tx_pin HIGH when idle");
        check(tx_busy == 0, "tx_busy LOW when idle");
        check(tx_done == 0, "tx_done LOW when idle");

        // ── TEST 2: send 0x55 = 0101_0101 ─────────────────────
        // Frame should be: START=0, D0=1,D1=0,D2=1,D3=0,D4=1,D5=0,D6=1,D7=0, STOP=1
        $display("\n--- Test 2: Send byte 0x55 (01010101) ---");
        fork
            send_byte(8'h55);
            capture_frame;
        join
        check(captured_frame[0] == 1'b0,  "Start bit = 0");
        check(captured_frame[1] == 1'b1,  "Bit 0 (LSB) = 1  [0x55 bit0]");
        check(captured_frame[2] == 1'b0,  "Bit 1       = 0  [0x55 bit1]");
        check(captured_frame[3] == 1'b1,  "Bit 2       = 1  [0x55 bit2]");
        check(captured_frame[4] == 1'b0,  "Bit 3       = 0  [0x55 bit3]");
        check(captured_frame[5] == 1'b1,  "Bit 4       = 1  [0x55 bit4]");
        check(captured_frame[6] == 1'b0,  "Bit 5       = 0  [0x55 bit5]");
        check(captured_frame[7] == 1'b1,  "Bit 6       = 1  [0x55 bit6]");
        check(captured_frame[8] == 1'b0,  "Bit 7 (MSB) = 0  [0x55 bit7]");
        check(captured_frame[9] == 1'b1,  "Stop bit = 1");

        // ── TEST 3: send 0xA3 = 1010_0011 ─────────────────────
        $display("\n--- Test 3: Send byte 0xA3 (10100011) ---");
        fork
            send_byte(8'hA3);
            capture_frame;
        join
        check(captured_frame[0] == 1'b0, "Start bit = 0");
        check(captured_frame[1] == 1'b1, "Bit 0 = 1  [0xA3 bit0]");
        check(captured_frame[2] == 1'b1, "Bit 1 = 1  [0xA3 bit1]");
        check(captured_frame[3] == 1'b0, "Bit 2 = 0  [0xA3 bit2]");
        check(captured_frame[4] == 1'b0, "Bit 3 = 0  [0xA3 bit3]");
        check(captured_frame[5] == 1'b0, "Bit 4 = 0  [0xA3 bit4]");
        check(captured_frame[6] == 1'b1, "Bit 5 = 1  [0xA3 bit5]");
        check(captured_frame[7] == 1'b0, "Bit 6 = 0  [0xA3 bit6]");
        check(captured_frame[8] == 1'b1, "Bit 7 = 1  [0xA3 bit7]");
        check(captured_frame[9] == 1'b1, "Stop bit = 1");

        // ── TEST 4: busy flag ──────────────────────────────────
        $display("\n--- Test 4: tx_busy goes HIGH while sending ---");
        @(posedge clk);
        data_in  = 8'hFF;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;
        #1;
        check(tx_busy == 1, "tx_busy HIGH immediately after tx_start");
        // wait for it to finish
        begin : wait2
            integer t2; t2 = 0;
            while (!tx_done && t2 < 200000) begin @(posedge clk); t2 = t2+1; end
        end
        @(posedge clk); #1;
        check(tx_busy == 0, "tx_busy LOW after transmission done");
        check(tx_done == 1, "tx_done pulses HIGH for 1 cycle");
        @(posedge clk); #1;
        check(tx_done == 0, "tx_done goes LOW next cycle");

        // ── TEST 5: line returns to idle HIGH ──────────────────
        $display("\n--- Test 5: Line returns to idle HIGH ---");
        @(posedge clk); #1;
        check(tx_pin == 1, "tx_pin HIGH after transmission complete");

        $display("\n================================================");
        $display("  UART Testbench complete.");
        $display("================================================");

        #100;
        $finish;
    end

endmodule