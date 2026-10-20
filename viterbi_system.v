module viterbi_system (
    input clk,
    input rst,
    input in_bit,
    output [1:0] encoded,
    output decoded
);

wire [1:0] enc_out;
reg  [1:0] noisy;
reg  [2:0] noise_cnt;

conv_encoder enc (
    .clk(clk),
    .rst(rst),
    .in_bit(in_bit),
    .out_bits(enc_out)
);

assign encoded = enc_out;

// ✅ SYNCHRONOUS CONTROLLED NOISE (FIXED)
always @(posedge clk or posedge rst) begin
    if (rst) begin
        noisy <= 0;
        noise_cnt <= 0;
    end else begin
        noise_cnt <= noise_cnt + 1;

        case (noise_cnt)
            3'd2: noisy <= enc_out ^ 2'b01;
            3'd5: noisy <= enc_out ^ 2'b10;
            default: noisy <= enc_out;
        endcase
    end
end

viterbi_decoder #(.TB_DEPTH(15)) dec (
    .clk(clk),
    .rst(rst),
    .rx(noisy),
    .decoded(decoded)
);

endmodule