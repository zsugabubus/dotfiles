local health = vim.health

local M = {}

function M.check()
	health.start('External tools')
	health.check_executable('tar')
	health.check_executable('zipinfo')
	health.check_executable('unzip')
	health.check_executable('gzip')
	health.check_executable('bzip2')
	health.check_executable('uncompress')
	health.check_executable('lzma')
	health.check_executable('xz')
	health.check_executable('lzip')
	health.check_executable('zstd')
	health.check_executable('brotli')
	health.check_executable('lzop')
end

return M
