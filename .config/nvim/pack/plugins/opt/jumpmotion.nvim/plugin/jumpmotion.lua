vim.api.nvim_set_keymap('', '<Plug>(JumpMotion)', '', {
	callback = function()
		local function rchar(c)
			return (c == '\\' and '\\\\' or c) .. '\\+'
		end

		local ok, c = pcall(vim.fn.getcharstr)
		if not ok then
			return
		end
		local pattern
		if c == '\r' then
			pattern = vim.fn.getreg('/')
		elseif c == ';' and vim.fn.getcharsearch().char ~= '' then
			pattern = '\\V' .. rchar(vim.fn.getcharsearch().char) .. '\\|' .. rchar(c)
		elseif c == '$' then
			pattern = '\\V\\$\\|' .. rchar(c)
		else
			pattern = '\\V' .. rchar(c)
		end
		require('jumpmotion').jump(pattern)
	end,
})
