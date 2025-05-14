local api = vim.api
local fn = vim.fn

local function m(lhs, rhs)
	if type(rhs) == 'function' then
		api.nvim_buf_set_keymap(0, 'i', lhs, '', {
			noremap = true,
			expr = true,
			replace_keycodes = true,
			callback = rhs,
		})
	else
		api.nvim_buf_set_keymap(0, 'i', lhs, rhs, {
			noremap = true,
		})
	end
end

local function sm(lhs, snippet, env)
	api.nvim_buf_set_keymap(0, 'i', lhs, '', {
		callback = function()
			local buf = api.nvim_get_current_buf()
			local row, col = unpack(api.nvim_win_get_cursor(0))
			local body = require('snippets.textmate').parse(snippet)
			require('snippets').expand(buf, row - 1, col, body, env)
		end,
	})
end

return function()
	local ft = vim.bo.filetype

	if ft ~= '' then
		m('<M-r>', 'return ')
	end

	if ft:find('sh$') then
		m('<M-c>', 'case ; in<CR>esac<Up><End><Left><Left><Left><Left>')
		m('<M-d>', '; do<CR>done<C-O>')
		m('<M-e>', 'elif ; then<Left><Left><Left><Left><Left><Left><Left>')
		m('<M-e><CR>', 'else<CR>')
		m(
			'<M-i>',
			'if ; then<CR>fi<Up><End><Left><Left><Left><Left><Left><Left><Left>'
		)
		m('<M-w>', 'while ')
		m('<M-f>', 'for ')
		m('<M-t>', '; then<CR>')
	end

	if ft:find('javascript') or ft:find('typescript') then
		m('<M-a>', 'await ')
		sm('<M-c>', 'const $1')
		sm('<M-i>', 'if ($1) {\n\t$2\n}')
		sm('<M-e>', 'else if ($1) {\n\t$2\n}')
		sm('<M-e><CR>', 'else {\n\t$1\n}')
		sm('<M-f>', 'for ($1 of $2) {\n\t$3\n}')
		sm('<M-l>', 'console.log($1);')
		sm('<M-u>e', 'useEffect(() => {\n\t$1\n}, [$2]);')
		sm('<M-u>s', 'const [$1, $SETTER] = useState($2);', {
			SETTER = function(t)
				return 'set' .. t[1]:gsub('^.', string.upper)
			end,
			[2] = function(t)
				return t[1]:find('^is[A-Z]') and 'false' or ''
			end,
		})
	end

	if ft == 'lua' then
		m('<M-d>', ' do<CR>end<C-O>O')
		sm('<M-e>', 'elseif $1 then')
		m('<M-e><CR>', 'else<CR>')
		sm('<M-i>', 'if $1 then\n\t$2\nend')
		m('<M-l>', 'local ')
		sm('<M-f>', 'function $1($2)\n\t$3\nend')
		sm('<M-f>(', 'function($1)\n\t$2\nend')
		sm('<M-f>)', 'function()\n\t$1\nend')
		sm('<M-w>', 'while ${1:true} do\n\t$2\nend')
		sm('<M-f>=', 'for ${1:i} = ${2:1}, $3 do\n\t$4\nend')
		sm('<M-f><M-f>', 'for $2 in $1 do\n\t$3\nend')
		sm('<M-f><M-i>', 'for $2 in ipairs($1) do\n\t$3\nend')
		sm('<M-f><M-p>', 'for $2 in pairs($1) do\n\t$3\nend')
	end

	if ft == 'html' or ft:find('scriptreact') then
		m('<M-x>', ' className="" <Left><Left>')
		m('<M-d>', '<LT>div<CR>><CR><LT>/div><C-O>O')
		m('<M-h>/', function()
			local s = fn.input('<Name/>: ')
			return '<LT>' .. s .. '<CR>/><C-O>O'
		end)
		m('<M-h>', function()
			local s = fn.input('<Name>: ')
			return '<LT>' .. s .. '<CR>><CR><LT>/' .. s .. '><C-O>O'
		end)
	end

	if ft == 'rust' then
		sm('<M-x>se', 'if let Some($2) = $1 else {\n\t$3\n};')
		m('<M-!>a', 'assert!();<Left><Left>')
		m('<M-!>da', 'debug_assert!();<Left><Left>')
		m('<M-!>f', 'format!("")<Left><Left>')
		m('<M-!>m', 'macro_rules! ')
		m('<M-!>p', 'println!();<Left><Left>')
		m('<M-!>t', 'todo!();<Left><Left>')
		m('<M-!>u', 'unreachable!();<Left><Left>')
		m('<M-!>w', 'write!("")<Left><Left>')
		m('<M-e>', 'else if ')
		m('<M-e><CR>', function()
			local semi = fn.getline('.'):find('%a') and ';' or ''
			return ' else {<CR>}' .. semi .. '<C-O>O'
		end)
		m('<M-f>', 'for ')
		m('<M-i>', 'if ')
		m('<M-l>', 'let ')
		m('<M-s>', 'Some()<Left>')
		m('<M-o>', 'Ok()<Left>')
		m('<M-m>', 'mut ')
		m('<M-w>', 'while ')
	end
end
