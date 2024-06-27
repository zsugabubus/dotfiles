local api = vim.api
local bo = vim.bo
local cmd = vim.cmd
local fn = vim.fn

local group = api.nvim_create_augroup('arglist', {})

api.nvim_create_user_command('Args', function()
	cmd.edit('args://')
	bo.bufhidden = 'unload'
end, {})

api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = 'args://',
	nested = true,
	callback = function()
		bo.buftype = 'acwrite'
		bo.swapfile = false
		bo.modeline = false
		api.nvim_buf_set_lines(0, 0, -1, true, fn.argv())
		api.nvim_win_set_cursor(0, { fn.argidx() + 1, 0 })
		api.nvim_buf_set_keymap(0, 'n', 'gf', '', {
			callback = function()
				local row = api.nvim_win_get_cursor(0)[1]
				cmd.argument(row)
			end,
			nowait = true,
		})
		api.nvim_buf_set_keymap(0, 'n', '<CR>', 'gf', { nowait = true })
	end,
})

api.nvim_create_autocmd('BufWriteCmd', {
	group = group,
	pattern = 'args://',
	nested = true,
	callback = function()
		local lines = api.nvim_buf_get_lines(0, 0, -1, true)
		pcall(cmd.argdelete, '*')
		for _, line in ipairs(lines) do
			cmd(string.format('$argadd %s', fn.fnameescape(line)))
		end
		bo.modified = false
		api.nvim_echo({ { 'arglist written', 'Normal' } }, false, {})
	end,
})
