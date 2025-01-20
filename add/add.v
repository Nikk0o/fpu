module adder(
             clk,
             reset,
             fp_a,
             fp_b,
             round,
             result,
             invalid_op,
             add_sub,
             done
);

    parameter precision = 32;
    parameter exp_size = 8;
    parameter mantissa_size = 23;

    parameter exp_bias = {exp_size - 1{1'b1}};

    input clk;
    input reset;
    input add_sub;
    input [precision - 1:0] fp_a;
    input [precision - 1:0] fp_b;
    output [precision - 1:0] result;
    output invalid_op;
    output done;
    input [1:0] round;

    reg sign_a;
    reg sign_b;
    reg signed [exp_size - 1:0] exp_a;
    reg signed [exp_size - 1:0] exp_b;
    reg [mantissa_size:0] mantissa_a;
    reg [mantissa_size:0] mantissa_b;

    reg sign_add;
    reg [exp_size - 1:0] exp_add;
    reg [mantissa_size + 1:0] mantissa_add;

    reg sign_r;
    reg [exp_size - 1:0] exp_r;
    reg [mantissa_size - 1:0] mantissa_r;

    reg [1:0] state;

    reg [precision - 1:0] frac;

    reg r_done;
    reg r_inv_op;

    initial begin
        r_done = 0;
        state = 2'b0;
    end

    integer index;
    integer shift;

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
                    sign_b <= fp_b[precision - 1] ^ add_sub;

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
                    if (fp_a[precision - 2:precision - 1 - exp_size] == {precision{1'b1}} && fp_a[mantissa_size - 1:mantissa_size - 2] == 2'b01 ||
                        fp_b[precision - 2:precision - 1 - exp_size] == {precision{1'b1}} && fp_b[mantissa_size - 1:mantissa_size - 2] == 2'b01) begin
                        // sNaN
                        sign_add <= 0;
                        exp_add <= {exp_size{1'b1}};
                        mantissa_add[mantissa_size - 1:mantissa_size - 2] <= 2'b10;
                        mantissa_add[mantissa_size - 3:0] <= {mantissa_size - 2{1'b0}};

                        r_done <= 1;
                        r_inv_op <= 1;
                    end
                    else if (fp_a[precision - 2:precision - 1 - exp_size] == {precision{1'b1}} && fp_a[mantissa_size - 1:mantissa_size - 2] == 2'b10 ||
                        fp_b[precision - 2:precision - 1 - exp_size] == {precision{1'b1}} && fp_b[mantissa_size - 1:mantissa_size - 2] == 2'b10) begin
                        // qNaN

                        sign_add <= 0;
                        exp_add <= {exp_size{1'b1}};
                        mantissa_add[mantissa_size - 1:mantissa_size - 2] <= 2'b10;
                        mantissa_add[mantissa_size - 3:0] <= {mantissa_size - 2{1'b0}};

                        r_done <= 1;
                        r_inv_op <= 0;
                    end
                    else if (fp_a[precision - 2:precision - 1 - exp_size] == {precision{1'b1}} && fp_a[mantissa_size - 1:0] == {mantissa_size{1'b0}} &&
                             fp_b[precision - 2:precision - 1 - exp_size] == {precision{1'b1}} && fp_b[mantissa_size - 1:0] == {mantissa_size{1'b0}} &&
                             sign_a ^ (sign_b ^  add_sub)) begin
                        // inf - inf

                        sign_add <= 0;
                        exp_add <= {exp_size{1'b1}};
                        mantissa_add[mantissa_size - 1:mantissa_size - 2] <= 2'b10;
                        mantissa_add[mantissa_size - 3:0] <= {mantissa_size - 2{1'b0}};

                        r_done <= 1;
                        r_inv_op <= 1;
                    end
                    else begin
                        r_done <= 0;
                        r_inv_op <= 0;
                    end

                    state <= 2'b10;
                end
                2'b10: begin: add
                    if (!r_done) begin
                        if (exp_a > exp_b) begin
                            // shift b to the size of a
                            for (index = 0; index < precision && index <= exp_a - exp_b; index = index + 1)
                                frac[precision - 1 - index] <= mantissa_b[index];

                            mantissa_b = mantissa_b >> exp_a - exp_b;
                            exp_add = exp_a + exp_bias;
                        end
                        else if (exp_a < exp_b) begin
                            // shift a to the size of b
                            for (index = 0; index < precision && index <= exp_a - exp_b; index = index + 1)
                                frac[precision - 1 - index] <= mantissa_b[index];

                            mantissa_a = mantissa_a >> exp_b - exp_a;
                            exp_add = exp_b + exp_bias;
                        end
                        else begin
                            frac <= {precision{1'b0}};
                            exp_add = exp_a + exp_bias;
                        end
                        
                        // add
                        if (sign_a == sign_b) begin
                            mantissa_add = mantissa_a + mantissa_b;
                            if (mantissa_add[mantissa_size + 1:mantissa_size] > 2'b01) begin
                                exp_add <= exp_add + 1;
                                mantissa_add <= mantissa_add >> 1;
                            end
                        end
                        else begin

                            if (mantissa_a >= mantissa_b)
                                mantissa_add = mantissa_a - mantissa_b;
                            else
                                mantissa_add = mantissa_b - mantissa_a;

                            if (sign_a && mantissa_a > mantissa_b) begin // abs(a) > abs(b) && a < 0 && b > 0 => result < 0
                                mantissa_add = mantissa_a - mantissa_b;
                                sign_add <= 1;
                            end
                            else if (sign_b && mantissa_b > mantissa_a) begin // abs(b) > abs(a) && b < 0 && a > 0 => result < 0
                                mantissa_add = mantissa_b - mantissa_a;
                                sign_add <= 1;
                            end
                            else if (sign_a && mantissa_b > mantissa_a) begin // abs(a) < abs(b) && a < 0 && b > 0 => result > 0
                                mantissa_add = mantissa_b - mantissa_a;
                                sign_add <= 0;
                            end
                            else if (sign_b && mantissa_a > mantissa_b) begin // abs(b) < abs(a) && b < 0 && a > 0 => result > 0
                                mantissa_add = mantissa_a - mantissa_b;
                                sign_add <= 0;
                            end
                            else begin // abs(a) == abs(b) => result = 0
                                mantissa_add = {mantissa_size + 2{1'b0}};
                                sign_add <= 0;
                            end

                            // idk if i have to change the exponent too, probably

                            for (index = 0; index <= mantissa_size + 1; index = index + 1)
                                if (mantissa_add[index] == 1'b1)
                                    shift = index;

                            if (shift < mantissa_size) begin // normalize the number
                                // this is probably wrong
                                mantissa_add <= mantissa_add << mantissa_size - shift;
                                exp_add <= exp_add + (mantissa_size - shift);
                            end
                        end
                    end
                    
                    state <= 2'b11;
                end
                2'b11: begin: rounding
                    if (!r_done) begin
                        case (round)
                            2'b00: begin: round_to_neginf
                                if (sign_add && frac[precision - 1] == 1'b1 && frac[precision - 2:0] != {precision - 1{1'b0}})
                                    mantissa_add = mantissa_add + 1'b1;
                                    // change the exponent too
                            end
                            2'b01: begin: round_to_posinf
                                if (!sign_add && frac[precision - 1] == 1'b1 && frac[precision - 2:0] != {precision - 1{1'b0}})
                                    mantissa_add = mantissa_add + 1'b1;
                            end
                            2'b10: begin: round_to_0
                            end
                            2'b11: begin: round_to_closest
                                if (sign_add && frac[precision - 1] == 1'b1 && frac[precision - 2:0] != {precision - 1{1'b0}})
                                    mantissa_add = mantissa_add + 1'b1;
                                else if (!sign_add && frac[precision - 1] == 1'b1 && frac[precision - 2:0] != {precision - 1{1'b0}})
                                    mantissa_add = mantissa_add + 1'b1;
                            end
                        endcase

                        sign_r <= sign_add;
                        exp_r <= exp_add;
                        mantissa_r <= mantissa_add[mantissa_size - 1:0];
                        r_done <= 1;
                    end
                end
            endcase
        end
    end

    assign done = r_done;
    assign inv_op = r_inv_op;
    assign result[precision - 1] = sign_r;
    assign result[precision - 2:precision - 1 - exp_size] = exp_r;
    assign result[mantissa_size - 1:0] = mantissa_r;

endmodule