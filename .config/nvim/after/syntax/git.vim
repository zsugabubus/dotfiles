syn region gitStatLine start=/^ .\+ | \+\d\+ \zs/ end=/$/ contains=gitLineAdds,gitLineDeletes keepend containedin=gitHead,
syn match gitLineAdds /+\+/ contained
syn match gitLineDeletes /-\+/ contained

hi link gitLineAdds DiffAdd
hi link gitLineDeletes DiffDelete
