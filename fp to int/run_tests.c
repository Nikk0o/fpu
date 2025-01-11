#include <stdio.h>
#include <stdlib.h>
#include <limits.h> // for INT_MAX
#include <stdint.h> 
#include <math.h> // for NAN

#include "../bin.h"

int create_test_file(FILE **tb)
{
    float in;
    uint32_t *p;
    int expected;
    int op = 0, op_max = 0;

    fprintf(*tb, "\
`include \"float_to_int.v\"\n \
`timescale 1ns/100ps\n \
\
module tb;\n \
\
    reg clk;\n  \
    reg [31:0] float;\n \
    reg  [31:0] expected;\n \
    reg reset = 1'b1;\n \
    wire done;\n \
    wire [31:0] int;\n\
    reg [1:0] conv;\n\
    wire invalid_flag;\n\
\
    reg state;\n \
\
    wire nan_exception;\n \
\
    integer op = 0;\n \
\
    floating_point_to_int #(.int_size(32)) fti\
                    (.clk(clk),\n \
                    .reset(reset),\n \
                    .invalid_op_flag(invalid_flag),\n \
                    .float(float),\n \
                    .conv(conv),\n\
                    .done(done),\n \
                    .int(int));\n\
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
        remove("tb.v");
        fclose(*tb);
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
        scanf(" %f", &in);
        p = (uint32_t *) &in;
        expected = (int) in;
        fprintf(*tb, "\t\t\t\t\t\t float = 32'b" str_32bit_binary ";\n", int_seq_32bit(*p));
        fprintf(*tb, "\t\t\t\t\t\t expected = 32'b" str_32bit_binary ";\n", int_seq_32bit(expected));
        

        fprintf(*tb, "\t\t\t\t\tend\n \
                         \t\t\t\t\telse if (op == %d) begin\n", op + 1);

        op++;
    }

    in = NAN;
    p = (uint32_t *) &in;
    expected = (int) in;
    fprintf(*tb, "\t\t\t\t\t\t float = 32'b" str_32bit_binary ";\n", int_seq_32bit(*p));
    fprintf(*tb, "\t\t\t\t\t\t expected = 32'b" str_32bit_binary ";\n", int_seq_32bit(expected));
    fprintf(*tb, "\t\t\t\t\tend\n \
\t\t\t\t\telse if (op == %d) begin\n", op + 1);
    op++;
    *p = 0b01111111101000000000000000000000;
    expected = (int) in;
    fprintf(*tb, "\t\t\t\t\t\t float = 32'b" str_32bit_binary ";\n", int_seq_32bit(*p));
    fprintf(*tb, "\t\t\t\t\t\t expected = 32'b" str_32bit_binary ";\n", int_seq_32bit(expected));
    fprintf(*tb, "\t\t\t\t\tend\n \
\t\t\t\t\telse if (op == %d) begin\n", op + 1);
    op++;
    in = INFINITY;
    expected = ((int) in);
    fprintf(*tb, "\t\t\t\t\t\t float = 32'b" str_32bit_binary ";\n", int_seq_32bit(*p));
    fprintf(*tb, "\t\t\t\t\t\t expected = 32'b" str_32bit_binary ";\n", int_seq_32bit(expected));
    fprintf(*tb, "\t\t\t\t\tend\n \
\t\t\t\t\telse if (op == %d) begin\n", op + 1);
    op++;
    in = -INFINITY;
    expected = ((int) in);
    fprintf(*tb, "\t\t\t\t\t\t float = 32'b" str_32bit_binary ";\n", int_seq_32bit(*p));
    fprintf(*tb, "\t\t\t\t\t\t expected = 32'b" str_32bit_binary ";\n", int_seq_32bit(expected));
    fprintf(*tb, "\t\t\t\t\tend\n", op + 1);

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

    // create vvp file
    if ((status = system("iverilog -o a.vvp tb.v")) != 0)
    {
        perror("Error generating vvp file.\n");
        return status;
    }

    if ((status = system("vvp a.vvp")) != 0)
    {
        return status;
    }

    return 0;
}