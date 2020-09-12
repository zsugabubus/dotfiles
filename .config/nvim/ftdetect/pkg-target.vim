autocmd BufRead,BufNewFile,BufFilePost fetch,make,install
  \  if expand('%:p:h:h:h:t') ==# 'pkg'
  \|   setfiletype sh
  \|   set noet ts=2 sw=2 sts=2
  \| endif
