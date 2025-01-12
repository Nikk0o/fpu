module float_to_double(
                       clk,
                       reset,
                       double,
                       float,
                       done,
                       nan_exception);

    parameter exp_bias_32 = 8'b01111111;
    parameter exp_bias_64 = 11'b01111111111;

    reg sign_32;
    reg signed [7:0] exp_32;
    reg [22:0] mantissa_32;

    reg sign_64;
    reg signed [10:0] exp_64;
    reg [51:0] mantissa_64;

    reg r_nan_exception;

    reg [1:0] state;
    reg r_done;
    input clk;
    input reset;
    input [31:0] float;
    output [63:0] double;
    output done;
    output nan_exception;

    initial begin
        mantissa_64 <= 52'b0;
        exp_64 <= 11'b0;
        sign_64 <= 0;
        state <= 2'b0;
        r_nan_exception <= 0;
        r_done <= 0;
    end


    always @(posedge clk or negedge reset)
    begin
        if (!reset) begin
            state <= 2'b0;
            r_nan_exception <= 0;
            r_done <= 0;
        end
        else begin
            case (state)
                2'b0: begin: load_values
                    sign_32 <= float[31];
                    exp_32 <= float[30:23];
                    mantissa_32 <= float[22:0];

                    state <= 2'b1;
                end
                2'b1: begin: check_value
                    if (exp_32 == 8'b11111111 && mantissa_32[22:21] == 2'b01) begin
                    // sNaN
                        sign_64 <= sign_32;
                        exp_64 <= 11'b11111111111;
                        mantissa_64[51:50] <= 2'b10; // converts the signaling nan into a quiet nan
                        mantissa_64[49:29] <= mantissa_32[20:0];
                        mantissa_64[28:0] <= 29'b0;
                        r_nan_exception <= 1;
                        r_done <= 1;
                        state <= 2'b11;
                    end
                    else if (exp_32 == 8'b11111111 && mantissa_32[22] == 1'b1) begin
                    // qNaN
                        sign_64 <= sign_32;
                        exp_64 <= 11'b11111111111;
                        mantissa_64[51:29] <= mantissa_32;
                        mantissa_64[28:0] <= 29'b0;
                        r_nan_exception <= 0;
                        r_done <= 1;
                        state <= 2'b11;
                    end
                    else if (exp_32 == 8'b11111111 && mantissa_32 == 23'b0) begin
                    // inf
                        sign_64 <= sign_32;
                        exp_64 <= 11'b11111111111;
                        mantissa_64 <= 52'b0;
                        r_nan_exception <= 0;
                        r_done <= 1;
                        state <= 2'b11;
                    end
                    else
                        state <= 2'b10;
                end
                2'b10: begin: conversion
                    sign_64 <= sign_32;
                    if (exp_32 >= exp_bias_32)
                        exp_64 <= exp_32 - exp_bias_32 + exp_bias_64;
                    else begin
                        exp_64 <= exp_32 + 11'b01110000000;
                    end
                    
                    mantissa_64[51:29] <= mantissa_32;
                    mantissa_64[28:0] <= 29'b0;

                    r_done <= 1;
                end
            endcase
        end    
    end

    assign double[63] = sign_64;
    assign double[62:52] = exp_64;
    assign double[51:0] = mantissa_64;
    assign nan_exception = r_nan_exception;

    assign done = r_done;

endmodule