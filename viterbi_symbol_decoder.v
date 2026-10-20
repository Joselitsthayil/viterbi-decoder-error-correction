module viterbi_symbol_decoder (
    input clk,
    input rst,
    input valid,
    input [1:0] rx_sym,
    output reg [1:0] dec_sym
);

    reg [3:0] pm [0:3];
    reg [3:0] pm_next [0:3];
    reg [1:0] path_sym [0:3];

    integer i;

    // ? declare once here
    reg [1:0] ns;
    reg [2:0] bm;
    reg [1:0] best;

    // Hamming distance
    function [2:0] hamming;
        input [1:0] a, b;
        begin
            hamming = (a[0]^b[0]) + (a[1]^b[1]);
        end
    endfunction

    // Encoder output (7,5)
    function [1:0] enc_out;
        input [1:0] state;
        input in_bit;
        reg [2:0] shift;
        begin
            shift = {in_bit, state};
            enc_out[1] = shift[2]^shift[1]^shift[0];
            enc_out[0] = shift[2]^shift[0];
        end
    endfunction

    function [1:0] next_state;
        input [1:0] state;
        input in_bit;
        begin
            next_state = {in_bit, state[1]};
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pm[0] <= 0;
            pm[1] <= 15;
            pm[2] <= 15;
            pm[3] <= 15;
        end
        else if (valid) begin

            // initialize
            for (i = 0; i < 4; i = i + 1)
                pm_next[i] = 15;

            for (i = 0; i < 4; i = i + 1) begin

                // -------- input = 0 --------
                ns = next_state(i, 0);
                bm = hamming(rx_sym, enc_out(i, 0));

                if (pm[i] + bm < pm_next[ns]) begin
                    pm_next[ns] = pm[i] + bm;
                    path_sym[ns] = enc_out(i, 0);
                end

                // -------- input = 1 --------
                ns = next_state(i, 1);
                bm = hamming(rx_sym, enc_out(i, 1));

                if (pm[i] + bm < pm_next[ns]) begin
                    pm_next[ns] = pm[i] + bm;
                    path_sym[ns] = enc_out(i, 1);
                end
            end

            // update metrics
            for (i = 0; i < 4; i = i + 1)
                pm[i] <= pm_next[i];

            // find best state
            best = 0;
            for (i = 1; i < 4; i = i + 1)
                if (pm[i] < pm[best])
                    best = i;

            dec_sym <= path_sym[best];
        end
    end

endmodule