let s:colors_name = fnamemodify(expand('<sfile>'), ':t:r')
let s:cache = stdpath('cache').'/'.s:colors_name.'-'.&background.'.vim'
if getftime(expand('<sfile>')) <=# getftime(s:cache)
	execute 'source' fnameescape(s:cache)
	finish
endif

" #ecbd1a

" indigo: #2b033b
" hi Identifier guifg=#005db2 guifg=#8500ac
" #30d440
" red #f868d8 #5858d8
" guibg=#b1d7ff

" f3f3a3

" redish background color: #f3eff0
" #fff3a0

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
\ ['NonText', '#d1d0d3|#484848', '', 'NONE'],
\ ['StatusLineModeTerm', '#ffffff', '#9D3695', 'bold'],
\ ['StatusLineModeTermEnd', 'StatusLineModeTerm.guibg', 'StatusLine.guibg'],
\ ['!diffText', '|#23252d', '#fffcda'],
\ ['DiffAdd', 'Normal|#c6f6a0', '#a4f6a0|Normal', 'bold'],
\ ['DiffChange', '|diffText', '#ffe3a0|#ffde6f'],
\ ['DiffDelete', '#ed407a', '#fdf0fa|Normal'],
\ ['diffRemoved', 'DiffDelete', 'DiffDelete'],
\ ['diffAdded', 'DiffAdd', 'DiffAdd', 'DiffAdd'],
\ ['!Special', '->Normal'],
\ ['!Directory', '->Normal'],
\ ['!SpecialKey', '#818192'],
\ ['Conceal', '->Normal'],
\ ['TabLineFill', '->TabLine'],
\ ['Type', '#ed0085|#fd0069', '', 'bold'],
\ ['Conditional', '#9d00c5|#ff6de9', '', 'bold'],
\ ['Identifier', '#4d4d4f|#cacacc', '', 'bold'],
\ ['PreProc', '#006dd9|#ffcd09'],
\ ['Number', '#fa3422|#fa7452', '', 'bold'],
\ ['Keyword', '#006de9|#009df9', '', 'bold'],
\]

let s:cached_cmds = []

" Cache Input... And... Output it.
command! -nargs=* Ciao call add(s:cached_cmds, <q-args>)|<args>
command! -bang -nargs=* Hi Ciao hi<bang> <args>

" Say hi! to the cache.
Hi clear
execute "Ciao let colors_name = '".s:colors_name."'"
Ciao if exists("syntax_on")|syntax reset|endif

Hi Pmenu guibg=#e0e0e0 guifg=#333333
Hi PmenuSel guibg=#ffaf5f guifg=#222222 gui=bold
Hi PmenuSbar guibg=#dcdcdc
Hi PmenuThumb guibg=#adadad

Hi Underlined guifg=#008df9
Hi! link Normal VertSplit
Hi VertSplit gui=NONE guifg=#ababab
Hi! link Normal Separator

Hi! link EndOfBuffer NonText

Hi Search guifg=#040404 guibg=#fdef39
Hi Search guifg=#040404 guibg=#fdef39
Hi MatchParen gui=bold guibg=#fde639 guifg=#111111

Hi String guifg=#5baa38
Hi! link String Constant
Hi SpecialChar gui=bold guifg=#df4f00
Hi! link Character String

Hi Folded guibg=#e1e1e1 guifg=#666666

Hi Comment guifg=#838385
Hi! clear Statement
Hi! link Statement Keyword
Hi cStorageClass gui=italic,bold guifg=#005db2
Hi! link cStorageClass Keyword

Hi! link Repeat Conditional

Hi SpellBad NONE
Hi SpellBad guibg=#f9f2f4 guifg=#c72750 gui=undercurl guisp=#d73750
Hi Error gui=bold guifg=#d80000 guibg=#ffd4d4
Hi Question guifg=#1ca53c
Hi MoreMsg guifg=#1c891a
Hi! clear ErrorMsg
Hi ErrorMsg gui=bold guifg=#fd1d54 guibg=#fdcdd4
Hi! clear WarningMsg
Hi WarningMsg gui=bold guifg=#933ab7 guibg=#e0d7f7

Hi Todo gui=bold,italic guifg=#1ca53c guibg=NONE

Hi CursorLineNr gui=NONE guibg=#eaeaeb guifg=#b7636c guifg=#434343 guifg=#0067a4 guifg=#ea5522 gui=bold guifg=#f65532 guibg=NONE
Hi! link CursorLineNr Number

Hi Constant guifg=#df4f00

Hi WildMenu gui=bold guibg=#fff109

Hi Title guibg=NONE guifg=#858585
Hi Tag guifg=NONE

Hi! link CfgOnOff Boolean

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
Hi! link cssIdentifier Normal
Hi cssImportant guifg=#f40000
" }}}

" Stylus {{{
Hi! link cssIdentifier Normal
Hi! link stylusImportant cssImportant
Hi! link stylusSelectorClass cssIdentifier
Hi! link stylusSelectorId cssIdentifier
Hi! link stylusSelectorPseudo Identifier
" }}}

" Vim Help {{{
Hi! link helpHyperTextEntry Tag
Hi! link helpHeadline Type
" }}}

" Makefile {{{
Hi! link makeStatement Function
Hi! link makeCommands Normal
Hi! link makeIdent PreProc
Hi! link makeTarget Identifier
Hi! link makeSpecTarget cConstant
" }}}

" Man {{{
Hi manOptionDesc gui=bold
Hi! link manSectionHeading Type
Hi! link manSubHeading manSectionHeading
" }}}

" Markdown {{{
Hi mkdListItem gui=bold
Hi mkdHeading gui=bold
Hi mkdHeadingDelimiter gui=bold
Hi htmlH1 gui=bold
Hi mkdCode guibg=#e8e8e8
Hi mkdCodeDelimiter gui=bold guibg=#e8e8e8
Hi! link mkdURL Underlined
Hi! link mkdLink Normal
Hi! link mkdLinkDef Identifier
" }}}

" Lua {{{
" hi luaFunction gui=bold guifg=#005f87
Hi! link luaFunction Keyword
Hi! link luaOperator Conditional
Hi! link luaRepeat Repeat
Hi! link luaTable Normal
Hi! link luaConstant cConstant
" }}}

" Vim {{{
Hi vimStatement guifg=#005db2
" hi livimFuncName guifg=#005db2
Hi! link vimOper Normal
Hi! link vimOperParen Normal
Hi! link vimCommentTitle Title
Hi! link vimVar Normal
Hi! link vimFuncVar Normal
Hi! link vimFuncName Keyword
Hi! link vimHiGuiAttrib Identifier
Hi! link vimHiGuiFgBg Normal
Hi! link vimHiCtermFgBg Normal
Hi! link vimHiGui Normal
Hi! link vimHiCTerm Normal
Hi! link vimHiTerm Normal
Hi! link vimHiCtermColor Normal
Hi! link vimOption Identifier
" }}}

" JavaScript {{{
Hi! link javaScriptNumber Number
Hi! link javaScriptBraces Normal
Hi! link javaScriptParens Normal
Hi! link javaScriptFunction Keyword
" }}}

" Rust {{{
Hi! link rustCommentLineDoc rustCommentLine
" }}}

" JSON {{{
Hi! link jsonTest String
Hi! link jsonKeyword String
" }}}

" Assembly {{{
Hi! link asmIdentifier Normal
" }}}

" SQL {{{
Hi! link sqlKeyword Keyword
" }}}

" PHP {{{
Hi! link phpConstant cConstant
" }}}

" Git {{{
Hi! link gitReference diffFile
" }}}

" TermDebug {{{
Hi debugPC guibg=#fff500
Hi debugBreakpoint gui=bold guibg=#f51030 guifg=#ffffff
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
		execute 'Hi! clear' name
	elseif name[0] ==# '.'
		let name = name[1:]
		execute 'Hi ' name 'NONE'
	endif
	if attrs[0][:1] ==# '->'
		execute 'Hi! link ' name attrs[0][2:]
	else
		execute 'Hi ' name
			\ s:compute_attr('guifg', get(attrs, 0, ''))
			\ s:compute_attr('guibg', get(attrs, 1, ''))
			\ s:compute_attr('gui',   get(attrs, 2, ''))
	endif
endfor

try
	call writefile(s:cached_cmds, s:cache)
catch
endtry

delcommand Hi
delcommand Ciao
