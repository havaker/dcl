const char* acceptable = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                         "123456789"
                         ":;?=<>@";
#include <stdlib.h>
#include <stdio.h>

int main(int argc, char **argv) {
    int n = 512;
    if (argc > 1)
        n = atoi(argv[1]);

    for (int i = 0; i < n; i++) {
        int r = rand() % 42;
        printf("%c", acceptable[r]);
    }
}
