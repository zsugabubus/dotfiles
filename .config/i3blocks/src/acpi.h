#include <errno.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/un.h>

static int
acpi_socket(void) {
	int sfd;

	if ((sfd = socket(AF_UNIX, SOCK_STREAM, 0)) != -1) {
		struct sockaddr_un sa;

		sa.sun_family = AF_UNIX;
		strncpy(sa.sun_path, "/var/run/acpid.socket", sizeof sa.sun_path - 1);

		if (connect(sfd, (struct sockaddr *)&sa, sizeof sa) == -1) {
			perror("Failed to connect to acpid.socket");
			(void)close(sfd), sfd = -1;
		}
	} else {
		perror("Failed to open socket");
	}

	return sfd;
}

static int
acpi_wait(int const sfd, char const *const events, int timeout) {
	/* XXX: Only on Linux. Not portable. Linux stores remain time after select(). */
	struct timeval tv = {
		.tv_sec = timeout,
		.tv_usec = 0
	};

	for (;;) {
		fd_set rfds;
		ssize_t r;
		char buf[500];
		char const *p = events;

		FD_ZERO(&rfds);
		FD_SET(sfd, &rfds);

		switch (select(sfd + 1, &rfds, NULL, NULL, timeout == -1 ? NULL : &tv)) {
		case -1:
			if (errno == EINTR)
				continue;

			perror("select");
			return -1;
		case 0:
			/* Timeout reached. */
			return 1;
		}

		/* FIXME: It works in a little hacky way, but it works. Parse newlines... etc in the future. */
		while ((r = read(sfd, buf, sizeof buf - 1)) == -1) {
			if (errno == EINTR)
				continue;

			perror("Failed to read acpid.socket");
			return -1;
		}
		buf[r] = '\0';

		for (;;) {
			size_t const len = strlen(p);
			/* No matching event found. */
			if (len == 0)
				break;

			if (strncmp(buf, p, len) != 0)
				return 0;

			p += len;
		}
	}

}
