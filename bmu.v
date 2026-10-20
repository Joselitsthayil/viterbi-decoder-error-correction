// bmu.v
module bmu (
    input  [1:0] rx,
    input  [1:0] expected,
    output [1:0] metric
);

assign metric = (rx[1] ^ expected[1]) + (rx[0] ^ expected[0]);

endmodule