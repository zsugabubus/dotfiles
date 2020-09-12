syn match mailMarkdownItalic     '\v%(^|[[:space:]])(_|\*)\zs\S@<=[^[:punct:]]{-1}\S@<=\ze\1' keepend
syn match mailMarkdownBold       '\v%(^|[[:space:]])(__|\*\*)\zs\S@<=[^[:punct:]]{-1}\S@<=\ze\1%([[:punct:][:space:]]|$)' keepend
syn match mailMarkdownBoldItalic '\v%(^|[[:space:]])(___|\*\*\*)\zs\S@<=[^[:punct:]]{-1}\S@<=\ze\1%([[:punct:][:space:]]|$)' keepend
hi mailMarkdownItalic cterm=bold,italic
hi mailMarkdownBold cterm=bold
hi mailMarkdownBoldItalic cterm=bold,italic
