local api = vim.api
local fn = vim.fn

local group = api.nvim_create_augroup('explorer', {})

local function is_dir(path)
	return fn.isdirectory(path) ~= 0
end

api.nvim_create_autocmd('BufEnter', {
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

		if not is_dir(opts.match) then
			return
		end

		local edit = vim.cmd.edit

		api.nvim_create_autocmd('BufReadCmd', {
			group = group,
			buffer = 0,
			nested = true,
			callback = function(opts)
				local dirpath = fn.fnamemodify(opts.match, ':p:.')
				local recursive = string.match(opts.file, '//$')

				local lines = {}
				for name in
					vim.fs.dir(dirpath == '' and '.' or dirpath, {
						depth = recursive and math.huge or 1,
					})
				do
					local path = dirpath .. name
					lines[#lines + 1] = path .. (is_dir(path) and '/' or '')
				end
				table.sort(lines)
				api.nvim_buf_set_lines(0, 0, -1, true, lines)

				bo.buftype = 'nofile'
				bo.swapfile = false
				bo.filetype = 'directory'
			end,
		})

		api.nvim_create_autocmd({ 'DirChanged', 'BufFilePost' }, {
			buffer = 0,
			nested = true,
			callback = function()
				edit()
			end,
		})

		local keymap = api.nvim_buf_set_keymap
		keymap(0, 'n', '<Plug>(explorer-goto-parent)', '', {
			callback = function()
				edit(fn.expand('%:p:h:h'))
			end,
		})
		keymap(0, 'n', '<Plug>(explorer-recursive)', ':file %/<CR>', {})
		keymap(0, 'n', '<Plug>(explorer-cd)', ':cd <C-r>%<CR>:edit .<CR>', {})

		edit()
	end,
})
