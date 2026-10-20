// =============================================================================
// File         : viterbi_top.v
// Project      : Viterbi Algorithm for Random Error Correction
// Description  : Top-level integration: Encoder + Noisy Channel + Decoder
//
//  ┌──────────────┐    ┌─────────────┐    ┌─────────────────┐
//  │ conv_encoder │───>│   Channel   │───>│ viterbi_decoder │
//  │  (Rate 1/2)  │    │ (+ errors)  │    │   (Traceback)   │
//  └──────────────┘    └─────────────┘    └─────────────────┘
//
// The `error_mask` input simulates a binary symmetric channel.
// XOR it with the encoded symbol to inject up to 2 bit-errors per symbol.
//
// Compatible   : Cadence Xcelium / Genus, Xilinx Vivado / ISE
// Standard     : Verilog-2001 (IEEE 1364-2001)
// =============================================================================

module viterbi_top #(
    parameter TB_DEPTH = 15,   // Viterbi traceback depth
    parameter PM_WIDTH = 8     // Path metric bit width
)(
    input            clk,
    input            rst_n,       // Active-low synchronous reset

    // --- Transmitter interface -----------------------------------------------
    input            tx_data,     // Serial data bit to transmit
    input            tx_valid,    // Transmit valid strobe

    // --- Simulated BSC channel -----------------------------------------------
    input      [1:0] error_mask,  // 2-bit error injection mask (XOR with encoded sym)

    // --- Receiver output -----------------------------------------------------
    output           rx_data,     // Recovered (decoded) data bit
    output           rx_valid,    // Decoded output valid

    // --- Monitoring / debug ports --------------------------------------------
    output     [1:0] enc_sym_out, // Encoded symbol (before channel errors)
    output     [1:0] rx_sym_out   // Received symbol (after channel errors)
);

    // =========================================================================
    // Encoder
    // =========================================================================
    wire [1:0] enc_sym;
    wire       enc_valid;

    conv_encoder u_encoder (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_in  (tx_data),
        .valid_in (tx_valid),
        .enc_out  (enc_sym),
        .valid_out(enc_valid)
    );

    // =========================================================================
    // Simulated Noisy Channel: inject errors via XOR with error_mask
    // =========================================================================
    wire [1:0] noisy_sym = enc_sym ^ error_mask;

    // Register channel output to properly align timing with enc_valid
    reg  [1:0] rx_sym_r;
    reg        rx_valid_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            rx_sym_r   <= 2'b00;
            rx_valid_r <= 1'b0;
        end else begin
            rx_sym_r   <= noisy_sym;
            rx_valid_r <= enc_valid;
        end
    end

    // =========================================================================
    // Viterbi Decoder
    // =========================================================================
    viterbi_decoder #(
        .TB_DEPTH (TB_DEPTH),
        .PM_WIDTH (PM_WIDTH)
    ) u_decoder (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx_in    (rx_sym_r),
        .valid_in (rx_valid_r),
        .dec_out  (rx_data),
        .valid_out(rx_valid)
    );

    // =========================================================================
    // Debug / monitoring assignments
    // =========================================================================
    assign enc_sym_out = enc_sym;
    assign rx_sym_out  = rx_sym_r;

endmodule