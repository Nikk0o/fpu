`timescale 1ns/100ps

module int_to_fp(
				 clk,
				 reset,
				 int,
				 fp);

	parameter int_size = 32;
	parameter precision = 32;
	parameter exponent_size = 8;
	parameter mantissa_size = 23;
	parameter exp_bias = {exponent_size{1'b1}} - {exponent_size - 1{1'b1}};

	input clk,
		  reset;
	input  [int_size - 1:0] int;
	output [precision - 1:0]       fp;

	reg     			      sign;
	reg [exponent_size - 1:0] exp;
	reg [mantissa_size - 1:0] mantissa;

	reg [int_size - 1:0] pos_int;

	initial begin
		mantissa <= {mantissa_size{1'b0}};
		sign <= 1'b0;
		exp <= {exponent_size{1'b0}};
	end

	always @(posedge clk or negedge reset) 
	begin
		if (!reset) begin
			mantissa <= {mantissa_size{1'b0}};
			exp <= {exponent_size{1'b0}};
			sign <= 0;
			pos_int <= {int_size{1'b0}};
		end
		else begin: conversion
			integer size, i;
			integer index;

			pos_int = (int[int_size - 1] == 1'b1) ? 1'b1 + ~int : int;

			if (int == {int_size{1'b0}}) begin
				sign <= 0;
				exp <= {exponent_size{1'b0}};
				mantissa <= {mantissa_size{1'b0}};
			end
			else if (int == {int_size{1'b1}} - {int_size - 1{1'b1}}) begin
				
			end
			else begin: get_exponent_size
				for (i = 1; i < int_size; i = i + 1) begin
					if (pos_int[i] == 1'b1)
						size = i - 1;
				end

				exp <= exp_bias + size[7:0];
			end
			for (index = 0; index < mantissa_size && index <= size; index = index + 1) begin
				mantissa[mantissa_size - 1 - index] <= pos_int[size - index];
			end

			sign <= int[int_size - 1];
		end
	end

	assign fp[precision - 1] = sign;
	assign fp[precision - 2: precision - 1 - exponent_size] = exp;
	assign fp[precision - exponent_size - 2:0] = mantissa;

endmodule