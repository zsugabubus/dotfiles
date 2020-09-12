#include <errno.h>
#include <fcntl.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <linux/limits.h>

#include "acpi.h"
#include "getopt.h"

#define BAT_CHG_SYMS L""
#define BAT_DISCHG_SYMS L""
#define BAT_UNKN_SYM L""
#define AC_ONLINE_SYM L"ﮣ"
#define AC_OFFLINE_SYM L"ﮤ"

#define SYSPOWER "/sys/class/power_supply"

#define DEBOUNCE_TIMEOUT_MS 150

#define die(s) do { perror(s); exit(EXIT_FAILURE); } while (0)

enum AC_STATES { AC_ONL, AC_OFL, AC_UNKN };
enum BAT_STATES { BAT_DISCHG, BAT_CHG, BAT_FULL, BAT_UNKN };

int
main(int argc, char **argv) {
	char path[PATH_MAX];
	char *ppath;
	struct {
		char const *name;
		int online_fd;
	} sysac = {
		.online_fd = -1,
	};
	struct {
		char const *name;
		int status_fd;
		int charge_now_fd;
		int charge_full_fd;
		int charge_full_design_fd;
	} sysbat = {
		.status_fd = -1,
		.charge_now_fd = -1,
		.charge_full_fd = -1,
		.charge_full_design_fd = -1,
	};
	int sfd;

	setlocale(LC_ALL, "");
	setbuf(stdout, NULL); /* Disable buffering. */

	timeout = 10;
	parse_opts(argc, argv);

	sysac.name = "AC";
	sysbat.name = "BAT0";

	(void)strcpy(path, SYSPOWER "/");

#define OPEN(class, res) \
	for (strcpy(ppath, #res); (sys##class.res##_fd = open(path, O_RDONLY)) == -1;) { \
		if (errno == EINTR) { \
			continue; \
		} else { \
			die("Failed to read " SYSPOWER "/.../" #res); \
		} \
	}

	if (sysac.name != NULL) {
		(void)strcat(path, sysac.name);
		(void)strcat(path, "/");
		ppath = strchrnul(path, '\0');

		OPEN(ac, online);

		path[sizeof SYSPOWER "/" - 1] = '\0';
	} else {
		sysac.online_fd = -1;
	}

	if (sysbat.name != NULL) {
		(void)strcat(path, sysbat.name);
		(void)strcat(path, "/");
		ppath = strchrnul(path, '\0');

		OPEN(bat, status);
		OPEN(bat, charge_now);
		OPEN(bat, charge_full);
		OPEN(bat, charge_full_design);

		path[sizeof SYSPOWER "/" - 1] = '\0';
	} else {
		sysbat.status_fd = -1;
		sysbat.charge_now_fd = -1;
		sysbat.charge_full_fd = -1;
		sysbat.charge_full_design_fd = -1;
	}

#undef OPEN

	sfd = acpi_socket();

	for (;;) {
		char buf[20];
		ssize_t r;
		struct {
			int status;
		} ac;
		struct {
			int status;
			unsigned long long charge_now_uah;
			unsigned long long charge_full_uah;
			unsigned long long charge_full_design_uah;
		} bat;

		while (-1 == (r = pread(sysac.online_fd, buf, sizeof buf - 1, 0))) {
			if (EINTR == errno)
				continue;

			die("Failed to read " SYSPOWER "/.../online");
		}
		buf[r] = '\0';

		if (0 == strcmp(buf, "0\n"))
			ac.status = AC_OFL;
		else if (0 == strcmp(buf, "1\n"))
			ac.status = AC_ONL;
		else
			ac.status = AC_UNKN;

		while (-1 == (r = pread(sysbat.status_fd, buf, sizeof buf - 1, 0))) {
			if (EINTR == errno)
				continue;

			die("Failed to read " SYSPOWER "/.../status");
		}
		buf[r] = '\0';

		if (0 == strcmp(buf, "Full\n"))
			bat.status = BAT_FULL;
		else if (0 == strcmp(buf, "Charging\n"))
			bat.status = BAT_CHG;
		else if (0 == strcmp(buf, "Discharging\n"))
			bat.status = BAT_DISCHG;
		else
			bat.status = BAT_UNKN;

#define UPDATE(res) \
		while (-1 == (r = pread(sysbat.res##_fd, buf, sizeof buf - 1, 0))) { \
			if (EINTR == errno) \
				continue; \
 \
			die("Failed to read " SYSPOWER "/.../" #res); \
		} \
		buf[r] = '\0'; \
		bat.res##_uah = strtoull(buf, NULL, 10);

		UPDATE(charge_now);
		UPDATE(charge_full);
		UPDATE(charge_full_design);

#undef UPDATE

		if (ac.status == AC_ONL && bat.charge_now_uah == bat.charge_full_uah) {
			printf("\n"); /*  */
		} else {
			printf("%s %3u%%\n",
					ac.status == AC_ONL ? " " : ac.status == AC_OFL ? "" : "??",
					(unsigned)((100ULL * bat.charge_now_uah) / bat.charge_full_uah)
					/*, 100 - (unsigned)((100ULL * bat.charge_full_uah) / bat.charge_full_design_uah) */ /* (-%2u%%) */);
		}

		if (-1 != sfd) {
			switch (acpi_wait(sfd, "ac_adapter\0battery\0", bat.status == BAT_FULL ? -1 : timeout)) {
			case -1:
				exit(EXIT_FAILURE);
			case 0:
				(void)usleep(DEBOUNCE_TIMEOUT_MS /*ms*/* 1000);
			}

		} else {
			(void)sleep(timeout);
		}
	}
}
