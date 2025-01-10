module float_to_double(
                       clk,
                       reset,
                       double,
                       float,
                       nan_exception);

    reg sign_32;
    reg [7:0] exp_32;
    reg [22:0] mantissa_32;

    reg sign_64;
    reg [10:0] exp_64;
    reg [51:0] mantissa_64;

    reg [1:0] state;

    always @(posedge clk or negedge reset)
    begin
        if (!reset) begin
        end
        else begin
            case (state)
                2'b0: begin: load_values
                    sign_32 <= float[31];
                    exp_32 <= float[30:23];
                    mantissa_32 <= float[22:0];
                end
                2'b1: begin: check_value
                    if (exp_32 == 8'b11111111 && mantissa_32[22:21] == 2'b01) begin
                    // sNaN
                        sign_64 <= sign_32;
                        exp_64 <= 11'b11111111111;
                        mantissa_64[51:50] <= 2'b10; // converts the signaling nan into a quiet nan
                        mantissa_64[49:29] <= mantissa_32[20:0];
                        mantissa_64[28:0] <= 29'b0;
                        nan_exception <= 1;
                    end
                    else if (exp_32 == 8'b11111111 && mantissa_32[22] == 1'b1) begin
                    // qNaN
                        sign_64 <= sign_32;
                        exp_64 <= 11'b11111111111;
                        mantissa_64[51:29] <= mantissa_32;
                        mantissa_64[28:0] <= 29'b0;
                    end
                end
            endcase
        end    
    end

endmodule