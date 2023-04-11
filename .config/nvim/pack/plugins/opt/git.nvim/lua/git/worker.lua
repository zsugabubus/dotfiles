local M = {}
M.__index = M

local function write_mpack(handle, x)
	local payload = vim.mpack.encode(x)
	local len = #payload
	local header = string.format('%08x', len)
	handle:write(header)
	handle:write(payload)
end

local function read_start_mpack(handle, callback)
	local buffer = ''
	handle:read_start(function(err, chunk)
		assert(not err)
		if not chunk then
			return
		end

		buffer = buffer .. chunk

		while true do
			if #buffer < 8 then
				return
			end

			local header = string.sub(buffer, 1, 8)
			local len = tonumber(header, 16)

			if #buffer < 8 + len then
				return
			end

			local frame = string.sub(buffer, 8 + 1, 8 + len)
			buffer = string.sub(buffer, 8 + len + 1)

			local payload = vim.mpack.decode(frame)
			callback(payload)
		end
	end)
end

function M.new(cls, worker_fn, on_reply, ...)
	local uv = vim.loop

	local NONBLOCK = {nonblock = true}

	local self = setmetatable({}, cls)

	local request_channel = uv.pipe(NONBLOCK, NONBLOCK)
	local reply_channel = uv.pipe(NONBLOCK, NONBLOCK)

	self.request_tx = uv.new_pipe()
	self.request_tx:open(request_channel.write)

	self.reply_rx = uv.new_pipe()
	self.reply_rx:open(reply_channel.read)

	uv.new_thread(
		function(rx_fd, tx_fd, worker_code, read_start_messages_code, write_mpack_code, ...)
			local read_start_mpack = load(read_start_messages_code)
			local write_mpack = load(write_mpack_code)

			local uv = vim.loop

			local request_rx = uv.new_pipe()
			request_rx:open(rx_fd)

			local reply_tx = uv.new_pipe()
			reply_tx:open(tx_fd)

			local function reply(message)
				write_mpack(reply_tx, message)
			end
			local on_request = load(worker_code)(reply, ...)

			read_start_mpack(request_rx, function(message)
				on_request(message)
			end)

			uv.run()
			on_request(nil)
		end,
		request_channel.read,
		reply_channel.write,
		string.dump(worker_fn),
		string.dump(read_start_mpack),
		string.dump(write_mpack),
		...
	)

	self.autocmd = vim.api.nvim_create_autocmd('VimLeave', {
		once = true,
		callback = function()
			self:close()
		end,
	})

	read_start_mpack(self.reply_rx, on_reply)

	return self
end

function M:send_request(message)
	write_mpack(self.request_tx, message)
end

function M:close()
	vim.api.nvim_del_autocmd(self.autocmd)
	self.request_tx:close()
	self.reply_rx:close()
end

return M
