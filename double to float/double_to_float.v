module double_to_float(
                       clk,
                       reset,
                       rounding,
                       overflow_exception,
                       underflow_exception,
                       nan_exception,
                       double,
                       done,
                       float);

    input clk, reset;
    input [1:0] rounding;
    input [63:0] double;
    output [31:0] float;
    output done;
    output nan_exception;
    output overflow_exception;
    output underflow_exception;

    reg [1:0] state;

    reg sign_64;
    reg [10:0] exp_64;
    reg [51:0] mantissa_64;

    reg sign_32;
    reg [7:0] exp_32;
    reg [22:0] mantissa_32;

    reg r_done;
    reg [28:0] frac;
    reg [23:0] mantissa_32_;
    reg [11:0] exp_32_;

    reg r_overflow_exception;
    reg r_underflow_exception;
    reg r_nan_exception;

    initial begin
        state <= 2'b0;
        r_done <= 0;
        r_overflow_exception <= 0;
        r_underflow_exception <= 0;
        r_nan_exception <= 0;
    end

    always @(posedge clk or negedge reset)
    begin
        if (!reset)
        begin
            state <= 2'b0;
            r_done <= 0;
        end
        else begin
            case (state)
                2'b0: begin: load_values
                    sign_64 <= double[63];
                    exp_64 <= double[62:52];
                    mantissa_64 <= double[51:0];

                    state <= 2'b1;
                end
                2'b1: begin: check_value
                    if (exp_64 == 11'b11111111111 && mantissa_64[51:50] == 2'b01) begin         
                    // sNaN
                        sign_32 <= sign_64;
                        exp_32 <= 8'b11111111;
                        mantissa_32[22:21] <= 2'b10;
                        mantissa_32[20:0] <= mantissa_64[49:29];

                        r_nan_exception <= 1;
                        r_overflow_exception <= 0;
                        r_underflow_exception <= 0;
                        state <= 2'b11;
                        r_done <= 1;
                    end
                    else if (exp_64 == 11'b11111111111 && mantissa_64[51] == 1'b1) begin
                    // qNaN
                        sign_32 <= sign_64;
                        exp_32 <= 8'b11111111;
                        mantissa_32 <= mantissa_64[51:29];

                        r_nan_exception <= 0;
                        r_overflow_exception <= 0;
                        r_underflow_exception <= 0;
                        state <= 2'b11;
                        r_done <= 1;
                    end
                    else if (exp_64 == 11'b11111111111 && mantissa_64 == 52'b0) begin
                    // inf
                        // returns inf
                        sign_32 <= sign_64;
                        exp_32 <= 8'b11111111;
                        mantissa_32 <= 23'b0;

                        r_nan_exception <= 0;
                        r_overflow_exception <= 0;
                        r_underflow_exception <= 0;

                        state <= 2'b11;
                        r_done <= 1;
                    end
                    else if (exp_64 >= 11'b10000000000 && exp_64 > 8'b11111110 + 11'b10000000000) begin
                    // overflow
                        // returns inf
                        sign_32 <= sign_64;
                        exp_32 <= 8'b11111111;
                        mantissa_32 <= 23'b0;
                        
                        r_overflow_exception <= 1;
                        r_nan_exception <= 0;
                        r_underflow_exception <= 0;

                        state <= 2'b11;
                        r_done <= 1;
                    end   
                    else if (exp_64 < 11'b01110000000) begin
                    // underflow i guess?
                        r_overflow_exception <= 0;
                        r_nan_exception <= 0;
                        r_underflow_exception <= 1;

                        state <= 2'b10;
                    end     
                    else begin
                        r_underflow_exception <= 0;
                        r_overflow_exception <= 0;
                        r_nan_exception <= 0;

                        state <= 2'b10;
                    end    
                end
                2'b10: begin: round_to_0
                    sign_32 <= sign_64;
                    exp_32 <= exp_64[6:0];
                    exp_32[7] <= (exp_64[10] == 1'b1) ? 1'b1 : 1'b0;
                    mantissa_32 = mantissa_64[51:29];

                    frac = mantissa_64[28:0];

                    if (mantissa_32 == 23'b0 && frac != 29'b0) begin
                        r_underflow_exception <= 1;
                    end
                    else
                        r_underflow_exception <= 0;

                    state <= 2'b11;
                end
                2'b11: begin: apply_rounding
                    if (! done)
                        case (rounding)
                            2'b0: begin: round_to_0
                                r_done <= 1;
                            end
                            2'b1: begin: round_to_posinf
                                if (~ sign_32)
                                    // only do this if the number is positive. otherwise the rounding is the same as rounding to 0
                                    if (frac[28] == 1'b1 && frac[27:0] != 28'b0) begin
                                        mantissa_32_ = mantissa_32 + 1'b1;

                                        if (mantissa_32_[23] == 1'b1) begin
                                            // the rounded mantissa goes 1 bit to the left, so we have to change the exponent
                                            exp_32_ = exp_64[7:0] + 1'b1;
                                            if (exp_32_[11] == 1'b1) begin // overflow. infinity. Check how to handle this properly in the IEEE 754
                                                sign_32 <= sign_64;
                                                mantissa_32 <= 23'b0;
                                                exp_32 <= 8'b11111111;

                                                r_overflow_exception <= 1;
                                            end
                                            else begin
                                                sign_32 <= sign_64;
                                                exp_32 <= exp_32_[7:0] + (exp_64[10] == 1'b1) ? 8'b10000000 : 1'b0;
                                                mantissa_32 <= mantissa_32_[23:1];
                                            end
                                        end
                                        else begin
                                            // mantissa is still 23 bits
                                            sign_32 <= sign_64;
                                            exp_32 <= exp_64[7:0] + (exp_64[10] == 1'b1) ? 8'b10000000 : 1'b0;
                                            mantissa_32 <= mantissa_32_[22:0];
                                        end
                                    end

                                r_done <= 1;
                            end
                            2'b10: begin: round_to_neginf
                                if (sign_32)
                                    // do the same thing as the round_to_posinf with the positive number
                                    if (frac[28] == 1'b1 && frac[27:0] != 28'b0) begin
                                        mantissa_32_ = mantissa_32 + 1'b1;

                                        if (mantissa_32_[23] == 1'b1) begin
                                            exp_32_ = exp_64[7:0] + 1'b1;
                                            if (exp_32_[11] == 1'b1) begin
                                                sign_32 <= sign_64;
                                                mantissa_32 <= 23'b0;
                                                exp_32 <= 8'b11111111;

                                                r_overflow_exception <= 1;
                                            end
                                            else begin
                                                sign_32 <= sign_64;
                                                exp_32 <= exp_32_[7:0] + (exp_64[10] == 1'b1) ? 8'b10000000 : 1'b0;
                                                mantissa_32 <= mantissa_32_[23:1];
                                            end
                                        end
                                        else begin
                                            sign_32 <= sign_64;
                                            exp_32 <= exp_64[7:0] + (exp_64[10] == 1'b1) ? 8'b10000000 : 1'b0;
                                            mantissa_32 <= mantissa_32_[22:0];
                                        end
                                    end

                                r_done <= 1;
                            end
                            2'b11: begin: round_to_closest
                                if (sign_32)
                                    // round to posinf or to 0
                                    if (frac[28] == 1'b1 && frac[27:0] != 28'b0) begin
                                        mantissa_32_ = mantissa_32 + 1'b1;

                                        if (mantissa_32_[23] == 1'b1) begin
                                            exp_32_ = exp_64[7:0] + 1'b1;
                                            if (exp_32_[11] == 1'b1) begin
                                                sign_32 <= sign_64;
                                                mantissa_32 <= 23'b0;
                                                exp_32 <= 8'b11111111;

                                                r_overflow_exception <= 1;
                                            end
                                            else begin
                                                sign_32 <= sign_64;
                                                exp_32 <= exp_32_[7:0] + (exp_64[10] == 1'b1) ? 8'b10000000 : 1'b0;
                                                mantissa_32 <= mantissa_32_[23:1];
                                            end
                                        end
                                        else begin
                                            sign_32 <= sign_64;
                                            exp_32 <= exp_64[7:0] + (exp_64[10] == 1'b1) ? 8'b10000000 : 1'b0;
                                            mantissa_32 <= mantissa_32_[22:0];
                                        end
                                    end
                                else
                                    // round to neginf or to 0
                                    if (frac[28] == 1'b1 && frac[27:0] != 28'b0) begin
                                        mantissa_32_ = mantissa_32 + 1'b1;

                                        if (mantissa_32_[23] == 1'b1) begin
                                            exp_32_ = exp_64[7:0] + 1'b1;
                                            if (exp_32_[11] == 1'b1) begin
                                                sign_32 <= sign_64;
                                                mantissa_32 <= 23'b0;
                                                exp_32 <= 8'b11111111;

                                                r_overflow_exception <= 1;
                                            end
                                            else begin
                                                sign_32 <= sign_64;
                                                exp_32 <= exp_32_[7:0] + (exp_64[10] == 1'b1) ? 8'b10000000 : 1'b0;
                                                mantissa_32 <= mantissa_32_[23:1];
                                            end
                                        end
                                        else begin
                                            sign_32 <= sign_64;
                                            exp_32 <= exp_64[7:0] + (exp_64[10] == 1'b1) ? 8'b10000000 : 1'b0;
                                            mantissa_32 <= mantissa_32_[22:0];
                                        end
                                    end
                                r_done <= 1;
                            end
                        endcase
                end
            endcase
        end
    end

    assign float[31] = sign_32;
    assign float[30:23] = exp_32;
    assign float[22:0] = mantissa_32;

    assign done = r_done;

    assign nan_exception = r_nan_exception;
    assign overflow_exception = r_overflow_exception;
    assign underflow_exception = r_underflow_exception;

endmodule