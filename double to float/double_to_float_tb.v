`include "double_to_float.v"
`timescale 1ns/100ps

module tb;

    reg clk;
    wire [31:0] float;
    reg [63:0] double;
    reg reset = 1'b1;
    reg [1:0] round = 2'b10;
    wire done;

    reg state;

    wire nan_exception;
    wire underflow_exception;
    wire overflow_exception;

    integer op = 0;

    double_to_float dtf (
                       .clk(clk),
                       .reset(reset),
                       .rounding(round),
                       .overflow_exception(overflow_exception),
                       .underflow_exception(underflow_exception),
                       .nan_exception(nan_exception),
                       .double(double),
                       .float(float),
                       .done(done));

    

    initial begin
        state  = 0;
        clk = 0;
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        forever
        begin
            #10;
            clk = ~ clk;
            if (!state) begin
                // wait
                if (done) 
                    state <= 1;
            end
            else begin
                // reset
                if (done)
                    reset <= 0;
                else begin
                    if (op == 0) begin
                        double <= 64'b1111111111110000000000000000000000000000000000000000000000000000;
                    end
                    else if (op == 1) begin
                        double <= 64'b1111111111110100000000000000000000000000000000000000000000000000;
                    end
                    if (op == 2) begin
                        double <= 64'b1000011111110000000000011111111100000000000000000000000000000000;
                    end
                    else if (op == 3) begin
                        double <= 64'b1011011111110000000000011111111100000000000000000000000000000000;
                    end
                    if (op == 4) begin
                        double <= 64'b1100000000000000000000000000000000000000000000000000000000000100;
                    end
                    else if (op == 5) begin
                        double <= 64'b0100000010101101011010011100011100101011000000100000110001001010;
                    end
                    if (op == 6) begin
                    end
                    else if (op == 7) begin
                    end
                    if (op == 8) begin
                    end
                    else if (op == 9) begin
                    end
                    if (op == 10) begin
                    end
                    else if (op == 11) begin
                    end

                    if (op != 12) begin
                        op <= op + 1;
                    end
                    else
                        $finish;

                    reset <= 1;
                    state <= 0;
                end
            end
        end
    end 

endmodule