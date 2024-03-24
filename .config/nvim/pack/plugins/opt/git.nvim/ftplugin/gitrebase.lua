local keymap = vim.api.nvim_buf_set_keymap

vim.b.git_use_preview = true

local function change_command(lhs, command)
	keymap(0, '', 'c' .. lhs, '', {
		nowait = true,
		silent = true,
		noremap = true,
		expr = true,
		callback = function()
			function _G._git_rebase_operatorfunc()
				vim.cmd(string.format("'[,']normal! 0ce%s", command))

				vim.o.operatorfunc = '{->0}'

				vim.cmd.normal({
					args = { 'g@_W' },
					bang = true,
				})

				vim.o.operatorfunc = 'v:lua._git_rebase_operatorfunc'
			end

			vim.o.operatorfunc = 'v:lua._git_rebase_operatorfunc'

			return 'g@_'
		end,
	})
end

change_command('d', 'drop')
change_command('e', 'edit')
change_command('f', 'fixup')
change_command('p', 'pick')
change_command('r', 'reword')
change_command('s', 'squash')

for _, x in ipairs({ 'gf', '<CR>' }) do
	keymap(0, 'n', x, '', {
		nowait = true,
		callback = function()
			return require('git.buffer').goto_object()
		end,
	})
end
