local api = vim.api
local fn = vim.fn

local user_command = api.nvim_create_user_command
local autocmd = api.nvim_create_autocmd

local ANY_BANG = { nargs = '*', bang = true }
local ANY_BANG_COUNT = { nargs = '*', bang = true, count = true }

local group = api.nvim_create_augroup('qf', {})

local M = setmetatable({}, {
	__index = function(t, k)
		local function f(...)
			return require('qf')[k](...)
		end
		t[k] = f
		return f
	end,
})

user_command('Qf', M.list_cmd, {
	nargs = '?',
	count = true,
	desc = 'Edit quickfix list',
})

user_command('Qedit', M.edit_cmd, {
	nargs = '?',
	count = true,
	desc = 'Edit quickfix lines',
})

user_command('Qstack', M.stack_cmd, {
	desc = 'Edit quickfix list stack',
})

for _, s in ipairs({
	'CNext',
	'CNfile',
	'Cabove',
	'Caddbuffer',
	'Caddexpr',
	'Caddfile',
	'Cafter',
	'Cbefore',
	'Cbelow',
	'Cbottom',
	'Cbuffer',
	'Cc',
	'Cexpr',
	'Cfile',
	'Cfirst',
	'Chistory',
	'Clast',
	'Cnext',
	'Cnfile',
	'Cpfile',
	'Cprevious',
	'Crewind',
	'Cwindow',
}) do
	user_command(s, M.proxy_cmd, ANY_BANG_COUNT)
end

for _, s in ipairs({
	'Cclose',
	'Cgetbuffer',
	'Cgetexpr',
	'Cgetfile',
	'Cnewer',
	'Colder',
	'Copen',
}) do
	user_command(s, M.proxy_cmd, ANY_BANG)
end

autocmd('BufReadCmd', {
	group = group,
	pattern = 'qf://*',
	nested = true,
	callback = M.read_qf_autocmd,
})

autocmd('BufReadCmd', {
	group = group,
	pattern = 'qe://*',
	nested = true,
	callback = M.read_qe_autocmd,
})

autocmd('QuickFixCmdPost', {
	group = group,
	nested = true,
	callback = M.cmdpost_autocmd,
})
