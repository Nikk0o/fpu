`include "add.v"
`include "double_to_float.v"
`include "equals.v"
`include "float_to_double.v"
`include "float_to_int.v"
`include "greather.v"
`include "int_to_fp.v"
`include "mult.v"
`include "div.v"

module fpu(
           input clk,
           input enable,
           input precision,
           input [3:0] instruction,
           input [63:0] fp_a,
           input [63:0] fp_b,
           input reg_a, // 0: get input from fp_a; 1: get input from a register
           input reg_b,
           input [1:0] rounding,
           input [31:0] int,
           input [2:0] reg_a_no,
           input [2:0] reg_b_no,
		   input [2:0] sl_loc,
		   input store_sel, //1: store b, 2: store a // precisa disso mesmo ?
           output reg [63:0] result,
           output reg [31:0] result_int,
		   output reg eq_flag_o,
		   output reg gr_flag_o,
           output done
);

    parameter all_1s = 64'hffffffffffffffff;

    reg [31:0] registers_float [7:0];
    reg [63:0] registers_double [7:0];

    wire ad;
    wire sub;
    wire mlt;
    wire dv;
    wire f_i;
    wire d_i;
    wire i_f;
    wire i_d;
    wire st;
    wire ld;
    wire d_f;
    wire f_d;
    wire gr;
    wire eq;

    wire w_done;

    wire done_add_f;
    wire done_div_f;
    wire done_mlt_f;
    wire done_eq_f;
    wire done_gr_ff;
    wire done_i_f;
    wire done_i_d;
    wire done_d_f;
    wire done_f_d;

    wire done_add_d;
    wire done_div_d;
    wire done_mlt_d;
    wire done_eq_d;
    wire done_gr_d;

    reg done_load_f;
    reg done_load_d;

    wire [31:0] res_add_f;
    wire [31:0] res_div_f;
    wire [31:0] res_mlt_f;

    wire [63:0] res_add_d;
    wire [63:0] res_div_d;
    wire [63:0] res_mlt_d;

    reg [31:0] res_load_f;
    reg [63:0] res_load_d;

    wire [31:0] res_f_i;
    wire [31:0] res_d_i;

    wire [31:0] res_i_f;
    wire [63:0] res_i_d;

	wire [31:0] res_d_f;
    wire [63:0] res_f_d;

    reg done_store_f;
    reg done_store_d;

    wire eq_flag_f;
    wire gr_flag_f;

    wire eq_flag_d;
    wire gr_flag_d;

    wire eq_flag;
    wire gr_flag;

    wire done_f_i;
    wire done_d_i;

	wire [63:0] input_fp_a;
	wire [63:0] input_fp_b;

    assign input_fp_a[63:32] = (!reg_a) ? fp_a[63:32] : ((precision) ? registers_double[reg_a_no][63:32] : registers_float[reg_a_no]);
    assign input_fp_a[31:0] = (!precision) ? 32'b0 : ((!reg_a) ? fp_a[31:0] : registers_double[reg_a_no][31:0]);
    
    assign input_fp_b[63:32] = (!reg_b) ? fp_b[63:32] : ((precision) ? registers_double[reg_b_no][63:32] : registers_float[reg_b_no]);
    assign input_fp_b[31:0] = (!precision) ? 32'b0 : ((!reg_b) ? fp_b[31:0] : registers_double[reg_b_no][31:0]);

    adder #(
        .precision(32),
        .exp_size(8),
        .mantissa_size(23)) 
        adder_subtractor_ff(
            .clk(clk),
            .enable(enable),
            .fp_a(input_fp_a[63:32]),
            .fp_b(input_fp_b[63:32]),
            .round(rounding),
            .result(res_add_f),
            .add_sub(sub),
            .done(done_add_f));

    divider #(
        .precision(32),
        .exp_size(8),
        .mantissa_size(23)) 
        divide_ff(
               .clk(clk),
               .enable(enable),
               .fp_a(input_fp_a[63:32]),
               .fp_b(input_fp_b[63:32]),
               .rounding(rounding),
               .result(res_div_f),
               .done(done_div_f));

    multiplier #(
        .precision(32),
        .exp_size(8),
        .mantissa_size(23))
        mult_ff(
                  .clk(clk),
                  .enable(enable),
                  .fp_a(input_fp_a[63:32]),
                  .fp_b(input_fp_b[63:32]),
                  .rounding(rounding),
                  .result(res_mlt_f),
                  .done(done_mlt_f));

    equals #(
        .precision(32),
        .exp_size(8),
        .mantissa_size(23))
        eq_ff(
              .clk(clk),
              .enable(enable),
              .fp_a(input_fp_a[63:32]),
              .fp_b(input_fp_b[63:32]),
              .res(eq_flag_f),
              .done(done_eq_f));

    greather #(
        .precision(32),
        .exp_size(8),
        .mantissa_size(23))
        gr_d(
                .clk(clk),
                .enable(enable),
                .fp_a(input_fp_a[63:32]),
                .fp_b(input_fp_b[63:32]),
                .res(gr_flag_f),
                .done(done_gr_ff));

    adder #(
        .precision(64),
        .exp_size(11),
        .mantissa_size(52)) 
        adder_subtractor_d(
            .clk(clk),
            .enable(enable),
            .fp_a(fp_a),
            .fp_b(fp_b),
            .round(rounding),
            .result(res_add_d),
            .add_sub(sub),
            .done(done_add_d));

    divider #(
        .precision(64),
        .exp_size(11),
        .mantissa_size(52))
        divide_d(
               .clk(clk),
               .enable(enable),
               .fp_a(input_fp_a),
               .fp_b(input_fp_b),
               .rounding(rounding),
               .result(res_div_d),
               .done(done_div_d));

    multiplier #(
        .precision(64),
        .exp_size(11),
        .mantissa_size(52))
        mult_d(
                  .clk(clk),
                  .enable(enable),
                  .fp_a(input_fp_a),
                  .fp_b(input_fp_b),
                  .rounding(rounding),
                  .result(res_mlt_d),
                  .done(done_mlt_d));

    equals #(
        .precision(64),
        .exp_size(11),
        .mantissa_size(52))
        eq_d(
              .clk(clk),
              .enable(enable),
              .fp_a(input_fp_a),
              .fp_b(input_fp_b),
              .res(eq_flag_d),
              .done(done_eq_d));

    greather #(
        .precision(64),
        .exp_size(11),
        .mantissa_size(52))
        gr_dd(
                .clk(clk),
                .enable(enable),
                .fp_a(input_fp_a),
                .fp_b(input_fp_b),
                .res(gr_flag_d),
                .done(done_gr_d));
            
    floating_point_to_int #(
        .precision(32),
        .exponent_size(8),
        .mantissa_size(23),
        .int_size(32))
        float_to_int(
					.clk(clk),
					.enable(enable),
				    .float(input_fp_a[63:32]),
					.conv(rounding),
					.done(done_f_i),
					.int(res_f_i));

    floating_point_to_int #(
        .precision(64),
        .exponent_size(11),
        .mantissa_size(52),
        .int_size(32))
        double_to_int(
					.clk(clk),
					.enable(enable),
				    .float(input_fp_a),
					.conv(rounding),
					.done(done_d_i),
					.int(res_d_i));

    int_to_fp #(
        .precision(32),
        .exponent_size(8),
        .mantissa_size(23),
        .int_size(32))
        int_to_float(
				 .clk(clk),
				 .enable(enable),
				 .int(int),
				 .done(done_i_f),
				 .fp(res_i_f));

    int_to_fp #(
        .precision(64),
        .exponent_size(11),
        .mantissa_size(52),
        .int_size(32))
        int_to_double(
				 .clk(clk),
				 .enable(enable),
				 .int(int),
				 .done(done_i_d),
				 .fp(res_i_d));

    double_to_float do_f (
                       .clk(clk),
                       .enable(enable),
                       .rounding(rounding),
                       .double(input_fp_a),
                       .done(done_d_f),
                       .float(res_d_f));

    float_to_double fl_d(
                       .clk(clk),
                       .enable(enable),
                       .double(res_f_d),
                       .float(input_fp_a[63:32]),
                       .done(done_f_d)
                       );

	// sinto q isso aqui ta errado
    always @(posedge clk) begin
        if (ad || sub || mlt || dv || ld) begin
		// operations that can have single or double precision output
            if (!precision) begin
                if (ad || sub) 
                    result[63:32] = res_add_f;
                else if (dv)
                    result[63:32] = res_div_f;
                else if (mlt)
                    result[63:32] = res_mlt_f;
                else
                    result[63:32] = res_load_f;
            end
            else begin
                if (ad || sub) 
                    result = res_add_d;
                else if (dv)
                    result = res_div_d;
                else if (mlt)
                    result = res_mlt_d;
                else
                    result = res_load_d;
            end
        end
        else begin
            if (f_i) begin
                result_int = res_f_i;
            end
            else if (i_f) begin
                result[63:32] = res_i_f;
            end
            else if (d_i) begin
                result_int = res_d_i;
            end
            else if (i_d) begin
                result = res_i_d;
            end
            else if (f_d) begin
                result = res_f_d;
            end
            else if (d_f) begin
                result = res_d_f;
            end
            else begin
                result = 64'b0;
            end
        end

		if (!precision) begin
			eq_flag_o = eq_flag_f;
			gr_flag_o = gr_flag_f;
		end else begin
			eq_flag_o = eq_flag_d;
			gr_flag_o = gr_flag_d;
		end
    end

    always @(posedge clk) begin // load
        if (instruction == 4'h9 && enable) begin
            if (!w_done)
                if (!precision) begin
                    res_load_f <= registers_float[sl_loc];
                    done_load_f <= 1;
                    done_load_d <= 0;
                end
                else begin
                    res_load_d <= registers_double[sl_loc];
                    done_load_d <= 1;
                    done_load_f <= 0;
                end
        end
        else begin
            done_load_f <= 0;
            done_load_d <= 0;
        end
    end

    always @(posedge clk) begin // store
        if (instruction == 4'h8 && enable) begin
            if (!w_done)
                if (!precision) begin
                    if (!store_sel)
                        registers_float[sl_loc] <= input_fp_a[63:32];
                    else
                        registers_float[sl_loc] <= input_fp_b[63:32];
                    done_store_f <= 1;
                    done_store_d <= 0;
                end
                else begin
                    if (!store_sel)
                        registers_double[sl_loc] <= input_fp_a;
                    else
                        registers_double[sl_loc] <= input_fp_b;
                    done_store_d <= 1;
                    done_store_f <= 0;
                end
        end
        else begin
            if (w_done && (ad || sub || dv || mlt)) begin
                if (!precision) // always store the result of operations in the last register
                    registers_float[7] <= result[63:32];
                else
                    registers_double[7] <= result;
            end
            done_store_f <= 0;
            done_store_d <= 0;
        end
    end


    assign eq_flag = eq_flag_d || eq_flag_f;
    assign gr_flag = gr_flag_d || gr_flag_f;

    assign w_done = done_div_f && dv || done_add_f && (ad || sub) || done_mlt_f && mlt || done_div_d && dv || done_add_d && (ad || sub) || done_mlt_d && mlt || done_load_f && ld || done_load_d && ld
                    || done_f_i && f_i || done_d_i && d_i || done_d_f && d_f || done_f_d && f_d
                    || done_i_f && i_f || done_i_d && i_d || done_store_d && st || done_store_f && st || done_gr_d && gr || done_gr_ff && gr || done_eq_d && eq || done_eq_f && eq;

    assign ad = (instruction == 4'h0) ? 1'b1 : 1'b0;
    assign sub = (instruction == 4'h1) ? 1'b1 : 1'b0;
    assign mlt = (instruction == 4'h2) ? 1'b1 : 1'b0;
    assign dv = (instruction == 4'h3) ? 1'b1 : 1'b0;
    assign f_i = (instruction == 4'h4) ? 1'b1 : 1'b0;
    assign d_i = (instruction == 4'h5) ? 1'b1 : 1'b0;
    assign f_d = (instruction == 4'h6) ? 1'b1 : 1'b0;
    assign d_f = (instruction == 4'h7) ? 1'b1 : 1'b0;
    assign st = (instruction == 4'h8) ? 1'b1 : 1'b0;
    assign ld = (instruction == 4'h9) ? 1'b1 : 1'b0;
    assign gr = (instruction == 4'ha) ? 1'b1 : 1'b0;
    assign eq = (instruction == 4'hb) ? 1'b1 : 1'b0;
    assign i_f = (instruction == 4'hc) ? 1'b1 : 1'b0;
    assign i_d = (instruction == 4'hd) ? 1'b1 : 1'b0;

	assign done = w_done;
    
endmodule