local Repository = require('git.repository')
local buffer = require('git.buffer')
local cli = require('git.cli')
local utils = require('git.utils')

local api = vim.api
local cmd = vim.cmd
local fn = vim.fn

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

local function user_command(opts)
	if opts.range == 2 and opts.args == '' then
		local file = fn.expand('%:p')
		local buf = api.nvim_create_buf(true, false)
		vim.b[buf].git_use_preview = true
		buffer.buf_init(buf)
		vim.bo[buf].filetype = 'git'

		cmd.vsplit()
		cmd.buffer(buf)

		local repo = Repository.from_current_buf()

		buffer.buf_pipe(buf, {
			args = {
				alias(repo, 'log-vim-patch') or 'log',
				string.format('-L%d,%d:%s', opts.line1, opts.line2, file),
			},
		})
	else
		cmd.vsplit(fn.fnameescape('git-log://' .. opts.args))
	end
end

local function autocmd(opts)
	local buf = opts.buf

	local s = string.sub(opts.match, 11)
	local args = api.nvim_parse_cmd('Glog ' .. s, {}).args

	buffer.buf_init(buf)
	vim.b[buf].git_use_preview = true

	local repo = Repository.from_current_buf()

	if #args == 0 then
		args = { '-n100' }
	end
	table.insert(args, 1, alias(repo, 'log-vim') or 'log')

	local has_AnsiEsc = fn.exists(':AnsiEsc') == 2

	if has_AnsiEsc then
		table.insert(args, 2, '--color=always')
	end

	buffer.buf_pipe(buf, {
		args = args,
		callback = function()
			if has_AnsiEsc then
				vim.bo.modifiable = true
				cmd.AnsiEsc()
				vim.bo.modifiable = false
			end
		end,
	})
end

return {
	user_command = user_command,
	autocmd = autocmd,
}
