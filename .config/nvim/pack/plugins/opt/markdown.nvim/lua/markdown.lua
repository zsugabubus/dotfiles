local api = vim.api
local concat = table.concat
local find = string.find
local fn = vim.fn
local format = string.format
local gmatch = string.gmatch
local insert = table.insert
local json_encode = vim.json.encode
local lower = string.lower
local match = string.match
local remove = table.remove
local schedule = vim.schedule
local uv = vim.uv

local CACHE_CONTROL = 'cache-control'
local CONTENT_SECURITY_POLICY = 'content-security-policy'
local CONTENT_TYPE = 'content-type'
local CRLF = '\r\n'
local ETAG = 'etag'
local IF_NONE_MATCH = 'if-none-match'
local NO_CACHE = 'no-cache'

local CHARSET_UTF8 = '; charset=utf-8'

local APPLICATION_JAVASCRIPT_UTF8 = 'application/javascript' .. CHARSET_UTF8
local IMAGE_SVG = 'image/svg+xml'
local IMAGE_SVG_UTF8 = IMAGE_SVG .. CHARSET_UTF8
local TEXT_CSS_UTF8 = 'text/css' .. CHARSET_UTF8
local TEXT_EVENT_STREAM = 'text/event-stream'
local TEXT_HTML_UTF8 = 'text/html' .. CHARSET_UTF8
local TEXT_PLAIN_UTF8 = 'text/plain' .. CHARSET_UTF8

local CSP_DIRECTIVES = concat({
	"default-src 'none'",
	"connect-src 'self' https://api.github.com/emojis",
	'img-src http:',
	'media-src http:',
	"script-src 'self' https://cdn.jsdelivr.net",
	"style-src 'unsafe-inline' 'self'",
}, '; ')

local ALLOWED_ASSETS = {
	svg = IMAGE_SVG,
	png = 'image/png',
}

local group = api.nvim_create_augroup('markdown', {})
local plugin_dir =
	match(api.nvim_get_runtime_file('lua/markdown.lua', false)[1], '^(.*/).*/.*$')
local public_dir = plugin_dir .. 'public'

local server
local subscribers = {}
local assets_dir
local markdown_buf
local client_file
local client_text
local client_line

local function noop()
	-- Do nothing.
end

local function debounce(fn, timeout)
	local timer = uv.new_timer()

	local function callback()
		schedule(fn)
	end

	return function()
		timer:start(timeout, 0, callback)
	end
end

local function is_path_safe(path)
	return find(path, '^/') and not find(path, '%.%.')
end

local function path_extension(path)
	return match(path, '%.([a-z]+)$')
end

local function dispatch_event(event, data)
	local s = format('event: %s\ndata: %s\n\n', event, json_encode(data))
	for _, client in ipairs(subscribers) do
		client:write(s)
	end
end

local function dispatch_file_change()
	dispatch_event('file-change', client_file)
end

local function dispatch_text_change()
	dispatch_event('text-change', client_text)
end

local function dispatch_cursor_move()
	dispatch_event('cursor-move', client_line)
end

local function dispatch_background_change()
	dispatch_event('background-change', vim.o.background)
end

local function update_client_file()
	local new = fn.expand('%:t')

	if client_file == new then
		return
	end

	client_file = new
	dispatch_file_change()
end

local update_client_text = debounce(function()
	if not markdown_buf then
		return
	end

	local new = concat(api.nvim_buf_get_lines(markdown_buf, 0, -1, true), '\n')

	if client_text == new then
		return
	end

	client_text = new
	dispatch_text_change()
end, 75)

local function update_client_line()
	local new = fn.line('.')

	if client_line == new then
		return
	end

	client_line = new
	dispatch_cursor_move()
end

local function has_subscribers()
	return #subscribers > 0
end

local function detach_from_buffer()
	api.nvim_create_augroup('markdown.buffer', {})
end

local function attach_to_buffer()
	api.nvim_buf_call(markdown_buf, function()
		local group = api.nvim_create_augroup('markdown.buffer', {})

		api.nvim_create_autocmd('TextChanged', {
			group = group,
			buffer = 0,
			callback = function()
				update_client_text()
			end,
		})

		api.nvim_create_autocmd('CursorMoved', {
			group = group,
			buffer = 0,
			callback = function()
				update_client_line()
			end,
		})

		api.nvim_create_autocmd('BufUnload', {
			group = group,
			buffer = 0,
			callback = function()
				markdown_buf = nil
			end,
		})

		assets_dir = fn.expand('%:h')

		update_client_file()
		update_client_text()
		update_client_line()
	end)
end

local function is_buffer_markdown()
	return vim.bo.filetype == 'markdown'
end

local function enter_buffer()
	if not is_buffer_markdown() then
		return
	end

	markdown_buf = api.nvim_get_current_buf()

	if has_subscribers() then
		attach_to_buffer()
	end
end

local function make_head(code, reason, headers)
	local s = 'HTTP/1.1 ' .. code .. ' ' .. reason .. CRLF
	for name, value in pairs(headers) do
		s = s .. name .. ': ' .. value .. CRLF
	end
	return s .. CRLF
end

local function close_connection(client)
	client:shutdown(function()
		client:close()
	end)
end

local function serve_http(client)
	local function reply(code, reason, headers, body)
		client:write({ make_head(code, reason, headers), body })
		close_connection(client)
	end

	local function reply_not_modified()
		reply(304, 'Not Modified', {}, '')
	end

	local function reply_forbidden_path()
		reply(403, 'Forbidden Path', {
			[CONTENT_TYPE] = TEXT_PLAIN_UTF8,
		}, 'Path is forbidden.\n')
	end

	local function reply_forbidden_extension()
		local t = { 'Extension is forbidden. Allowed extensions:\n' }
		for ext, mime_type in pairs(ALLOWED_ASSETS) do
			insert(t, format('- %s (%s)\n', ext, mime_type))
		end
		reply(403, 'Forbidden Extension', {
			[CONTENT_TYPE] = TEXT_PLAIN_UTF8,
		}, concat(t))
	end

	local function reply_not_found()
		reply(404, 'Not Found', {}, '')
	end

	local function reply_error(err)
		reply(500, 'Internal Server Error', {}, err .. '\n')
	end

	local function serve_file(req, filepath, headers)
		uv.fs_open(filepath, 'r', 0, function(err, fd)
			if err and find(err, '^ENOENT:') then
				reply_not_found()
				return
			elseif err then
				reply_error(err)
				return
			end

			uv.fs_fstat(fd, function(err, stat)
				if err then
					reply_error(err)
					uv.fs_close(fd, noop)
					return
				end

				local client_etag = req.headers[IF_NONE_MATCH]
				local etag = format(
					'"%d|%d|%d|%d"',
					stat.ino,
					stat.size,
					stat.mtime.sec,
					stat.mtime.nsec
				)

				if client_etag == etag then
					reply_not_modified()
					uv.fs_close(fd, noop)
					return
				end

				headers[ETAG] = etag

				uv.fs_read(fd, stat.size, 0, function(err, data)
					uv.fs_close(fd, noop)

					if err then
						reply_error(err)
						return
					end

					assert(#data == stat.size)
					reply(200, 'OK', headers, data)
				end)
			end)
		end)
	end

	local function serve_public_file(req, filepath, headers)
		serve_file(req, public_dir .. filepath, headers)
	end

	local function serve_events()
		insert(subscribers, client)

		client:write(make_head(200, 'OK', {
			[CONTENT_TYPE] = TEXT_EVENT_STREAM,
			[CACHE_CONTROL] = NO_CACHE,
		}))

		client:read_start(function(_, chunk)
			if not chunk then
				for i = 1, #subscribers do
					if subscribers[i] == client then
						remove(subscribers, i)
						break
					end
				end

				close_connection(client)

				if not has_subscribers() then
					schedule(function()
						detach_from_buffer()
					end)
				end
			end
		end)

		schedule(function()
			client_file = nil
			client_text = nil
			client_line = nil
			dispatch_background_change()
			if markdown_buf then
				attach_to_buffer()
			end
		end)
	end

	local function serve_assets(req)
		local path = req.path

		if not assets_dir or not is_path_safe(path) then
			reply_forbidden_path()
			return
		end

		local ext = path_extension(path)
		local mime_type = ALLOWED_ASSETS[ext]

		if not mime_type then
			reply_forbidden_extension()
			return
		end

		serve_file(req, assets_dir .. path, {
			[CONTENT_TYPE] = mime_type,
			[CACHE_CONTROL] = 'max-age=3',
		})
	end

	local function handle_request(req)
		if req.method == 'GET' and req.path == '/' then
			serve_public_file(req, '/index.html', {
				[CONTENT_TYPE] = TEXT_HTML_UTF8,
				[CONTENT_SECURITY_POLICY] = CSP_DIRECTIVES,
			})
		elseif req.method == 'GET' and req.path == '/.index.mjs' then
			serve_public_file(req, '/index.mjs', {
				[CONTENT_TYPE] = APPLICATION_JAVASCRIPT_UTF8,
			})
		elseif req.method == 'GET' and req.path == '/.index.css' then
			serve_public_file(req, '/index.css', {
				[CONTENT_TYPE] = TEXT_CSS_UTF8,
			})
		elseif req.method == 'GET' and req.path == '/.index.svg' then
			serve_public_file(req, '/index.svg', {
				[CONTENT_TYPE] = IMAGE_SVG_UTF8,
				[CACHE_CONTROL] = 'max-age=60',
			})
		elseif req.method == 'GET' and req.path == '/events' then
			serve_events()
		elseif req.method == 'GET' then
			serve_assets(req)
		else
			reply_not_found()
		end
	end

	local buf = ''

	client:read_start(function(err, chunk)
		assert(not err, err)
		if chunk == nil then
			return
		end

		buf = buf .. chunk

		local head = match(buf, '^(.-\r\n)\r\n')
		if head then
			local method, path, header_string =
				match(buf, '^([^ ]+) ([^ ]+) HTTP/1%.1\r\n(.*)')

			local headers = {}
			for name, value in gmatch(header_string, '([^:]*): *([^\r\n]-) *\r\n') do
				headers[lower(name)] = value
			end

			client:read_stop()
			handle_request({
				method = method,
				path = path,
				headers = headers,
			})
		end
	end)
end

local function get_browser_url()
	if server then
		local sock = assert(uv.tcp_getsockname(server))
		return format('http://%s:%d', sock.ip, sock.port)
	end
end

local function trigger(name, data)
	api.nvim_exec_autocmds('User', { pattern = name, data = data })
end

local function notify_info(...)
	vim.notify(format(...), vim.log.levels.INFO)
end

local function stop_server()
	if not server then
		return
	end

	server:close()
	server = nil

	for _, client in ipairs(subscribers) do
		close_connection(client)
	end

	notify_info('Stopped markdown preview')
	trigger('MarkdownPreviewStop')
end

local function start_server(host, port)
	stop_server()

	server = uv.new_tcp('inet')
	server:bind(host, port)

	local _, err = server:listen(10, function(err)
		assert(not err, err)

		local client = uv.new_tcp()
		server:accept(client)

		serve_http(client)
	end)

	if err then
		server:close()
		server = nil
		error(err)
	end

	notify_info('Visit markdown preview on %s', get_browser_url())
	trigger('MarkdownPreviewStart', { browser_url = get_browser_url() })
end

api.nvim_create_autocmd('BufEnter', {
	group = group,
	callback = function()
		enter_buffer()
	end,
})

api.nvim_create_autocmd('OptionSet', {
	group = group,
	pattern = 'background',
	callback = function()
		dispatch_background_change()
	end,
})

enter_buffer()

return {
	get_browser_url = get_browser_url,
	stop_server = stop_server,
	start_server = start_server,
}
