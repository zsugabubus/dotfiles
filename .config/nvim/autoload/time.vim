function! time#Time(arg) abort
	let start = reltime()
	try
		execute a:arg
	finally
		echomsg 'time' reltimestr(reltime(start)) 's'
	endtry
endfunction
