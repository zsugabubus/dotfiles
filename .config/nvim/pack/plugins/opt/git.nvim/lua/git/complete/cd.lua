return function(prefix)
	return vim.tbl_filter(function(path)
		return string.sub(path, -1) == '/'
	end, require('git.complete.edit')(prefix))
end
