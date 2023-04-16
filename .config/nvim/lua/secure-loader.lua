-- require('non-existent-file') falls back to cwd that is dangerous.
assert(#package.loaders == 5)

package.loaders = {
	package.loaders[1], -- package.preload loader.
	package.loaders[2], -- NeoVim loader.
}

local Trace = require 'trace'
if Trace.verbose > 0 then
	local vim_loader = package.loaders[2]
	table.insert(package.loaders, 1, function(path)
		local span = Trace.trace(string.format('require "%s"', path))
		vim_loader(path)
		Trace.trace(span)
	end)
end
