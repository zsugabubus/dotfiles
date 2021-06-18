let s:colors_name = fnamemodify(expand('<sfile>'), ':t:r')
let s:cache = (has('nvim') ? stdpath('cache') : '/tmp').'/'.s:colors_name.'-'.&background.(has('nvim') ? '-nvim' : '').'.vim'
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

let s:cached_cmds = []
" Cache Input... And... Output it.
command! -nargs=* Ciao call add(s:cached_cmds, <q-args>)|<args>

function! s:hi(name, ...)
	let name = a:name
	if name[0] ==# '!'
		let name = name[1:]
		execute 'Ciao hi! clear' name
	elseif name[0] ==# '.'
		let name = name[1:]
		execute 'Ciao hi ' name 'NONE'
	endif
	if get(a:000, 0, '')[0] ==# '='
		execute 'Ciao hi! link ' name a:000[0][1:]
		return
	endif
	let cmd = 'Ciao hi '.name
	let attrs = {}
	for attr in a:000
		let [_, key, value; _] = matchlist(attr, '\v%(([a-z]+)\=)?(.*)')
		if !empty(key)
			" Choose value according to &background.
			let value = split(value, '\V|', 1)
			let value = get(value, len(value) ==# 2 && &background ==# 'dark', '')

			" Resolve highlight["." { attribute | name }].
			if value =~# '\m\C^[A-Z][a-z]'
				let [name, arg; _] = split(value, '\V.') + [key]
				redir => output
				silent! execute 'hi' name
				redir END
				let value = matchstr(output, ' '.arg.'=\zs[^ \n]*')
			endif

			if empty(value)
				continue
			endif

			let attrs[key] = value

			" Really. Fuck your diverging shit.
			if has('nvim') && key ==# 'cterm' && value =~# 'bold'
				let attrs['gui'] = get(attrs, 'gui', '').(!empty(get(attrs, 'gui', '')) ? ',' : '').value
			endif
		else
			let attrs[''] = value
		endif
	endfor
	let cmd = join([cmd] + map(filter(items(attrs), {_,x-> !empty(x[1])}), {_,x-> (!empty(x[0]) ? x[0].'=' : '').(type(x[1]) ==# v:t_list ? join(x[1], ',') : x[1])}), ' ')
	execute cmd
endfunction
command! -nargs=+ Hi call s:hi(<f-args>)

Ciao hi clear
execute "Ciao let colors_name = '".s:colors_name."'"
Ciao if exists("syntax_on")|syntax reset|endif


Hi Normal guifg=#2f323f|#eeede9 guibg=#eeeeee|#222432

Hi Visual guibg=#accdfe|#5c4dbd gui=NONE
Hi VisualNOS guifg=#d8d8dc
Hi !StatusLine guifg=#313140|#f8ece8 guibg=#e8e8e8|#363a46 cterm=bold
Hi !StatusLineNC guifg=#404040|#d8ccc8 guibg=StatusLine gui=NONE
Hi !StatusLineTerm =Normal
Hi !StatusLineTermNC =StatusLineTerm
Hi !TabLine guifg=#444444|#f8fcf8 guibg=StatusLine gui=NONE
Hi TabLineSel guifg=#414140 guibg=#eeeeee|#ffaf5f cterm=bold
Hi LineNr guifg=#b0abab|#8085a0 guibg=#ededed|NONE
Hi SignColumn guifg=#444444 guibg=LineNr
Hi FoldColumn guifg=#b0abab guibg=LineNr
Hi User1 guifg=#e0e0e0|#ffaf5f guibg=#e8e8e8|#363a46
Hi User2 guifg=#686868|#383838 guibg=User1.guifg
Hi User3 guifg=#444444 guibg=User1.guifg cterm=bold
Hi User4 guifg=#777777 guibg=User1.guifg
Hi User9 guifg=#888888|#a4a4a4 guibg=#e8e8e8|#363a46
Hi !NonText guifg=#d1d0d3|#484848 gui=NONE
Hi StatusLineModeTerm guifg=#ffffff guibg=#9D3695 cterm=bold
Hi StatusLineModeTermEnd guifg=StatusLineModeTerm.guibg guibg=StatusLine.guibg
Hi !diffText guifg=|#23252d guibg=#fffcda
Hi DiffAdd guifg=Normal|#c6f6a0 guibg=#a4f6a0|Normal cterm=bold
Hi DiffChange guifg=|diffText guibg=#ffe3a0|#ffde6f
Hi DiffDelete guifg=#ed407a guibg=#fdf0fa|Normal
Hi diffRemoved guifg=DiffDelete guibg=DiffDelete
Hi diffAdded guifg=DiffAdd guibg=DiffAdd gui=DiffAdd
Hi !Special =Normal
Hi !Directory =Normal
Hi !SpecialKey =NonText
Hi Conceal =Normal
Hi TabLineFill =TabLine
Hi Type guifg=#ed0085|#fd0069 cterm=bold
Hi Conditional guifg=#9d00c5|#ff6de9 cterm=bold
Hi Identifier guifg=#4d4d4f|#cacacc cterm=bold
Hi PreProc guifg=#006dd9|#ffcd09
Hi Number guifg=#fa3422|#fa7452 cterm=bold
Hi Keyword guifg=#006de9|#009df9 cterm=bold

Hi Pmenu guibg=#e0e0e0 guifg=#333333
Hi PmenuSel guibg=#ffaf5f guifg=#222222 cterm=bold
Hi PmenuSbar guibg=#dcdcdc
Hi PmenuThumb guibg=#adadad

Hi Underlined guifg=#008df9
Hi Normal =VertSplit
Hi VertSplit gui=NONE guifg=#ababab
Hi Normal =Separator

Hi EndOfBuffer =NonText

Hi Search guifg=#040404 guibg=#fdef39
Hi Search guifg=#040404 guibg=#fdef39
Hi MatchParen cterm=bold guibg=#fde639 guifg=#111111

Hi String guifg=#5baa38
Hi String =Constant
Hi SpecialChar cterm=bold guifg=#df4f00
Hi Character =String

Hi Folded guibg=#e1e1e1 guifg=#666666

Hi Comment guifg=#838385
Hi !Statement =Keyword
" Hi cStorageClass gui=italic,bold guifg=#005db2
Hi cStorageClass =Keyword

Hi Repeat =Conditional

Hi SpellBad NONE
Hi SpellBad guibg=#f9f2f4 guifg=#c72750 gui=undercurl guisp=#d73750
Hi Error cterm=bold guifg=#d80000 guibg=#ffd4d4
Hi Question guifg=#1ca53c
Hi MoreMsg guifg=#1c891a
Hi !ErrorMsg cterm=bold guifg=#fd1d54 guibg=#fdcdd4
Hi !WarningMsg cterm=bold guifg=#933ab7 guibg=#e0d7f7

Hi Todo cterm=bold,italic guifg=#1ca53c guibg=NONE

Hi CursorLineNr gui=NONE guibg=#eaeaeb guifg=#b7636c guifg=#434343 guifg=#0067a4 guifg=#ea5522 cterm=bold guifg=#f65532 guibg=NONE
Hi CursorLineNr =Number

Hi Constant guifg=#df4f00

Hi WildMenu cterm=bold guibg=#fff109

Hi Title guibg=NONE guifg=#858585
Hi Tag guifg=NONE

Hi CfgOnOff =Boolean

" C/C++ {{{
Hi cUserLabel guifg=#9d00c5 gui=underline
Hi Label =cUserLabel
Hi Structure =Keyword
Hi cLabel =Keyword
Hi cConstant guifg=#009017|#1ca51c cterm=bold
Hi Boolean =cConstant
Hi cOctalZero guifg=#8700af cterm=bold
" }}}

" CSS {{{
Hi cssIdentifier =Normal
Hi cssImportant guifg=#f40000
" }}}

" Stylus {{{
Hi cssIdentifier =Normal
Hi stylusImportant =cssImportant
Hi stylusSelectorClass =cssIdentifier
Hi stylusSelectorId =cssIdentifier
Hi stylusSelectorPseudo =Identifier
" }}}

" Vim Help {{{
Hi helpHyperTextEntry =Tag
Hi helpHeadline =Type
" }}}

" Makefile {{{
Hi makeStatement =Function
Hi makeCommands =Normal
Hi makeIdent =PreProc
Hi makeTarget =Identifier
Hi makeSpecTarget =cConstant
" }}}

" Man {{{
Hi manOptionDesc cterm=bold
Hi manSectionHeading =Type
Hi manSubHeading =manSectionHeading
" }}}

" Markdown {{{
Hi mkdListItem cterm=bold
Hi mkdHeading cterm=bold
Hi mkdHeadingDelimiter cterm=bold
Hi htmlH1 cterm=bold
Hi mkdCode guibg=#e8e8e8
Hi mkdCodeDelimiter cterm=bold guibg=#e8e8e8
Hi mkdURL =Underlined
Hi mkdLink =Normal
Hi mkdLinkDef =Identifier
" }}}

" Lua {{{
" hi luaFunction cterm=bold guifg=#005f87
Hi luaFunction =Keyword
Hi luaOperator =Conditional
Hi luaRepeat =Repeat
Hi luaTable =Normal
Hi luaConstant =cConstant
" }}}

" Vim {{{
Hi vimStatement guifg=#005db2
" hi livimFuncName guifg=#005db2
Hi vimOper =Normal
Hi vimOperParen =Normal
Hi vimCommentTitle =Title
Hi vimVar =Normal
Hi vimFuncVar =Normal
Hi vimFuncName =Keyword
Hi vimHiGuiAttrib =Identifier
Hi vimHiGuiFgBg =Normal
Hi vimHiCtermFgBg =Normal
Hi vimHiGui =Normal
Hi vimHiCTerm =Normal
Hi vimHiTerm =Normal
Hi vimHiCtermColor =Normal
Hi vimOption =Identifier
" }}}

" JavaScript {{{
Hi javaScriptNumber =Number
Hi javaScriptBraces =Normal
Hi javaScriptParens =Normal
Hi javaScriptFunction =Keyword
" }}}

" Rust {{{
Hi rustCommentLineDoc =rustCommentLine
" }}}

" JSON {{{
Hi jsonTest =String
Hi jsonKeyword =String
" }}}

" Assembly {{{
Hi asmIdentifier =Normal
" }}}

" SQL {{{
Hi sqlKeyword =Keyword
" }}}

" PHP {{{
Hi phpConstant =cConstant
" }}}

" Git {{{
Hi gitReference =diffFile
" }}}

" TermDebug {{{
Hi debugPC guibg=#fff500
Hi debugBreakpoint cterm=bold guibg=#f51030 guifg=#ffffff
" }}}

try
	call writefile(s:cached_cmds, s:cache)
catch
endtry

delcommand Hi
delcommand Ciao
