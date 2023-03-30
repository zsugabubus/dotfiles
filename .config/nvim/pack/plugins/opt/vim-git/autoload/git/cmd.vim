let s:git_jobs = {}

function! git#cmd#run(cb, ...) abort dict
	let cmd = ['git', '--no-optional-locks'] + a:000
	if &verbose >= 1
		echomsg 'git: Running' string(cmd)
	end

	if has('nvim')
		let job_id = jobstart(cmd, {
			\  'pty': 0,
			\  'stdout_buffered': 1,
			\  'stderr_buffered': 1,
			\  'on_stdout': function('s:git_nvim_on_stdout'),
			\  'on_stderr': function(!empty(self) ? 's:git_ignore_stderr' : 's:git_print_stderr'),
			\  'on_exit': function('s:git_nvim_on_exit'),
			\  'self': self,
			\  'cb': a:cb
			\})
		if job_id <= 0
			echoerr 'git: jobstart() failed'
			call interrupt()
		endif
		let s:git_jobs[job_id] = job_id
	else
		let job = job_start(cmd, {
			\  'in_io': 'null',
			\  'out_io': 'pipe',
			\  'err_io': 'null',
			\  'close_cb': function('s:git_vim_on_exit')
			\})
		let s:git_jobs[job_info(job).process] = [job, a:cb, self]
	endif
endfunction

function! git#cmd#cancel_jobs() abort
	if empty(s:git_jobs)
		echomsg 'git: No running jobs'
		return
	else
		echomsg printf('git: Cancelling %d jobs...', len(s:git_jobs))
	endif

	if has('nvim')
		for job_id in values(s:git_jobs)
			call jobstop(job_id)
		endfor
	else
		" TODO: Implement
	endif
endfunction

function! git#cmd#output(...) abort
	if has('nvim')
		let cmd = ['git', '--no-optional-locks'] + a:000
	else
		let cmd = 'git --no-optional-locks'.join(map(copy(a:000), {_,x-> ' '.shellescape(x)}), '')
	endif
	if &verbose >= 1
		echomsg 'git: Running ' string(cmd)
	end
	let output = systemlist(cmd)
	if v:shell_error
		call s:print_error(output)
		call interrupt()
	endif
	return output
endfunction

function! s:git_ignore_stderr(chan_id, data, name) abort dict
endfunction

function! s:git_print_stderr(chan_id, data, name) abort dict
	call s:print_error(a:data)
endfunction

function! s:git_nvim_on_exit(chan_id, data, name) abort dict
	unlet s:git_jobs[a:chan_id]
endfunction

function! s:git_vim_on_exit(ch) abort
	let output = []
	while ch_status(a:ch, { 'part': 'out' }) ==# 'buffered'
		let output += [ch_read(a:ch)]
	endwhile
	let process = job_info(ch_getjob(a:ch)).process
	let [job, cb, git] = s:git_jobs[process]
	unlet s:git_jobs[process]
	if output ==# ['']
		return
	endif
	call call(function(cb), [output], git)
endfunction

function! s:git_nvim_on_stdout(chan_id, data, name) abort dict
	call call(self.cb, [a:data], self.self)
endfunction

function! s:print_error(output) abort
	echohl Error
	echomsg join(a:output, "\n")
	echohl None
endfunction
