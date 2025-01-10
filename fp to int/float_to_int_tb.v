`include "float_to_int.v"
`timescale 1ns/100ps

module t;

reg clk;
reg rst = 1'b1;
reg [31:0] float = 32'b11000100111011111001010101101100;
wire inv_fl;
reg [1:0] conv = 2'b10;
wire [63:0] int;

floating_point_to_int uutb(
					.clk(clk),
					.reset(rst),
				    .float(float),
					.invalid_op_flag(inv_fl),
					.conv(conv),
					.int(int));

initial begin
	$dumpfile("porra.vcd");
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