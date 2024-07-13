local api = vim.api

local autocmd = api.nvim_create_autocmd
local keymap = api.nvim_set_keymap
local user_command = api.nvim_create_user_command

local group = api.nvim_create_augroup('git', {})

local function make_read_autocmd(pattern, package)
	autocmd('BufReadCmd', {
		group = group,
		pattern = pattern,
		nested = true,
		callback = function(...)
			return require(package).handle_read_autocmd(...)
		end,
	})
end

make_read_autocmd('git://*', 'git.show')
make_read_autocmd('git-blame://*', 'git.blame')
make_read_autocmd('git-log://*', 'git.log')

local function make_user_command(names, package, opts)
	local function callback(...)
		return require(package).handle_user_command(...)
	end

	if opts.nargs then
		function opts.complete(...)
			local fn = require(package).handle_complete
			if fn then
				return fn(...)
			end
		end
	end

	for _, name in ipairs(names) do
		user_command(name, callback, opts)
	end
end

make_user_command({ 'Gcd', 'Glcd', 'Gtcd' }, 'git.cd', {
	nargs = '?',
})

make_user_command({ 'Gshow', 'Gs' }, 'git.show', {
	nargs = '*',
})

make_user_command(
	{
		'Gedit',
		'Ge',
		'Gtabedit',
		'Gtabe',
		'Gsplit',
		'Gsp',
		'Gvsplit',
		'Gvs',
	},
	'git.edit',
	{
		nargs = 1,
	}
)

make_user_command({ 'Gdiff' }, 'git.diff', {
	nargs = '?',
})

make_user_command({ 'Gblame' }, 'git.blame', {})

make_user_command({ 'Gsign' }, 'git.sign', {})

make_user_command({ 'Glog', 'Gl' }, 'git.log', {
	nargs = '*',
	range = true,
	bang = true,
})

keymap('n', '<Plug>(git-goto-file)', '', {
	callback = function()
		require('git.buffer').goto_object()
	end,
})

_G.git_status = function(...)
	local fn = require('git.repository').status
	_G.git_status = fn
	return fn(...)
end
