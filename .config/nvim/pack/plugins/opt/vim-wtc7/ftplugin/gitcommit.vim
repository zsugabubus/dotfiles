command! -buffer WTC call setline(1, systemlist(['curl', '-s', 'http://whatthecommit.com/index.txt'])[0])
