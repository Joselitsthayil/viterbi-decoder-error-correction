`timescale 1ns/1ps

module tb_viterbi;

    // Parameters
    parameter TB_DEPTH = 15;
    parameter DATA_LEN = 32;

    reg clk;
    reg rst_n;

    reg tx_data;
    reg tx_valid;
    reg [1:0] error_mask;

    wire rx_data;
    wire rx_valid;

    wire [1:0] enc_sym_out;
    wire [1:0] rx_sym_out;

    // DUT
    viterbi_top #(
        .TB_DEPTH(TB_DEPTH),
        .PM_WIDTH(8)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .tx_valid(tx_valid),
        .error_mask(error_mask),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .enc_sym_out(enc_sym_out),
        .rx_sym_out(rx_sym_out)
    );

    // Clock
    always #5 clk = ~clk;

    // ============================================================
    // REFERENCE BUFFER (CRITICAL FIX)
    // ============================================================
    reg [TB_DEPTH:0] ref_shift;
    reg expected_rx;
    reg expected_valid;

    always @(posedge clk) begin
        if (!rst_n) begin
            ref_shift <= 0;
            expected_valid <= 0;
        end else if (tx_valid) begin
            ref_shift <= {ref_shift[TB_DEPTH-1:0], tx_data};
            expected_rx <= ref_shift[TB_DEPTH];
            expected_valid <= 1;
        end
    end

    // ============================================================
    // ERROR COUNTER (REAL CHECKING)
    // ============================================================
    integer bit_errors;
    integer total_bits;

    always @(posedge clk) begin
        if (!rst_n) begin
            bit_errors <= 0;
            total_bits <= 0;
        end else if (rx_valid && expected_valid) begin
            total_bits <= total_bits + 1;

            if (rx_data !== expected_rx) begin
                bit_errors <= bit_errors + 1;
                $display("ERROR at time %0t: expected=%b, got=%b",
                         $time, expected_rx, rx_data);
            end
        end
    end

    // ============================================================
    // TEST STIMULUS
    // ============================================================
    reg [DATA_LEN-1:0] test_data;
    integer i;

    initial begin
        clk = 0;
        rst_n = 0;
        tx_valid = 0;
        error_mask = 2'b00;

        bit_errors = 0;
        total_bits = 0;

        // Example pattern
        test_data = 32'hB4CAF1A6;

        #20;
        rst_n = 1;

        #10;

        // Send data
        for (i = DATA_LEN-1; i >= 0; i = i - 1) begin
            @(posedge clk);
            tx_data  <= test_data[i];
            tx_valid <= 1;

            // Inject controlled errors (optional)
            if (i % 7 == 0)
                error_mask <= 2'b01;
            else
                error_mask <= 2'b00;
        end

        // Stop input
        @(posedge clk);
        tx_valid <= 0;
        error_mask <= 0;

        // Wait for traceback completion
        repeat (TB_DEPTH + 20) @(posedge clk);

        // ========================================================
        // FINAL RESULT
        // ========================================================
        $display("=======================================");
        $display("TOTAL BITS   = %0d", total_bits);
        $display("BIT ERRORS   = %0d", bit_errors);

        if (bit_errors == 0)
            $display("✅ TEST PASSED");
        else
            $display("❌ TEST FAILED");

        $display("=======================================");

        $finish;
    end

endmodule