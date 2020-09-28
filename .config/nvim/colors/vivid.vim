syntax reset

let g:colors_name = 'vivid'

" indigo: #2b033b
if &background == 'light'
	hi Normal guibg=#eeeeee guifg=#424241 guifg=#2f323f

	hi User1 guibg=#e8e8e8 guifg=#e0e0e0
	hi User2 guibg=#e0e0e0 guifg=#686868
	hi User3 guibg=#e0e0e0 gui=bold guifg=#444444
	hi User4 guibg=#e0e0e0 guifg=#777777
	hi User9 guibg=#e8e8e8 guifg=#888888

	hi StatusLine gui=bold guibg=#e8e8e8 guifg=#313140
	hi StatusLineNC gui=NONE guibg=#e8e8e8 guifg=#6e6e6e
else
	" snazzy
	hi Normal guibg=#23252d guifg=#eeede9

	hi User1 guibg=#343844 guifg=#e0e0e0
	hi User2 guibg=#343844 guifg=#686868
	hi User3 guibg=#343844 gui=bold guifg=#444444
	hi User4 guibg=#343844 guifg=#777777
	hi User9 guibg=#343844 guifg=#888888

	hi StatusLine gui=bold guibg=#343844 guifg=#313140
	hi StatusLineNC gui=NONE guibg=#343844 guifg=#6e6e6e
endif

hi Pmenu guibg=#e0e0e0 guifg=#333333
hi PmenuSel guibg=#ffaf5f guifg=#222222 gui=bold
hi PmenuSbar guibg=#dcdcdc
hi PmenuThumb guibg=#adadad

hi! link Conceal Normal

hi! clear Special
hi! link Special Normal
hi! clear Directory
hi! link Directory Normal
hi! clear SpecialKey
hi SpecialKey guifg=#818192

hi TabLine gui=NONE guibg=#e8e8e8 guifg=#444444
hi TabLineSel gui=bold guibg=#eeeeee guifg=#414140
hi! link TabLineFill TabLine

hi Underlined guifg=#008df9
hi! link Normal VertSplit
hi VertSplit gui=NONE guifg=#ababab
hi! link Normal Separator

hi! link EndOfBuffer NonText

hi Search guifg=#040404 guibg=#fdef39
hi Search guifg=#040404 guibg=#fdef39
hi MatchParen gui=bold guibg=#fde639 guifg=#111111

if &background == 'light'
	hi NonText gui=NONE guifg=#cdcccf

	hi LineNr guibg=#ededed guifg=#b0abab
	hi SignColumn guibg=#ededed guifg=#444444
	hi FoldColumn guibg=#ededed guifg=#b0abab

	hi Visual gui=NONE guibg=#b9b9bd
	hi Visual gui=NONE guibg=#b6d6fd guibg=#accdfe
	hi VisualNOS gui=NONE guibg=#d8d8dc

	" hi Identifier guifg=#005db2 guifg=#8500ac
	hi Identifier gui=bold guifg=#4d4d4f
else
	hi NonText gui=NONE guifg=#555555

	" snazzy
	hi LineNr guibg=NONE guifg=#8085a0
	hi SignColumn guibg=NONE guifg=#444444
	hi FoldColumn guibg=NONE guifg=#b0abab

	" guibg=#b1d7ff
	hi Visual gui=NONE guibg=#4949bd
	hi Visual gui=NONE guibg=#69698d

	hi Identifier gui=bold guifg=#cacacc
endif

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

if &background == 'light'
	hi Type gui=bold guifg=#d70087
	hi Type gui=bold guifg=#ed0085

	hi Conditional gui=bold guifg=#9d00c5
else
	hi Type gui=bold guifg=#fd0069

	hi Conditional gui=bold guifg=#fd42d0
endif
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

if &background == 'light'
	hi DiffAdd guibg=#bff2c6
	hi DiffAdd guibg=#bff3b8
	hi DiffChange guibg=#ffd787
	hi DiffChange guibg=#ffdeaf
	hi DiffDelete guibg=#fedff6 guifg=#ff7183 guifg=#ffc1d3
	hi DiffDelete guibg=#fec9df guifg=#ffa4c8
	hi DiffDelete guibg=#fed4e0 guifg=#ffb4e8
	" hi DiffText guibg=#e0e0e0 guifg=#acf2bd guifg=#262626 guifg=#acf2bd
	hi! clear DiffText
	hi DiffText guibg=#fffcda
else
	hi DiffAdd guifg=#23252d guibg=#9fd368
	hi DiffChange guifg=#23252d guibg=#ffde6f
	hi DiffDelete guifg=#ff84c8 guibg=#feb4b0
	hi! clear DiffText
	hi DiffText guifg=#23252d guibg=#fffcda
endif

hi WildMenu gui=bold guibg=#fff109

hi Title guibg=NONE guifg=#858585
hi Tag guifg=NONE

" C/C++ {{{
hi cUserLabel gui=bold guifg=#f41645
hi! cUserLabel gui=underline guifg=#9d00c5
hi! link Label cUserLabel
hi! link Structure Keyword
hi! link cLabel Keyword
if &background == 'light'
	hi cConstant gui=bold guifg=#008700
	hi cConstant gui=bold guifg=#009017
else
	hi cConstant gui=bold guifg=#1ca51c
endif
hi! link Boolean cConstant
hi! link CfgOnOff Boolean
hi cOctalZero gui=bold guifg=#8700af
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
hi! link makeStatement Normal
hi! link makeCommands Normal
hi! link makeIdent Normal
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

" TermDebug {{{
hi debugPC guibg=#fff500
hi debugBreakpoint gui=bold guibg=#f51030 guifg=#ffffff
" }}}

