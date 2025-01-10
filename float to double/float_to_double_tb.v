`include "float_to_double.v"
`timescale 1ns/100ps

module tb;

    reg clk;
    reg reset = 1;
    reg [31:0] float;
    wire [63:0] double;
    wire nan;

    float_to_double test(.clk(clk), .reset(reset), .float(float), .double(double), .nan_exception(nan));

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        #10; clk = 1'b0;
        #10; clk = 1'b1;
        #10; clk = 1'b0;
        #10; clk = 1'b1;
        #10; clk = 1'b0;
        #10; clk = 1'b1;
        #10; clk = 1'b0;
        #10; clk = 1'b1;
        #10; clk = 1'b0;
        #10; clk = 1'b1;
        #10; clk = 1'b0;
        #10; clk = 1'b1;
        #10; $finish;
    end

endmodule