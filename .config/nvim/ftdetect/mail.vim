autocmd BufRead *
  \  if getline(1) =~# 'From '
  \|   setfiletype mail
  \| endif
