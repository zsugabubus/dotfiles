local V = vim.api
local ns = V.nvim_create_namespace('showindent')
local attached = {}

local function detach_from_buffer(buffer)
	if (buffer or 0) == 0 then
		buffer = V.nvim_get_current_buf()
	end
	attached[buffer] = nil
	V.nvim_buf_clear_namespace(buffer, ns, 0, -1)
end

local function update_lines(buffer, fromline, toline)
	V.nvim_buf_clear_namespace(buffer, ns, fromline, toline)

	local listchars = V.nvim_get_option('listchars')
	local space = '·'
	for m in listchars:gmatch('space:([^,]+)') do
		space = m
	end
	local tab = ' │'
	for m in listchars:gmatch('tab:([^,]+)') do
		tab = m
	end
	local tab_head, tab_rep =
		tab:match('^([\x01-\x7f\xc2-\xf4][\x80-\xbf]*)(.*)$')

	local expandtab = V.nvim_buf_get_option(buffer, 'expandtab')
	local tabstop = V.nvim_buf_get_option(buffer, 'tabstop')
	local shiftwidth = V.nvim_buf_get_option(buffer, 'shiftwidth')
	if shiftwidth == 0 then
		shiftwidth = tabstop
	end
	local indentexpr = V.nvim_buf_get_option(buffer, 'indentexpr')
	local eval = false
	local lnumoff = 0
	if indentexpr ~= '' then
		eval = true
	elseif V.nvim_buf_get_option(buffer, 'cindent') then
		indentexpr = 'cindent'
	elseif V.nvim_buf_get_option(buffer, 'lisp') then
		indentexpr = 'lispindent'
	elseif V.nvim_buf_get_option(buffer, 'smartindent') then
		lnumoff = -1
		indentexpr = 'indent'
	else
		return
	end

	for index, line in
		ipairs(V.nvim_buf_get_lines(buffer, fromline, toline, false))
	do
		-- Skip line if not blank.
		if #line > 0 then
			goto next_line
		end

		local lnum1 = fromline + index
		local lnum0 = lnum1 - 1

		local indent
		if eval then
			V.nvim_set_vvar('lnum', lnum1)
			V.nvim_command(
				('sandbox let v:errmsg = (%s)'):format(indentexpr:gsub('\n', ' '))
			)
			indent = V.nvim_get_vvar('errmsg')
		else
			indent = V.nvim_call_function(indentexpr, {
				lnum1 + lnumoff,
			})
		end

		-- Skip if not number.
		indent = tonumber(indent)
		if not indent then
			goto next_line
		end

		local indentstr
		if not expandtab then
			indentstr = (
				(tab_head .. tab_rep:rep(tabstop - 1)):rep(math.floor(indent / tabstop))
				.. space:rep(indent % tabstop)
			)
		else
			indentstr = space:rep(indent)
		end

		V.nvim_buf_set_extmark(buffer, ns, lnum0, 0, {
			virt_text = { { indentstr, 'Whitespace' } },
			virt_text_pos = 'overlay',
		})

		::next_line::
	end
end

return {
	attach_to_buffer = function(buffer)
		if (buffer or 0) == 0 then
			buffer = V.nvim_get_current_buf()
		end
		if attached[buffer] then
			return
		end

		update_lines(buffer, 0, V.nvim_buf_line_count(buffer) - 1)

		V.nvim_buf_attach(buffer, false, {
			on_lines = function(_, changedtick, firstline, lastline, new_lastline)
				-- Changing indentation of last line (likely) changes indentation of
				-- empty lines following it.
				new_lastline = V.nvim_call_function('nextnonblank', {
					new_lastline + 1,
				})
				update_lines(buffer, firstline, new_lastline)
				return not attached[buffer]
			end,
			on_detach = detach_from_buffer,
		})
		attached[buffer] = true
	end,
	reattach = function(buffer)
		local buffers

		if buffer == 0 then
			buffer = vim.api.nvim_get_current_buf()
		end
		if buffer then
			if not attached[buffer] then
				return
			end
			buffers = { buffer }
		else
			buffers = attached
		end

		for _, buffer in ipairs(buffers) do
			update_lines(buffer, 0, -1)
		end
	end,
	detach_from_buffer = detach_from_buffer,
	is_buffer_attached = function(buffer)
		if (buffer or 0) == 0 then
			buffer = vim.api.nvim_get_current_buf()
		end
		return attached[buffer] or false
	end,
}
