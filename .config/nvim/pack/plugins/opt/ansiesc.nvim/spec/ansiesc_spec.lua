local vim = create_vim()

local function assert_hls(expected)
	local ms = vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })
	local actual = {}

	for _, m in ipairs(ms) do
		local _, row, col, details = unpack(m)
		local hl = vim.api.nvim_get_hl(0, { name = details.hl_group })
		table.insert(actual, {
			region = { row, col, details.end_row, details.end_col },
			hl = hl,
		})
	end

	return assert.same(expected, actual)
end

describe(':AnsiEsc', function()
	it('removes SGR and keeps added highlights after ColorScheme', function()
		local hls = {
			{
				region = { 0, 0, 0, 3 },
				hl = {
					bold = true,
					cterm = { bold = true },
				},
			},
			{
				region = { 0, 3, 1, 0 },
				hl = {
					bold = true,
					italic = true,
					underline = true,
					reverse = true,
					strikethrough = true,
					cterm = {
						bold = true,
						italic = true,
						underline = true,
						reverse = true,
						strikethrough = true,
					},
					fg = 0x010203,
					bg = 0x040506,
					sp = 0x070809,
				},
			},
		}
		vim:set_lines({
			'\x1b[1m012\x1b[3;4;7;9;38;2;1;2;3;48;2;4;5;6;58;2;7;8;9m345',
			'6\x1b[m7\x1b[999999999999;;;;;;;;;;;;;;;;;m8\x1b[9999m',
		})
		vim.cmd.AnsiEsc()
		vim:assert_lines({ '012345', '678' })
		assert_hls(hls)
		vim.cmd.colorscheme('default')
		assert_hls(hls)
	end)
end)

it('parses SGR correctly', function()
	local function test_hl(params, hl)
		vim.cmd.enew()
		vim:set_lines({
			string.format('\x1b[%sm012\x1b[%s;0mdefault', params, params),
		})
		vim.cmd.doautocmd('colorscheme')
		vim.cmd.AnsiEsc()

		return assert_hls({
			hl and {
				region = { 0, 0, 0, 3 },
				hl = hl,
			},
		})
	end

	local bold = { bold = true, cterm = { bold = true } }
	test_hl('1', bold)
	test_hl('1;22', nil)

	local italic = { italic = true, cterm = { italic = true } }
	test_hl('3', italic)
	test_hl('3;23', nil)

	local underline = { underline = true, cterm = { underline = true } }
	test_hl('4', underline)
	test_hl('4;24', nil)

	local reverse = { reverse = true, cterm = { reverse = true } }
	test_hl('7', reverse)
	test_hl('7;27', nil)

	test_hl('9', { strikethrough = true, cterm = { strikethrough = true } })

	local t = {
		0x000000,
		0xff0000,
		0x00ff00,
		0xffff00,
		0x0000ff,
		0xff00ff,
		0xc0c0c0,
		0x808080,
	}
	for i = 0, 7 do
		local function test_normal(color)
			test_hl('3' .. i, { fg = color })
			test_hl('4' .. i, { bg = color })
			test_hl('38;5;' .. i, { fg = color })
			test_hl('48;5;' .. i, { bg = color })
			test_hl('58;5;' .. i, { sp = color })
		end

		vim.g['terminal_color_' .. i] = '#123456'
		test_normal(0x123456)

		vim.g['terminal_color_' .. i] = nil
		test_normal(t[i + 1])
	end

	local t = {
		0x000000,
		0xff0000,
		0x00ff00,
		0xffff00,
		0x0000ff,
		0xff00ff,
		0x00ffff,
		0xffffff,
	}
	for i = 0, 7 do
		local function test_bright(color)
			test_hl('9' .. i, { fg = color })
			test_hl('10' .. i, { bg = color })
			test_hl('38;5;' .. (i + 8), { fg = color })
			test_hl('48;5;' .. (i + 8), { bg = color })
			test_hl('58;5;' .. (i + 8), { sp = color })
		end

		vim.g['terminal_color_' .. (i + 8)] = '#123456'
		test_bright(0x123456)

		vim.g['terminal_color_' .. (i + 8)] = nil
		test_bright(t[i + 1])
	end

	test_hl('30;30', { fg = 0x000000 })
	test_hl('30;39', nil)

	test_hl('40;40', { bg = 0x000000 })
	test_hl('40;49', nil)

	local function test_indexed(i, color)
		test_hl('38;5;' .. i, { fg = color })
		test_hl('48;5;' .. i, { bg = color })
		test_hl('58;5;' .. i, { sp = color })
	end

	test_indexed(16, 0x000000)
	test_indexed(17, 0x00005f)
	test_indexed(18, 0x000087)
	test_indexed(19, 0x0000af)
	test_indexed(20, 0x0000d7)
	test_indexed(21, 0x0000ff)
	test_indexed(22, 0x005f00)
	test_indexed(34, 0x00af00)
	test_indexed(37, 0x00afaf)
	test_indexed(51, 0x00ffff)
	test_indexed(160, 0xd70000)
	test_indexed(201, 0xff00ff)
	test_indexed(211, 0xff87af)
	test_indexed(232, 0x080808)
	test_indexed(233, 0x121212)
	test_indexed(234, 0x1c1c1c)
	test_indexed(244, 0x808080)
	test_indexed(254, 0xe4e4e4)
	test_indexed(255, 0xeeeeee)

	local function test_rgb(params, color)
		test_hl('38;2;' .. params, { fg = color })
		test_hl('48;2;' .. params, { bg = color })
		test_hl('58;2;' .. params, { sp = color })
	end

	test_rgb('1;2;3', 0x010203)
	test_rgb('0;0;0', 0x000000)
	test_rgb('255;255;255', 0xffffff)

	test_hl('9999;1', bold)

	test_hl('1m\x1b[1', bold)
	test_hl('1m\x1b[', nil)
	test_hl('3;', nil)
	test_hl('1;;3', italic)
	test_hl('1;0;3', italic)
end)
