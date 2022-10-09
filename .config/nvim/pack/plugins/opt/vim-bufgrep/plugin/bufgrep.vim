command! -nargs=* BufGrep call bufgrep#BufGrep(<q-args>, 0)
command! -nargs=* BufGrepAdd call bufgrep#BufGrep(<q-args>, 1)
