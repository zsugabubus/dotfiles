local keymap = vim.api.nvim_set_keymap

local NOREMAP_SILENT = {
	noremap = true,
	silent = true,
}

-- Inner line.
keymap('v', 'il', '_og_', NOREMAP_SILENT)
keymap('o', 'il', ':normal vil<CR>', NOREMAP_SILENT)

-- Outer line.
keymap('v', 'al', '0o$h', NOREMAP_SILENT)
keymap('o', 'al', ':normal val<CR>', NOREMAP_SILENT)

-- Indentation.
keymap('v', 'ii', '', {
	callback = function()
		local normal = vim.cmd.normal
		local search = vim.fn.search

		local n = vim.fn.indent(vim.fn.prevnonblank('.'))

		normal({ bang = true, args = { 'V' } })
		if search(string.format([[\v\n\s*%%<%dv\S]], n + 1), '') == 0 then
			normal({ bang = true, args = { 'G' } })
		end

		normal({ bang = true, args = { 'o' } })
		if
			search(string.format([[\v^\zs\s*%%<%dv\S.*\n\zs]], n + 1), 'eb') == 0
		then
			normal({ bang = true, args = { 'gg' } })
		end
	end,
})
keymap('o', 'ii', ':normal vii<CR>', NOREMAP_SILENT)
