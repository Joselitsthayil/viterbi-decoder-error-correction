module viterbi_decoder #(
    parameter TB_DEPTH = 15
)(
    input clk,
    input rst,
    input [1:0] rx,
    output reg decoded
);

integer i, k;

// Path metrics
reg [5:0] pm[0:3];
reg [5:0] pm_next[0:3];

// Survivor memory (store previous state)
reg [1:0] survivor[0:TB_DEPTH-1][0:3];

integer t;

// Encoder model
function [1:0] enc_out;
    input [1:0] state;
    input in_bit;
    reg [2:0] tmp;
    begin
        tmp = {in_bit, state};
        enc_out[1] = tmp[2]^tmp[1]^tmp[0];
        enc_out[0] = tmp[2]^tmp[0];
    end
endfunction

// Hamming distance
function [1:0] dist;
    input [1:0] a,b;
    begin
        dist = (a[1]^b[1]) + (a[0]^b[0]);
    end
endfunction

reg [1:0] prev0, prev1;

// ACS + Survivor update
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pm[0]<=0; pm[1]<=63; pm[2]<=63; pm[3]<=63;
        t<=0;
    end else begin

        // STATE 0
        prev0=0; prev1=2;
        if (pm[prev0]+dist(rx,enc_out(prev0,0)) <= pm[prev1]+dist(rx,enc_out(prev1,0))) begin
            pm_next[0]=pm[prev0]+dist(rx,enc_out(prev0,0));
            survivor[t][0]=prev0;
        end else begin
            pm_next[0]=pm[prev1]+dist(rx,enc_out(prev1,0));
            survivor[t][0]=prev1;
        end

        // STATE 1
        prev0=0; prev1=2;
        if (pm[prev0]+dist(rx,enc_out(prev0,1)) <= pm[prev1]+dist(rx,enc_out(prev1,1))) begin
            pm_next[1]=pm[prev0]+dist(rx,enc_out(prev0,1));
            survivor[t][1]=prev0;
        end else begin
            pm_next[1]=pm[prev1]+dist(rx,enc_out(prev1,1));
            survivor[t][1]=prev1;
        end

        // STATE 2
        prev0=1; prev1=3;
        if (pm[prev0]+dist(rx,enc_out(prev0,0)) <= pm[prev1]+dist(rx,enc_out(prev1,0))) begin
            pm_next[2]=pm[prev0]+dist(rx,enc_out(prev0,0));
            survivor[t][2]=prev0;
        end else begin
            pm_next[2]=pm[prev1]+dist(rx,enc_out(prev1,0));
            survivor[t][2]=prev1;
        end

        // STATE 3
        prev0=1; prev1=3;
        if (pm[prev0]+dist(rx,enc_out(prev0,1)) <= pm[prev1]+dist(rx,enc_out(prev1,1))) begin
            pm_next[3]=pm[prev0]+dist(rx,enc_out(prev0,1));
            survivor[t][3]=prev0;
        end else begin
            pm_next[3]=pm[prev1]+dist(rx,enc_out(prev1,1));
            survivor[t][3]=prev1;
        end

        for (i=0;i<4;i=i+1)
            pm[i] <= pm_next[i];

        if (t < TB_DEPTH-1)
            t <= t+1;
        else
            t <= 0;
    end
end

// TRACEBACK
reg [1:0] state, best;

always @(*) begin
    best = 0;
    for (i=1;i<4;i=i+1)
        if (pm[i] < pm[best])
            best = i;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        decoded <= 0;
    end else if (t == TB_DEPTH-1) begin

        state = best;

        for (k=TB_DEPTH-1; k>0; k=k-1)
            state = survivor[k][state];

        decoded <= state[1];
    end
end

endmodule