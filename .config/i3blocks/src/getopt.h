#include <getopt.h>

static long timeout = 3;

static inline void
parse_opts(int argc, char *argv[]) {
	int opt;

	if (NULL != getenv("_TIMEOUT"))
		timeout = atol(getenv("_TIMEOUT"));

	while (-1 != (opt = getopt(argc, argv, "t:"))) {
		switch (opt) {
		case 't':
			timeout = atol(optarg);
			break;
		default:
			fprintf(stderr, "Usage: %s [-t timeout]\n", argv[0]);
		}
	}
}
