local user_command = vim.api.nvim_create_user_command

user_command('ContextToggle', function()
	require('context').toggle()
end, {})

user_command('ContextEnable', function()
	require('context').toggle(true)
end, {})

user_command('ContextDisable', function()
	require('context').toggle(false)
end, {})
