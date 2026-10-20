
// File         : conv_encoder.v
// Project      : Viterbi Algorithm for Random Error Correction
// Description  : Rate 1/2, Constraint Length K=3 Convolutional Encoder
//
// Generator Polynomials:
//   G1 = 1 + D + D^2  (binary: 111, octal: 7)
//   G2 = 1 + D^2      (binary: 101, octal: 5)
//
// Encoder State : 2-bit shift register [d(n-1), d(n-2)]
// Code Rate     : 1/2 (1 input bit -> 2 output bits per clock)
//
// Compatible    : Cadence Xcelium / Genus, Xilinx Vivado / ISE
// Standard      : Verilog-2001 (IEEE 1364-2001)
// =============================================================================

module conv_encoder (
    input            clk,
    input            rst_n,       // Active-low synchronous reset
    input            data_in,     // Serial input data bit
    input            valid_in,    // Input valid strobe
    output reg [1:0] enc_out,     // Encoded output: {G1_bit, G2_bit}
    output reg       valid_out    // Output valid strobe
);

    // -------------------------------------------------------------------------
    // Encoder state register: stores the last 2 input bits
    //   state[1] = d(n-1)  (one step delayed)
    //   state[0] = d(n-2)  (two steps delayed)
    // -------------------------------------------------------------------------
    reg [1:0] state;

    // -------------------------------------------------------------------------
    // Output equations:
    //   enc_out[1] = d(n) XOR d(n-1) XOR d(n-2)  [G1 = 111]
    //   enc_out[0] = d(n) XOR d(n-2)              [G2 = 101]
    // State update:
    //   state <= {d(n), d(n-1)} = {data_in, state[1]}
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= 2'b00;
            enc_out   <= 2'b00;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                enc_out[1] <= data_in ^ state[1] ^ state[0]; // G1 = 1+D+D^2
                enc_out[0] <= data_in ^ state[0];             // G2 = 1+D^2
                state      <= {data_in, state[1]};            // Shift register update
            end
        end
    end

endmodule