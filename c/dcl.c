#include <unistd.h>
#include <stdlib.h>

#define INTERNAL // static inline

#define NCHARS 42
#define BUFSIZE 4096

char buf[BUFSIZE]; // 4KB

char *L, *R, *T;
char Li[NCHARS], Ri[NCHARS], Ti[NCHARS];
int l, r;

INTERNAL
char squeeze(char c) {
    if (c >= '1' && c <= 'Z')
        return c - '1';
    exit(1);
}

INTERNAL
char unsqueeze(char c) {
    return c + '1';
}

INTERNAL
void squeeze_buf(char* buf, int count) {
    for (int i = 0; i < count; i++) {
        buf[i] = squeeze(buf[i]);
    }

    if (buf[count] != 0)
        exit(1);
}

INTERNAL
void unsqueeze_buf(char* buf, int count) {
    for (int i = 0; i < count; i++) {
        buf[i] = unsqueeze(buf[i]);
    }
}

INTERNAL
void inverse_buf(char* dest, const char* src, int count) {
    for (int i = 0; i < count; i++) {
        unsigned char c = src[i];
        if (dest[c] != 0)
            exit(1);
        dest[c] = i + 1;
    }

    for (int i = 0; i < count; i++)
        dest[i] -= 1;
}

INTERNAL
void load_lr(char* buf) {
    l = buf[0];
    r = buf[1];
}

INTERNAL
void show(char* buf, size_t count) {
    while (count > 0) {
        ssize_t e = write(1, buf, count);

        if (e < 0)
            exit(1);

        count -= e;
        buf += e;
    }
}

INTERNAL
unsigned char Q(int i, unsigned char c) {
    return (c + i) % NCHARS;
}

INTERNAL
unsigned char Qi(int i, unsigned char c) {
    return (NCHARS + c - i) % NCHARS;
}

INTERNAL
unsigned char permutate(unsigned char c) {
    c = Q(r, c);
    c = R[c];
    c = Qi(r, c);

    c = Q(l, c);
    c = L[c];
    c = Qi(l, c);

    c = T[c];

    c = Q(l, c);
    c = Li[c];
    c = Qi(l, c);

    c = Q(r, c);
    c = Ri[c];
    c = Qi(r, c);

    return c;
}

INTERNAL
void update_lr() {
    r = Q(1, r);
    if (r == squeeze('L') || r == squeeze('R') || r == squeeze('T'))
        l = Q(1, l);
}

INTERNAL
void process(char* buf, size_t count) {
    for (int i = 0; i < count; i++) {
        update_lr();
        buf[i] = unsqueeze(permutate(squeeze(buf[i])));
    }
}

INTERNAL
ssize_t loop() {
    for (;;) {
        ssize_t count = read(0, buf, sizeof(buf));

        if (count > 0) {
            process(buf, count);
            show(buf, count);
        } else if (count == 0) {
            return 0;
        } else {
            return -1;
        }
    }
}

int main(int argc, char **argv) {
    if (argc != 5)
        return -1;

    squeeze_buf(argv[1], NCHARS);
    squeeze_buf(argv[2], NCHARS);
    squeeze_buf(argv[3], NCHARS);

    squeeze_buf(argv[4], 2);
    load_lr(argv[4]);

    L = argv[1];
    R = argv[2];
    T = argv[3];

    inverse_buf(Li, L, NCHARS);
    inverse_buf(Ri, R, NCHARS);
    inverse_buf(Ti, T, NCHARS);

    return loop();
}

