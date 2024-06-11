local api = vim.api
local strdisplaywidth = vim.fn.strdisplaywidth

local max_lines = 10000
local pad = 1

local width = setmetatable({}, {
	__mode = 'kv',
	__index = function(t, s)
		local n = strdisplaywidth(s)
		t[s] = n
		return n
	end,
})

local function compute_vartabstop(buf)
	local result = {}

	local lines = api.nvim_buf_get_lines(buf, 0, max_lines, false)
	local start = {}
	local col = 1

	while true do
		local max_width = 0
		local any = false

		for i, line in ipairs(lines) do
			local tab = string.find(line, '\t', start[i], true)

			local s = ''
			if tab then
				s = string.sub(line, start[i] or 1, tab - 1)
				start[i] = tab + 1
				any = true
			elseif start[i] then
				s = string.sub(line, start[i])
				start[i] = #line + 1
			else
				start[i] = #line + 1
			end

			if #s * 2 > max_width then
				max_width = math.max(max_width, width[s])
			end
		end

		if not any then
			return result
		end

		table.insert(result, max_width + pad)
		col = col + max_width + pad
	end
end

local function reload_buffer(buf)
	vim.bo[buf].vartabstop = table.concat(compute_vartabstop(buf), ',')
end

local function attach_to_buffer(buf)
	local group = api.nvim_create_augroup('varign/' .. buf, {})

	api.nvim_create_autocmd('TextChanged', {
		group = group,
		buffer = buf,
		callback = function()
			vim.schedule(function()
				reload_buffer(buf)
			end)
		end,
	})

	reload_buffer(buf)
end

local function setup(opts)
	opts = opts or {}

	if opts.auto_attach ~= false then
		local group = api.nvim_create_augroup('varign', {})

		local function is_buffer_enabled(buf)
			local s = api.nvim_buf_get_lines(buf, 0, 1, false)[1]
			return string.find(s, '^[^\t]+\t[^\t]+\t[^\t]+')
		end

		api.nvim_create_autocmd('BufReadPost', {
			group = group,
			callback = function(opts)
				local buf = opts.buf

				if is_buffer_enabled(buf) then
					attach_to_buffer(buf)
				end
			end,
		})
	end

	api.nvim_create_user_command('Varign', function()
		attach_to_buffer(api.nvim_get_current_buf())
	end, {})
end

return {
	attach_to_buffer = attach_to_buffer,
	reload_buffer = reload_buffer,
	setup = setup,
}
