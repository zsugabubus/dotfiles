syn match nroffHeader /^\.S[SH]\>.*/ keepend
hi link nroffHeader manSectionHeading

syn match nroffBold /^\.B\>.*/ keepend
hi link nroffBold nroffEscRegArg

syn match nroffDot /^\.$/
hi link nroffDot Comment
