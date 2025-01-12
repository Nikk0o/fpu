module multiplier(
                  clk,
                  reset,
                  fp_a,
                  fp_b,
                  inv_op,
                  result,
                  done
);

    parameter precision = 32;
    parameter exp_size = 8;
    parameter mantissa_size = 23;

    parameter exp_bias = {exp_size - 1{1'b1}};

    input clk;
    input reset;
    input [precision - 1:0] fp_a;
    input [precision - 1:0] fp_b;
    output [precision - 1:0] result;
    output inv_op;
    output done;

    reg sign_a;
    reg sign_b;
    reg signed [exp_size - 1:0] exp_a;
    reg signed [exp_size - 1:0] exp_b;
    reg [mantissa_size - 1:0] mantissa_a;
    reg [mantissa_size - 1:0] mantissa_b;

    reg sign_r;
    reg [exp_size - 1:0] exp_r;
    reg [mantissa_size - 1:0] mantissa_r;

    reg [2 * (mantissa_size + 1):0] mantissa_mult;

    reg [1:0] state;

    reg r_done;
    reg r_inv_op;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= 2'b0;
        end
        else begin
            case (state)
                2'b0: begin: load_values
                    sign_a <= fp_a[precision - 1];
                    
                    exp_a <= (fp_a[precision - 2:precision - 1 - exp_size] >= exp_bias) ? fp_a[precision - 2:precision - 1 - exp_size] - exp_bias : 
                                                                                          - $signed(fp_a[precision - 2:precision - 1 - exp_size]);
                    mantissa_a = fp_a[mantissa_size - 1:0];

                    sign_b <= fp_b[precision - 1];
                    exp_b <= (fp_b[precision - 2:precision - 1 - exp_size] >= exp_bias) ? fp_b[precision - 2:precision - 1 - exp_size] - exp_bias : 
                                                                                          - $signed(fp_b[precision - 2:precision - 1 - exp_size]);
                    mantissa_b = fp_b[mantissa_size - 1:0];

                    state <= 2'b01;
                end
                2'b01: begin: special_cases
                    if (exp_a == {exp_size{1'b1}} - exp_bias && mantissa_a == {mantissa_size{1'b0}} &&
                                      exp_b == {exp_size{1'b0}} && mantissa_b == {mantissa_size{1'b0}} ||
                                      exp_b == {exp_size{1'b1}} - exp_bias && mantissa_b == {mantissa_size{1'b0}} &&
                                         exp_a == {exp_size{1'b0}} && mantissa_a == {mantissa_size{1'b0}}) begin
                    // inf * 0 or 0 * inf
                        sign_r <= 1'b0;
                        exp_r <= {exp_size{1'b1}};
                        mantissa_r[mantissa_size - 1:mantissa_size - 2] <= 2'b10;
                        mantissa_r[mantissa_size - 3:0] <= {mantissa_size - 2{1'b0}};

                        r_inv_op <= 1;
                        r_done <= 1;
                    end
                    else if (exp_a == {exp_size{1'b1}} - exp_bias && mantissa_a != {mantissa_size{1'b0}} ||
                               exp_b == {exp_size{1'b1}} - exp_bias && mantissa_b != {mantissa_size{1'b0}}) begin
                    // NaN
                    // returns qNaN
                        sign_r <= 1'b0;
                        exp_r <= {exp_size[1'b1]};
                        mantissa_r[mantissa_size - 1:mantissa_size - 2] <= 2'b10;
                        mantissa_r[mantissa_size - 3:0] <= {mantissa_size - 2{1'b0}};

                        if (mantissa_a[mantissa_size - 1:mantissa_size - 2] == 2'b01 || 
                               mantissa_b[mantissa_size - 1:mantissa_size - 2] == 2'b01)
                            r_inv_op <= 1;
                        else
                            r_inv_op <= 0;
                        
                        r_done <= 1;
                    end

                    state <= 2'b10;
                end
                2'b10: begin: multiply
                end
            endcase
        end
    end

    assign result = r_result;
    assign done = r_done;
    assign inv_op = r_inv_op;

endmodule