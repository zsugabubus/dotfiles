if empty($WAYLAND_DISPLAY)
	finish
endif

let clipboard = {
\  'copy': {
\     '+': 'wl-copy --foreground --type text/plain',
\     '*': 'wl-copy --foreground --primary --type text/plain',
\   },
\  'paste': {
\     '+': {-> split(system('wl-paste --no-newline'), '\r\?\n', 1)},
\     '*': {-> split(system('wl-paste --no-newline --primary'), '\r\?\n', 1)},
\  },
\  'cache_enabled': 1,
\}
