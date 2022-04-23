local V = vim.api
local ns = V.nvim_create_namespace('showempty')
local attached = {}

local function detach_from_buffer(buffer)
	if (buffer or 0) == 0 then
		buffer = V.nvim_get_current_buf()
	end
	attached[buffer] = nil
	V.nvim_buf_clear_namespace(buffer, ns, 0, -1)
end

return {
	attach_to_buffer=function(buffer)
		if (buffer or 0) == 0 then
			buffer = V.nvim_get_current_buf()
		end
		if attached[buffer] then
			return
		end

		local fillchar = V.nvim_get_option('listchars'):match('space:([^,]+)') or '·';
		local opts = {
			virt_text={
				{(fillchar):rep(500), "Whitespace"},
			},
		}

		V.nvim_buf_clear_namespace(buffer, ns, 0, -1)
		for lnum=0, V.nvim_buf_line_count(buffer) - 1 do
			V.nvim_buf_set_extmark(buffer, ns, lnum, 0, opts)
		end

		V.nvim_buf_attach(buffer, false, {
			on_lines=function(_, changedtick, firstline, lastline, new_lastline)
				for lnum=lastline, new_lastline do
					V.nvim_buf_set_extmark(buffer, ns, lnum, 0, opts)
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
			buffer = V.nvim_get_current_buf()
		end
		return attached[buffer] or false
	end
}
