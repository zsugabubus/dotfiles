local api = vim.api

local autocmd = api.nvim_create_autocmd
local config = vim.g.varign or {}
local user_command = api.nvim_create_user_command

local group = api.nvim_create_augroup('varign', {})

if config.auto_attach ~= false then
	autocmd('BufReadPost', {
		group = group,
		callback = function(opts)
			local buf = opts.buf
			local s = api.nvim_buf_get_lines(buf, 0, 1, false)[1]
			if not s:find('^[^\t]+\t[^\t]+\t[^\t]') then
				return
			end
			if s:find('[%z\x01-\x08\x0a-\x1f]') then
				return
			end
			require('varign').attach_to_buffer(buf)
		end,
	})
end

user_command('Varign', function()
	require('varign').attach_to_buffer(api.nvim_get_current_buf())
end, {})
