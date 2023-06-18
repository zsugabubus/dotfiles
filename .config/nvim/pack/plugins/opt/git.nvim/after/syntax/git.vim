syn match gitFileNew /(new)/ display containedin=gitHead
syn match gitFileGone /(gone)/ display containedin=gitHead
syn region gitStatLine start=/ | \+\d\+ \zs/ end=/$/ display contains=gitLineAdds,gitLineDeletes keepend containedin=gitHead
syn match gitLineAdds /+\+/ display contained
syn match gitLineDeletes /-\+/ display contained
syn match gitCommitReference /(.\+)/ display contained containedin=gitHead

hi default gitRed guifg=#ff0000 gui=bold ctermfg=196 cterm=bold

hi link gitLineAdds diffAdded
hi link gitLineDeletes diffRemoved
hi link gitFileNew diffAdded
hi link gitFileGone diffRemoved
hi link gitCommitReference gitRed
