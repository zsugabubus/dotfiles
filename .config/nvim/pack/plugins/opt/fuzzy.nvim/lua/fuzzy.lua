local api = vim.api
local cmd = vim.cmd
local fn = vim.fn

local shesc = fn.shellescape

local term_buf
local tmpfile1 = fn.tempname()
local tmpfile2 = fn.tempname()

local function choose(opts)
	local cur_buf = api.nvim_get_current_buf()

	if not term_buf or not api.nvim_buf_is_valid(term_buf) then
		term_buf = api.nvim_create_buf(false, true)
	end

	local group = api.nvim_create_augroup('fuzzy', {})

	api.nvim_create_autocmd('TermOpen', {
		group = group,
		buffer = term_buf,
		callback = function()
			cmd('startinsert|keepalt file ' .. opts.title)
		end,
	})

	api.nvim_create_autocmd('TermClose', {
		group = group,
		buffer = term_buf,
		callback = function()
			if api.nvim_buf_is_valid(cur_buf) then
				cmd('keepalt buffer ' .. cur_buf)
			end
		end,
	})

	cmd('keepalt buffer ' .. term_buf)
	cmd('noautocmd setlocal nonumber norelativenumber nomodified')

	local stdout = tmpfile1

	local function run(cmdline)
		fn.termopen(cmdline, {
			on_exit = function(_, code)
				if code ~= 0 then
					return
				end

				local f = assert(io.open(stdout))
				local s = assert(f:read('*a'))
				assert(f:close())

				local t = {}

				for x in string.gmatch(s, '(%Z*)%z') do
					table.insert(t, x)
				end

				vim.schedule(function()
					opts.callback(t)
				end)
			end,
		})
	end

	if opts.choices then
		local stdin = tmpfile2

		local f = assert(io.open(stdin, 'w'))
		assert(f:write(table.concat(opts.choices, '\0')))
		assert(f:close())

		run(
			string.format(
				'fzr --select-1 --exit-0 --read0 --print0 <%s >%s',
				shesc(stdin),
				shesc(stdout)
			)
		)
	elseif opts.choices_cmd0 then
		run(
			string.format(
				'%s | fzr --select-1 --exit-0 --read0 --print0 >%s',
				opts.choices_cmd0,
				shesc(stdout)
			)
		)
	else
		error('no choices')
	end
end

local function buffers()
	local choices = {}

	local bufs = fn.getbufinfo({ buflisted = true })
	local current = fn.bufnr()

	table.sort(bufs, function(a, b)
		return a.lastused > b.lastused
	end)

	for _, buf in ipairs(bufs) do
		if buf.bufnr ~= current then
			local name = fn.bufname(buf.bufnr)

			if name == '' then
				name = '[No Name]'
			end

			local flags = buf.changed == 0 and '' or '+'

			table.insert(choices, string.format('%3d%3s\t%s', buf.bufnr, flags, name))
		end
	end

	choose({
		title = 'Select buffer',
		choices = choices,
		callback = function(t)
			local bufnr = assert(tonumber(string.match(t[1], '%d+')))
			cmd.buffer(bufnr)
		end,
	})
end

local function files()
	choose({
		title = 'Select file',
		choices_cmd0 = 'rg --files --sortr=modified --iglob=!.git --hidden -0',
		callback = function(t)
			local path = assert(t[1])
			cmd.edit(fn.fnameescape(path))
		end,
	})
end

local function tags()
	local choices = {}
	local counts = {}
	local choice_pri = {}

	for _, tag in ipairs(fn.taglist('.', fn.expand('%:p'))) do
		local s = string.format('%s\t\x1b[37m%s', tag.name, tag.filename)
		local n = (counts[tag.name] or 0) + 1
		counts[tag.name] = n
		choice_pri[s] = n
		table.insert(choices, s)
	end

	choose({
		title = 'Select tag',
		choices = choices,
		callback = function(t)
			local s = t[1]
			local pri = assert(choice_pri[s])
			local name = assert(string.match(s, '^[^\t]+'))
			cmd(string.format('%d tag %s', pri, name))
		end,
	})
end

return {
	files = files,
	buffers = buffers,
	tags = tags,
}
