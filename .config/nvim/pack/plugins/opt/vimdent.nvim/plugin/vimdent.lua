local group = vim.api.nvim_create_augroup('Vimdent', {})

local function sw_max(t)
	local sum = 0
	local max = 2
	for i = 2, 99 do
		sum = sum + t[i]
		if t[i] > t[max] then
			max = i
		end
	end
	-- Value is maximum by a great margin.
	if sum < t[max] * 2 then
		return max
	end
end

local function detect()
	if vim.bo.buftype ~= '' then
		return
	end

	local ffi = require 'ffi'

	local sw_tbl = ffi.new('int[?]', 100)
	local sw2_tbl = ffi.new('int[?]', 100)
	local et_tbl = ffi.new('int[?]', 100)
	local tab_only = 0

	local saved_tabstop = vim.bo.tabstop
	local saved_vartabstop = vim.bo.vartabstop
	vim.bo.tabstop = 100
	vim.bo.vartabstop = ''

	local prev_tab, prev_sp = 0, 0
	local endl = vim.api.nvim_buf_line_count(0)
	for i = math.max(1, endl - 1000), endl do
		local indent = vim.fn.indent(i)
		local tab, sp = math.floor(indent / 100), indent % 100

		if tab == prev_tab then
			if tab == 0 then
				if sp == 0 and vim.fn.nextnonblank(i) ~= i then
					goto ignore_blank
				end
				-- SP SP SP
				et_tbl[sp] = et_tbl[sp] + 1
			end
			-- TAB
			-- TAB SP SP
			-- TAB
			local n = math.abs(sp - prev_sp)
			sw_tbl[n] = sw_tbl[n] + 1
		elseif math.abs(tab - prev_tab) == 1 then
			if prev_sp == 0 and sp == 0 then
				-- TAB
				-- TAB TAB
				-- TAB
				tab_only = tab_only + 1
			elseif prev_sp > 1 and sp == 0 and prev_tab + 1 == tab then
				-- TAB SP SP
				-- TAB TAB
				sw2_tbl[prev_sp] = sw2_tbl[prev_sp] + 1
			elseif prev_sp == 0 and sp > 1 and prev_tab - 1 == tab then
				-- TAB TAB
				-- TAB SP SP
				sw2_tbl[sp] = sw2_tbl[sp] + 1
			end
		end

		prev_tab, prev_sp = tab, sp
		::ignore_blank::
	end

	-- Tab having this size should be expanded.
	for i = 98, 2, -1 do
		et_tbl[i] = et_tbl[i] + et_tbl[i + 1]
	end

	if et_tbl[2] < tab_only then
		-- Tab only.
		vim.bo.shiftwidth = 0
		vim.bo.expandtab = false
		vim.bo.tabstop = saved_tabstop
		vim.bo.vartabstop = saved_vartabstop
		vim.bo.softtabstop = 0
		vim.b.did_vimdent = 1
		return
	end

	local best_sw = sw_max(sw_tbl)
	if best_sw and best_sw <= 8 then
		local best_sw2 = sw_max(sw2_tbl)

		-- Too much 8 spaces (universal default &tabstop across editors) became a
		-- tab on adjacent lines. It mostly occurs when somebody starts using
		-- &noexpandtab on a file that was historically &expandtab.
		if best_sw2 == 8 then
			best_sw2 = best_sw2 - best_sw
			sw2_tbl[best_sw2] = sw2_tbl[best_sw2] + sw2_tbl[8]
		end

		vim.bo.shiftwidth = best_sw
		if (
			best_sw2 and
			best_sw2 % best_sw == 0 and
			et_tbl[best_sw2 + best_sw] < sw2_tbl[best_sw2]
		) then
			-- Space with tabs.
			vim.bo.expandtab = false
			vim.bo.tabstop = best_sw + best_sw2
			vim.bo.vartabstop = ''
		else
			-- Space only.
			vim.bo.expandtab = true
			vim.bo.tabstop = 8
			vim.bo.vartabstop = saved_vartabstop
		end
		vim.bo.softtabstop = 0
		vim.b.did_vimdent = 1
		return
	end

	-- Unknown.
	vim.bo.tabstop = saved_tabstop
	vim.bo.vartabstop = saved_vartabstop

	vim.api.nvim_create_autocmd('BufWritePost', {
		group = group,
		buffer = 0,
		once = true,
		callback = detect,
	})

	if vim.bo.filetype == '' then
		vim.api.nvim_create_autocmd('FileType', {
			group = group,
			buffer = 0,
			once = true,
			callback = detect,
		})
		return
	end

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if (
			vim.b[buf].did_vimdent == 1 and
			vim.bo[buf].filetype == vim.bo.filetype
		) then
			vim.bo.shiftwidth = vim.bo[buf].shiftwidth
			vim.bo.expandtab = vim.bo[buf].expandtab
			vim.bo.tabstop = vim.bo[buf].tabstop
			vim.bo.vartabstop = vim.bo[buf].vartabstop
			vim.bo.softtabstop = vim.bo[buf].softtabstop
			-- Do not set did_vimdent, it is only a soft guess.
			return
		end
	end
end

vim.api.nvim_create_autocmd('BufReadPost', {
	group = group,
	callback = function()
		vim.api.nvim_create_autocmd('BufEnter', {
			group = group,
			buffer = 0,
			once = true,
			callback = detect,
		})
	end,
})

vim.api.nvim_create_autocmd('BufNewFile', {
	group = group,
	callback = detect,
})

vim.api.nvim_create_user_command('Vimdent', detect, {})
