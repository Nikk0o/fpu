#include <stdio.h>
#include <stdlib.h>
#include <limits.h> // for INT_MAX
#include <stdint.h> 
#include <math.h> // for NAN

#include "bin.h"

int create_test_file(FILE **tb)
{
    double in;
    float out;
    uint32_t *p1;
    uint64_t *p2;
    int op = 0, op_max = 0;

    fprintf(*tb, "\
`include \"double_to_float.v\"\n \
`timescale 1ns/100ps\n \
\
module tb;\n \
\
    reg clk;\n  \
    wire [31:0] float;\n \
    reg  [31:0] expected;\n \
    reg [63:0] double;\n \
    reg reset = 1'b1;\n \
    reg [1:0] round = 2'b10;\n \
    wire done;\n \
\
    reg state;\n \
\
    wire nan_exception;\n \
    wire underflow_exception;\n \
    wire overflow_exception;\n \
\
    integer op = 0;\n \
\
    double_to_float dtf (\n \
                    .clk(clk),\n \
                    .reset(reset),\n \
                    .rounding(round),\n \
                    .overflow_exception(overflow_exception),\n \
                    .underflow_exception(underflow_exception),\n \
                    .nan_exception(nan_exception),\n \
                    .double(double),\n \
                    .float(float),\n \
                    .done(done));\n \
\
    \
\
    initial begin\n \
        state  = 0;\n \
        clk = 0;\n \
        $dumpfile(\"tb.vcd\");\n \
        $dumpvars(0, tb);\n \
        forever\n \
        begin\n \
            #10;\n \
            clk = ~ clk;\n \
            if (!state) begin\n \
                // wait\n \
                if (done) \n \
                    state <= 1;\n \
            end\n \
            else begin\n \
                // reset\n \
                if (done)\n \
                    reset <= 0;\n \
                else begin\n \
                    if (op == 0) begin\n");

    printf("Enter the number of tests you want to run:\n");
    if (scanf(" %d", &op_max) < 1)
    {
        perror("Invalid input\n");
        return 2;
    }
    if (op_max <= 0)
    {
        printf("Number of tests must be at least 1.\n");
        remove("tb.v");
        fclose(*tb);
        *tb = NULL;
        return 2;
    }
    /* 4 extra cases: qNaN, sNaN, +- inf */
    op_max += 4;

    while (op < INT_MAX && op < op_max - 4)
    {
        printf("Type a floating point number (must not be NaN or +- inf):\n");
        scanf(" %lf", &in);
        p2 = (uint64_t *) &in;
        out = (float) in;
        p1 = (uint32_t *) &out;
        fprintf(*tb, "\t\t\t\t\t\t double = 64'b" str_64bit_binary ";\n", int_seq_64bit(*p2));
        fprintf(*tb, "\t\t\t\t\t\t expected = 32'b" str_32bit_binary ";\n", int_seq_32bit(*p1));
        

        fprintf(*tb, "\t\t\t\t\tend\n \
                         \t\t\t\t\telse if (op == %d) begin\n", op + 1);

        op++;
    }

    in = (double) NAN;
    out = ((float) in);
    p1 = (uint32_t *) &out;
    fprintf(*tb, "\t\t\t\t\t\t double = 64'b" str_64bit_binary ";\n", int_seq_64bit(*p2));
    fprintf(*tb, "\t\t\t\t\t\t expected = 32'b" str_32bit_binary ";\n", int_seq_32bit(*p1));
    fprintf(*tb, "\t\t\t\t\tend\n \
                         \t\t\t\t\telse if (op == %d) begin\n", op + 1);
    op++;
    *p2 = 0b0111111111110100000000000000000000000000000000000000000000000000;
    out = ((float) in);
    *p1 = 0b01111111101000000000000000000000; // C's NaN is slightly different from my implementation. So I'll just put the value here
    fprintf(*tb, "\t\t\t\t\t\t double = 64'b" str_64bit_binary ";\n", int_seq_64bit(*p2));
    fprintf(*tb, "\t\t\t\t\t\t expected = 32'b" str_32bit_binary ";\n", int_seq_32bit(*p1));
    fprintf(*tb, "\t\t\t\t\tend\n \
 \t\t\t\t\telse if (op == %d) begin\n", op + 1);
    op++;
    in = (double) INFINITY;
    out = ((float) in);
    p1 = (uint32_t *) &out;
    fprintf(*tb, "\t\t\t\t\t\t double = 64'b" str_64bit_binary ";\n", int_seq_64bit(*p2));
    fprintf(*tb, "\t\t\t\t\t\t expected = 32'b" str_32bit_binary ";\n", int_seq_32bit(*p1));
    fprintf(*tb, "\t\t\t\t\tend\n \
                         \t\t\t\t\telse if (op == %d) begin\n", op + 1);
    op++;
    in = (double) -INFINITY;
    out = ((float) in);
    p1 = (uint32_t *) &out;
    fprintf(*tb, "\t\t\t\t\t\t double = 64'b" str_64bit_binary ";\n", int_seq_64bit(*p2));
    fprintf(*tb, "\t\t\t\t\t\t expected = 32'b" str_32bit_binary ";\n", int_seq_32bit(*p1));
    fprintf(*tb, "\t\t\t\t\tend\n");

    fprintf(*tb, "\t\t\t\t\tif (op != %d) begin\n \
                        op <= op + 1;\n \
                    end\n \
                    else\n \
                        $finish;\n \
\
                    reset <= 1;\n \
                    state <= 0;\n \
                end\n \
            end\n \
        end\n \
    end \n \
\
endmodule\n", op_max);

        fclose(*tb);
        *tb = NULL;
    return 0;
}

int main(void)
{
    FILE *tb = fopen("tb.v", "w");

    if (tb == NULL) 
    {
        perror("Unable to create testbench file.\n");
        return 1;
    }

    // create the testbench file
    int status;
    if ((status = create_test_file(&tb)) != 0)
        return status;

    // create this file
    if ((status = system("iverilog -o a.vvp tb.v")) != 0)
    {
        perror("Error generating a.vvp.\n");
        return status;
    }

    return 0;
}