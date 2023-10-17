local trace = require('trace').trace

vim.g.colors_name = 'vivid'

-- Can be skipped on startup since it is useless.
if vim.v.vim_did_enter ~= 0 then
	vim.cmd.highlight('clear')

	if vim.g.syntax_on then
		vim.cmd.syntax('reset')
	end
end

local light = vim.o.background == 'light'

local span = trace('colorscheme data')

-- stylua: ignore start
local theme = {
	Conceal = 'Normal',
	Directory = 'Normal',
	EndOfBuffer = 'NonText',
	Folded = { bg = '#e1e1e1', fg = '#666666' },
	NonText = { fg = light and '#d1d0d3' or '#484848' },
	Normal = { fg = light and '#2f323f' or '#eeede9' },
	Search = { fg = '#040404', bg = '#fdef39' },
	Special = 'Normal',
	SpecialKey = 'NonText',
	VertSplit = { fg = '#ababab' },
	Visual = { bg = light and '#acd0fe' or '#4c4dbd', ctermbg = 4 },
	VisualNOS = { fg = '#d8d8dc' },

	TabLine = { fg = light and '#444444' or '#d8ccd8', bg = 'StatusLine' },
	TabLineFill = 'TabLine',
	TabLineSel = { fg = light and '#414140' or 'Normal', bg = light and '#eeeeee' or 'Normal', bold = true },

	StatusLine = { fg = light and '#313140' or '#f8ece8', bg = light and '#e8e8e8' or '#363a46', bold = true },
	StatusLineModeTerm = { fg = '#ffffff', bg = '#9D3695', bold = true },
	StatusLineModeTermEnd = { fg = 'StatusLineModeTerm.bg', bg = 'StatusLine' },
	StatusLineNC = { fg = light and '#404040' or '#d8ccd8', bg = 'StatusLine' },
	StatusLineTerm = 'Normal',
	StatusLineTermNC = 'StatusLineTerm',

	User1 = { fg = light and '#dddddd' or '#ede4ed', bg = 'StatusLine' },
	User2 = { fg = light and '#686868' or '#383838', bg = 'User1.fg' },
	User3 = { fg = '#444444', bg = 'User1.fg', bold = true },
	User9 = { fg = light and '#888888' or '#a4a4a4', bg = 'StatusLine' },

	Error = { fg = '#d80000', bg = '#ffd4d4', bold = true },
	ErrorMsg = { fg = '#fd1d54', bg = '#fdcdd4', bold = true },
	MoreMsg = { fg = '#1c891a', bold = true },
	Question = { fg = '#1ca53c', bold = true },
	WarningMsg = { fg = '#933ab7', bg = '#e0d7f7', bold = true },

	CursorLineNr = { fg = 'Number', bg = 'LineNr', bold = true },
	FoldColumn = { fg = '#b0abab', bg = 'LineNr' },
	LineNr = { fg = light and '#b0abab' or '#8085a0', bg = light and '#ededed' or nil },
	SignColumn = { fg = '#444444', bg = 'LineNr' },

	Character = 'String',
	Comment = { fg = '#838385' },
	Conditional = { fg = light and '#9d00c5' or '#ff6de9', bold = true },
	Constant = { fg = '#df4f00' },
	Identifier = { fg = light and '#4d4d4f' or '#cacacc', bold = true },
	Keyword = { fg = light and '#006de9' or '#009df9', bold = true },
	Number = { fg = light and '#fa3422' or '#fa7452', bold = true },
	PreProc = { fg = light and '#006dd9' or '#ffcd09' },
	Repeat = 'Conditional',
	SpecialChar = { fg = '#df4f00', bold = true },
	Statement = 'Keyword',
	String = 'Constant',
	Type = { fg = light and '#ed0085' or '#fd0069', bold = true },

	DiffAdd = { bg = light and '#b5f78b' or nil, fg = not light and '#2edd2e' or nil },
	DiffChange = { bg = light and '#ffdda5' or nil, fg = not light and '#ffc028' or nil },
	DiffDelete = { bg = light and '#ffa195' or '#ea1f24', fg = light and '#9d1e17' or '#fff0f0' },
	diffAdded = { fg = light and '#00a206' or '#2edd2e' },
	diffRemoved = { fg = '#fe2e1f' },
	diffText = { bg = light and '#ffafff' or '#ffc028', fg = not light and '#000000' or nil },

	GitSignAdd = { bg = light and '#b5f78b' or '#2edd2e', fg = '#000000', bold = true, },
	GitSignDelete = { bg = light and '#ffa195' or '#ea1f24', fg = light and '#000000' or '#ffffff', bold = true, },
	GitSignChange = { bg = light and '#ffdda5' or '#ffc028', fg = '#000000', bold = true, },

	Pmenu = { bg = '#e0e0e0', fg = '#303030' },
	PmenuSbar = { bg = 'Pmenu' },
	PmenuSel = 'Visual',
	PmenuThumb = { bg = '#adadad' },
	WildMenu = { bg = 'Visual', fg = 'Visual', bold = true },

	SpellBad = { bg = '#f9f2f4', fg = '#c72750', undercurl = true, sp = '#d73750' },
	Tag = {},
	Title = { fg = '#858585' },
	Todo = { fg = '#1ca53c', bold = true, italic = true },
	Underlined = { fg = '#008df9' },

	MatchParen = { bg = '#fde639', fg = '#111111', bold = true },

	CfgOnOff = 'Boolean',

	Boolean = 'cConstant',
	Label = 'cUserLabel',
	Structure = 'Keyword',
	cConstant = { fg = light and '#009017' or '#1ca51c', bold = true },
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
	vimStatement = { fg = '#005db2' },
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

	debugPC = { bg = '#fff500' },
	debugBreakpoint = { bg = '#f51030', fg = '#ffffff' },

	changeLogError = {},
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
