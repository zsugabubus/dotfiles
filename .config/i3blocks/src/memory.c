#include <errno.h>
#include <fcntl.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "getopt.h"

#define die(s) do { perror(s); exit(EXIT_FAILURE); } while (0)
#define ENTRY_NAME(name) name ":", strlen(name ":")

int
main(int argc, char **argv) {
	int fd = -1;
	char buf[1024];
	unsigned long total_kib, avail_kib;
	struct {
		char const *const name;
		size_t const len;
		unsigned long *const val;
	} const entries[] = {
		{ ENTRY_NAME("MemTotal"),     &total_kib },
		{ ENTRY_NAME("MemAvailable"), &avail_kib },
		{ ENTRY_NAME("SwapTotal"),    &total_kib },
		{ ENTRY_NAME("SwapFree"),     &avail_kib },
	};
	unsigned prev_percent = -1;
	unsigned long prev_total_hgi = -1, prev_used_hgi = -1;

	(void)setlocale(LC_ALL, "");
	setbuf(stdout, NULL); /* Disable buffering. */

	parse_opts(argc, argv);

	while ((fd = open("/proc/meminfo", O_RDONLY)) == -1) {
		if (EINTR == errno)
			continue;

		die("Failed to open /proc/meminfo");
	}

	for (;;) {
		unsigned long total_hgi, used_hgi;

		unsigned i;
		ssize_t r;
		char *p;
		unsigned percent;

		total_kib = 0, avail_kib = 0;

		while (-1 == (r = pread(fd, buf, sizeof buf - 1, 0))) {
			if (EINTR == errno)
				continue;

			die("Failed to read /proc/meminfo");
		}

		for (i = 0, p = buf;;p = strchrnul(p, '\n') + 1) {
			if (0 == memcmp(p, entries[i].name, entries[i].len)) {
				*entries[i].val += strtoul(p + entries[i].len, &p, 10);

				if (++i >= (sizeof entries / sizeof *entries))
					break;
			}
		}

		percent = 100 - (unsigned)((100UL * avail_kib) / total_kib);
		total_hgi = (100UL * total_kib) / 1024UL / 1024UL;
		used_hgi = (100UL * (total_kib - avail_kib)) / 1024UL / 1024UL;

		if (prev_percent != percent
		    || prev_total_hgi != total_hgi
		    || prev_used_hgi != used_hgi) {
			prev_percent = percent;
			prev_total_hgi = total_hgi;
			prev_used_hgi = used_hgi;

			printf("\
{\
	\"full_text\": \" %u.%02uGi/%u.%02uGi (%2u%%)\", \
	\"short_text\": \" %u%%\"\
}\n",
					/* Full text. */
					(unsigned)(used_hgi / 100ULL), (unsigned)(used_hgi % 100),
					(unsigned)(total_hgi / 100ULL), (unsigned)(total_hgi % 100ULL),
					percent,
					/* Short text. */
					percent);
		}

		(void)sleep(timeout);
	}
}
