local uv = require('luv')
local a = require('async')

local I = vim.inspect
print('before')
a.async_do(function(inside)
	print(inside)

	print(I(a.uv.assert(a.await(a.future(a.uv.popen, {
		'git',
		'--no-optional-locks',
		'rev-parse',
		'--path-format=relative',
		'--abbrev-ref',
		'--absolute-git-dir',
		'--is-bare-repository',
		'--is-inside-git-dir',
		'--show-cdup',
		'--git-dir',
		'HEAD',
	})))))

	--[[ print(I(a.uv.assert(a.await(a.popen, {
		'git',
		'--no-optional-locks',
		'status',
		'--porcelain',
	})))) ]]

	--[[ print(a.await(a.popen, {
		'git',
		'--no-optional-locks',
		'rev-list',
		'--count',
		'--left-right',
		'--count',
		'--@{upstream}..@',
	})) ]]

	print('await simpl', a.uv_await.fs_open('/etc/passwd', 'r', 438))
	print('await man', a.await(a.uv.fs_open('/etc/passwd', 'r', 438)))

	print('aall', I(a.await_all({ a.all({ a.imm(6, 6, 6) }), a.all({}) })))
	print('ab', I(a.await_race({ a = a.all({}), b = a.all({}) })))
	print('123', a.await(a.imm(1, 2, 3)))

	print(
		'files',
		I(a.await_race({
			tmo = a.uv.timer(100),
			k = a.imm('k'),
			k2 = a.imm('k', 2),
			filesz = a.all({
				ok = a.uv.fs_open('/etc/passwd', 'r', 438),
				err = a.uv.fs_open('/etc/blabla', 'r', 438),
				msg = a.imm('hello', 'world'),
			}),
		}))
	)

	print(
		'cfiles',
		I(a.await_all({
			tmo = a.uv.timer(1),
			const = a.imm(1, 2, 3),
			files = a.all({
				a.race({ a.uv.future(uv.fs_open, '/etc/passwd', 'r', 438) }),
			}),
		}))
	)

	print(
		'race',
		I(a.await_race({
			a.uv.future(uv.fs_open, '/etc/passwd', 'r', 438),
			a.uv.future(uv.fs_open, '/etc/passwd', 'r', 438),
			a.uv.future(uv.fs_open, '/etc/passwd', 'r', 438),
		}))
	)
	print(
		'all',
		unpack(a.uv.assert(a.await_all({
			a.uv.future(uv.fs_open, '/etc/passwd', 'r', 438),
			a.uv.future(uv.fs_open, '/etc/passwd', 'r', 438),
			a.uv.future(uv.fs_open, '/etc/passwd', 'r', 438),
		})))
	)
	print('end')
end, 'inside')
print('after')
