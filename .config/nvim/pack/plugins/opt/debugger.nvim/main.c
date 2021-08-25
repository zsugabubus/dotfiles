#include <stdio.h>

struct alm {
	int barack; int cse;
};

struct alm func(int k)
{
struct alm alm = { .barack = 6, .cse = 53 };
    printf("Hello from func(%d)\n", k);
    return alm;
}

int main(int argc, char *argv[])
{
	int j = argc + 2;
	int k = j + 7;
    func(5);
    char *hangya = "kalapács";

    for (int i = 0; i < 4;  ++i)
        func(++argc);

    func(4);
    ++argc;
    return 0;
}
