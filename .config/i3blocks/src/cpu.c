#include <errno.h>
#include <fcntl.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "getopt.h"

#define die(s) do { perror(s); exit(EXIT_FAILURE); } while (0)

int
main(int argc, char **argv) {
	int fd;
	char buf[200];
	unsigned long long total = 0;
	unsigned long long idle = 0;
	unsigned char prev_percent = -1;

	setlocale(LC_ALL, "");
	setbuf(stdout, NULL); /* Disable buffering. */

	parse_opts(argc, argv);

	while (-1 == (fd = open("/proc/stat", O_RDONLY))) {
		if (EINTR == errno)
			continue;

		die("Failed to open /proc/stat");
	}

	for (;;) {
		char *p;
		unsigned i;
		ssize_t r;
		unsigned long long new_total, delta_total;
		unsigned long long new_idle = new_idle, delta_idle;
		unsigned char percent;

		while (-1 == (r = pread(fd, buf, sizeof buf, sizeof "cpu "/*skip it*/))) {
			if (EINTR == errno)
				continue;

			die("Failed read /proc/stat");
		}

		new_total = 0ULL, new_idle = 0ULL;
		for (p = buf, i = 0; *p != '\n'; ++i) {
			unsigned long long const val = strtoull(p, &p, 10);
			new_total += val;
			switch (i) {
			case 3/*idle*/:
			case 4/*iowait*/:
				new_idle += val;
			}
		}

		delta_total = new_total - total;
		delta_idle = new_idle - idle;

		percent = 100 - ((100ULL * delta_idle) / delta_total);
		if (percent != prev_percent) {
			prev_percent = percent;
			printf("%2d%%\n", percent);
		}

		idle = new_idle;
		total = new_total;

		(void)sleep(timeout);
	}
}
