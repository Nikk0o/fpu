`timescale 1ns/100ps

module floating_point_to_int(
					clk,
					reset,
				    float,
					invalid_op_flag,
					conv,
					done,
					int);

	parameter int_size      = 64;
	parameter mantissa_size = 23;
	parameter exponent_size =  8;
	parameter precision     = 32;
	parameter unsigned exp_bias      = {exponent_size - 1{1'b1}};

	input                   clk;
	input					reset;
	input [precision - 1:0] float;
	input [1:0]				conv;
	output      		    invalid_op_flag;
	output [int_size - 1:0] int;
	output 					done;

	reg        sign;
	reg signed [exponent_size - 1:0]  exp;
	reg        [mantissa_size:0] mantissa; 

	reg signed [int_size - 1:0] r_int;
	reg r_invalid_flag;

	reg [1:0] state;

	reg [22:0] frac;
	reg r_done;

	initial begin
		state <= 2'b0;
		r_invalid_flag <=0;
		r_done <= 0;
		r_int <= {int_size{1'b0}};
	end

	always @(posedge clk or negedge reset) begin: conversion_logic
		if (!reset) begin
			r_int <= {int_size{1'b0}};
			exp <= {exponent_size{1'b0}};
			mantissa <= {mantissa_size + 1{1'b0}};
			sign <= 0;
			state <= 2'b0;
			r_done <= 0;
		end
		else
			case (state)
				2'b0: begin: get_float
					sign     <= float[precision - 1];
					mantissa[mantissa_size - 1:0] <= float[mantissa_size - 1:0];
					if (float[precision - 2:precision - 1 - exponent_size] != {exponent_size{1'b0}}) 
						mantissa[mantissa_size] <= 1'b1;
					else 
						mantissa[mantissa_size] <= 1'b0;

					if (float[precision - 2:precision - 1 - exponent_size] < exp_bias)
						exp <= - $signed(float[precision - 2:precision - 1 - exponent_size]);
					else
						exp <= float[precision - 2:precision - 1 - exponent_size] - exp_bias;

					r_int <= {int_size{1'b0}};
					state <= 2'b1;
				end
				2'b1: begin: special_cases
						if (float[precision - 2:precision - 1 - exponent_size] == {exponent_size{1'b1}}) begin

							r_int[int_size - 1] <= 1'b1;

							r_invalid_flag <= 1;
							r_done <= 1;
							state <= 2'b11;
						end 
						else begin
							r_invalid_flag <= 0; 
							state <= 2'b10;
						end
				end
				2'b10: begin: conversion
					integer shift;
					// start by rounding to 0
					if (exp < 0) begin
						r_int <= {int_size{1'b0}};
					end
					else if (exp == 0) begin
						if (mantissa != {mantissa_size + 1{1'b0}})
							if (sign)
								r_int <= {int_size{1'b1}};
							else
								r_int <= 1'b1;
						else
							r_int <= {int_size{1'b0}};
					end
					else begin
						for (shift = 0; shift <= exp && shift <= mantissa_size; shift = shift + 1) begin 
							r_int[exp - shift] = mantissa[mantissa_size - shift];
						end

						if (sign) 
							r_int = - r_int;
					end

					if (exp >= 0) 
						frac <= mantissa << exp;
					else
						frac <= mantissa >> - exp;

					state <= 2'b11;
				end
				2'b11: begin: rounding
					if (!done && frac[22] != 1'b0 && frac[21:0] != 22'b0) begin
						case (conv)
							2'b0: begin: round_to_0
							end
							2'b1: begin: round_to_neginf
								if (sign)
									r_int <= r_int - 1;
							end
							2'b10: begin: rount_to_posinf
								if (!sign)
									r_int <= r_int + 1;
							end
							2'b11: begin: round_to_closest
								if (sign)
									r_int <= r_int - 1;
								else
									r_int <= r_int + 1;
							end
						endcase
					end
					
					r_done <= 1;
				end
			endcase
	end

	assign invalid_op_flag = r_invalid_flag;
	assign int = r_int;
	assign done = r_done;

endmodule