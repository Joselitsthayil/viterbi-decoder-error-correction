module conv_encoder (
    input clk,
    input rst,
    input in_bit,
    output reg [1:0] out_bits
);

reg [2:0] shift;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        shift <= 3'b000;
        out_bits <= 2'b00;
    end else begin
        shift <= {in_bit, shift[2:1]};
        out_bits[1] <= shift[2]^shift[1]^shift[0]; // G1 = 111
        out_bits[0] <= shift[2]^shift[0];          // G2 = 101
    end
end

endmodule