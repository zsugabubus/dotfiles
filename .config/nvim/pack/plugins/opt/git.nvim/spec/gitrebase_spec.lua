local vim = create_vim()

describe('gitrebase', function()
	before_each(function()
		vim.bo.filetype = 'gitrebase'
	end)

	it('changes command', function()
		local function test_case(keys, command)
			vim:set_lines({
				'xxx 0 A',
				'xxx 0 B',
				'xxx 0 C',
				'xxx 0 D',
			})
			vim:feed('gg' .. keys)
			vim:assert_lines({
				command .. ' 0 A',
				'xxx 0 B',
				'xxx 0 C',
				'xxx 0 D',
			})
			vim:feed('j.')
			vim:assert_lines({
				command .. ' 0 A',
				command .. ' 0 B',
				'xxx 0 C',
				'xxx 0 D',
			})
		end

		test_case('cd', 'drop')
		test_case('ce', 'edit')
		test_case('cf', 'fixup')
		test_case('cp', 'pick')
		test_case('cr', 'reword')
		test_case('cs', 'squash')
	end)

	it('previews commit; gf', function()
		vim:set_lines({ '0000' })
		vim:feed('gf')
		vim.cmd.wincmd('P')
		assert.same('git://0000', vim.fn.bufname())
	end)

	it('previews commit; <CR>', function()
		vim:set_lines({ '0000 xxx' })
		vim:feed('$\r')
		vim.cmd.wincmd('P')
		assert.same('git://0000', vim.fn.bufname())
	end)
end)
