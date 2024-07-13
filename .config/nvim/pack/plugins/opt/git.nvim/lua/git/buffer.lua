local revision = require('git.revision')
local utils = require('git.utils')

local api = vim.api
local cmd = vim.cmd
local fn = vim.fn

local M = {}

function M.buf_get_rev(buf)
	local s = api.nvim_buf_get_name(buf)
	return string.match(s, '^git[^:]*://(.*)')
end

local function buf_map(buf, lhs, rhs)
	if type(rhs) == 'function' then
		api.nvim_buf_set_keymap(buf, 'n', lhs, '', {
			nowait = true,
			callback = rhs,
		})
	else
		api.nvim_buf_set_keymap(buf, 'n', lhs, rhs, {
			nowait = true,
		})
	end
end

function M.goto_revision(rev, lnum)
	local use_preview = vim.b.git_use_preview
	local file = fn.fnameescape('git://' .. rev)
	local lnum_cmd = lnum and string.format('+%d ', lnum) or ''

	-- May block file open since it can make rev expand to nothing.
	local saved_wildignore = vim.go.wildignore
	vim.go.wildignore = ''

	if use_preview then
		local saved_previewheight = vim.go.previewheight
		vim.go.previewheight = 82
		cmd(string.format('topleft vertical pedit %s%s', lnum_cmd, file))
		vim.go.previewheight = saved_previewheight
	else
		cmd(string.format('edit %s%s', lnum_cmd, file))
	end

	vim.go.wildignore = saved_wildignore
end

function M.get_diff_source()
	local row = api.nvim_win_get_cursor(0)[1]

	local c = api.nvim_buf_get_text(0, row - 1, 0, row - 1, 1, {})[1]
	if c ~= ' ' and c ~= '+' and c ~= '-' then
		return
	end

	row = row - 1

	local a_offset, b_offset = 0, 0

	while row > 0 do
		local s = api.nvim_buf_get_text(0, row - 1, 0, row - 1, 1, {})[1]
		if s == '-' then
			a_offset = a_offset + 1
		elseif s == '+' then
			b_offset = b_offset + 1
		elseif s == ' ' then
			a_offset = a_offset + 1
			b_offset = b_offset + 1
		else
			break
		end
		row = row - 1
	end

	local s = api.nvim_buf_get_lines(0, row - 1, row, true)[1]
	local a_start, b_start = string.match(s, '^@@ %-(%d*),%d* %+(%d*)')

	local a_path, b_path

	if a_start then
		while row > 0 do
			local s = api.nvim_buf_get_text(0, row - 1, 0, row - 1, 4, {})[1]
			if s == '+++ ' then
				local a, b = unpack(api.nvim_buf_get_lines(0, row - 2, row, true))
				a_path = string.match(a, '%-%-%- [^/]*/(.*)')
				b_path = string.match(b, '%+%+%+ [^/]*/(.*)')
				row = row - 2
				break
			end
			row = row - 1
		end
	end

	local b_commit

	while row > 0 do
		local s = api.nvim_buf_get_lines(0, row - 1, row, true)[1]
		b_commit = string.match(s, '^commit (%x*)')
			or string.match(s, '^[* ]*%x%x%x%x%x%x%x%x*')
		if b_commit then
			break
		end
		row = row - 1
	end

	if not b_commit then
		return
	end

	if a_start then
		local a = c == '-'
		return {
			commit = a and b_commit .. '~' or b_commit,
			path = a and a_path or b_path,
			lnum = a and a_start + a_offset or b_start + b_offset,
		}
	end

	return {
		commit = b_commit,
	}
end

function M.goto_object()
	local cfile = fn.expand('<cfile>')

	if string.match(cfile, '^%x%x%x%x+$') then
		M.goto_revision(cfile)
		return
	end

	local pos = M.get_diff_source()
	if pos then
		M.goto_revision(revision.join(pos.commit, pos.path or cfile), pos.lnum)
		return
	end

	local rev = M.buf_get_rev(0)
	if rev then
		M.goto_revision(revision.join(rev, cfile))
		return
	end

	api.nvim_feedkeys('gf', 'xtin', false)
end

local function goto_parent_tree()
	local parent = revision.parent_tree(M.buf_get_rev(0))
	if not parent then
		utils.log_error('Not a tree-ish revision')
		return
	end
	M.goto_revision(parent)
end

local function goto_ancestor()
	M.goto_revision(revision.ancestor(M.buf_get_rev(0), vim.v.count1))
end

local function goto_parent()
	M.goto_revision(revision.parent_commit(M.buf_get_rev(0), vim.v.count1))
end

function M.buf_init(buf)
	local bo = vim.bo[buf]
	bo.buftype = 'nofile'
	bo.modeline = false
	bo.modifiable = false
	bo.swapfile = false
	bo.undolevels = -1

	buf_map(buf, 'q', '<C-W>c')
	buf_map(buf, 'gf', M.goto_object)
	buf_map(buf, '<CR>', M.goto_object)
	buf_map(buf, 'u', goto_parent_tree)
	buf_map(buf, '~', goto_ancestor)
	buf_map(buf, '^', goto_parent)
end

function M.fold_hunks()
	local wo = vim.wo[0][0]
	wo.foldexpr = 'v:lua._git_fde()'
	wo.foldlevel = 999
	wo.foldmethod = 'expr'
end

function _G._git_fde()
	local row = api.nvim_get_vvar('lnum')
	local s = api.nvim_buf_get_text(0, row - 1, 0, row - 1, 11, {})[1]
	if s == '' then
		return 0
	elseif string.sub(s, 1, 3) == '@@ ' then
		return '>2'
	elseif string.sub(s, 1, 11) == 'diff --git ' then
		return '>1'
	end
	return '='
end

return M
