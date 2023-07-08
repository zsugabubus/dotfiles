local Repository = require('git.repository')
local buffer = require('git.buffer')
local cli = require('git.cli')
local utils = require('git.utils')

local function alias(repo, name)
	if
		utils.execute(cli.make_args(repo, {
			'config',
			'alias.' .. name,
		}, true))
	then
		return name
	end
end

return function(opts)
	if opts.range == 2 and opts.args == '' then
		local file = vim.fn.expand('%:p')
		local buf = vim.api.nvim_create_buf(true, false)
		vim.b[buf].git_use_preview = true
		buffer.buf_init(buf)
		vim.bo[buf].filetype = 'git'

		vim.cmd.vsplit()
		vim.cmd.buffer(buf)

		local repo = Repository.from_current_buf()

		buffer.buf_pipe(buf, {
			args = {
				alias(repo, 'log-vim-patch') or 'log',
				string.format('-L%d,%d:%s', opts.line1, opts.line2, file),
			},
		})
	else
		vim.cmd.enew()

		local buf = vim.api.nvim_get_current_buf()
		vim.b[buf].git_use_preview = true
		buffer.buf_init(buf)

		local repo = Repository.from_current_buf()

		local args = opts.fargs
		table.insert(args, 1, alias(repo, 'log-vim') or 'log')

		vim.fn.termopen(cli.make_args(repo, args, true))
	end
end
