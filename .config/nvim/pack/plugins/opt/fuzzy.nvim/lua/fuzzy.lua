local fn = vim.fn

local shesc = fn.shellescape

local tmpfile1 = fn.tempname()
local tmpfile2 = fn.tempname()

local function choose(opts)
	vim.cmd(string.format(
		[[
		keepalt enew|
		setlocal nobuflisted bufhidden=wipe noswapfile hidden nonumber norelativenumber filetype=|
		autocmd TermClose <buffer> silent! keepalt %d buffer|
		autocmd TermOpen <buffer> startinsert
	]],
		fn.bufnr()
	))

	local stdout = tmpfile1

	local function run(cmd)
		fn.termopen(cmd, {
			on_exit = function(_, code)
				if code ~= 0 then
					return
				end

				local f = assert(io.open(stdout))
				local s = assert(f:read('*a'))
				assert(f:close())

				local answer = string.sub(s, 1, #s - 1)
				opts.callback(answer)
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
				'fzr --select-1 --read0 <%s >%s',
				shesc(stdin),
				shesc(stdout)
			)
		)
	elseif opts.choices_cmd0 then
		run(
			string.format(
				'%s | fzr --select-1 --read0 >%s',
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
		choices = choices,
		callback = function(s)
			vim.cmd.buffer({ count = assert(tonumber(string.match(s, '%d+'))) })
		end,
	})
end

local function files()
	choose({
		choices_cmd0 = 'rg --files --iglob=!.git --hidden -0',
		callback = function(s)
			vim.cmd.edit(fn.fnameescape(s))
		end,
	})
end

return {
	files = files,
	buffers = buffers,
}
