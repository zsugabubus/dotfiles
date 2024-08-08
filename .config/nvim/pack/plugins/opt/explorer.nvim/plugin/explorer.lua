local api = vim.api
local cmd = vim.cmd
local fn = vim.fn
local uv = vim.uv

local autocmd = api.nvim_create_autocmd

local group = api.nvim_create_augroup('explorer', {})

local function dir_empty()
	-- Do nothing.
end

local function dir(path)
	local handle = uv.fs_scandir(path)
	if handle then
		return uv.fs_scandir_next, handle
	end
	return dir_empty
end

local function find(t, base, limit)
	if limit <= 0 then
		return
	end

	for name, kind in dir(base == '' and '.' or base) do
		local path = base .. name
		if kind == 'directory' then
			table.insert(t, path .. '/')
			find(t, path .. '/', limit - 1)
		else
			table.insert(t, path)
		end
	end
end

autocmd('BufEnter', {
	group = group,
	nested = true,
	callback = function(opts)
		if string.sub(opts.match, 1, 1) ~= '/' then
			return
		end

		local bo = vim.bo
		if bo.buftype ~= '' then
			return
		end

		local b = vim.b
		if b.loaded_explorer then
			return
		end
		b.loaded_explorer = true

		if fn.isdirectory(opts.match) == 0 then
			return
		end

		bo.buftype = 'nofile'
		bo.swapfile = false
		bo.modeline = false
		bo.filetype = 'directory'

		autocmd('BufReadCmd', {
			group = group,
			buffer = 0,
			nested = true,
			callback = function(opts)
				local root = fn.fnamemodify(opts.match, ':p:.')
				local recursive = string.match(opts.file, '//$')

				local lines = {}
				find(lines, root, recursive and math.huge or 1)
				table.sort(lines)

				api.nvim_buf_set_lines(0, 0, -1, true, lines)
			end,
		})

		autocmd({ 'DirChanged', 'BufFilePost' }, {
			buffer = 0,
			nested = true,
			callback = function()
				cmd.edit()
			end,
		})

		local keymap = api.nvim_buf_set_keymap
		keymap(0, 'n', '<Plug>(explorer-goto-parent)', '', {
			callback = function()
				cmd.edit(fn.fnameescape(fn.expand('%:p:h:h')))
			end,
		})
		keymap(0, 'n', '<Plug>(explorer-recursive)', ':file %//<CR>', {
			callback = function()
				cmd.file(fn.fnameescape(string.gsub(fn.expand('%'), '/+$', '') .. '//'))
			end,
		})
		keymap(0, 'n', '<Plug>(explorer-cd)', ':cd <C-r>%<CR>:edit .<CR>', {})

		cmd.edit()
	end,
})
