module double_to_float(
                       clk,
                       reset,
                       rounding,
                       double,
                       float);

    input clk, reset;
    input [1:0] rounding;
    input [63:0] double;
    output [31:0] float;

    reg [2:0] state;

    reg sign_64;
    reg [10:0] exp_64;
    reg [51:0] mantissa_64;

    reg sign_32;
    reg [7:0] exp_32;
    reg [22:0] mantissa_32;

    always @(posedge clk or negedge reset)
    begin
        if (!reset && !clk)
        begin
            state <= 3'b0;
        end
        else begin
            case (state)
                3'b0: begin: load_values
                    sign_64 <= double[63];
                    exp_64 <= double[62:52];
                    mantissa_64 <= double[51:0];
                end
                3'b1: 
            endcase
        end
    end
endmodule