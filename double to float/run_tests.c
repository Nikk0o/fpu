#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    FILE *tb = fopen("tb.v", "w");
    if (tb == NULL) 
    {
        perror("Unable to create testbench file.\n");
        return 1;
    }

    return 0;
}