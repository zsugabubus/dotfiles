vim.api.nvim_set_keymap('', '<Plug>(jumpmotion)', '', {
	callback = function()
		local ok, c = pcall(vim.fn.getcharstr)
		if not ok then
			return
		end

		local function pat(c)
			return (c == '\\' and '\\\\' or c) .. '\\+'
		end

		local jump = require('jumpmotion').jump

		if c == '/' and vim.fn.getreg('/') ~= '' then
			jump(vim.fn.getreg('/') .. '\\V\\|' .. pat(c))
		elseif c == ';' and vim.fn.getcharsearch().char ~= '' then
			jump('\\V' .. pat(vim.fn.getcharsearch().char) .. '\\|' .. pat(c))
		elseif c == '$' then
			jump('\\V\\$\\|' .. pat(c))
		else
			jump('\\V' .. pat(c))
		end
	end,
})
