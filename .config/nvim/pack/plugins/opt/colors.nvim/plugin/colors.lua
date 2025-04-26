vim.api.nvim_create_user_command('ColorsInstall', function()
	require('colors').install_library()
	require('colors').load_library()
end, {})
