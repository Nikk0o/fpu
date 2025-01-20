`include "add/add.v"
`include "double to float/double_to_float.v"
`include "equals/equals.v"
`include "float to double/float_to_double.v"
`include "fp to int/float_to_int.v"
`include "greather/greather.v"
`include "int to fp/int_to_fp.v"
`include "mult/mult.v"
`include "div/div.v"

module fpu(
           input clk,
           input reset, // low active
           input precision,
           input [3:0] instruction,
           input [63:0] fp_a,
           input [63:0] fp_b,
           input reg_a, // 0: get input from fp_a; 1: get input from a register
           input reg_b,
           input [1:0] rounding,
           input [31:0] int,
           input [7:0] reg_a_no,
           input [7:0] reg_b_no,
           output reg [63:0] result,
           output reg [31:0] result_int,
           output done
);

    reg [7:0] registers_float [31:0];
    reg [7:0] registers_double [63:0];

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

    wire done_add_d;
    wire done_div_d;
    wire done_mlt_d;
    wire done_eq_d;
    wire done_gr_d;

    reg done_load_f;
    reg done_load_d;

    wire add_or_sub;
    wire [31:0] res_add_f;
    wire [31:0] res_div_f;
    wire [31:0] res_mlt_f;

    wire [63:0] res_add_d;
    wire [63:0] res_div_d;
    wire [63:0] res_mlt_d;

    reg [31:0] res_load_f;
    reg [63:0] res_load_d;

    reg done_store_f;
    reg done_store_d;

    wire eq_flag_f;
    wire gr_flag_f;

    wire eq_flag_d;
    wire gr_flag_d;

    wire eq_flag;
    wire gr_flag;

    adder #(
        .precision(32),
        .exp_size(8),
        .mantissa_size(23)) 
        adder_subtractor_ff(
            .clk(clk),
            .reset(reset),
            .fp_a(fp_a[63:32]),
            .fp_b(fp_b[63:32]),
            .round(rounding),
            .result(res_add_f),
            .add_sub(add_or_sub),
            .done(done_add_f));

    divider #(
        .precision(32),
        .exp_size(8),
        .mantissa_size(23)) 
        divide_ff(
               .clk(clk),
               .reset(reset),
               .fp_a(fp_a[63:32]),
               .fp_b(fp_b[63:32]),
               .rounding(rounding),
               .result(res_div_f),
               .done(done_div_f));

    multiplier #(
        .precision(32),
        .exp_size(8),
        .mantissa_size(23))
        mult_ff(
                  .clk(clk),
                  .reset(reset),
                  .fp_a(fp_a[63:32]),
                  .fp_b(fp_b[63:32]),
                  .rounding(rounding),
                  .result(res_mlt_f),
                  .done(done_mlt_f));

    equals #(
        .precision(32),
        .exp_size(8),
        .mantissa_size(23))
        eq_ff(
              .clk(clk),
              .reset(reset),
              .fp_a(fp_a[63:32]),
              .fp_b(fp_b[63:32]),
              .res(eq_flag_f),
              .done(done_eq_f));

    greather #(
        .precision(32),
        .exp_size(8),
        .mantissa_size(23))
        gr_d(
                .clk(clk),
                .reset(reset),
                .fp_a(fp_a[63:32]),
                .fp_b(fp_b[63:32]),
                .res(gr_flag_f),
                .done(done_gr_ff));

    adder #(
        .precision(64),
        .exp_size(11),
        .mantissa_size(52)) 
        adder_subtractor_d(
            .clk(clk),
            .reset(reset),
            .fp_a(fp_a),
            .fp_b(fp_b),
            .round(rounding),
            .result(res_add_d),
            .add_sub(add_or_sub),
            .done(done_add_f));

    divider #(
        .precision(64),
        .exp_size(11),
        .mantissa_size(52))
        divide_d(
               .clk(clk),
               .reset(reset),
               .fp_a(fp_a),
               .fp_b(fp_b),
               .rounding(rounding),
               .result(res_div_d),
               .done(done_div_d));

    multiplier #(
        .precision(64),
        .exp_size(11),
        .mantissa_size(52))
        mult_d(
                  .clk(clk),
                  .reset(reset),
                  .fp_a(fp_a),
                  .fp_b(fp_b),
                  .rounding(rounding),
                  .result(res_mlt_d),
                  .done(done_mlt_d));

    equals #(
        .precision(64),
        .exp_size(11),
        .mantissa_size(52))
        eq_d(
              .clk(clk),
              .reset(reset),
              .fp_a(fp_a),
              .fp_b(fp_b),
              .res(eq_flag_d),
              .done(done_eq_d));

    greather #(
        .precision(64),
        .exp_size(11),
        .mantissa_size(52))
        gr_dd(
                .clk(clk),
                .reset(reset),
                .fp_a(fp_a),
                .fp_b(fp_b),
                .res(gr_flag_d),
                .done(done_gr_d));


    always @(posedge w_done) begin
        if (ad || sub || mlt || dv || ld || gr || eq) begin
            // operations that can have either single or double precision results
            if (!precision) begin
                result[63:32] <= res_add_f * ad || res_div_f * dv || res_mlt_f * mlt || res_load_f * ld;
                result[31:0] <= 32'b0;
            end
            else begin
                result <= res_add_d * ad || res_div_d * dv || res_mlt_d * mlt || res_load_d * ld;
            end
        end
        else begin
            // operations whose result has a defined precision
        end
    end

    always @(posedge clk or negedge reset) begin // load
        if (!reset) begin
            done_load_f <= 0;
            done_load_d <= 0;
        end
        else if (!w_done && instruction == 4'h9) begin
            if (!precision) begin
                res_load_f <= registers_float[reg_a_no];
                done_load_f <= 1;
            end
            else begin
                res_load_d <= registers_double[reg_a_no];
                done_load_d <= 1;
            end
        end
        else begin
            done_load_f <= 0;
            done_load_d <= 0;
        end
    end

    always @(posedge clk or negedge reset) begin // store
        if (!reset) begin
            done_store_f <= 0;
            done_store_d <= 0;
        end
        else if (!w_done && instruction == 4'h9) begin
            if (!precision) begin
                registers_float[reg_a_no] <= fp_a[63:32];
                done_store_f <= 1;
            end
            else begin
                registers_double[reg_a_no] <= fp_a;
                done_store_d <= 1;
            end
        end
        else begin
            done_store_f <= 0;
            done_store_d <= 0;
        end
    end


    assign eq_flag = eq_flag_d || eq_flag_f;
    assign gr_flag = gr_flag_d || gr_flag_f;

    assign w_done = done_div_f || done_add_f || done_load_f || done_load_d;

    assign add_or_sub =  !(ad * (! sub));

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
    
endmodule