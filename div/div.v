module divider(
               clk,
               reset,
               fp_a,
               fp_b,
               result,
               rounding,
               done
);

    parameter precision = 32;
    parameter exp_size = 8;
    parameter mantissa_size = 23;

    input clk;
    input reset;
    output done;
    input [1:0] rounding;
    input [precision - 1:0] fp_a;
    input [precision - 1:0] fp_b;
    output [precision - 1:0] result;

    parameter exp_bias = {exp_size - 1{1'b1}};

    reg sign_a;
    reg signed [exp_size - 1:0] exp_a;
    reg [mantissa_size - 1:0] mantissa_a;

    reg sign_b;
    reg signed [exp_size - 1:0] exp_b;
    reg [mantissa_size:0] mantissa_b;

    reg sign_div;
    reg signed [exp_size - 1:0] exp_div;
    reg [mantissa_size:0] mantissa_div;

    reg [mantissa_size - 1:0] rem;

    reg [1:0] state;

    always @(posedge clk) begin
        case (state)
            2'b00: begin: load_values
                sign_a <= fp_a[precision - 1];
                exp_a <= (fp_a[precision - 2:precision - 1 - exp_size] >= exp_bias) ? fp_a[precision - 2:precision - 1 - exp_size] - exp_bias : $signed(fp_a[precision - 2:precision - 1 - exp_size]) - exp_bias;
                mantissa_a[mantissa_size - 1:0] <= fp_a[mantissa_size - 1:0];
                if (fp_a[precision - 2:precision - 1 - exp_size] != {exp_size{1'b0}})
                    mantissa_a[mantissa_size] = 1'b1;
                else
                    mantissa_a[mantissa_size] = 1'b0;

                sign_b <= fp_b[precision - 1];
                exp_b <= (fp_b[precision - 2:precision - 1 - exp_size] >= exp_bias) ? fp_b[precision - 2:precision - 1 - exp_size] - exp_bias : $signed(fp_b[precision - 2:precision - 1 - exp_size]) - exp_bias;
                mantissa_b[mantissa_size - 1:0] <= fp_b[mantissa_size - 1:0];
                if (fp_b[precision - 2:precision - 1 - exp_size] != {exp_size{1'b0}})
                    mantissa_b[mantissa_size] = 1'b1;
                else
                    mantissa_b[mantissa_size] = 1'b0;

                state <= 2'b01;
            end
            2'b01: begin: special_cases
                state <= 2'b10;
            end
            2'b10: begin: divide
                sign_div = sign_a ^ sign_b;
                exp_div = exp_a - exp_b;
                mantissa_div = mantissa_a / mantissa_b;
                rem <= mantissa_a % mantissa_b;

                state <= 2'b11;
            end
            2'b11: begin: round
                case (rounding)
                    2'b00: begin: round_to_neginf
                        if (sign_div && rem > mantissa_a / 2) begin
                            mantissa_div <= mantissa_div + 1'b1;
                        end
                    end
                    2'b01: begin: round_to_posinf
                        if (!sign_div && rem > mantissa_a / 2) begin
                            mantissa_div <= mantissa_div + 1'b1;
                        end
                    end
                    2'b10: begin: round_to_0
                    end
                    2'b11: begin: round_to_closest
                        if (rem > mantissa_a / 2) begin
                            mantissa_div <= mantissa_div + 1'b1;
                        end
                    end
                endcase
            end
        endcase
    end

endmodule