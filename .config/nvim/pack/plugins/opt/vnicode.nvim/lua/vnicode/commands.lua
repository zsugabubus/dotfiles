local data = require('vnicode.data')

local M = {}

local function filter_completions(prefix, choices)
	return vim.tbl_filter(function(x)
		return vim.startswith(x, prefix)
	end, choices)
end

local function get_codepoints()
	local buffer = require('vnicode.buffer')
	return vim.fn.str2list(buffer.get_current_text())
end

local function show(show_utf8)
	local Printer = require('vnicode.printer')
	local printer = Printer:new()
	printer:codepoints(get_codepoints(), show_utf8)
	vim.api.nvim_echo(printer:chunks(), false, {})
end

function M.ga()
	show(false)
end

function M.g8()
	show(true)
end

function M.view(opts)
	local ucd = opts.fargs[1] or 'NamesList.txt'
	vim.cmd.view(vim.fn.fnameescape(data.get_ucd_filename(ucd)))
end

function M.view_complete(prefix)
	return filter_completions(prefix, data.get_installed_ucds())
end

function M.install(opts)
	if #opts.fargs == 0 then
		for _, ucd in ipairs(data.get_default_ucds()) do
			data.install(ucd)
		end
	else
		data.install(opts.fargs[1])
	end
end

function M.install_complete(prefix)
	local all = vim.fn.uniq(
		vim.fn.sort(
			vim.list_extend(data.get_default_ucds(), data.get_installed_ucds())
		)
	)
	return filter_completions(prefix, all)
end

function M.update(opts)
	for _, ucd in ipairs(data.get_installed_ucds()) do
		data.install(ucd)
	end
end

return M
