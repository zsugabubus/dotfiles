local api = vim.api
local autocmd = api.nvim_create_autocmd
local config = vim.g.varign or {}
local user_command = api.nvim_create_user_command

local group = api.nvim_create_augroup('varign', {})

local auto_attach = config.auto_attach

if auto_attach ~= false then
	autocmd('BufReadPost', {
		group = group,
		callback = function(opts)
			local buf = opts.buf

			if type(auto_attach) == 'function' then
				if not auto_attach(buf) then
					return
				end
			else
				local s = api.nvim_buf_get_lines(buf, 0, 1, false)[1]
				if not string.find(s, '^[^\t]+\t[^\t]+\t[^\t]+') then
					return
				end
			end

			require('varign').attach_to_buffer(buf)
		end,
	})
end

user_command('Varign', function()
	require('varign').attach_to_buffer(api.nvim_get_current_buf())
end, {})
