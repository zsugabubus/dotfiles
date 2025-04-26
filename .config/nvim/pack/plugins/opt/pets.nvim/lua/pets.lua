local function keymap_iexpr(key, callback)
	vim.api.nvim_set_keymap('i', key, '', {
		expr = true,
		noremap = true,
		replace_keycodes = true,
		silent = true,
		callback = callback,
	})
end

local function keymap_iexpr_ascii(char, callback)
	local plug_key = '<Plug>(_pets-' .. char:byte() .. ')'
	vim.api.nvim_set_keymap('i', char, '<C-G>U' .. plug_key, { noremap = true })
	keymap_iexpr(plug_key, callback)
end

local function current_line_and_col()
	return vim.fn.getline('.'), vim.fn.col('.')
end

local function balanced(s, i, open, close)
	return not (s:sub(1, i) .. '\0' .. s:sub(i + 1))
		:gsub('\\.', '')
		:gsub('%b' .. open .. close, '')
		:gsub('%z.*', '')
		:find(open, 1, true)
end

local function handle_open(open, close)
	local s, i = current_line_and_col()
	if open == '[' and vim.bo.filetype == 'lua' then
		return open
	elseif s:sub(i):find([=[[^)%]}%s;,]]=]) then
		return open
	end
	if open == '{' and not s:find([=[["']]=]) and vim.bo.filetype == 'rust' then
		return open .. '<CR>' .. close .. '<C-O>O'
	end
	return open .. close .. '<C-G>U<Left>'
end

local function handle_close(open, close)
	local s, i = current_line_and_col()
	if close == ']' and vim.bo.filetype == 'lua' then
		return close
	elseif s:sub(i, i) == close and balanced(s, i, open, close) then
		return '<C-G>U<Right>'
	elseif
		i == #s + 1
		and s:sub(i - 1, i - 1):find('%S')
		and balanced(s, i, open, close)
	then
		local row = vim.fn.line('.') + 1
		local _, col = vim.fn.getline(row):find('^[ \t]*' .. vim.pesc(close))
		if col then
			return ('<C-O>:call cursor(%d,%d)<CR>'):format(row, col + 1)
		end
	end
	return close
end

local function handle_quote(quote, exclude_pat)
	local s, i = current_line_and_col()
	if s:sub(i - 1, i - 1) == '\\' then
		return quote
	elseif s:sub(i, i) == quote and not s:sub(i + 1):find('[^%p%s]') then
		return '<C-G>U<Right>'
	elseif s:sub(i - 1, i - 1):find(exclude_pat) then
		return quote
	elseif not s:sub(i):find('[^%p%s]') and balanced(s, i, quote, quote) then
		return quote .. quote .. '<C-G>U<Left>'
	end
	return quote
end

local function handle_bs(key)
	local s, i = current_line_and_col()
	local function pair(open, close)
		if
			s:sub(i - 1, i) == open .. close
			and s:sub(i - 2, i - 2) ~= '\\'
			and balanced(s, i, open, close)
		then
			return key .. '<Del>'
		end
	end
	return pair('"', '"')
		or pair("'", "'")
		or pair('`', '`')
		or pair('(', ')')
		or pair('[', ']')
		or pair('{', '}')
		or key
end

local function handle_cr(key)
	local s, i = current_line_and_col()
	if s:sub(i - 1, i):find('^[({[<][>%]})]$') then
		return '<CR>0<C-D><C-R>="' .. s:match('^[ \t]*') .. '"<CR><C-O>O'
	end
	return key
end

local function map_paren(open, close)
	keymap_iexpr_ascii(open, function()
		return handle_open(open, close)
	end)
	keymap_iexpr_ascii(close, function()
		return handle_close(open, close)
	end)
end

local function map_quote(quote, exclude_pat)
	keymap_iexpr_ascii(quote, function()
		return handle_quote(quote, exclude_pat)
	end)
end

local function map_bs(key)
	keymap_iexpr(key, function()
		return handle_bs(key)
	end)
end

local function map_cr(key)
	keymap_iexpr(key, function()
		return handle_cr(key)
	end)
end

map_paren('(', ')')
map_paren('[', ']')
map_paren('{', '}')

map_quote('"', '"')
map_quote("'", "[%a']")
map_quote('`', '`')

map_bs('<BS>')
map_bs('<C-H>')
map_bs('<C-W>')
map_bs('<C-U>')

map_cr('<CR>')
