local ns = vim.api.nvim_create_namespace('showempty')
local attached = {}

local function detach_from_buffer(buffer)
	if (buffer or 0) == 0 then
		buffer = vim.api.nvim_get_current_buf()
	end
	attached[buffer] = nil
	vim.api.nvim_buf_clear_namespace(buffer, ns, 0, -1)
end

return {
	attach_to_buffer=function(buffer)
		if (buffer or 0) == 0 then
			buffer = vim.api.nvim_get_current_buf()
		end
		if attached[buffer] then
			return
		end

		-- FIXME
		-- vim.api.nvim_win_get_width(0)
		-- nvim.ex.augroup("END")
		local fillchar = vim.api.nvim_get_option('listchars'):match('space:([^,]+)') or '·';
		local CHUNKS = {{(fillchar):rep(500), "Whitespace"}}

		vim.api.nvim_buf_clear_namespace(buffer, ns, 0, -1)
		for lnum=0,vim.api.nvim_buf_line_count(buffer)-1 do
			vim.api.nvim_buf_set_virtual_text(buffer, ns, lnum, CHUNKS, {})
		end

		vim.api.nvim_buf_attach(buffer, false, {
			on_lines=function(_, changedtick, firstline, lastline, new_lastline)
				for lnum=lastline,new_lastline do
					vim.api.nvim_buf_set_virtual_text(buffer, ns, lnum, CHUNKS, {})
				end
				return not attached[buffer]
			end,
			on_detach=detach_from_buffer
		})
		attached[buffer] = true
	end,
	detach_from_buffer=detach_from_buffer,
	is_buffer_attached=function(buffer)
		if (buffer or 0) == 0 then
			buffer = vim.api.nvim_get_current_buf()
		end
		return attached[buffer] or false
	end
}
