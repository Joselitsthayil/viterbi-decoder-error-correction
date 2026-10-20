// acs.v
module acs (
    input  [3:0] pm_in0,
    input  [3:0] pm_in1,
    input  [1:0] bm0,
    input  [1:0] bm1,
    output reg [3:0] pm_out,
    output reg decision
);

wire [3:0] m0 = pm_in0 + bm0;
wire [3:0] m1 = pm_in1 + bm1;

always @(*) begin
    if (m0 <= m1) begin
        pm_out = m0;
        decision = 1'b0;
    end else begin
        pm_out = m1;
        decision = 1'b1;
    end
end

endmodule