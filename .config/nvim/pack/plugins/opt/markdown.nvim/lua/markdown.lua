local api = vim.api
local fn = vim.fn
local json_encode = vim.json.encode
local schedule = vim.schedule
local uv = vim.uv

local CACHE_CONTROL = 'cache-control'
local CONTENT_LENGTH = 'content-length'
local CONTENT_SECURITY_POLICY = 'content-security-policy'
local CONTENT_TYPE = 'content-type'
local CRLF = '\r\n'
local ETAG = 'etag'
local IF_NONE_MATCH = 'if-none-match'
local NO_CACHE = 'no-cache'
local NO_REFERRER = 'no-referrer'
local REFERRER_POLICY = 'referrer-policy'

local CHARSET_UTF8 = '; charset=utf-8'

local APPLICATION_JAVASCRIPT_UTF8 = 'application/javascript' .. CHARSET_UTF8
local IMAGE_SVG = 'image/svg+xml'
local IMAGE_SVG_UTF8 = IMAGE_SVG .. CHARSET_UTF8
local TEXT_CSS_UTF8 = 'text/css' .. CHARSET_UTF8
local TEXT_EVENT_STREAM = 'text/event-stream'
local TEXT_HTML_UTF8 = 'text/html' .. CHARSET_UTF8
local TEXT_PLAIN_UTF8 = 'text/plain' .. CHARSET_UTF8

local CSP_DIRECTIVES = table.concat({
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
	jpg = 'image/jpeg',
	jpeg = 'image/jpeg',
	mp4 = 'video/mp4',
}

local group = api.nvim_create_augroup('markdown', {})
local plugin_dir =
	api.nvim_get_runtime_file('lua/markdown.lua', false)[1]:match('^(.*/).*/.*$')
local public_dir = plugin_dir .. 'public'

local server
local subscribers = {}
local assets_dir
local preview_buf
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
	return path:find('^/') and not path:find('%.%.')
end

local function path_extension(path)
	return path:match('%.([a-z0-9]+)$')
end

local function is_directory(path)
	return fn.isdirectory(path) == 1
end

local function count_backticks(s)
	local n = 0
	for m in s:gmatch('`+') do
		n = math.max(n, #m)
	end
	return n
end

local function format_inline_code(s)
	local ZWJ = '\u{200d}'
	local fence = ZWJ .. ('`'):rep(1 + count_backticks(s)) .. ZWJ
	return ('%s%s%s'):format(fence, s:gsub('[%z\x01-\x1f]', ' '), fence)
end

local function format_block_code(s, filetype)
	local fence = ('`'):rep(3 + count_backticks(s))
	return ('%s%s\n%s\n%s\n'):format(fence, filetype, s, fence)
end

local function get_asset_preview(path)
	local mime_type = ALLOWED_ASSETS[path_extension(path)]

	if mime_type and mime_type:find('^image/') then
		return ('![Image](%s)'):format(vim.uri_encode(path))
	end

	if mime_type and mime_type:find('^video/') then
		return ('<video src="%s" controls></video>'):format(vim.uri_encode(path))
	end
end

local function get_buffer_preview(buf)
	local path = fn.bufname(buf)

	if is_directory(path) then
		local files = {}
		for name in vim.fs.dir(path) do
			table.insert(
				files,
				('## %s\n%s\n\n'):format(
					format_inline_code(name),
					get_asset_preview(name) or ''
				)
			)
		end
		return table.concat(files)
	end

	local filetype = vim.bo[buf].filetype

	if filetype == '' then
		local asset = get_asset_preview(fn.fnamemodify(path, ':t'))
		if asset then
			return asset
		end
	end

	local content = table.concat(api.nvim_buf_get_lines(buf, 0, -1, true), '\n')

	if filetype == 'markdown' or filetype == 'svg' then
		return content
	end

	return format_block_code(content, filetype)
end

local function dispatch_event(event, data)
	local s = ('event: %s\ndata: %s\n\n'):format(event, json_encode(data))
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
	if not preview_buf then
		return
	end

	local new = get_buffer_preview(preview_buf)

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
	api.nvim_buf_call(preview_buf, function()
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
				preview_buf = nil
			end,
		})

		if is_directory(fn.expand('%')) then
			assets_dir = fn.expand('%') .. '/'
		else
			assets_dir = fn.expand('%:h')
		end

		update_client_file()
		update_client_text()
		update_client_line()
	end)
end

local function enter_buffer()
	preview_buf = api.nvim_get_current_buf()

	if has_subscribers() then
		attach_to_buffer()
	end
end

local function make_head(code, reason, headers)
	local s = 'HTTP/1.0 ' .. code .. ' ' .. reason .. CRLF
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
			table.insert(t, ('- %s (%s)\n'):format(ext, mime_type))
		end
		reply(403, 'Forbidden Extension', {
			[CONTENT_TYPE] = TEXT_PLAIN_UTF8,
		}, table.concat(t))
	end

	local function reply_not_found()
		reply(404, 'Not Found', {}, '')
	end

	local function reply_error(err)
		reply(500, 'Internal Server Error', {}, err .. '\n')
	end

	local function serve_file(req, filepath, headers)
		uv.fs_open(filepath, 'r', 0, function(err, fd)
			if err and err:find('^ENOENT:') then
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
				local etag = ('"%d|%d|%d|%d|%d"'):format(
					stat.dev,
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
				headers[CONTENT_LENGTH] = stat.size

				client:write(make_head(200, 'OK', headers), function()
					uv.fs_sendfile(client:fileno(), fd, 0, stat.size, function()
						close_connection(client)
						uv.fs_close(fd, noop)
					end)
				end)
			end)
		end)
	end

	local function serve_public_file(req, filepath, headers)
		serve_file(req, public_dir .. filepath, headers)
	end

	local function serve_events()
		table.insert(subscribers, client)

		client:write(make_head(200, 'OK', {
			[CONTENT_TYPE] = TEXT_EVENT_STREAM,
			[CACHE_CONTROL] = NO_CACHE,
		}))

		client:read_start(function(_, chunk)
			if not chunk then
				for i = 1, #subscribers do
					if subscribers[i] == client then
						table.remove(subscribers, i)
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
			if preview_buf then
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
				[REFERRER_POLICY] = NO_REFERRER,
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

		local head = buf:match('^(.-\r\n)\r\n')
		if head then
			local method, path, header_string =
				buf:match('^([^ ]+) ([^ ]+) HTTP/1%.1\r\n(.*)')

			local headers = {}
			for name, value in header_string:gmatch('([^:]*): *([^\r\n]-) *\r\n') do
				headers[name:lower()] = value
			end

			client:read_stop()
			handle_request({
				method = method,
				path = vim.uri_decode(path),
				headers = headers,
			})
		end
	end)
end

local function get_browser_url()
	if server then
		local sock = assert(uv.tcp_getsockname(server))
		return ('http://%s:%d'):format(sock.ip, sock.port)
	end
end

local function trigger(name, data)
	api.nvim_exec_autocmds('User', { pattern = name, data = data })
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

	vim.notify('Stopped markdown preview', vim.log.levels.INFO)
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

	vim.notify(
		('Visit markdown preview on %s'):format(get_browser_url()),
		vim.log.levels.INFO
	)
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
