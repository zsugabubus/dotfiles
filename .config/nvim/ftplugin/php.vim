let php_sql_query = 1
let php_htmlInStrings = 1
let php_parent_error_close = 1
set makeprg=php\ -lq\ %
set errorformat=%m\ in\ %f\ on\ line\ %l,%-GErrors\ parsing\ %f,%-G
