`include "int_to_fp.v"
`timescale 1ns/100ps

module tb;

reg clk;
reg reset = 1'b1;
reg [31:0] int = 32'b11111111111111111111100010000100;
wire [31:0] fp;

int_to_fp teste(
				 .clk(clk),
				 .reset(reset),
				 .int(int),
				 .fp(fp));

initial begin
	$dumpfile("tb.vcd");
	$dumpvars(0, t);
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