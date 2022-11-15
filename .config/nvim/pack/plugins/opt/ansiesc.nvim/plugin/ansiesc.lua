vim.api.nvim_create_user_command('AnsiEsc', function()
	require 'ansiesc'.highlight_buffer(0)
end, {})
