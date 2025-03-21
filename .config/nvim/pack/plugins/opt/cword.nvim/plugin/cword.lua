local user_command = vim.api.nvim_create_user_command

user_command('CwordToggle', function()
	require('cword').toggle()
end, {})

user_command('CwordEnable', function()
	require('cword').toggle(true)
end, {})

user_command('CwordDisable', function()
	require('cword').toggle(false)
end, {})
