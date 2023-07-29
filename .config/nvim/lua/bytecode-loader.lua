local Trace = require('trace')
local cache_dir = vim.fn.stdpath('cache')
local bytecode_dir = cache_dir .. '/bytecode'
local loadfile = loadfile -- Make it local.

function _G.loadfile(path)
	local trace = Trace.trace
	local span = trace(path)

	local uv = vim.loop

	local stat_span = trace('stat')
	local stat = uv.fs_stat(path)
	trace(stat_span)

	local path_key = string.gsub(path, '/', '%%')
	local cache_path = string.format(
		'%s/%s%%M=%s_%s,S=%s',
		bytecode_dir,
		path_key,
		stat.mtime.sec,
		stat.mtime.nsec,
		stat.size
	)

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

	uv.fs_mkdir(cache_dir, tonumber('700', 8), function()
		uv.fs_mkdir(bytecode_dir, tonumber('700', 8), function()
			local tmp_path = string.format('%s.%d~', cache_path, uv.os_getpid())
			uv.fs_open(tmp_path, 'wx', tonumber('600', 8), function(err, fd)
				-- Maybe another loadfile() would like to cache concurrently, or maybe
				-- something below failed so do not try again.
				if err and string.find(err, '^EEXIST:') then
					return
				end
				-- Cannot do much about it.
				if err and string.find(err, '^EROFS:') then
					return
				end
				assert(not err, err)
				-- LuaJIT accepts a second argument "strip". When set, the produced
				-- bytecode will be free from debug information that results in smaller
				-- size and faster loading.
				--
				-- Important: The so produced bytecode is not that much portable so
				-- version of Nvim (that hopefully identifies version of LuaJIT) must
				-- always be present in cache key.
				--
				-- See: https://luajit.org/extensions.html.
				uv.fs_write(fd, string.dump(code, true), -1, function(err)
					assert(not err, err)
					uv.fs_close(fd, function(err, success)
						assert(not err, err)
						assert(success)

						uv.fs_opendir(bytecode_dir, function(err, dir)
							assert(not err, err)

							local function read_next(err, entries)
								assert(not err, err)
								if not entries then
									uv.fs_closedir(dir, function(err, success)
										assert(not err, err)
										assert(success)
									end)

									uv.fs_rename(tmp_path, cache_path, function(err, success)
										assert(not err, err)
										assert(success)
									end)
									return
								end

								-- Clean up old entries.
								for _, entry in ipairs(entries) do
									local name = string.match(entry.name, '(.*)%%.*[^~]$')
									if name == path_key then
										uv.fs_unlink(
											bytecode_dir .. '/' .. entry.name,
											function(err, success)
												if err and string.find(err, '^ENOENT:') then
													return
												end
												assert(not err, err)
												assert(success)
											end
										)
									end
								end

								uv.fs_readdir(dir, read_next)
							end

							uv.fs_readdir(dir, read_next)
						end)
					end)
				end)
			end)
		end)
	end)

	return code
end
