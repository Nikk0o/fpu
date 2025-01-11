#include <stdio.h>
#include <stdlib.h>
#include <limits.h> // for INT_MAX
#include <stdint.h> 
#include <math.h> // for NAN

#include "../bin.h"

int create_test_file(FILE **tb)
{
    int in;
    float expected;
    uint32_t *p;
    int op = 0, op_max = 0;

    fprintf(*tb, "\
`include \"int_to_fp.v\"\n \
`timescale 1ns/100ps\n \
\
module tb;\n \
\
    reg clk;\n  \
    wire [31:0] float;\n \
    reg  [31:0] expected;\n \
    reg reset = 1'b1;\n \
    reg [31:0] int;\n\
\
    wire done;\n\
\
    reg state;\n \
\
    wire nan_exception;\n \
\
    integer op = 0;\n \
\
    int_to_fp #(.int_size(32)) itf\
                    (.clk(clk),\n \
                    .reset(reset),\n \
                    .fp(float),\n \
                    .int(int),\n\
                    .done(done));\n\
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

    while (op < INT_MAX && op < op_max)
    {
        printf("Type an integer:\n");
        scanf(" %d", &in);
        expected = (float) in;
        p = (uint32_t *) &expected;
        fprintf(*tb, "\t\t\t\t\t\t int = 32'b" str_32bit_binary ";\n", int_seq_32bit(in));
        fprintf(*tb, "\t\t\t\t\t\t expected = 32'b" str_32bit_binary ";\n", int_seq_32bit(*p));
        

        if (op != op_max - 1)
            fprintf(*tb, "\t\t\t\t\tend\n \
                         \t\t\t\t\telse if (op == %d) begin\n", op + 1);
        else
            fprintf(*tb, "\t\t\t\t\tend\n");

        op++;
    }

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