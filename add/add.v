module adder(
             clk,
             reset,
             fp_a,
             fp_b,
             result,
             invalid_op,
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
    output [precision - 1:0] reset;
    output invalid_op;
    output done;

    reg sign_a;
    reg sign_b;
    reg signed [exp_size - 1:0] exp_a;
    reg signed [exp_size - 1:0] exp_b;
    reg [mantissa_size:0] mantissa_a;
    reg [mantissa_size:0] mantissa_b;

    reg [exp_size - 1:0] exp_add;
    reg [mantissa_size + 2:0] mantissa_add;

    reg sign_r;
    reg [exp_size - 1:0] exp_r;
    reg [mantissa_size - 1:0] mantissa_r;

    reg [1:0] state;

    reg r_done;
    reg r_inv_op;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= 2'b00;
            r_done <= 0;
            r_inv_op <= 0;
        end
        else begin
            case (state)
                2'b00: begin: load_values
                    sign_a <= fp_a[precision - 1];
                    sign_b <= fp_b[precision - 1];

                    if (fp_a[precision - 2:precision - 1 - exp_size] >= exp_bias)
                        exp_a <= fp_a[precision - 2:precision - 1 - exp_size] - exp_bias;
                    else
                        exp_a <= - $signed(exp_bias - fp_a[precision - 2:precision - 1 - exp_size]);

                    if (fp_b[precision - 2:precision - 1 - exp_size] >= exp_bias)
                        exp_b <= fp_b[precision - 2:precision - 1 - exp_size] - exp_bias;
                    else
                        exp_b <= - $signed(exp_bias - fp_b[precision - 2:precision - 1 - exp_size]);

                    mantissa_a[mantissa_size - 1:0] <= fp_a[mantissa_size - 1:0];
                    mantissa_b[mantissa_size - 1:0] <= fp_b[mantissa_size - 1:0];

                    if (fp_a[precision - 2:precision - 1 - exp_size] != {exp_size{1'b0}})
                        mantissa_a[mantissa_size] <= 1'b1;
                    else
                        mantissa_a[mantissa_size] <= 1'b0;

                    if (fp_b[precision - 2:precision - 1 - exp_size] != {exp_size{1'b0}})
                        mantissa_b[mantissa_size] <= 1'b1;
                    else
                        mantissa_b[mantissa_size] <= 1'b0;

                    state <= 2'b01;
                end
                2'b01: begin: special_cases
                end
                2'b10: begin: add
                    if (exp_a > exp_b) begin
                        // shift b to the size of a
                        mantissa_b = mantissa_b >> exp_a - exp_b;
                        exp_b = exp_a;
                    end
                    else if (exp_a < exp_b) begin
                        // shift a to the size of b
                        mantissa_a = mantissa_a >> exp_b - exp_a;
                        exp_a = exp_b;
                    end

                    exp_add = exp_a;
                    
                    // add
                    if (sign_a == sign_b) begin
                        mantissa_add = mantissa_a + mantissa_b;
                        if (mantissa_add[mantissa_size + 2:mantissa_size + 1] > 2'b01)
                            exp_r <= exp_r + 1;
                    end
                    
                end
                2'b11: begin: round
                end
            endcase
        end
    end

    assign done = r_done;
    assign inv_op = r_inv_op;

endmodule