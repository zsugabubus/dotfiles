" $ vim -S test.vim

function s:detect() abort
	let &sw = 42
	let &ts = 42
	let &sts = 42
	let &et = 0

	%delete
	call setline(1, s:input)
	call vimdent#Detect()
endfunction

function s:got() abort
	return {'et': &et, 'ts': &ts, 'sts': &sts, 'sw': &sw}
endfunction

let s:input =<< EOF
	x
	x
		x
EOF
call s:detect()
call assert_equal({'et': 0, 'ts': 42, 'sts': -1, 'sw': 0}, s:got())

let s:input =<< EOF
 x
	x
 x
	x
 x
		x
EOF
call s:detect()
call assert_equal({'et': 0, 'ts': 42, 'sts': 42, 'sw': 42}, s:got())

let s:input =<< EOF
    x
    x
	x
	    x
    x
    x
EOF
call s:detect()
call assert_equal({'et': 0, 'ts': 8, 'sts': 8, 'sw': 4}, s:got())

let s:input =<< EOF
					x
                x
			x

			x
			x

			x
				x
					x
					x
				x
				x
					x
                x
            x
		x
EOF
call s:detect()
call assert_equal({'et': 0, 'ts': 4, 'sts': 4, 'sw': 4}, s:got())

let s:input =<< EOF
					x
                x
			x

			x
			x

			x
				x
					x
					x
				x
				x
					x
				x
            x
		x
EOF
call s:detect()
call assert_equal({'et': 0, 'ts': 4, 'sts': 4, 'sw': 4}, s:got())

let s:input =<< EOF
				x
	            x
					x
				x
	        x
		x
EOF
call s:detect()
call assert_equal({'et': 0, 'ts': 4, 'sts': 4, 'sw': 4}, s:got())

let s:input =<< EOF
				x
				x
			x
	        x
		x
EOF
call s:detect()
call assert_equal({'et': 0, 'ts': 4, 'sts': 4, 'sw': 4}, s:got())

let s:input =<< EOF
x
  x
  x
  x
  x
    x
    x
    x
      x
            x
	       x
	       x
	    x
            x
	    x
	x
	    x
EOF
call s:detect()
call assert_equal({'et': 1, 'ts': 2, 'sts': 2, 'sw': 2}, s:got())

let s:input =<< EOF

x
  x
      x
	x
      x
	x
  x
    x
      x
            x
	       x
	       x
	    x
            x
	    x
	x
	    x
EOF
call s:detect()
call assert_equal({'et': 0, 'ts': 8, 'sts': 8, 'sw': 2}, s:got())

" Space used for alignment.
let s:input =<< EOF
	x
	  x
	x
EOF
call s:detect()
call assert_equal({'et': 0, 'ts': 42, 'sts': -1, 'sw': 0}, s:got())
let s:input =<< EOF
	x
	    x
	x
EOF
call s:detect()
call assert_equal({'et': 0, 'ts': 42, 'sts': -1, 'sw': 0}, s:got())

if empty(v:errors)
	cquit 0
else
	echomsg 'Press C-c to examine'
	echoe v:errors
end
