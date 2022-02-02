if exists('b:current_syntax')
	finish
endif

let b:current_syntax = 'rfc'
setl nolist nonumber norelativenumber

syn match rfcNumber display '\<-\?\d*\>'
syn match rfcHeader display /^\S.*/
syn match rfcSectionHeading display '^\d.*'
syn match rfcString display '"[^"]*"'
syn keyword rfcBold display MAY SHOULD MUST NOT

hi def rfcBold cterm=bold gui=bold
hi def link rfcHeader Title
hi def link rfcString String
hi def link rfcNumber Number
hi def link rfcSectionHeading Type
