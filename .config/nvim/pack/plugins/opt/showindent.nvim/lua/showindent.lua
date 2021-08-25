local ns = vim.api.nvim_create_namespace('showindent')
local attached = {}

local function detach_from_buffer(buffer)
	if (buffer or 0) == 0 then
		buffer = vim.api.nvim_get_current_buf()
	end
	attached[buffer] = nil
	vim.api.nvim_buf_clear_namespace(buffer, ns, 0, -1)
end

local function update_lines(buffer, fromline, toline)
	vim.api.nvim_buf_clear_namespace(buffer, ns, fromline, toline)

	local listchars = vim.api.nvim_get_option('listchars')
	local space = '·'
	for _space in listchars:gmatch('space:([^,]+)') do
		space = _space
	end
	local tab = ' │'
	for _tab in listchars:gmatch('tab:([^,]+)') do
		tab = _tab
	end
	local tabta, tabab = tab:match("^([\x01-\x7f\xc2-\xf4][\x80-\xbf]*)(.*)$")

	local expandtab = vim.api.nvim_buf_get_option(buffer, 'expandtab')
	local tabstop = vim.api.nvim_buf_get_option(buffer, 'tabstop')
	local shiftwidth = vim.api.nvim_buf_get_option(buffer, 'shiftwidth')
	if shiftwidth == 0 then
		shiftwidth = tabstop
	end
	local indentexpr = vim.api.nvim_buf_get_option(buffer, 'indentexpr')
	local eval = false
	local lnumoff = 0
	if indentexpr ~= '' then
		eval = true
	elseif vim.api.nvim_buf_get_option(buffer, 'cindent') then
		indentexpr = 'cindent'
	elseif vim.api.nvim_buf_get_option(buffer, 'lisp') then
		indentexpr = 'lispindent'
	elseif vim.api.nvim_buf_get_option(buffer, 'smartindent') then
		lnumoff = -1
		indentexpr = 'indent'
	else
		return
	end

	for index, line in ipairs(vim.api.nvim_buf_get_lines(buffer, fromline, toline, false)) do
		-- Skip line if not blank.
		if #line > 0 then
			goto next_line
		end

		local lnum1 = fromline + index
		local lnum0 = lnum1 - 1

		local indent
		if eval then
			-- Evaluate 'indentexpr' in sandbox.
			vim.api.nvim_set_vvar('lnum', lnum1)
			vim.api.nvim_command('sandbox let v:errmsg = ('..indentexpr:gsub('\n', ' ')..')')
			indent = vim.api.nvim_get_vvar('errmsg')
		else
			indent = vim.api.nvim_call_function(indentexpr, {lnum1 + lnumoff})
		end

		-- Skip if not number.
		indent = tonumber(indent)
		if not indent then
			goto next_line
		end

		local indentstr

		-- FIXME: Read values from 'listchars'.
		if not expandtab then
			indentstr = (((tabstop == shiftwidth and tabab or space):rep(shiftwidth - 1)..tabta):rep(indent / shiftwidth))
		else
			indentstr = space:rep(indent - 1)
		end

		vim.api.nvim_buf_set_virtual_text(buffer, ns, lnum0, {
			{indentstr, 'Whitespace'}
		}, {})

		::next_line::
	end
end

return {
	attach_to_buffer=function(buffer)
		if (buffer or 0) == 0 then
			buffer = vim.api.nvim_get_current_buf()
		end
		if attached[buffer] then
			return
		end

		update_lines(buffer, 0, vim.api.nvim_buf_line_count(buffer) - 1)

		vim.api.nvim_buf_attach(buffer, false, {
			on_lines=function(_, changedtick, firstline, lastline, new_lastline)
				update_lines(buffer, firstline, new_lastline)
				return not attached[buffer]
			end,
			on_detach=detach_from_buffer
		})
		attached[buffer] = true
	end,
	reattach=function(buffer)
		local buffers

		if buffer == 0 then
			buffer = vim.api.nvim_get_current_buf()
		end
		if buffer then
			if not attached[buffer] then
				return
			end
			buffers = {buffer}
		else
			buffers = attached
		end

		for _, buffer in ipairs(buffers) do
			update_lines(buffer, 0, -1)
		end
	end,
	detach_from_buffer=detach_from_buffer,
	is_buffer_attached=function(buffer)
		if (buffer or 0) == 0 then
			buffer = vim.api.nvim_get_current_buf()
		end
		return attached[buffer] or false
	end
}
