highlight qfWarning gui=bold guifg=#a36ac7
highlight qfError gui=bold guifg=#ed407a
highlight qfCode gui=bold
match qfWarning /warning:/
2match qfError /error:/
3match qfCode /‘[^’]*’/
