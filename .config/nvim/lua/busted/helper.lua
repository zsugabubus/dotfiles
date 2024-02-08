local busted = require('busted')

local function reset_all()
	-- Buffers must be deleted before resetting 'undolevels' otherwise we may get
	-- "E439: undo list corrupt".
	vim.cmd([[
		%bdelete!
		set all&
		clearjumps
		mapclear
		mapclear!
		abclear
		comclear
		highlight clear
		messages clear
	]])
	vim.api.nvim_clear_autocmds({})
end

local runtime_files
local function load_plugins()
	vim.opt.runtimepath:append('.')

	if not runtime_files then
		runtime_files = {}
		vim.list_extend(
			runtime_files,
			vim.api.nvim_get_runtime_file('plugin/**/*.vim', true)
		)
		vim.list_extend(
			runtime_files,
			vim.api.nvim_get_runtime_file('plugin/**/*.lua', true)
		)
		runtime_files = vim.tbl_filter(function(file)
			return vim.startswith(file, './')
		end, runtime_files)
	end

	for _, f in ipairs(runtime_files) do
		vim.cmd.source({ args = { f } })
	end
end

busted.subscribe({ 'suite', 'start' }, function()
	busted.stub(vim.api, 'nvim_echo')
	reset_all()
	load_plugins()
end)

-- before_each() is executed before { 'test', 'start' } so we fall back to
-- 'end' event.
busted.subscribe({ 'test', 'end' }, function()
	reset_all()
	load_plugins()
end)
