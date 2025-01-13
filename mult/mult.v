module multiplier(
                  clk,
                  reset,
                  fp_a,
                  fp_b,
                  inv_op,
                  rounding,
                  result,
                  done
);

    parameter precision = 32;
    parameter exp_size = 8;
    parameter mantissa_size = 23;

    parameter exp_bias = {exp_size - 1{1'b1}};

    input clk;
    input reset;
    input [1:0] rounding;
    input [precision - 1:0] fp_a;
    input [precision - 1:0] fp_b;
    output [precision - 1:0] result;
    output inv_op;
    output done;

    reg sign_a;
    reg sign_b;
    reg signed [exp_size - 1:0] exp_a;
    reg signed [exp_size - 1:0] exp_b;
    reg [mantissa_size:0] mantissa_a;
    reg [mantissa_size:0] mantissa_b;

    reg sign_r;
    reg [exp_size - 1:0] exp_r;
    reg [mantissa_size - 1:0] mantissa_r;

    reg [2 * (mantissa_size + 1) - 1:0] mantissa_mult;
    reg [mantissa_size - 1:0] frac;

    reg [1:0] state;

    reg r_done;
    reg r_inv_op;

    initial begin
        r_done = 0;
        state = 2'b0;
    end

    integer index = 0;
    integer shift = 0;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= 2'b0;
            r_done <= 0;
        end
        else begin
            case (state)
                2'b0: begin: load_values
                    sign_a <= fp_a[precision - 1];
                    sign_b <= fp_b[precision - 1];

                    if (fp_a[precision - 2: precision - 1 - exp_size] >= exp_bias)
                        exp_a <= fp_a[precision - 2: precision - 1 - exp_size] - exp_bias;
                    else
                        exp_a <= $signed(fp_a[precision - 2: precision - 1 - exp_size]) - exp_bias;

                    if (fp_b[precision - 2: precision - 1 - exp_size] >= exp_bias)
                        exp_b <= fp_b[precision - 2: precision - 1 - exp_size] - exp_bias;
                    else
                        exp_b <= $signed(fp_b[precision - 2: precision - 1 - exp_size]) - exp_bias;

                    mantissa_a[mantissa_size - 1:0] <= fp_a[mantissa_size - 1:0];
                    if (fp_a[precision - 2: precision - 1 - exp_size] != {exp_size{1'b0}})
                        mantissa_a[mantissa_size] <= 1'b1;
                    else
                        mantissa_a[mantissa_size] <= 1'b0;

                    mantissa_b[mantissa_size - 1:0] <= fp_b[mantissa_size - 1:0];
                    if (fp_b[precision - 2: precision - 1 - exp_size] != {exp_size{1'b0}})
                        mantissa_b[mantissa_size] <= 1'b1;
                    else
                        mantissa_b[mantissa_size] <= 1'b0;

                    state <= 2'b01;
                    r_done <= 0;
                end
                2'b01: begin: special_cases
                    if (fp_a[precision - 2: precision - 1 - exp_size] == {exp_size{1'b1}} && mantissa_a[mantissa_size - 1:0] == {mantissa_size{1'b0}} &&
                                      fp_b[precision - 1:0] == {precision{1'b0}} || fp_b[precision - 2: precision - 1 - exp_size] == {exp_size{1'b1}} && 
                                      mantissa_b[mantissa_size - 1:0] == {mantissa_size{1'b0}} && fp_a[precision - 1: 0] == {precision{1'b0}}) begin
                    // inf * 0 or 0 * inf
                        sign_r <= sign_a ^ sign_b;
                        exp_r <= {exp_size{1'b1}};
                        mantissa_r[mantissa_size - 1:mantissa_size - 2] <= 2'b10;
                        mantissa_r[mantissa_size - 3:0] <= {mantissa_size - 2{1'b0}};

                        r_inv_op <= 1;
                        r_done <= 1;
                        state <= 2'b11;
                    end
                    else if (fp_a[precision - 2: precision - 1 - exp_size] == {exp_size{1'b1}} && fp_a[mantissa_size - 1:0] != {mantissa_size{1'b0}} ||
                               fp_b[precision - 2: precision - 1 - exp_size] == {exp_size{1'b1}} && fp_b[mantissa_size - 1:0] != {mantissa_size{1'b0}}) begin
                    // NaN
                    // returns qNaN
                        sign_r <= sign_a ^ sign_b;
                        exp_r <= {exp_size{1'b1}};
                        mantissa_r[mantissa_size - 1:mantissa_size - 2] <= 2'b10;
                        mantissa_r[mantissa_size - 3:0] <= {mantissa_size - 2{1'b0}};

                        if (mantissa_a[mantissa_size - 1:mantissa_size - 2] == 2'b01 || 
                               mantissa_b[mantissa_size - 1:mantissa_size - 2] == 2'b01)
                            r_inv_op <= 1;
                        else
                            r_inv_op <= 0;
                        
                        r_done <= 1;
                        state <= 2'b11;
                    end
                    else if (fp_a[precision - 2: precision - 1 - exp_size] == {exp_size{1'b1}} && fp_a[mantissa_size - 1:0] == {mantissa_size{1'b0}} ||
                               fp_b[precision - 2: precision - 1 - exp_size] == {exp_size{1'b1}} && fp_b[mantissa_size - 1:0] == {mantissa_size{1'b0}}) begin
                            // inf * x
                            exp_r <= {exp_size{1'b1}};
                            sign_r <= sign_a ^ sign_b;
                            mantissa_r <= {mantissa_size{1'b0}};

                            r_done <= 1;
                            state <= 2'b11;                            
                    end
                    else begin
                        r_done <= 0;
                        r_inv_op <= 0;
                        state <= 2'b10;
                    end
                end
                2'b10: begin: multiply

                    integer i;

                    mantissa_mult = mantissa_a * mantissa_b;
                    exp_r = exp_bias + exp_a + exp_b;
                    if (mantissa_mult[2 * (mantissa_size + 1) - 1] == 1'b1)
                        exp_r <= exp_r + 1'b1;

                    for (index = 0; index <= 2 * (mantissa_size + 1); index = index + 1) begin
                        if (mantissa_mult[index] == 1'b1)
                            shift = index;
                    end
                    if (shift >= mantissa_size)
                        for (i = mantissa_size; i <= shift; i = i + 1)
                            frac[i - mantissa_size] <= mantissa_mult[i];
                    else
                        frac <= {mantissa_size{1'b0}};

                    shift = mantissa_size - shift;
                    if (shift >= 0) begin
                        mantissa_mult = mantissa_mult << shift;
                    end
                    else begin
                        mantissa_mult = mantissa_mult  >> - shift;
                    end

                    mantissa_r <= mantissa_mult;
                    sign_r <= sign_a ^ sign_b;
                    state <= 2'b11;
                end
                2'b11: begin: round
                    if (!r_done) begin
                        case (rounding)
                            2'b0: begin: round_to_neginf
                                if (sign_r && frac[mantissa_size - 1] && frac[mantissa_size - 2:0] != {mantissa_size - 1{1'b0}}) begin
                                    mantissa_r = mantissa_r + 1'b1;
                                    if (mantissa_r == {mantissa_size{1'b0}})
                                        exp_r <= exp_r + 1'b1;
                                end
                            end
                            2'b01: begin: round_to_posinf
                                if (!sign_r && frac[mantissa_size - 1] && frac[mantissa_size - 2:0] != {mantissa_size - 1{1'b0}}) begin
                                    mantissa_r = mantissa_r + 1'b1;
                                    if (mantissa_r == {mantissa_size{1'b0}})
                                        exp_r <= exp_r + 1'b1;
                                end
                            end
                            2'b10: begin: round_to_0
                            end
                            2'b11: begin: round_to_closest
                                if (sign_r && frac[mantissa_size - 1] && frac[mantissa_size - 2:0] != {mantissa_size - 1{1'b0}}) begin
                                    mantissa_r = mantissa_r + 1'b1;
                                    if (mantissa_r == {mantissa_size{1'b0}})
                                        exp_r <= exp_r + 1'b1;
                                end
                                else if (!sign_r && frac[mantissa_size - 1] && frac[mantissa_size - 2:0] != {mantissa_size - 1{1'b0}}) begin
                                    mantissa_r = mantissa_r + 1'b1;
                                    if (mantissa_r == {mantissa_size{1'b0}})
                                        exp_r <= exp_r + 1'b1;
                                end
                            end
                        endcase
                        r_done <= 1;
                    end
                end
            endcase
        end
    end

    assign result[precision - 1] = sign_r;
    assign result[precision - 2:precision - 1 - exp_size] = exp_r;
    assign result[mantissa_size - 1:0] = mantissa_r;
    assign done = r_done;
    assign inv_op = r_inv_op;

endmodule