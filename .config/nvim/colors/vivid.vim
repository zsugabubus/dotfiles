packadd vim-cccache

if CCCacheBegin(expand('<sfile>'))
	finish
endif

" darkbluenice  #232a3f
" darkerbluenic #1b1f33
" whiteblue #8e98b3
" orange #e8a152
" nice green: #45993d
" whiteshit: #f7f7f7
" #ecbd1a
" indigo: #2b033b
" hi Identifier guifg=#005db2 guifg=#8500ac
" #30d440
" red #f868d8 #5858d8
" guibg=#b1d7ff
" f3f3a3
" redish background color: #f3eff0
" #fff3a0
" #0f2f21 guibg=#7afb70|#1f362a #fdce67
" #372230 043617 44212f
" guibg=#faeaf4|#4e0d16

Hi Number guifg=#fa3422|#fa7452 cterm=bold

Hi Normal guifg=#2f323f|#eeede9 guibg=#eeeeee|#222432 guibg=NONE
Hi Visual guibg=#accdfe|#5c4dbd gui=NONE ctermbg=4
Hi VisualNOS guifg=#d8d8dc
Hi !StatusLine guifg=#313140|#f8ece8 guibg=#e8e8e8|#363a46 cterm=bold
Hi !StatusLineNC guifg=#404040|#d8ccc8 guibg=StatusLine gui=NONE
Hi !StatusLineTerm =Normal
Hi !StatusLineTermNC =StatusLineTerm
Hi !TabLine guifg=#444444|#f8fcf8 guibg=StatusLine gui=NONE
Hi TabLineSel guifg=#414140 guibg=#eeeeee|#ffaf5f cterm=bold
Hi LineNr guifg=#b0abab|#8085a0 guibg=#ededed|Normal
Hi CursorLineNr guifg=Number guibg=LineNr
Hi SignColumn guifg=#444444 guibg=LineNr
Hi FoldColumn guifg=#b0abab guibg=LineNr
" f0e0e0
Hi User1 guifg=#e0e0e0|#ffaf5f guibg=StatusLine
Hi User2 guifg=#686868|#383838 guibg=User1.guifg
Hi User3 guifg=#444444 guibg=User1.guifg cterm=bold
Hi User4 guifg=#777777 guibg=User1.guifg
Hi User9 guifg=#888888|#a4a4a4 guibg=StatusLine
Hi !NonText guifg=#d1d0d3|#484848 gui=NONE
Hi EndOfBuffer =NonText
Hi !SpecialKey =NonText
Hi StatusLineModeTerm guifg=#ffffff guibg=#9D3695 cterm=bold
Hi StatusLineModeTermEnd guifg=StatusLineModeTerm.guibg guibg=StatusLine
Hi !diffText guifg=#000000 guibg=#ffaf08
Hi DiffAdd guifg=#00a206|#2edd2e cterm=NONE gui=NONE guibg=#ddf7cf|NONE guibg=NONE
Hi DiffChange guifg=NONE guifg=#ec5f00|#ffaf08 guibg=#ffedaa|NONE guibg=NONE
Hi DiffDelete guifg=#ff003e|#ff2e1f cterm=NONE gui=NONE guibg=#ffe5f0|NONE guibg=NONE
Hi diffRemoved =DiffDelete
Hi diffAdded =DiffAdd
Hi !Special =Normal
Hi !Directory =Normal
Hi Conceal =Normal
Hi TabLineFill =TabLine
Hi Folded guibg=#e1e1e1 guifg=#666666
Hi Search guifg=#040404 guibg=#fdef39
Hi MatchParen cterm=bold guibg=#fde639 guifg=#111111
Hi WildMenu cterm=bold guibg=#fff109
Hi Pmenu guibg=#e0e0e0 guifg=#333333
Hi PmenuSel guibg=#ffaf5f guifg=#222222 cterm=bold
Hi PmenuSbar guibg=#dcdcdc
Hi PmenuThumb guibg=#adadad
Hi Underlined guifg=#008df9
Hi VertSplit gui=NONE guifg=#ababab
Hi SpellBad NONE
Hi SpellBad guibg=#f9f2f4 guifg=#c72750 gui=undercurl guisp=#d73750
Hi Error cterm=bold guifg=#d80000 guibg=#ffd4d4
Hi Question guifg=#1ca53c
Hi MoreMsg guifg=#1c891a
Hi !ErrorMsg cterm=bold guifg=#fd1d54 guibg=#fdcdd4
Hi !WarningMsg cterm=bold guifg=#933ab7 guibg=#e0d7f7

Hi Type guifg=#ed0085|#fd0069 cterm=bold
Hi Conditional guifg=#9d00c5|#ff6de9 cterm=bold
Hi Identifier guifg=#4d4d4f|#cacacc cterm=bold
Hi PreProc guifg=#006dd9|#ffcd09
Hi Keyword guifg=#006de9|#009df9 cterm=bold
Hi String =Constant
Hi SpecialChar cterm=bold guifg=#df4f00
Hi Character =String
Hi Constant guifg=#df4f00
Hi Title guibg=NONE guifg=#858585
Hi Tag guifg=NONE
Hi Comment guifg=#838385
Hi !Statement =Keyword
Hi Repeat =Conditional
Hi Todo cterm=bold,italic guifg=#1ca53c guibg=NONE

Hi CfgOnOff =Boolean

Hi cStorageClass =Keyword
Hi cUserLabel guifg=#9d00c5 gui=underline
Hi Label =cUserLabel
Hi Structure =Keyword
Hi cLabel =Keyword
Hi cConstant guifg=#009017|#1ca51c cterm=bold
Hi Boolean =cConstant
Hi cOctalZero guifg=#8700af cterm=bold

Hi cssIdentifier =Normal
Hi cssImportant guifg=#f40000

Hi cssIdentifier =Normal
Hi stylusImportant =cssImportant
Hi stylusSelectorClass =cssIdentifier
Hi stylusSelectorId =cssIdentifier
Hi stylusSelectorPseudo =Identifier

Hi helpHyperTextEntry =Tag
Hi helpHeadline =Type

Hi makeStatement =Function
Hi makeCommands =Normal
Hi makeIdent =PreProc
Hi makeTarget =Identifier
Hi makeSpecTarget =cConstant

Hi manOptionDesc cterm=bold
Hi manSectionHeading =Type
Hi manSubHeading =manSectionHeading

Hi mkdListItem cterm=bold
Hi mkdHeading cterm=bold
Hi mkdHeadingDelimiter cterm=bold
Hi htmlH1 cterm=bold
Hi mkdCode guibg=#e8e8e8
Hi mkdCodeDelimiter cterm=bold guibg=#e8e8e8
Hi mkdURL =Underlined
Hi mkdLink =Normal
Hi mkdLinkDef =Identifier

Hi luaFunction =Keyword
Hi luaOperator =Conditional
Hi luaRepeat =Repeat
Hi luaTable =Normal
Hi luaConstant =cConstant

Hi vimStatement guifg=#005db2
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

Hi javaScriptNumber =Number
Hi javaScriptBraces =Normal
Hi javaScriptParens =Normal
Hi javaScriptFunction =Keyword

Hi rustCommentLineDoc =rustCommentLine

Hi jsonTest =String
Hi jsonKeyword =String

Hi asmIdentifier =Normal

Hi sqlKeyword =Keyword

Hi phpConstant =cConstant

Hi gitReference =diffFile

Hi debugPC guibg=#fff500
Hi debugBreakpoint cterm=bold guibg=#f51030 guifg=#ffffff

Hi changeLogError guifg=Normal

call CCCacheEnd()
