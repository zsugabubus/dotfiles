static char const BLOCK_SEP[] = " ";
static char const GROUP_SEP[] = /* " \xe2\x9d\x98 " */ "\n\e[K";

#define NAMED_DIR(hash) "$(zsh -c '. $ZDOTDIR/??""-hashes.zsh;print "hash"')"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"

static Block BLOCKS[] =
{
	/* { 1, block_seabar, NULL, "%t" }, */
	{ 1, block_battery, "BAT0", ANSI_RGB(123, 63, 0, "%F\xf0\x9f\xa6\x87 %s, %p[%P] (%l)") },

	/* { 8, block_backlight, "backlight/intel_backlight", "LVDS %i %p" },
	{ 8, block_backlight, "leds/dell::kbd_backlight", "KBD %i %p %b/%B" }, */

	{ 2, block_datetime, NULL, " %a, %_d %b \e[1m%H∶%M\e[m" },

	{ 3, block_alsa, "default,Master", ANSI_RGB(26, 83, 159, "%P%i%d (%p)") },
	{ 3, block_alsa, "default,Capture", ANSI_RGB(26, 83, 159, "%C%i%p") },

	{ 4, block_cpu, "", ANSI_RGB(234, 15, 72, " " ANSI_BOLD("%p")), .interval = 4 },
	{ 4, block_read, "/sys/devices/system/cpu/intel_pstate/max_perf_pct", ANSI_RGB(234, 15, 72, "/ %l%%"), .interval = 60 },
	{ 4, block_memory, NULL, ANSI_RGB(234, 85, 34, " %u/%t (" ANSI_BOLD("%p") ")") },

	{ 5, block_fs, NAMED_DIR("~S"), "%i%n: %r%a", .interval = 30 },
	{ 5, block_fs, NAMED_DIR("~N"), "%i%n: %r%a", .interval = 30 },
	{ 5, block_fs, NAMED_DIR("~m"), "%i%n: %r%a", .interval = 10 },
	{ 5, block_fs, NAMED_DIR("~e/silicon"), "%i%n: %r%a", .interval = 30 },
	{ 5, block_fs, NAMED_DIR("~e/archive"), "%i%n: %r%a", .interval = 30 },

/* #define NET_UP_FORMAT ANSI_RGB(92, 169, 58, "%U%i%a  %R @ " ANSI_BOLD ("%r") "  %T @ " ANSI_BOLD("%t")) \ */
#define NET_UP_FORMAT "%U%i%a  %R @ \e[1;38;5;34m%r\e[m  %T @ \e[1;38;5;33m%t\e[m" \

	{ 6, block_net, "enp10s0", NET_UP_FORMAT "\t" "%n (down)"},
	{ 6, block_net, "wlp2s0", NET_UP_FORMAT },

#undef NET_UP_FORMAT

	{ 7, block_uptime, NULL, "♥ %t" },

	{ 8, block_sensor, "hwmon3/fan1", "%Z\xef\x9c\x8f %i", .interval = 8 },

	{ 9, block_text, NULL, "" },
	{ 9, block_text, NULL, "" },
	{ 9, block_sensor, "hwmon4/temp1", "%i", .interval = 8 },

};

#pragma GCC diagnostic pop

#undef NAMED_DIR

static Block *blocks = BLOCKS;
static size_t num_blocks = ARRAY_SIZE(BLOCKS);

static void
init(void)
{ }
