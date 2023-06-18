local function alias(repo, name)
	local Cli = require('git.cli')
	local Utils = require('git.utils')

	if
		Utils.execute(Cli.make_args(repo, {
			'config',
			'alias.' .. name,
		}, true))
	then
		return name
	end
end

return function(opts)
	local Buffer = require('git.buffer')
	local Repository = require('git.repository')

	if opts.range == 2 and opts.args == '' then
		local file = vim.fn.expand('%:p')
		local buf = vim.api.nvim_create_buf(true, false)
		vim.b[buf].git_use_preview = true
		Buffer.buf_init(buf)
		vim.bo[buf].filetype = 'git'

		vim.cmd.vsplit()
		vim.cmd.buffer(buf)

		local repo = Repository.from_current_buf()

		Buffer.buf_pipe(buf, {
			args = {
				alias(repo, 'log-vim-patch') or 'log',
				string.format('-L%d,%d:%s', opts.line1, opts.line2, file),
			},
		})
	else
		local Cli = require('git.cli')

		vim.cmd.enew()

		local buf = vim.api.nvim_get_current_buf()
		vim.b[buf].git_use_preview = true
		Buffer.buf_init(buf)

		local repo = Repository.from_current_buf()

		local args = opts.fargs
		table.insert(args, 1, alias(repo, 'log-vim') or 'log')

		vim.fn.termopen(Cli.make_args(repo, args, true))
	end
end
