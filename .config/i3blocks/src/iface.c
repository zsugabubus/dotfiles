#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <net/if.h>
#include <linux/ethtool.h>
#include <linux/limits.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <linux/sockios.h>
#include <linux/wireless.h>
#include <locale.h>
#include <netinet/ether.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include <wchar.h>

#include "getopt.h"
#include "fourmat/fourmat.h"

#define UPLOAD_LABEL ""
#define DOWNLOAD_LABEL ""

#define NSEC_PER_SEC 1000000000L

#define die(s) do { perror(s); exit(EXIT_FAILURE); } while (0)

static int const so_one = 1, so_zero = 0;

int
main(int argc, char **argv) {
	char *ifname;
	unsigned ifindex;
	unsigned long long last_rx_bytes = 0, last_tx_bytes = 0;
	int nlfd;
	long const pagesize = sysconf(_SC_PAGESIZE);
	char buf[pagesize];

	struct sockaddr_nl nlsa;

	unsigned long long rx_bytes = 0, tx_bytes = 0;

	struct timeval tv, *ptv;

	struct nlmsghdr *nlh;
	/* struct nlattr *nla; */
	struct ifinfomsg *ifi;
	struct ifaddrmsg *ifa;
	struct rtattr *rta;

	struct timespec now, last_update;
	int first_update;
	int sfd;
	struct iwreq iwr;
	char essid_str[IW_ESSID_MAX_SIZE + 1];
	char ipaddr_str[INET_ADDRSTRLEN + sizeof("/32")];
	char ip6addr_str[INET6_ADDRSTRLEN + sizeof("/128")];
	char macaddr_str[sizeof("00:00:00:00:00:00")];
	char link_speed_str[4];
	wchar_t const *icon_str;
	int operstate;
	int req_seq = 0;
	int req_getaddr = 1; /* Get addresses only once. We will receive auto updates after it. */

	setlocale(LC_ALL, "");
	setbuf(stdout, NULL); /* Disable buffering. */

	parse_opts(argc, argv);

	nlsa.nl_family = AF_NETLINK;
	nlsa.nl_groups = RTMGRP_LINK | RTMGRP_IPV4_IFADDR | RTMGRP_IPV6_IFADDR;
	nlsa.nl_pad = 0;
	nlsa.nl_pid = getpid();

	essid_str[0] = '\0';
	ipaddr_str[0] = '\0';
	ip6addr_str[0] = '\0';
	macaddr_str[0] = '\0';
	link_speed_str[0] = '\0';
	icon_str = L"\0";
	operstate = IF_OPER_UNKNOWN;
	first_update = 1;

	tv.tv_sec = 0;
	tv.tv_usec = 0;
	ptv = &tv;

	if ((ifname = getenv("BLOCK_INSTANCE")) == NULL) {
		fprintf(stderr, "BLOCK_INSTANCE is not set.");
		exit(EXIT_FAILURE);
	}

	ifindex = if_nametoindex(ifname);
	if (0 == ifindex)
		die("if_nametoindex()");

	if (-1 == (sfd = socket(AF_INET, SOCK_DGRAM | SOCK_CLOEXEC, IPPROTO_IP)))
		die("socket()");

	if (-1 == (nlfd = socket(AF_NETLINK, SOCK_RAW | SOCK_NONBLOCK | SOCK_CLOEXEC, NETLINK_ROUTE)))
		die("socket()");

	setsockopt(nlfd, SOL_NETLINK, NETLINK_EXT_ACK, &so_one, sizeof(so_one));

	if (-1 == bind(nlfd, (struct sockaddr *)&nlsa, sizeof(nlsa)))
		die("bind()");

	(void)rta;
	strncpy(iwr.ifr_name, ifname, IF_NAMESIZE - 1);

	for (;;) {
		int len;
		int ret;
		unsigned long long delta_rx_bytes, delta_tx_bytes;

		char fdelta_rx[4], fdelta_tx[4];
		char frx[4], ftx[4];

		fd_set rfds;
		FD_ZERO(&rfds);
		FD_SET(nlfd, &rfds);

		while (-1 == (ret = select(nlfd + 1, &rfds, NULL, NULL, ptv))) {
			if (errno == EINTR)
				continue;

			die("select()");
		}

		if (ret == 0) {
			nlh = (struct nlmsghdr *)buf;
			nlh->nlmsg_type = RTM_GETLINK;
			nlh->nlmsg_flags = NLM_F_REQUEST; /* Retrieve only the matching. */
			nlh->nlmsg_pid = getpid();
			nlh->nlmsg_seq = ++req_seq;
			nlh->nlmsg_len = NLMSG_LENGTH(sizeof(*ifi) /* + sizeof(*nla) */);

			ifi = NLMSG_DATA(nlh);
			ifi->ifi_family = AF_UNSPEC; /* AF_PACKET */
			ifi->ifi_type = 0; /* ARPHDR_NETROM */
			ifi->ifi_index = ifindex;
			ifi->ifi_flags = 0;
			ifi->ifi_change = 0xFFffFFff; /* 0 */

			/* nla = (struct nlattr *)(ifi + 1);
			nla->nla_len = 8;
			nla->nla_type = IFLA_EXT_MASK;
			(void)nla; */

			setsockopt(nlfd, SOL_NETLINK, NETLINK_GET_STRICT_CHK, &so_zero, sizeof(so_zero));
			if (-1 == sendto(nlfd, nlh, nlh->nlmsg_len, 0, NULL, 0))
				perror("sendto()");

			if (req_getaddr) {
				req_getaddr = 0;
				nlh->nlmsg_type = RTM_GETADDR;
				nlh->nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
				nlh->nlmsg_pid = getpid();
				nlh->nlmsg_seq = ++req_seq;
				nlh->nlmsg_len = NLMSG_LENGTH(sizeof(*ifa));

				ifa = NLMSG_DATA(nlh);
				ifa->ifa_family = AF_UNSPEC;
				ifa->ifa_prefixlen = 0;
				ifa->ifa_flags = 0/*must be zero*/;
				ifa->ifa_scope = RT_SCOPE_UNIVERSE;
				ifa->ifa_index = ifindex;

				setsockopt(nlfd, SOL_NETLINK, NETLINK_GET_STRICT_CHK, &so_one, sizeof(so_one));
				if (-1 == sendto(nlfd, nlh, nlh->nlmsg_len, 0, NULL, 0))
					perror("sendto()");
			}

			tv.tv_sec = timeout;
			tv.tv_usec = 0;
			continue;
		}

		struct iovec iov = { buf, sizeof(buf) };
		struct msghdr msg = { &nlsa, sizeof(nlsa), &iov, 1, NULL, 0, 0 };

		for (;;) {
			len = recvmsg(nlfd, &msg, MSG_DONTWAIT);
			if (len == -1) {
				if (EAGAIN == errno)
					break;

				die("recvmsg()");
			}

			for (nlh = (struct nlmsghdr *)buf; NLMSG_OK(nlh, len);
			     nlh = NLMSG_NEXT(nlh, len)) {
				size_t rtl;

				switch (nlh->nlmsg_type) {
				case NLMSG_DONE:
					continue;
				case NLMSG_ERROR:
					fprintf(stderr, "NLMSG_ERROR\n");
					continue;
				case RTM_NEWLINK:
				case RTM_GETLINK:
					ifi = NLMSG_DATA(nlh);
					/* We receive events for other interfaces too. */
					if (ifindex != (unsigned)ifi->ifi_index)
						continue;

					rta = IFLA_RTA(ifi);
					rtl = IFLA_PAYLOAD(nlh);
					ifa = NULL;

					switch (ifi->ifi_type) {
					case ARPHRD_ETHER:
						icon_str = L" ";
						break;
					default:
						icon_str = L"ﯱ ";
						break;
					}

					essid_str[0] = '\0';
					link_speed_str[0] = '\0';

					/* Is wireless? */
					if (0 == ioctl(sfd, SIOCGIWNAME, &iwr)) {
						struct iw_statistics iwstat;

						icon_str = L" ";

						iwr.u.data.pointer = &iwstat;
						iwr.u.data.length = sizeof(iwstat);

						/*
						if(0 == ioctl(sfd, SIOCGIWSTATS, &iwr)) {
							if (iwstat.qual.updated & IW_QUAL_DBM) {
								printf("SIGNAL: %ddBm\n", iwstat.qual.level - 256);
							}
						} */

						iwr.u.essid.pointer = essid_str;
						iwr.u.essid.length = sizeof(essid_str);
						iwr.u.essid.flags = 0;

						(void)ioctl(sfd, SIOCGIWESSID, &iwr);

						if(0 == ioctl(sfd, SIOCGIWRATE, &iwr))
							fmt_speed(link_speed_str, iwr.u.bitrate.value);

					}
					break;
				case RTM_NEWADDR:
				case RTM_GETADDR:
					ifa = NLMSG_DATA(nlh);
					/* We receive events for other interfaces too. */
					if (ifindex != ifa->ifa_index)
						continue;

					rta = IFA_RTA(ifa);
					rtl = IFA_PAYLOAD(nlh);
					ifi = NULL;
					break;
				default:
					continue;
				}

				for (; RTA_OK(rta, rtl); rta = RTA_NEXT(rta, rtl)) {
					switch (rta->rta_type) {
					case IFLA_ADDRESS:
						switch (nlh->nlmsg_type) {
						case RTM_GETADDR:
						case RTM_NEWADDR: {
							size_t str_size;
							char *str;

							if (AF_INET == ifa->ifa_family)
								str = ipaddr_str, str_size = sizeof(ipaddr_str);
							else
								str = ip6addr_str, str_size = sizeof(ip6addr_str);

							inet_ntop(ifa->ifa_family, RTA_DATA(rta), str, str_size);
							sprintf(str + strlen(str), "/%u", ifa->ifa_prefixlen);
						}
							break;
						case RTM_NEWLINK:
						case RTM_GETLINK:
							ether_ntoa_r(RTA_DATA(rta), macaddr_str);
							break;
						}
						break;
					case IFLA_OPERSTATE:
						operstate = *(int *)RTA_DATA(rta);
						break;
					case IFLA_STATS64: {
						struct rtnl_link_stats64 *ls64 = (struct rtnl_link_stats64 *)RTA_DATA(rta);
						rx_bytes = ls64->rx_bytes;
						tx_bytes = ls64->tx_bytes;
						break;
					}
					}

				}
			}
		}

		switch (operstate) {
		case IF_OPER_UP:
		case IF_OPER_DORMANT:
			if (-1 == clock_gettime(CLOCK_MONOTONIC, &now))
				die("clock_gettime()");

			if (!first_update) {
				long elapsed_nsecs;

				if ((elapsed_nsecs = (now.tv_nsec - last_update.tv_nsec)) < 0)
					elapsed_nsecs += NSEC_PER_SEC;
				elapsed_nsecs += (now.tv_sec - last_update.tv_sec) * NSEC_PER_SEC;

				delta_rx_bytes = (rx_bytes - last_rx_bytes) * NSEC_PER_SEC / elapsed_nsecs;
				delta_tx_bytes = (tx_bytes - last_tx_bytes) * NSEC_PER_SEC / elapsed_nsecs;
			} else {
				first_update = 0;
				delta_rx_bytes = 0;
				delta_tx_bytes = 0;
				ptv = &tv;
			}

			memcpy(&last_update, &now, sizeof(struct timespec));
			last_rx_bytes = rx_bytes;
			last_tx_bytes = tx_bytes;

			fmt_speed(frx, rx_bytes);
			fmt_speed(ftx, tx_bytes);
			fmt_speed(fdelta_rx, delta_rx_bytes);
			fmt_speed(fdelta_tx, delta_tx_bytes);

			printf("\
{\
	\"full_text\": \"%ls%s%s%s " DOWNLOAD_LABEL " %.*s @ %.*s " UPLOAD_LABEL " %.*s @ %.*s\", \
	\"short_text\": \"%ls" DOWNLOAD_LABEL "%.*s " UPLOAD_LABEL "%.*s\"\
}\n",
				/* Full text. */
				icon_str,
				essid_str,
				(strlen(essid_str) > 0 ? " " : ""),
				(strlen(ipaddr_str) > 0 ? ipaddr_str : strlen(ip6addr_str) > 0 ? ip6addr_str : macaddr_str),
				4, frx, 4, fdelta_rx,
				4, ftx, 4, fdelta_tx,
				/* Short text. */
				icon_str,
				4, fdelta_rx, 4, fdelta_tx);

			break;
		default:
			printf("{}\n");
			first_update = 1;
			ptv = NULL;
			break;
		}
	}
}
