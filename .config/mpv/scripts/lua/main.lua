require('cache')
require('choose-value')
require('confirm')
require('delete')
require('external-albumart')
require('fuzzy-subtitle')
require('here')
require('ipc')
require('mouse')
require('oom')
require('osd-bar')
require('osd-cache')
require('osd-colors')
require('osd-filters')
require('osd-icons')
require('osd-metadata')
require('osd-playlist')
require('osd-title')
require('osd-tracks')
require('playlist-fail')
require('playlist-filtersort')
require('playlist-older')
require('playlist-random')
require('playlist-seek')
require('push-to-fastforward')
require('reload')
require('screensaver')
require('tmux')
require('yank-title')

assert(mp.flush_keybindings)
mp.unregister_idle(mp.flush_keybindings)
mp.flush_keybindings()
