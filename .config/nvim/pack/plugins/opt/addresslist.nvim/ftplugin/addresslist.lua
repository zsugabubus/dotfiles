local buf_user_command = vim.api.nvim_buf_create_user_command

local function get_mail_buf()
	local list = vim.fn.getbufinfo({ buflisted = true })
	table.sort(list, function(a, b)
		return a.lastused > b.lastused
	end)
	for _, info in ipairs(list) do
		if vim.bo[info.bufnr].filetype == 'mail' then
			return info.bufnr
		end
	end
end

local function append_header_value(buf, header, value)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, 1000, false)
	for i, line in ipairs(lines) do
		local s = line:match('^' .. header .. ': *(.*)')
		if s then
			local append = s ~= ''
			while (lines[i + 1] or ''):sub(1, 1) == '\t' do
				i = i + 1
				line = lines[i]
				append = #line > 1
			end
			local new_lines
			if append then
				local appended = line .. ', ' .. value
				local wrap = vim.api.nvim_buf_call(buf, function()
					local tw = vim.bo.textwidth
					return tw ~= 0 and vim.fn.strdisplaywidth(appended .. ',') > tw
				end)
				if wrap then
					new_lines = { line .. ',', '\t' .. value }
				else
					new_lines = { appended }
				end
			else
				new_lines = { line .. value }
			end
			vim.api.nvim_buf_set_lines(buf, i - 1, i, false, new_lines)
			return
		end
	end
	error('Header not found')
end

local function add_address(header)
	local mail_buf = assert(get_mail_buf(), 'No mail buffer found')
	local address = vim.api.nvim_get_current_line()
	append_header_value(mail_buf, header, address)
	vim.notify(('Added %s: %s'):format(header, address), vim.log.levels.INFO)
end

buf_user_command(0, 'MailTo', function()
	add_address('To')
end, { desc = 'Add To:' })

buf_user_command(0, 'MailCc', function()
	add_address('Cc')
end, { desc = 'Add Cc:' })

buf_user_command(0, 'MailBcc', function()
	add_address('Bcc')
end, { desc = 'Add Bcc:' })
