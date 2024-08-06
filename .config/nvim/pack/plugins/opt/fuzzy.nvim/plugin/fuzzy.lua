local user_command = vim.api.nvim_create_user_command

user_command('FuzzyBuffers', function()
	require('fuzzy').buffers()
end, {})

user_command('FuzzyFiles', function()
	require('fuzzy').files()
end, {})

user_command('FuzzyTags', function()
	require('fuzzy').tags()
end, {})
