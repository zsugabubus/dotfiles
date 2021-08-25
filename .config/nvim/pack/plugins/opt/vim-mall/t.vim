source plugin/mall.vim
source autoload/mall.vim

%d|a
aaa = 4,     eeee  = h
bbb    = 8, bb   = k
c = 9,   = z

aaa = 4,     eeee = h
bbb = 8, bb       = k
c   = 9,          = z

.

normal ggV3jgl=
call assert_equal(getline(1, 4), getline(5, 8))

%d|a
aaa = 4,     eeee  = h
bbb    = 8, bb   = k
c = 9,   = z
aaa = 4,     eeee  = h
bbb = 8, bb   = k
c   = 9,   = z
.

normal ggV2j1gl=
call assert_equal(getline(1, 3), getline(4, 6))

if empty(v:errors)
	cquit 0
endif

redraw
for error in v:errors
	echoe error
endfor
