local group = vim.api.nvim_create_augroup('git', {})

vim.api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = 'git://*',
	nested = true,
	callback = function(opts)
		return require('git.buffer').autocmd(opts)
	end,
})

vim.api.nvim_create_autocmd('BufReadCmd', {
	group = group,
	pattern = 'git-blame://*',
	nested = true,
	callback = function(opts)
		return require('git.blame').autocmd(opts)
	end,
})

_G.git_status = function()
	local fn = require('git.repository').status
	_G.git_status = fn
	return fn()
end

vim.api.nvim_create_user_command('Gblame', function(opts)
	return require('git.command.blame')(opts)
end, {
	nargs = '*',
	desc = 'Git blame',
})

vim.api.nvim_create_user_command('Gdiff', function(opts)
	return require('git.command.diff')(opts)
end, {
	nargs = '?',
	desc = 'Git diff',
})

local opts = {
	nargs = '*',
	range = true,
	desc = 'Git log',
}
for _, x in ipairs({ 'l', 'log' }) do
	vim.api.nvim_create_user_command('G' .. x, function(opts)
		return require('git.command.log')(opts)
	end, opts)
end

local opts = {
	nargs = '*',
	complete = function(...)
		return require('git.complete.show')(...)
	end,
	desc = 'Git show',
}
for _, x in ipairs({ 'Gs', 'Gshow' }) do
	vim.api.nvim_create_user_command(x, function(opts)
		return require('git.command.show')(opts)
	end, opts)
end

local opts = {
	nargs = '?',
	complete = function(...)
		return require('git.complete.cd')(...)
	end,
	desc = 'Cd to git directory',
}
for _, x in ipairs({ 'cd', 'lcd', 'tcd' }) do
	vim.api.nvim_create_user_command('G' .. x, function(opts)
		return require('git.command.cd')(x, opts)
	end, opts)
end

local opts = {
	nargs = 1,
	complete = function(...)
		return require('git.complete.edit')(...)
	end,
	desc = 'Edit git file',
}
for _, x in ipairs({
	'e',
	'edit',
	'tabe',
	'tabedit',
	'sp',
	'split',
	'vs',
	'vsplit',
}) do
	vim.api.nvim_create_user_command('G' .. x, function(opts)
		return require('git.command.edit')(x, opts)
	end, opts)
end

local opts = {
	nargs = '*',
	bang = true,
	desc = 'Git grep',
}
for _, x in ipairs({
	'gr',
	'grep',
	'grepa',
	'grepadd',
	'lgr',
	'lgrep',
	'lgrepa',
	'lgrepadd',
}) do
	vim.api.nvim_create_user_command('G' .. x, function(opts)
		return require('git.command.show')(opts)
	end, opts)
end
