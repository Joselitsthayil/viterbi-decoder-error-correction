
// File         : viterbi_decoder.v
// Project      : Viterbi Algorithm for Random Error Correction
// Description  : Hard-Decision Viterbi Decoder
//                Rate 1/2, Constraint Length K=3
//                4 trellis states: 00, 01, 10, 11
//
// Architecture :
//   - Branch Metric Unit (BMU): Hamming distance, hard decision
//   - Add-Compare-Select (ACS): Parallel for all 4 states
//   - Path Metric Normalization: Prevents PM register overflow
//   - Traceback: Register-Exchange method (depth = TB_DEPTH)
//
// Latency      : TB_DEPTH clock cycles from first valid input
//
// Generator Polynomials:
//   G1 = 1+D+D^2 (111 binary) | G2 = 1+D^2 (101 binary)
//
// Trellis (State | Input -> Next State | Output):
//   00 | 0 -> 00 | 00        10 | 0 -> 01 | 10
//   00 | 1 -> 10 | 11        10 | 1 -> 11 | 01
//   01 | 0 -> 00 | 11        11 | 0 -> 01 | 01
//   01 | 1 -> 10 | 00        11 | 1 -> 11 | 10
//
// Compatible   : Cadence Xcelium / Genus, Xilinx Vivado / ISE
// Standard     : Verilog-2001 (IEEE 1364-2001)
// =============================================================================

module viterbi_decoder #(
    parameter TB_DEPTH = 15,   // Traceback depth (recommended >= 5*K = 15 for K=3)
    parameter PM_WIDTH = 8     // Path metric bit width (must hold 0..TB_DEPTH*2)
)(
    input               clk,
    input               rst_n,
    input        [1:0]  rx_in,    // Received 2-bit symbol (possibly corrupted)
    input               valid_in, // Input valid strobe
    output reg          dec_out,  // Decoded data bit (delayed by TB_DEPTH cycles)
    output reg          valid_out // Output valid strobe
);

    // =========================================================================
    // Path Metrics & Survivor Path Memories
    // =========================================================================

    // Path metric for each of the 4 states (normalized)
    reg [PM_WIDTH-1:0] pm [0:3];

    // Register-Exchange survivor path memories
    //   path_mem[s] is a TB_DEPTH-bit shift register for state s
    //   Bit [TB_DEPTH-1] = oldest decoded bit (output candidate)
    //   Bit [0]          = newest decoded bit (just computed)
    //   At each step: new_path[s] = { path_mem[pred_s][TB_DEPTH-2:0], dec_bit_s }
    reg [TB_DEPTH-1:0] path_mem [0:3];

    // Output-enable delay counter
    reg [4:0] step_cnt;

    // =========================================================================
    // SECTION 1: Branch Metric Unit (BMU)
    // Computes Hamming distance between received rx_in and all 4 codewords:
    //   hd_00 = dist(rx_in, 00),  hd_11 = dist(rx_in, 11)
    //   hd_10 = dist(rx_in, 10),  hd_01 = dist(rx_in, 01)
    // Result range: 0, 1, or 2  (fits in 2 bits)
    // =========================================================================

    wire [1:0] hd_00 = {1'b0, rx_in[1] ^ 1'b0} + {1'b0, rx_in[0] ^ 1'b0};
    wire [1:0] hd_11 = {1'b0, rx_in[1] ^ 1'b1} + {1'b0, rx_in[0] ^ 1'b1};
    wire [1:0] hd_10 = {1'b0, rx_in[1] ^ 1'b1} + {1'b0, rx_in[0] ^ 1'b0};
    wire [1:0] hd_01 = {1'b0, rx_in[1] ^ 1'b0} + {1'b0, rx_in[0] ^ 1'b1};

    // =========================================================================
    // SECTION 2: Add-Compare-Select (ACS) Unit
    //
    // For each destination state, two predecessor candidates compete:
    //
    //   -> Dest State 00: from State 00 (out=00) OR State 01 (out=11)
    //   -> Dest State 01: from State 10 (out=10) OR State 11 (out=01)
    //   -> Dest State 10: from State 00 (out=11) OR State 01 (out=00)
    //   -> Dest State 11: from State 10 (out=01) OR State 11 (out=10)
    //
    // Decoded input bit arriving at state s = s[1] (MSB of destination state):
    //   States 00, 01 -> input bit = 0
    //   States 10, 11 -> input bit = 1
    // =========================================================================

    // --- Candidate path metrics (ADD) ----------------------------------------
    wire [PM_WIDTH-1:0] c_s0_a = pm[0] + {{(PM_WIDTH-2){1'b0}}, hd_00}; // s=00 via out=00
    wire [PM_WIDTH-1:0] c_s0_b = pm[1] + {{(PM_WIDTH-2){1'b0}}, hd_11}; // s=01 via out=11

    wire [PM_WIDTH-1:0] c_s1_a = pm[2] + {{(PM_WIDTH-2){1'b0}}, hd_10}; // s=10 via out=10
    wire [PM_WIDTH-1:0] c_s1_b = pm[3] + {{(PM_WIDTH-2){1'b0}}, hd_01}; // s=11 via out=01

    wire [PM_WIDTH-1:0] c_s2_a = pm[0] + {{(PM_WIDTH-2){1'b0}}, hd_11}; // s=00 via out=11
    wire [PM_WIDTH-1:0] c_s2_b = pm[1] + {{(PM_WIDTH-2){1'b0}}, hd_00}; // s=01 via out=00

    wire [PM_WIDTH-1:0] c_s3_a = pm[2] + {{(PM_WIDTH-2){1'b0}}, hd_01}; // s=10 via out=01
    wire [PM_WIDTH-1:0] c_s3_b = pm[3] + {{(PM_WIDTH-2){1'b0}}, hd_10}; // s=11 via out=10

    // --- Survivor selection (COMPARE) ----------------------------------------
    // surv_sX = 0 -> first candidate wins (predecessor _a)
    // surv_sX = 1 -> second candidate wins (predecessor _b)
    wire surv_s0 = (c_s0_b < c_s0_a) ? 1'b1 : 1'b0;
    wire surv_s1 = (c_s1_b < c_s1_a) ? 1'b1 : 1'b0;
    wire surv_s2 = (c_s2_b < c_s2_a) ? 1'b1 : 1'b0;
    wire surv_s3 = (c_s3_b < c_s3_a) ? 1'b1 : 1'b0;

    // --- Raw (pre-normalization) path metrics (SELECT) -----------------------
    wire [PM_WIDTH-1:0] pm_raw0 = surv_s0 ? c_s0_b : c_s0_a;
    wire [PM_WIDTH-1:0] pm_raw1 = surv_s1 ? c_s1_b : c_s1_a;
    wire [PM_WIDTH-1:0] pm_raw2 = surv_s2 ? c_s2_b : c_s2_a;
    wire [PM_WIDTH-1:0] pm_raw3 = surv_s3 ? c_s3_b : c_s3_a;

    // =========================================================================
    // SECTION 3: Path Metric Normalization
    // Subtract global minimum to keep all metrics bounded within [0, ~2*TB_DEPTH]
    // Prevents register overflow in long continuous operation.
    // =========================================================================

    wire [PM_WIDTH-1:0] min_01  = (pm_raw0 <= pm_raw1) ? pm_raw0 : pm_raw1;
    wire [PM_WIDTH-1:0] min_23  = (pm_raw2 <= pm_raw3) ? pm_raw2 : pm_raw3;
    wire [PM_WIDTH-1:0] min_all = (min_01  <= min_23 ) ? min_01  : min_23;

    wire [PM_WIDTH-1:0] pm_new0 = pm_raw0 - min_all;
    wire [PM_WIDTH-1:0] pm_new1 = pm_raw1 - min_all;
    wire [PM_WIDTH-1:0] pm_new2 = pm_raw2 - min_all;
    wire [PM_WIDTH-1:0] pm_new3 = pm_raw3 - min_all;

    // =========================================================================
    // SECTION 4: Best State Selection (for traceback output)
    // Select the state with the minimum path metric after normalization.
    // Since min_all was subtracted, best state(s) have pm = 0.
    // We still use raw metrics to break ties deterministically.
    // =========================================================================

    wire [1:0] best_s01   = (pm_raw0 <= pm_raw1) ? 2'd0 : 2'd1;
    wire [1:0] best_s23   = (pm_raw2 <= pm_raw3) ? 2'd2 : 2'd3;
    wire [1:0] best_state = (min_01  <= min_23 ) ? best_s01 : best_s23;

    // =========================================================================
    // SECTION 5: Register-Exchange Traceback
    //
    // Each state s has a TB_DEPTH-bit path register.
    // At each step, we inherit the predecessor's path and append the new bit:
    //   new_path[s] = { pred_path[s][TB_DEPTH-2:0], dec_bit_for_s }
    //
    // Predecessor map (from ACS survivor bits):
    //   State 00: surv=0 -> pred=State 00,  surv=1 -> pred=State 01
    //   State 01: surv=0 -> pred=State 10,  surv=1 -> pred=State 11
    //   State 10: surv=0 -> pred=State 00,  surv=1 -> pred=State 01
    //   State 11: surv=0 -> pred=State 10,  surv=1 -> pred=State 11
    //
    // Decoded bit (= input that caused transition INTO state s = s[1]):
    //   State 00 -> dec bit = 0
    //   State 01 -> dec bit = 0
    //   State 10 -> dec bit = 1
    //   State 11 -> dec bit = 1
    // =========================================================================

    // Predecessor path selection for each destination state
    wire [TB_DEPTH-1:0] pred_path_s0 = surv_s0 ? path_mem[1] : path_mem[0]; // pred=01 or 00
    wire [TB_DEPTH-1:0] pred_path_s1 = surv_s1 ? path_mem[3] : path_mem[2]; // pred=11 or 10
    wire [TB_DEPTH-1:0] pred_path_s2 = surv_s2 ? path_mem[1] : path_mem[0]; // pred=01 or 00
    wire [TB_DEPTH-1:0] pred_path_s3 = surv_s3 ? path_mem[3] : path_mem[2]; // pred=11 or 10

    // Shift and append decoded bit at LSB (dec_bit = dest_state[1])
    wire [TB_DEPTH-1:0] new_path_s0 = {pred_path_s0[TB_DEPTH-2:0], 1'b0}; // dec_bit=0
    wire [TB_DEPTH-1:0] new_path_s1 = {pred_path_s1[TB_DEPTH-2:0], 1'b0}; // dec_bit=0
    wire [TB_DEPTH-1:0] new_path_s2 = {pred_path_s2[TB_DEPTH-2:0], 1'b1}; // dec_bit=1
    wire [TB_DEPTH-1:0] new_path_s3 = {pred_path_s3[TB_DEPTH-2:0], 1'b1}; // dec_bit=1

    // Output = MSB of best state's updated path register (oldest stored bit)
    wire dec_bit_mux = (best_state == 2'd0) ? new_path_s0[TB_DEPTH-1] :
                       (best_state == 2'd1) ? new_path_s1[TB_DEPTH-1] :
                       (best_state == 2'd2) ? new_path_s2[TB_DEPTH-1] :
                                              new_path_s3[TB_DEPTH-1];

    // =========================================================================
    // SECTION 6: Sequential State Update
    // =========================================================================

    always @(posedge clk) begin
        if (!rst_n) begin
            // Initialise: assume encoder starts in state 00
            // State 00 gets metric 0; all others get max (255 for PM_WIDTH=8)
            pm[0]       <= {PM_WIDTH{1'b0}};
            pm[1]       <= {PM_WIDTH{1'b1}};
            pm[2]       <= {PM_WIDTH{1'b1}};
            pm[3]       <= {PM_WIDTH{1'b1}};
            // Clear all path memories
            path_mem[0] <= {TB_DEPTH{1'b0}};
            path_mem[1] <= {TB_DEPTH{1'b0}};
            path_mem[2] <= {TB_DEPTH{1'b0}};
            path_mem[3] <= {TB_DEPTH{1'b0}};
            step_cnt    <= 5'd0;
            dec_out     <= 1'b0;
            valid_out   <= 1'b0;
        end else if (valid_in) begin
            // ---- Update path metrics (normalised) ---------------------------
            pm[0] <= pm_new0;
            pm[1] <= pm_new1;
            pm[2] <= pm_new2;
            pm[3] <= pm_new3;

            // ---- Update register-exchange survivor memories -----------------
            path_mem[0] <= new_path_s0;
            path_mem[1] <= new_path_s1;
            path_mem[2] <= new_path_s2;
            path_mem[3] <= new_path_s3;

            // ---- Output decoded bit with latency gate -----------------------
            dec_out   <= dec_bit_mux;
            // Assert valid_out only after traceback buffer is filled
            valid_out <= (step_cnt >= (TB_DEPTH - 1));
            if (step_cnt < (TB_DEPTH - 1))
                step_cnt <= step_cnt + 5'd1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule