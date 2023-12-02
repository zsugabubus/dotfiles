local api = vim.api
local cmd = vim.cmd
local fn = vim.fn

local M = {}

function M.fold(opts)
	opts = opts or {}
	opts.context = opts.context or 0
	assert(opts.context >= 0)

	cmd.normal({ args = { 'zE' }, bang = true })

	local fold_start = 1
	local last_match = 0
	local last_lnum = api.nvim_buf_line_count(0)

	while fold_start < last_lnum do
		api.nvim_win_set_cursor(0, { last_match + 1, 0 })
		local match = fn.search('', 'cW')

		if match == 0 then
			cmd.fold({ range = { fold_start, last_lnum } })
			break
		end

		local fold_end = match - opts.context - 1
		if fold_start < fold_end then
			cmd.fold({ range = { fold_start, fold_end } })
		end

		fold_start = match + opts.context + 1
		last_match = match
	end

	api.nvim_win_set_cursor(0, { 1, 0 })
	api.nvim_set_option_value('foldenable', true, { scope = 'local' })
end

return M
