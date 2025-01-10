`timescale 1ns/100ps

module floating_point_to_int(
					clk,
					reset,
				    float,
					invalid_op_flag,
					conv,
					int);

	parameter int_size      = 64;
	parameter mantissa_size = 23;
	parameter exponent_size =  8;
	parameter precision     = 32;
	parameter exp_bias      = {exponent_size{1'b1}} - {exponent_size - 1{1'b1}};

	input                   clk;
	input					reset;
	input [precision - 1:0] float;
	input [1:0]				conv;
	output      		    invalid_op_flag;
	output [int_size - 1:0] int;

	reg        sign;
	reg signed [exponent_size - 1:0]  exp;
	reg        [mantissa_size:0] mantissa; 

	reg signed [int_size - 1:0] r_int;
	reg r_invalid_flag;

	reg [1:0] state;

	reg [23:0] frac;
	reg done;

	initial begin
		state <= 2'b0;
		r_invalid_flag <=0;
		done <= 0;
		r_int <= {int_size{1'b0}};
	end

	always @(posedge clk or negedge reset) begin: conversion_logic
		if (!reset && !clk) begin
			r_int <= {int_size{1'b0}};
			exp <= {exponent_size{1'b0}};
			mantissa <= {mantissa_size + 1{1'b0}};
			sign <= 0;
			state <= 2'b0;
			done <= 0;
		end
		else
			case (state)
				2'b0: begin: get_float
					sign     <= float[precision - 1];
					mantissa[mantissa_size - 1:0] <= float[mantissa_size - 1:0];
					mantissa[mantissa_size] <= 1'b1;

					if (float[precision - 2:precision - exponent_size - 1] < exp_bias)
						exp <= - float[precision - 2:precision - exponent_size - 1];
					else
						exp <= float[precision - 2:precision - exponent_size - 1] - exp_bias;

					r_int <= {int_size{1'b0}};
					state <= 2'b1;
				end
				2'b1: begin: special_cases
						if (float[precision - 2:precision - exponent_size - 1] == {exponent_size{1'b1}} ||
							exp >= int_size) begin
						// nan or infinity, or value is bigger than the max int
							r_int <= {int_size{1'b1}};
							state <= 2'b11;
							r_invalid_flag <= 1;
						end
						else begin
							state <= 2'b10;
							r_invalid_flag <= 0;
						end
				end
				2'b10: begin: conversion
					// first round number to 0
					integer index;
					if (exp < 0)
						r_int <= {int_size{1'b0}};
					else if (exp == 0)
						if (sign)
							r_int <= {int_size{1'b1}};
						else
							r_int <= 1'b1;
					else begin
						for (index = 0; index <= exp && index <= mantissa_size; index = index + 1) begin
							r_int[exp + 1 - index] = mantissa[mantissa_size - index];
						end

						if (sign)
							r_int = 1'b1 + ~ r_int;
					end

					state <= 2'b11;
				end
				2'b11: begin: rounding
					frac = mantissa << exp;
					if (exp < mantissa_size && ! done) begin
						if (frac != {exponent_size{1'b0}}) begin
							case (conv)
								2'b0: begin: round_to_0
								end
								2'b1: begin: round_to_posinf
									if (!sign)
										r_int = r_int + 1;
								end
								2'b10: begin: round_to_neginf
									if (sign)
										r_int = r_int - 1;
								end
								2'b11: begin: rount_to_closest
									if (frac[mantissa_size - 1] && frac[mantissa_size - 2:0] != {mantissa_size - 1{1'b0}})
										r_int = r_int + (sign) ? -1 : 1;
								end
							endcase
						end
					end
					done <= 1;
				end
			endcase
	end

	assign invalid_op_flag = r_invalid_flag;
	assign int = r_int;

endmodule