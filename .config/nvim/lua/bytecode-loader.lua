local Trace = require 'trace'
local cache_dir = vim.fn.stdpath('cache') .. '/bytecode'
local loadfile = loadfile -- Make it local.
local version_key
do
	local v = vim.version()
	version_key = string.format('%d_%d_%d', v.major, v.minor, v.patch)
end

function _G.loadfile(path)
	local trace = Trace.trace

	local span = trace(path)

	local uv = vim.loop
	local cache_path
	local path_key = string.gsub(path, '/', '%%')
	if string.find(path, '/share/nvim/runtime/') then
		cache_path = string.format(
			'%s/%s%%%%V=%s',
			cache_dir,
			path_key,
			version_key
		)
	else
		local span = trace('stat')
		local stat = uv.fs_stat(path)
		trace(span)
		cache_path = string.format(
			'%s/%s%%%%S=%s,M=%s_%s',
			cache_dir,
			path_key,
			stat.size,
			stat.mtime.sec,
			stat.mtime.nsec
		)
	end

	if Trace.verbose > 5 then
		local diff = trace('')
		local slow = trace('loadfile(text)')
		loadfile(path)
		local fast = trace(slow, 'loadfile(bytecode)')
		loadfile(cache_path)
		trace(diff)
		diff.name = string.format(
			'loadfile speedup: %.3f ms',
			(slow.elapsed - fast.elapsed) / 1e6
		)
	end

	local cache_code = loadfile(cache_path)
	if cache_code then
		trace(span)
		return cache_code
	end

	local code = loadfile(path)
	trace(span)
	if not code then
		return
	end

	uv.fs_mkdir(cache_dir, 448, function()
		local tmp_path = string.format('%s.%d~', cache_path, uv.os_getpid())
		uv.fs_open(tmp_path, 'wx', 384, function(err, fd)
			-- Maybe another loadfile() would like to cache concurrently, or maybe
			-- something below failed so do not try again.
			if err and string.find(err, '^EEXIST:') then
				return
			end
			assert(not err, err)
			uv.fs_write(fd, string.dump(code), -1, function(err)
				assert(not err, err)
				uv.fs_close(fd, function(err, success)
					assert(not err, err)
					assert(success)
					uv.fs_rename(tmp_path, cache_path, function(err, success)
						assert(not err, err)
						assert(success)
					end)
				end)
			end)
		end)
	end)

	return code
end
