syntax reset

" #ecbd1a

let g:colors_name = 'vivid'

" indigo: #2b033b
" hi Identifier guifg=#005db2 guifg=#8500ac
" #30d440
" red #f868d8 #5858d8
" guibg=#b1d7ff

let s:highlights = [
\ ['Normal', '#2f323f|#eeede9', '#eeeeee|#23252d'],
\ ['Visual', '', '#accdfe|#5c4dbd', 'NONE'],
\ ['VisualNOS', '#d8d8dc'],
\ ['StatusLine', '#313140|#f8ece8', '#e8e8e8|#363a46', 'bold'],
\ ['StatusLineNC', '#6e6e6e|#d8ccc8', 'StatusLine', 'NONE'],
\ ['TabLine', '#444444|#f8fcf8', 'StatusLine', 'NONE'],
\ ['TabLineSel', '#414140', '#eeeeee|#ffaf5f', 'bold'],
\ ['LineNr', '#b0abab|#8085a0', '#ededed|NONE'],
\ ['SignColumn', '#444444', 'LineNr'],
\ ['FoldColumn', '#b0abab', 'LineNr'],
\ ['User1', '#e0e0e0|#ffaf5f', '#e8e8e8|#363a46'],
\ ['User2', '#686868|#383838', 'User1.guifg'],
\ ['User3', '#444444', 'User1.guifg', 'bold'],
\ ['User4', '#777777', 'User1.guifg'],
\ ['User9', '#888888|#a4a4a4', '#e8e8e8|#363a46'],
\ ['NonText', '#cdcccf|#555555', '', 'NONE'],
\ ['StatusLineModeTerm', '#ffffff', '#9D3695', 'bold'],
\ ['StatusLineModeTermEnd', 'StatusLineModeTerm.guibg', 'StatusLine.guibg'],
\ ['!diffText', '|#23252d', '#fffcda'],
\ ['DiffAdd', '|diffText', '#bff3b8|#9fd368'],
\ ['DiffChange', '|diffText', '#ffdeaf|#ffde6f'],
\ ['DiffDelete', '#ffb4e8|#ff84c8', '#fed4e0|#feb4b0'],
\ ['diffRemoved', '|diffText', 'DiffDelete'],
\ ['diffAdded', '|diffText', 'DiffAdd', 'bold'],
\ ['!Special', '->Normal'],
\ ['!Directory', '->Normal'],
\ ['!SpecialKey', '#818192'],
\ ['Conceal', '->Normal'],
\ ['TabLineFill', '->TabLine'],
\ ['Type', '#ed0085|#fd0069', '', 'bold'],
\ ['Conditional', '#9d00c5|#fd42d0', '', 'bold'],
\ ['Identifier', '#4d4d4f|#cacacc', '', 'bold'],
\]

hi Pmenu guibg=#e0e0e0 guifg=#333333
hi PmenuSel guibg=#ffaf5f guifg=#222222 gui=bold
hi PmenuSbar guibg=#dcdcdc
hi PmenuThumb guibg=#adadad

hi Underlined guifg=#008df9
hi! link Normal VertSplit
hi VertSplit gui=NONE guifg=#ababab
hi! link Normal Separator

hi! link EndOfBuffer NonText

hi Search guifg=#040404 guibg=#fdef39
hi Search guifg=#040404 guibg=#fdef39
hi MatchParen gui=bold guibg=#fde639 guifg=#111111

hi String guifg=#5baa38
hi! link String Constant
hi SpecialChar gui=bold guifg=#df4f00
hi! link Character String

hi Folded guibg=#e1e1e1 guifg=#666666

hi Number gui=bold guifg=#fa3422

hi Comment guifg=#838385
hi Keyword gui=bold guifg=#005db2
hi Keyword gui=bold guifg=#006de9
hi! clear Statement
hi! link Statement Keyword
hi cStorageClass gui=italic,bold guifg=#005db2
hi! link cStorageClass Keyword

hi! link Repeat Conditional

hi PreProc guifg=#005faf guifg=#006dd9

hi SpellBad NONE
hi SpellBad guibg=#f9f2f4 guifg=#c72750 gui=undercurl guisp=#d73750
hi Error guifg=#e70000 guibg=#ffd2d2
hi Question guifg=#1ca53c
hi MoreMsg guifg=#1c891a
hi! clear ErrorMsg
hi ErrorMsg gui=bold guifg=#fd1d54 guibg=#fdcdd4
hi! clear WarningMsg
hi WarningMsg gui=bold guifg=#933ab7 guibg=#e0d7f7

hi Todo gui=bold,italic guifg=#1ca53c guibg=NONE

hi CursorLineNr gui=NONE guibg=#eaeaeb guifg=#b7636c guifg=#434343 guifg=#0067a4 guifg=#ea5522 gui=bold guifg=#f65532 guibg=NONE
hi! link CursorLineNr Number

hi Constant guifg=#df4f00

hi WildMenu gui=bold guibg=#fff109

hi Title guibg=NONE guifg=#858585
hi Tag guifg=NONE

hi! link CfgOnOff Boolean

" C/C++ {{{
let s:highlights += [
\ ['cUserLabel', '#9d00c5', '', 'underline'],
\ ['Label', '->cUserLabel'],
\ ['Structure', '->Keyword'],
\ ['cLabel', '->Keyword'],
\ ['cConstant', '#009017|#1ca51c', '', 'bold'],
\ ['Boolean', '->cConstant'],
\ ['cOctalZero', '#8700af', '', 'bold']
\]
" }}}

" CSS {{{
hi! link cssIdentifier Normal
hi cssImportant guifg=#f40000
" }}}

" Stylus {{{
hi! link cssIdentifier Normal
hi! link stylusImportant cssImportant
hi! link stylusSelectorClass cssIdentifier
hi! link stylusSelectorId cssIdentifier
hi! link stylusSelectorPseudo Identifier
" }}}

" Vim Help {{{
hi! link helpHyperTextEntry Tag
hi! link helpHeadline Type
" }}}

" Makefile {{{
hi! link makeStatement Function
hi! link makeCommands Normal
hi! link makeIdent PreProc
hi! link makeTarget Identifier
hi! link makeSpecTarget cConstant
" }}}

" Man {{{
hi manOptionDesc gui=bold
hi! link manSectionHeading Type
hi! link manSubHeading manSectionHeading
" }}}

" Markdown {{{
hi mkdListItem gui=bold
hi mkdHeading gui=bold
hi mkdHeadingDelimiter gui=bold
hi htmlH1 gui=bold
hi mkdCode guibg=#e8e8e8
hi mkdCodeDelimiter gui=bold guibg=#e8e8e8
hi! link mkdURL Underlined
hi! link mkdLink Normal
hi! link mkdLinkDef Identifier
" }}}

" Lua {{{
" hi luaFunction gui=bold guifg=#005f87
hi! link luaFunction Keyword
hi! link luaOperator Conditional
hi! link luaRepeat Repeat
hi! link luaTable Normal
hi! link luaConstant cConstant
" }}}

" Vim {{{
hi vimStatement guifg=#005db2
" hi livimFuncName guifg=#005db2
hi! link vimOper Normal
hi! link vimOperParen Normal
hi! link vimCommentTitle Title
hi! link vimVar Normal
hi! link vimFuncVar Normal
hi! link vimFuncName Keyword
hi! link vimHiGuiAttrib Identifier
hi! link vimHiGuiFgBg Normal
hi! link vimHiCtermFgBg Normal
hi! link vimHiGui Normal
hi! link vimHiCTerm Normal
hi! link vimHiTerm Normal
hi! link vimHiCtermColor Normal
hi! link vimOption Identifier
" }}}

" JavaScript {{{
hi! link javaScriptNumber Number
hi! link javaScriptBraces Normal
hi! link javaScriptParens Normal
hi! link javaScriptFunction Keyword
" }}}

" JSON {{{
hi! link jsonTest String
hi! link jsonKeyword String
" }}}

" Assembly {{{
hi! link asmIdentifier Normal
" }}}

" SQL {{{
hi! link sqlKeyword Keyword
" }}}

" PHP {{{
hi! link phpConstant cConstant
" }}}

" TermDebug {{{
hi debugPC guibg=#fff500
hi debugBreakpoint gui=bold guibg=#f51030 guifg=#ffffff
" }}}

function s:compute_attr(name, value)
	" Choose value according to &background.
	let value = split(a:value, '\V|', 1)
	let value = get(value, len(value) ==# 2 && &background ==# 'dark', '')

	" Resolve highlight["." { attribute | name }].
	if value =~# '\m\C^[A-Z][a-z]'
		let [name, arg; _] = split(value, '\V.') + [a:name]
		redir => output
		silent! execute 'hi' name
		redir END
		let value = matchstr(output, ' '.arg.'=\zs[^ ]*')
	endif

	if empty(value)
		return ''
	endif

	return a:name.'='.value
endfunction

for [name; attrs] in s:highlights
	if name[0] ==# '!'
		let name = name[1:]
		execute 'hi! clear' name
	elseif name[0] ==# '.'
		let name = name[1:]
		execute 'hi ' name 'NONE'
	endif
	if attrs[0][:1] ==# '->'
		execute 'hi! link ' name attrs[0][2:]
	else
		execute 'hi ' name
			\ s:compute_attr('guifg', get(attrs, 0, ''))
			\ s:compute_attr('guibg', get(attrs, 1, ''))
			\ s:compute_attr('gui',   get(attrs, 2, ''))
	endif
endfor
