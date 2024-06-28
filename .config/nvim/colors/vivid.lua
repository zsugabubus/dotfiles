local trace = require('trace').trace

vim.g.colors_name = 'vivid'

-- Can be skipped on startup since it is useless.
if vim.v.vim_did_enter ~= 0 then
	vim.cmd.highlight('clear')

	if vim.g.syntax_on then
		vim.cmd.syntax('reset')
	end
end

local light = vim.o.background == 'light' or nil
local dark = not light or nil

local span = trace('colorscheme data')

-- stylua: ignore start
local theme = {
	Character = 'String',
	ColorColumn = { bg = light and '#e0e0e0' or '#3a404a' },
	Comment = { fg = '#808082' },
	Conceal = 'Normal',
	Conditional = { fg = light and '#9d00c5' or '#ff6de9', bold = true, ctermfg = 5 },
	Constant = { fg = '#df4f00', ctermfg = 3 },
	CurSearch = 'Search',
	CursorLineNr = { fg = 'Number', bg = 'LineNr', bold = true, ctermfg = 1 },
	Delimiter = 'Special',
	Directory = 'Normal',
	EndOfBuffer = 'NonText',
	Error = { fg = '#d80000', bg = '#ffd4d4', bold = true },
	ErrorMsg = { fg = '#ff0020', bold = true },
	FoldColumn = { fg = '#b0abab', bg = 'LineNr' },
	Folded = { bg = light and '#e3e5ea' or '#44455c', fg = light and '#44546a' or '#d1d2d6' },
	Function = 'Identifier',
	Identifier = { fg = light and '#4d4d4f' or '#cacacc', bold = true },
	Keyword = { fg = light and '#006de9' or '#009df9', bold = true, ctermfg = 4 },
	LineNr = { fg = light and '#b0abab' or '#8085a0', bg = light and '#ededed' },
	ModeMsg = { bold = true },
	MoreMsg = { fg = '#1c891a', bold = true },
	NonText = { fg = light and '#d1d0d3' or '#484848' },
	Normal = { fg = light and '#2f323f' or '#eeede9' },
	NormalFloat = 'Pmenu',
	Number = { fg = light and '#fa3422' or '#fa7452', bold = true, ctermfg = 1 },
	Operator = 'Statement',
	Pmenu = { bg = '#e0e0e0', fg = '#303030' },
	PmenuSbar = { bg = 'Pmenu' },
	PmenuSel = 'Visual',
	PmenuThumb = { bg = '#adadad' },
	PreProc = { fg = 'Keyword', ctermfg = 4 },
	Question = { fg = '#1ca53c', bold = true },
	QuickFixLine = 'Search',
	Repeat = 'Conditional',
	Search = { fg = '#000000', bg = '#fdef39' },
	SignColumn = { fg = '#444444', bg = 'LineNr' },
	Special = 'Normal',
	SpecialChar = { fg = '#df4f00', bold = true },
	SpecialKey = 'NonText',
	SpellBad = { undercurl = true },
	Statement = 'Keyword',
	StatusLine = { fg = light and '#313140' or '#f8ece8', bg = light and '#e8e8e8' or '#363a4a', bold = true },
	StatusLineModeTerm = { fg = '#ffffff', bg = '#9d3695', bold = true },
	StatusLineModeTermEnd = { fg = 'StatusLineModeTerm.bg', bg = 'StatusLine' },
	StatusLineNC = { fg = light and '#404040' or '#d0ccd8', bg = 'StatusLine' },
	StatusLineTerm = 'Normal',
	StatusLineTermNC = 'StatusLineTerm',
	String = 'Constant',
	TabLine = { fg = 'StatusLineNC', bg = 'StatusLine' },
	TabLineFill = 'TabLine',
	TabLineSel = { fg = 'StatusLine', bg = light and '#eeeeee' or 'Normal', bold = true },
	Tag = {},
	Title = { fg = '#858585' },
	Todo = { fg = '#1ca53c', bold = true, italic = true, ctermfg = 2 },
	Type = { fg = light and '#ed0085' or '#fd0069', bold = true, ctermfg = 1 },
	Underlined = { fg = '#008df9' },
	User1 = { fg = light and '#dddddd' or '#ede4ed', bg = 'StatusLine' },
	User2 = { fg = light and '#686868' or '#383838', bg = 'User1.fg' },
	User3 = { fg = '#444444', bg = 'User1.fg', bold = true },
	User9 = { fg = light and '#888888' or '#a4a4a4', bg = 'StatusLine' },
	VertSplit = { fg = '#ababab' },
	Visual = { bg = light and '#a0d0ff' or '#4c5dfd', fg = dark and '#ffffff', ctermbg = 4 },
	WarningMsg = { fg = '#933ab7', bg = '#e0d7f7', bold = true },
	WildMenu = { bg = 'Visual', fg = 'Visual', bold = true },
	WinBar = 'Normal',
	WinBarNC = 'WinBar',
	WinSeparator = 'VertSplit',

	DiffAdd = { bg = light and '#b5f789', fg = dark and '#00d700' },
	DiffChange = { bg = light and '#ffdda5', fg = dark and '#ffc028' },
	DiffDelete = { bg = light and '#ffa195' or '#ea1f24', fg = light and '#9d1e17' or '#fff0f0' },
	diffAdded = { fg = light and '#00af00' or '#00d700' },
	diffRemoved = { fg = '#ff0000' },
	diffText = { bg = light and '#ffafff' or '#ffc028', fg = dark and '#000000' },

	CfgOnOff = 'Boolean',

	Boolean = 'cConstant',
	Label = 'cUserLabel',
	Structure = 'Keyword',
	cConstant = { fg = light and '#009017' or '#1ca51c', bold = true, ctermfg = 2 },
	cLabel = 'Keyword',
	cOctalZero = { fg = '#8700af', bold = true },
	cStorageClass = 'Keyword',
	cUserLabel = { fg = '#9d00c5', underline = true },

	cssIdentifier = 'Normal',
	cssIdentifier = 'Normal',
	cssImportant = { fg = '#f40000' },
	stylusImportant = 'cssImportant',
	stylusSelectorClass = 'cssIdentifier',
	stylusSelectorId = 'cssIdentifier',
	stylusSelectorPseudo = 'Identifier',

	helpHeadline = 'Type',
	helpHyperTextEntry = 'Tag',

	makeCommands = 'Normal',
	makeIdent = 'PreProc',
	makeSpecTarget = 'cConstant',
	makeStatement = 'Function',
	makeTarget = 'Identifier',

	manOptionDesc = { bold = true },
	manSectionHeading = 'Type',
	manSubHeading = 'manSectionHeading',

	htmlH1 = { bold = true },
	mkdCode = { bg = '#e8e8e8' },
	mkdCodeDelimiter = { bg = '#e8e8e8', bold = true },
	mkdHeading = { bold = true },
	mkdHeadingDelimiter = { bold = true },
	mkdLink = 'Normal',
	mkdLinkDef = 'Identifier',
	mkdListItem = { bold = true },
	mkdURL = 'Underlined',

	luaConstant = 'cConstant',
	luaFunction = 'Keyword',
	luaOperator = 'Conditional',
	luaRepeat = 'Repeat',
	luaTable = 'Normal',

	vimCommentTitle = 'Title',
	vimFuncName = 'Keyword',
	vimFuncVar = 'Normal',
	vimHiCTerm = 'Normal',
	vimHiCtermColor = 'Normal',
	vimHiCtermFgBg = 'Normal',
	vimHiGui = 'Normal',
	vimHiGuiAttrib = 'Identifier',
	vimHiGuiFgBg = 'Normal',
	vimHiTerm = 'Normal',
	vimOper = 'Normal',
	vimOperParen = 'Normal',
	vimOption = 'Identifier',
	vimVar = 'Normal',

	javaScriptBraces = 'Normal',
	javaScriptFunction = 'Keyword',
	javaScriptNumber = 'Number',
	javaScriptParens = 'Normal',

	rustCommentLineDoc = 'rustCommentLine',

	jsonKeyword = 'String',
	jsonTest = 'String',

	asmIdentifier = 'Normal',

	sqlKeyword = 'Keyword',

	phpConstant = 'cConstant',

	gitReference = 'diffFile',

	changeLogError = {},

	Search1 = { fg = '#000000', bg = '#58f0f0' },
	Search2 = { fg = '#000000', bg = '#f085f0' },
	Search3 = { fg = '#000000', bg = '#ffaa58' },
	Search4 = { fg = '#000000', bg = '#aaff58' },
	Search5 = { fg = '#000000', bg = '#58ccff' },
}
-- stylua: ignore end

local span = trace(span, 'set highlights')

local function resolve(spec, k)
	local v = spec[k]
	if
		type(v) == 'string' and string.byte(v, 1) ~= 35 -- '#'
	then
		local tn, tk = string.match(v, '([^.]+)%.([^.]+)')
		spec[k] = theme[tn or v][tk or k]
	end
end

local link_spec = {}
for name, spec in pairs(theme) do
	if type(spec) ~= 'string' then
		resolve(spec, 'bg')
		resolve(spec, 'fg')
	else
		link_spec.link = spec
		spec = link_spec
	end
	vim.api.nvim_set_hl(0, name, spec)
end

trace(span)
