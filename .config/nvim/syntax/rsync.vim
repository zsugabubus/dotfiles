if exists("b:current_syntax")
  finish
endif

syn match rsyncHeader /\%1l./ keepend

syn region rsyncChanges start=/\%2l/ end=/\n\n/ transparent contains=rsyncNewFile,rsyncDeletedFile

syn match rsyncChangedFile /^c.\{10\} .*$/ contained nextgroup=rsyncPath
syn match rsyncNewFile /^..+++++++++/ contained nextgroup=rsyncPath
syn match rsyncDeletedFile /^*deleted .*$/ contained nextgroup=rsyncPath
syn match rsyncPath /.*$/ contained

" syn region rsyncSummary start=/\%2l/ end=/\n\n/ transparent contains=rsyncLine

let b:current_syntax="rsync"

hi link rsyncHeader Comment
hi link rsyncNewFile DiffAdd
hi link rsyncChangedFile DiffChange
hi link rsyncDeletedFile DiffDelete
hi link rsyncPath String
