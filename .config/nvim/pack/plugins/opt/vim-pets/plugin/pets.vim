" Pets. Snippets like regexp-based abbrevations.
if exists('g:loaded_pets')
	finish
end

let s:save_cpo = &cpo
set cpo&vim

" Replace <Tab> with this key.
if !has_key(g:, 'pets_joker')
	let g:pets_joker = "<Tab>"
endif

let s:skipsc = 'synIDattr(synID(line("."), col("."), 0), "name") =~? "\vstring|comment"'
function! g:PetsUnclosedBrackets(lookbehind) abort
	let winview = winsaveview()
	let brackets = ''
	let roundpos = [0, 0]
	let prev_roundpos = [0, 0]
	let squarepos = [0, 0]
	let prev_squarepos = [0, 0]

	while 1
		if prev_squarepos ==# squarepos
			let squarepos = searchpairpos('\V[', '', '\V]', 'nb', s:skipsc, max([line('.') - a:lookbehind, 1]), 30)
		endif
		if prev_roundpos ==# roundpos
			let roundpos = searchpairpos('\V(', '', '\V)', 'nb', s:skipsc, max([line('.') - a:lookbehind, 1]), 30)
		endif
		if prev_squarepos ==# squarepos && prev_roundpos ==# roundpos || (squarepos ==# [0, 0] && roundpos ==# [0, 0])
			break
		endif

		if squarepos[0] ># roundpos[0] || (squarepos[0] ==# roundpos[0] && squarepos[1] ># roundpos[1])
			let brackets .= ']'
			call cursor(squarepos)
			let prev_squarepos = squarepos
		else
			let brackets .= ')'
			call cursor(roundpos)
			let prev_roundpos = roundpos
		endif
	endwhile

	call winrestview(winview)
	return brackets
endfunction

function! g:PetsCFormatPreprocessorDirective(pd)
	return matchstr(repeat(' ', searchpair('\v\C^#\s*<ifn?%(def)?>', '\v\C^#\s*<%(elif|else)>', '\v\C^#\s*<endif>', 'nWrm', s:skipsc)).a:pd, '\v\C^\s?\zs.*$')
endfunction

augroup vim_pets_snippets
	autocmd!

	" Reset.
	autocmd FileType * let b:pets_snippets = []

	autocmd BufNew,BufCreate,BufAdd,BufReadPost,BufWinEnter *
		\ if !exists('b:pets_snippets')|
		\   let b:pets_snippets = []|
		\ endif

	autocmd FileType lex,yacc let b:pets_snippets += [
		\ ["\\%{", "{\<CR>%}\<C-o>O"],
		\]

	autocmd FileType html,xml let b:pets_snippets += [
		\ ["\\<([a-zA-Z0-9:]+)[^>]*/@<!\\>[^>]*\<CR>", "\<CR></\\1>\<Esc>O"],
		\ ["\\<([a-zA-Z0-9:]+)[^>]*>", ">\<Esc>a</\\1>\<C-g>U\<C-o>`["],
		\ ["\\<([a-zA-Z0-9:]+)[^>]*\\>[^>]*<", "</\\1>"],
		\ ["\\<([a-zA-Z0-9:]+)[^>]{-}\\ze\\s*/", " />"],
		\]

	autocmd FileType css let b:pets_snippets += [
		\ ['\ze\s*!', ' !important;'],
		\]

	autocmd FileType c,cpp let b:pets_snippets += [
		\ ['^\s*enum\s+(\k+)\s*{', {m-> "{\<CR>".toupper(substitute(m[1], '\C\v[^A-Z_]\zs\ze[A-Z]|[A-Z]\zs\ze[A-Z][a-z]', '_', 'g'))."_,\<CR>};\<Esc>k$i"}],
		\ ["^\\s*<%(if|for|while)> ", " ("],
		\ ["^\\s*<%(if|for|while)>.{-}\\)\\ze ", {m-> empty(g:PetsUnclosedBrackets(winline())) ? " {\<CR>}\<C-O>O" : " "}],
		\ ["<for>[^;]+;(\\s?)[^;]+;", {m-> ";".m[1]}],
		\ ["<for>\\s*\\([^;]*;(\\s*)(\\k+)\\s*([<>])\\s*[^; \t]+\<Tab>", {m-> ';'.m[1].(m[3] == '<' ? '++' : '--').m[2].')'}],
		\ ["<for>(\\s*)\\((\\k+)(\\s*)\\=\\s*(\\d+)\<Tab>", {m-> ';'.m[1][:0].m[2].m[3]."<>"[m[4] >=# 1].m[3]}],
		\ ["^\\ze#ifndef (\\k+_H)\<CR>", {m-> "#ifndef ".m[1]."\<CR>#define ".m[1]."\<CR>\<CR>\<CR>\<CR>#endif /* ".m[1]." */\<Up>\<Up>"}],
		\ ["^#ifdef __cplusplus\<CR>", "\<CR>extern \"C\" {\<CR>#endif\<CR>\<CR>\<CR>#ifdef __cplusplus\<CR>}\<CR>#endif\<Up>\<Up>\<Up>\<C-O>O\<C-D>"],
		\ ["^#(\\s*)if.*\<CR>", "\<CR>#\\1endif\<C-O>O"],
		\ ["^#(\\s*)endif.*\<CR>", "\<C-O>O#\\1e"],
		\ ['^\ze(\s*)#(\s*)%[include]<',  "\\1#\\2include <.h>\<Left>\<Left>\<Left>"],
		\ ['^\ze(\s*)#(\s*)%[include]"', "\\1#\\2include \".h\"\<Left>\<Left>\<Left>"],
		\ ["^\\ze#\\s*<(p%[ragma]|i%[fdef]|i%[fndef]|e%[lif]|e%[ndif]|u%[ndef]|d%[efine]|i%[nclude]|i%[mport]|e%[rro])> ", {m-> '#'.PetsCFormatPreprocessorDirective(matchstr('# pragma # if # ifdef # ifndef #elif #else # undef # define # include # import # error # endif ', '\v\C#\zs ?\V'.m[1].'\v.{-} '))}],
		\ ["^\\ze#\\s*<(e%[lse])>\<CR>", {m-> '#'.PetsCFormatPreprocessorDirective('else')."\<CR>"}],
		\ ["^#(\\s*)<ifn?%(def)?>\\s*\\S*\<CR>", "\<CR>#\\1endif\<C-O>O"],
		\ ['^\s*\zei(', {m-> 'if'.(search('\v^\s*if( +)?\(', 'bnpw') ==# 1 ? '' : ' ').'('}],
		\ ['^\s*<case>.+:\s*\ze{', {m-> "\<CR>\<C-D>{\<CR>}\<CR>\<C-T>break;\<CR>\<C-O>2k\<C-O>O"}],
		\ ['^\s*\zede%[fault]:', "default:\<CR>"],
		\ ['^\s*\ze<(f%[or]|s%[witch]|w%[hile])>(', {m-> matchstr('for switch while', '\v<'.m[1].'\v.{-}>').(search('\v^\s*'.matchstr('for switch while', '\v<'.m[1].'\v.{-}>').'( +)?\(', 'bnpw') ==# 1 ? '' : ' ').'('}],
		\ ['^\s*<(if|do|for|switch|while)>.*\S{', {m-> (search('\v^\s*'.m[1].'>.{-}( +)?\{$', 'bnpw') ==# 1 ? '' : ' ')."{\<CR>}\<C-O>O"}],
		\ ['^\s*}? *\ze<(e%[lse])> ', {m-> 'else '}],
		\ ['^\s*}? *\ze<(e%[lse])>(', {m-> 'else if'.(search('\v^\s*if( +)?\(', 'bnpw') ==# 1 ? '' : ' ').'('}],
		\ ['^\s*\ze(} *)?<(e%[lse])>{', {m-> (!empty(m[1]) ? '}'.(search('\v^\s*}( +)?else>', 'bnpw') ==# 1 ? '' : ' ') : '')."else".(search('\v^\s*}? *else( +)?\{', 'bnpw') ==# 1 ? '' : ' ')."{\<CR>}\<C-O>O"}],
		\ ["^\\s*}? *\\ze<(e%[lse])>\<CR>", "else\<CR>"],
		\ ['^%(.{-}<for>.*)@!\ze;', {m-> substitute(g:PetsUnclosedBrackets(winline()), '\m^$', ';', '')}],
		\ ['^%(.{-}<for>.*)@!;\\ze;', "\<CR>"],
		\ ['typedef.*{', "{\<CR>} ;\<Left>"],
		\ ['\ze<s%[truct]%(\s+(\k+))?\s*{', {m-> 'struct'.(!empty(m[1]) ? ' '.m[1] : '').(search('\v^\s*struct\s+\k+( +)?\{', 'bnpw') ==# 1 ? '' : ' ')."{\<CR>};\<C-O>O"}],
		\ ["\\ze<s%[truct]\\s+(\\k+)\<CR>", "struct \\1\<CR>{\<CR>};\<C-O>O"],
		\ ['\ze<s%[truct]\s+(\k+);', "struct \\1;\<C-O>o"],
		\ ["^\\s*#(\\s*)define\\s*(\\k+).*[^\\\\]\<CR>", "\<CR>#\\1undef \\2\<Esc>j$"],
		\ ["^\\s*\\zer%[eturn];", "return;\<Left>"],
		\ ['\S-\ze\>-', '-'],
		\ ["^[^\"]*%(%(\"[^\"]*){2})*[^- \\t\"'[({0-9]-", '->'],
		\ ['-\>>', ''],
		\ ['%(<for>.*)@<!;;', "\<C-F>\<Esc>"],
		\ ['^\s*memset\(([*()]*\w+[*()]*))', ', 0, sizeof *\1);'],
		\]

	autocmd FileType c,cpp,rust let b:pets_snippets += [
		\ ['%(^|\w\s*){', "{\<CR>}\<C-O>O"],
		\ ["\\.\\w+\\s*\\=\\s*\\{\<CR>", "\<CR>},\<C-O>O"],
		\ ["\\=\\s*\\{ ", "  },\<Left>\<Left>\<Left>"],
		\ ["\\{\<CR>", "\<CR>}\<C-O>O"],
		\ ['\{ ', "  }\<Left>\<Left>"],
		\ ['\)\s*{', "{\<CR>}\<C-O>O"],
		\ ['^\s*\ze3;', "__asm__(\"int3\");\<C-F>"],
		\ ['^\s*va_list (\k+);', {m-> ";\<CR>va_start(".m[1].", ".matchstr(getline(searchpos('\V...', 'bW')[0]), '\v\k+\ze[ \t]*,+[ \t]*\.\.\.').");\<CR>va_end(".m[1].");\<Esc>k_"}],
		\ ['^\s*<(b%[rea]|c%[ontinu])>;', {m-> matchstr('break;continue;', '\V\<'.m[1].'\v\zs.{-};')}],
		\]

	autocmd FileType php let b:pets_snippets += [
		\ ["['\"]=", ' => '],
		\ ["\S-", '->']
		\]

	autocmd FileType rust let b:pets_snippets += [
		\ ["^\\s*<%(fun|trait|struct|for|loop|match|%(<else> )?if)>.{-}[^{]\\zs\\s*\<CR>", "\<CR>{\<CR>}\<C-O>O"],
		\ ["^\\s*<%(fun|trait|struct|for|loop|match|%(<else> )?if)>.{-}[^{]\\zs\\s*{", " {\<CR>}\<C-O>O"],
		\ ["^.*<let>.*=", "= "],
		\ ["\\=>", "> "],
		\ ["\\ze<e%[lse]>{", "else {\<CR>}\<C-O>O"],
		\ ["\\ze<e%[lse]>\<CR>", "else\<CR>{\<CR>}\<C-O>O"],
		\]

	autocmd FileType sh,bash,zsh let b:pets_snippets += [
		\ ["^\\s*<case>%(\\s+\\S+|.{-}\\ze\\s+<in>)\<CR>", " in\<CR>esac\<C-O>O"],
		\ ["<then>\<CR>", "\<CR>fi\<C-O>O"],
		\ ["<do>\<CR>", "\<CR>done\<C-O>O"],
		\ ["<for>\\s+\\w+ ", " in "],
		\ ["^\\s*<%(for|while|until)>.*;", "; do\<CR>done\<C-O>O"],
		\ ["^\\s*<%(for|while|until)>.*\<CR>", "\<CR>do\<CR>done\<C-O>O"],
		\ ["\\<\\<(\"?)(\\w+)\\ze\"?\<CR>", "\\1\<CR>\\2\<C-O>O"],
		\ ["\\<\\<(\"?)\<CR>", "EOF\\1\<CR>EOF\<C-O>O"],
		\]

	autocmd FileType vim let b:pets_snippets += [
		\ ["^\\s*<(fu%[nction]|for|wh%[ile]|try|if)>.*\<CR>", "\<CR>end\\1\<C-O>O"],
		\ ["^\\s*<(aug%[roup]>(\\s+<END>)@!)>.*\<CR>", "\<CR>\\1 END\<C-O>O"],
		\]

	autocmd FileType lua let b:pets_snippets += [
		\ ["<%(else)?if>.{-}\\ze\\s*%(.*<then>.*)@<!\<CR>", {-> " then\<CR>end\<C-O>O"}],
		\ ["<%(else)?if>.*<then>.*\\S+.{-}\\ze\s*%(<end>)@<!\<CR>", " end\<CR>"],
		\ ["<%(do|then)>%(.*<end>.*)@<!\<CR>", "\<CR>end\<C-O>O"],
		\ ["\\ze<%(f%[unction])>(.{-})%(<end>)@<!\<CR>", {m-> 'function'.m[1].g:PetsUnclosedBrackets(1)."\<CR>end\<C-O>O"}],
		\ ["^\\s*\\ze<e%[ls]>\<CR>", "else\<CR>"],
		\ ["^\\s*\\ze<e%(%[lsif]|%[lseif])> ", "elseif "],
		\ ["^\\s*<(for|while)>.{-}\\ze\\s*%(<do>\\s*)@<!\<CR>", " do\<CR>end\<C-O>O"],
		\]

	autocmd FileType meson let b:pets_snippets += [
		\ ["^\\s*(if|foreach)>.*\<CR>", "\<CR>end\\1\<C-d>\<C-O>O"],
		\]

	autocmd FileType tex,plaintex let b:pets_snippets += [
		\ ["^\\\\begin\\{([^}]+)\\}.*\<CR>", "\<CR>\\\\end{\\1}\<C-O>O"],
		\ ["^\\\\%(sub)?section.*\<CR>", "\<CR>\<CR>"],
		\]

	autocmd FileType gdb let b:pets_snippets += [
		\ ["^\\s*<%(define|doc%[ument]|if|while|commands?)>.*\<CR>", "\<CR>end\<C-O>O"]
		\]

	" Vim fold marks
	autocmd FileType * let b:pets_snippets += [
		\ ["^\\s*(\\S+\\s*).{-}\\{\\{\\{(\\d*).{-}(\\s*\\S+)\<CR>", "\<CR>\\1\\2}}}\\3\<C-O>O"],
		\]

	autocmd FileType * let b:pets_snippets += [
		\ ["([([{'\"]+)\<CR>", {m-> "\<CR>".join(reverse(split(substitute(m[1], '.', {n-> get({'(': ')', '[': ']', '{': '}'}, n[0], n[0])}, 'g'), '\zs')), '')."\<C-o>O"}],
		\]

augroup END

augroup vim_pets_cmds
	autocmd!
	autocmd BufEnter *
		\ for [pat, Sub] in get(b:, 'pets_snippets', [])|
		\   let key = pat[-1:-1]|
		\   let key = get({"\<Space>": '<Space>', "\<Tab>": g:pets_joker}, key, key)|
		\   if !empty(key)|
		\     execute 'inoremap <expr><nowait><buffer><script><silent> '.key.' <SID>pets("'.(key ==# '"' ? '\"' : key).'")'|
		\   endif|
		\ endfor
augroup END

function! s:pets(key) abort
	let llen = col('$')
	if col('.') ==# llen && empty(reg_recording()) && empty(reg_executing())
		let lnum = line('.')
		let line = getline(lnum)
		let key = a:key !=# g:pets_joker ? a:key : "\<Tab>"

		for [pat, Sub] in get(b:, 'pets_snippets', [])
			if pat[-1:-1] !=# a:key
				continue
			endif

			let pat = '\v\C'.(pat[0] ==# '^' ? '\_' : '^.{-}').pat[:-2].'$'
			try
				let m = matchend(line, pat)
			catch
				throw 'pets: regexp: '.pat.': '.v:exception
				continue
			endtry
			if m !=# -1
				let dellen = len(substitute(strpart(line, m), '\m.', '.', 'g'))
				return (dellen >=# 2 ? "\<C-O>".(dellen - 1). 'X' : '') .
						 \ (dellen >=# 1 ? "\<C-O>x" : '') .
						 \ substitute(line, pat.'\m\ze', Sub, 'I')
			endif
		endfor
	endif

	return a:key
endfunction

let g:loaded_pets=1

let &cpo = s:save_cpo
unlet s:save_cpo
