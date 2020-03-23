#include <unistd.h>
#include <stdlib.h>

#define N 42

char buf[256];

char *L, *R, *T;
char Li[N], Ri[N], Ti[N];
int l, r;

char squeeze(char c) {
    if (c >= 49 && c <= 90)
        return c - 49;
    if (c >= 97 && c <= 122 )
        return c - 97 + 49;

    exit(1);
}

char unsqueeze(char c) {
    if (c <= 90 - 49)
        return c + 49;
    else
        return c + 97 - 49;
}

void squeeze_buf(char* buf, int count) {
    for (int i = 0; i < count; i++) {
        buf[i] = squeeze(buf[i]);
    }

    if (buf[count] != 0)
        exit(1);
}

void unsqueeze_buf(char* buf, int count) {
    for (int i = 0; i < count; i++) {
        buf[i] = unsqueeze(buf[i]);
    }
}

void inverse_buf(char* dest, const char* src) {
    for (int i = 0; i < N; i++) {
        char c = src[i];
        if (dest[c] != 0)
            exit(1);
        dest[c] = i + 1;
    }

    for (int i = 0; i < N; i++)
        dest[i] -= 1;
}

void load_lr(char* buf) {
    l = buf[0];
    r = buf[1];
}


void show(char* buf, size_t count) {
    while (count > 0) {
        ssize_t e = write(1, buf, count);

        if (e < 0)
            abort();

        count -= e;
        buf += e;
    }
}

char Q(int i, char c) {
    return (c + i) % N;
}

char Qi(int i, char c) {
    return (N + c - i) % N;
}

char permutate(char c) {
    return Qi(r,Ri[Q(r, Qi(l,Li[Q(l, T[ Qi(l,L[Q(l, Qi(r,R[Q(r,c)]))])])]))]);
}

void update_lr() {
    r = (r + 1) % N;
    if (r == squeeze('L') || r == squeeze('R') || r == squeeze('T'))
        l = (l + 1) % N;
}

void process(char* buf, size_t count) {
    squeeze_buf(buf, count);

    for (int i = 0; i < count; i++) {
        update_lr();
        buf[i] = permutate(buf[i]);
    }

    unsqueeze_buf(buf, count);
}

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

    squeeze_buf(argv[1], N);
    squeeze_buf(argv[2], N);
    squeeze_buf(argv[3], N);

    squeeze_buf(argv[4], 2);
    load_lr(argv[4]);

    L = argv[1];
    R = argv[2];
    T = argv[3];

    inverse_buf(Li, L);
    inverse_buf(Ri, R);
    inverse_buf(Ti, T);

    return loop();
}

