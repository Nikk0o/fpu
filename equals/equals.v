module equals(
              clk,
              reset,
              fp_a,
              fp_b,
              nan_exception,
              res,
              done
);

    parameter precision = 32;
    parameter exp_size = 8;
    parameter mantissa_size = 23;

    input clk;
    input reset;
    input [precision - 1:0] fp_a;
    input [precision - 1:0] fp_b;
    output res;
    output done;

    reg sign_a;
    reg sign_b;
    reg [exp_size - 1:0] exp_a;
    reg [exp_size - 1:0] exp_b;
    reg [mantissa_size - 1:0] mantissa_a;
    reg [mantissa_size - 1:0] mantissa_b;

    reg r_res;
    reg r_done;
    reg excep;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            r_done <= 0;
            r_res <= 0;
            excep <= 0;
        end
        else if (!done) begin
            sign_a = fp_a[precision - 1];
            sign_b = fp_b[precision - 1];
            exp_a = fp_a[precision - 2:precision - 1 - exp_size];
            exp_b = fp_b[precision - 2:precision - 1 - exp_size];
            mantissa_a = fp_a[mantissa_size - 1:0];
            mantissa_b = fp_b[mantissa_size - 1:0];

            if (mantissa_a == {mantissa_size{1'b0}} && mantissa_b == {mantissa_size{1'b0}}) begin
                r_res <= 1;
            end
            else if (mantissa_a == mantissa_b && sign_a == sign_b && exp_a == exp_b) begin
                r_res <= 1;
            end
            else begin
                r_res <= 0;
            end

            if (exp_a == {exp_size{1'b1}} && mantissa_a[mantissa_size - 1:mantissa_size -2] == 2'b01 || 
               exp_b == {exp_size{1'b1}} && mantissa_b[mantissa_size - 1:mantissa_size -2] == 2'b01) // ?
                excep <= 1;
            else 
                excep <= 0;
        
            r_done <= 1;
        end
    end

    assign res = r_res;
    assign done = r_done;
    assign nan_exception = excep;

endmodule