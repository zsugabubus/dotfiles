local autocmd = vim.api.nvim_create_autocmd
local user_command = vim.api.nvim_create_user_command

local group = vim.api.nvim_create_augroup('git', {})

autocmd('BufReadCmd', {
	group = group,
	pattern = 'git://*',
	nested = true,
	callback = function(opts)
		return require('git.buffer').autocmd(opts)
	end,
})

autocmd('BufReadCmd', {
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

user_command('Gblame', function(...)
	return require('git.command.blame')(...)
end, { nargs = '*' })

user_command('Gdiff', function(...)
	return require('git.command.diff')(...)
end, { nargs = '?' })

user_command('Gsign', function(...)
	return require('git.command.sign')(...)
end, {})

local function command_factory(package, opts)
	return function(name)
		return user_command(name, function(...)
			return require(package)(...)
		end, opts)
	end
end

local function command_with_cmd_factory(package, opts)
	return function(name)
		return user_command(name, function(opts)
			local cmd = string.sub(opts.name, 2)
			return require(package)(cmd, opts)
		end, opts)
	end
end

local command_log = command_factory('git.command.log', {
	nargs = '*',
	range = true,
})
command_log('Gl')
command_log('Glog')

local command_show = command_factory('git.command.show', {
	nargs = '*',
	complete = function(...)
		return require('git.complete.show')(...)
	end,
})
command_show('Gs')
command_show('Gshow')

local command_cd = command_with_cmd_factory('git.command.cd', {
	nargs = '?',
	complete = function(...)
		return require('git.complete.cd')(...)
	end,
})
command_cd('Gcd')
command_cd('Glcd')
command_cd('Gtcd')

local command_edit = command_with_cmd_factory('git.command.edit', {
	nargs = 1,
	complete = function(...)
		return require('git.complete.edit')(...)
	end,
})
command_edit('Ge')
command_edit('Gedit')
command_edit('Gtabe')
command_edit('Gtabedit')
command_edit('Gsp')
command_edit('Gsplit')
command_edit('Gvs')
command_edit('Gvsplit')

local command_grep = command_factory('git.command.show', {
	nargs = '*',
	bang = true,
})
command_grep('Ggr')
command_grep('Ggrep')
command_grep('Ggrepa')
command_grep('Ggrepadd')
command_grep('Glgr')
command_grep('Glgrep')
command_grep('Glgrepa')
command_grep('Glgrepadd')
