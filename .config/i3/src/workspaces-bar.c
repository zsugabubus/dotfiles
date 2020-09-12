#define _GNU_SOURCE
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <i3/ipc.h>
#include <linux/limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/uio.h>
#include <sys/un.h>
#include <unistd.h>
#include <xcb/xcb.h>
#include <sys/prctl.h>
#include <signal.h>

/* Config */
#define TIMEOUT_MS 678

static char *
i3_get_socket_path(void) {
	xcb_intern_atom_reply_t *atom_reply;
	char *path = NULL;
	char const *ATOM_NAME = "I3_SOCKET_PATH";
	xcb_connection_t *conn;
	xcb_screen_t *screen;
	xcb_intern_atom_cookie_t cookie;
	xcb_window_t root;
	xcb_get_property_cookie_t prop_cookie;
	xcb_get_property_reply_t *prop_reply;
	int len;

	conn = xcb_connect(NULL, NULL);
	if (xcb_connection_has_error(conn)) {
		fputs("Cannot open display\n", stderr);
		goto error;
	}

	/* Get the first screen. */
	screen = xcb_setup_roots_iterator(xcb_get_setup(conn)).data;
	root = screen->root;

	cookie = xcb_intern_atom(conn, 0, strlen(ATOM_NAME), ATOM_NAME);

	if ((atom_reply = xcb_intern_atom_reply(conn, cookie, NULL)) == NULL)
		goto disconnect;

	prop_cookie = xcb_get_property_unchecked(conn,
		0,                         /* _delete */
		root,                      /* window */
		atom_reply->atom,          /* property */
		XCB_GET_PROPERTY_TYPE_ANY, /* type */
		0,                         /* long_offset */
		PATH_MAX / sizeof(long)    /* long_length */
	);

	if ((prop_reply = xcb_get_property_reply(conn, prop_cookie, NULL)) == NULL)
		goto free_atom;

	if ((len = xcb_get_property_value_length(prop_reply)) == 0)
		goto free_prop;

	path = malloc(len + 1);
	if (path == NULL)
		goto free_prop;

	strncpy(path, (char *)xcb_get_property_value(prop_reply), len);
	path[len] = '\0';

free_prop:
	free(prop_reply);
free_atom:
	free(atom_reply);
disconnect:
	xcb_disconnect(conn);
error:
	return path;
}

int
main(int argc, char **argv) {
	int sfd = -1;
	struct sockaddr_un sa;
	char payload[2 << 14] __attribute__ ((nonstring));
	ssize_t r;
	i3_ipc_header_t whdr;
	struct iovec wiov[2];
	char *socket_path;
	char const* const barname = argc >= 2 ? argv[1] : "workspaces";

	int ipc_write(void) {
		wiov[1].iov_len = whdr.size;
		while ((r = writev(sfd, wiov, 2)) == -1) {
			if (errno == EINTR) {
				continue;
			} else {
				perror("Cannot write socket");
				return -1;
			}
		}

		return 0;
	}

	int memprestr(void const *s1, void const *s2) {
		return memcmp(s1, s2, strlen(s2));
	}

#define die(label, msg) do { perror("workspaces-bar: " msg); goto label; } while (0)

	puts("{\"version\":1,\"stop_signal\": 18}\n[[]");

	prctl(PR_SET_PDEATHSIG, SIGKILL);

	if ((sfd = socket(AF_UNIX, SOCK_STREAM, 0)) == -1)
		die(close, "Cannot open socket");

	if ((socket_path = i3_get_socket_path()) == NULL) {
		fputs("Cannot obtain socket path\n", stderr);
		goto error;
	}

	sa.sun_family = AF_UNIX;
	strncpy(sa.sun_path, socket_path, sizeof sa.sun_path - 1);

	free(socket_path);

	if (connect(sfd, (struct sockaddr *)&sa, sizeof sa) == -1)
		die(close, "Cannot connect to socket");

	(void)fcntl(sfd, F_SETFD, FD_CLOEXEC);

	wiov[0].iov_base = &whdr;
	wiov[0].iov_len = sizeof whdr;
	wiov[1].iov_base = "[\"workspace\"]";

	memcpy(whdr.magic, I3_IPC_MAGIC, sizeof whdr.magic);
	whdr.size = strlen(wiov[1].iov_base);
	whdr.type = I3_IPC_MESSAGE_TYPE_SUBSCRIBE;

	if (ipc_write() == -1)
		goto close;

	wiov[1].iov_base = payload;

	int shown = 0;
	for (;;) {
		fd_set rfds;
		i3_ipc_header_t rhdr;
		struct timeval tv = {
			.tv_sec = TIMEOUT_MS / 1000,
			.tv_usec = (TIMEOUT_MS % 1000) * 1000,
		};

		FD_ZERO(&rfds);
		FD_SET(sfd, &rfds);

		switch (select(sfd + 1, &rfds, NULL, NULL, shown ? &tv : NULL)) {
		case -1:
			if (errno == EINTR)
				continue;

			die(close, "select()");
		case 0:
			/* Timeout reached. */
			whdr.size = snprintf(payload, sizeof payload,
					"bar mode invisible %s", barname);
			whdr.type = I3_IPC_MESSAGE_TYPE_RUN_COMMAND;
			if (ipc_write() == -1)
				goto close;
			shown = 0;
			continue;
		}

		/* Read message header. */
		while ((r = read(sfd, &rhdr, sizeof rhdr)) == -1)
			if (errno == EINTR)
				continue;
			else
				die(close, "Cannot read socket");

		/* Read first chunk only. */
		while ((r = read(sfd, payload, (rhdr.size >= sizeof payload ? sizeof payload : rhdr.size))) == -1)
			if (errno == EINTR)
				continue;
			else
				die(close, "Cannot read socket");

		switch (rhdr.type) {
		case I3_IPC_EVENT_WORKSPACE:
			/* Show bar on workspace focus change. */
			if (memprestr(payload, "{\"change\":\"focus\",") == 0)
				shown = 2;

			break;
		case I3_IPC_REPLY_TYPE_COMMAND:
			/* Check if every run command succeeds. */
			if (memprestr(payload, "[{\"success\":true}]") != 0) {
				fprintf(stderr,
						"IPC RUN_COMMAND message reply: (%u)%.*s.\n",
						rhdr.size, (int)r, payload);
				goto close;
			}
			break;
		}

		/* Drop rest of the message. */
		while ((rhdr.size -= r) > 0)
			while ((r = read(sfd, payload, (rhdr.size >= sizeof payload ? sizeof payload : rhdr.size))) == -1)
				if (errno == EINTR)
					continue;
				else
					die(close, "Cannot read socket");

		/* FIXME: WTF!? Stream delivers packets out of order. I just do not
		 * want to open another socket for working out this shit. */
		if (shown == 2) {
			shown = 1;
			whdr.size = snprintf(payload, sizeof payload,
					"bar mode hide %s", barname);
			whdr.type = I3_IPC_MESSAGE_TYPE_RUN_COMMAND;
			if (ipc_write() == -1)
				goto close;
		}

	}

#undef die

close:
	(void)close(sfd);
error:
	exit(EXIT_FAILURE);
}
