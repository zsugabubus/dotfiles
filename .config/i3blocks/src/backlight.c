#include <errno.h>
#include <fcntl.h>
#include <linux/limits.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <unistd.h>
#include <wchar.h>

/* http://man7.org/tlpi/code/online/diff/inotify/demo_inotify.c.html */

#include "acpi.h"
#include "getopt.h"

#define SYSBL "/sys/class/backlight"

#define die(s) do { perror(s); exit(EXIT_FAILURE); } while (0)

wchar_t const symbols[] = L"";

int
main(int argc, char **argv) {
	char path[PATH_MAX];
	char *ppath;
	int sfd = -1;
	unsigned last_percent = 0;
	struct {
		char const *name;
		int enabled_fd;
		int actual_brightness_fd;
		int max_brightness_fd;
	} sysbl = {
		.enabled_fd = -1,
		.actual_brightness_fd = -1,
		.max_brightness_fd = -1,
	};

	timeout = 5;
	parse_opts(argc, argv);

	setlocale(LC_ALL, "");
	setbuf(stdout, NULL); /* Disable buffering. */

	sysbl.name = "intel_backlight";

	(void)strcpy(path, SYSBL "/");
	(void)strcat(path, sysbl.name);
	(void)strcat(path, "/");
	ppath = strchrnul(path, '\0');

#define OPEN(fd, subpath) \
	for (strcpy(ppath, subpath); -1 == (fd = open(path, O_RDONLY));) \
		if (EINTR == errno) \
			continue; \
		else \
			die("Failed to open " SYSBL "/.../" subpath);

	OPEN(sysbl.enabled_fd, "device/enabled");
	OPEN(sysbl.actual_brightness_fd, "actual_brightness");
	OPEN(sysbl.max_brightness_fd, "max_brightness");

#undef OPEN

	if (-1 == (sfd = acpi_socket()))
		exit(EXIT_FAILURE);

	for (;;) {
		char buf[20];
		ssize_t r;
		struct {
			unsigned long actual_brightness;
			unsigned long max_brightness;
		} bl;
		unsigned percent;

		while (-1 == (r = pread(sysbl.enabled_fd, buf, sizeof buf - 1, 0))) {
			if (EINTR == errno)
				continue;

			die("Failed to read " SYSBL "/.../device/enabled");
		}
		buf[r] = '\0';

		if (strcmp(buf, "enabled\n") != 0) {
			printf("\n");
		} else {
#define UPDATE(res) \
			while (-1 == (r = pread(sysbl.res##_fd, buf, sizeof buf - 1, 0))) \
				if (EINTR == errno) \
					continue; \
				else \
					die("Failed to read " SYSBL "/.../" #res); \
			buf[r] = '\0'; \
			bl.res = strtoul(buf, NULL, 10);

			UPDATE(actual_brightness);
			UPDATE(max_brightness);

#undef UPDATE

			percent = (unsigned)((100UL * bl.actual_brightness) / bl.max_brightness);
			if (percent != last_percent) {
				last_percent = percent;
				printf("%lc %3u%%\n",
					symbols[(7 * bl.actual_brightness) / bl.max_brightness],
					percent);
			}
		}

		if (sfd != -1) {
			if (-1 == acpi_wait(sfd, "video/brightness\0", -1))
				exit(EXIT_FAILURE);

			(void)usleep(150 /*ms*/* 1000);
		} else {
			(void)sleep(timeout);
		}

	}
}
