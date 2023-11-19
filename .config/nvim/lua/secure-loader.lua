-- require('non-existent-file') falls back to cwd that is dangerous.
assert(#package.loaders == 5)

package.loaders = {
	package.loaders[1], -- package.preload loader.
	package.loaders[2], -- NeoVim loader.
}

local Trace = require('trace')
if Trace.verbose > 0 then
	local vim_loader = package.loaders[2]
	package.loaders[2] = function(path)
		local span = Trace.trace('require ' .. path)
		local t = vim_loader(path)
		Trace.trace(span)
		return t
	end
end
