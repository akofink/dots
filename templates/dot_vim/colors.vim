" Syntax Highlighting
set t_Co=256
set background=light
" Use the fixed 256-color solarized palette so it does not depend on the
" terminal's ANSI palette being solarized (e.g. Herdr's default theme).
let g:solarized_termcolors = 256
colorscheme solarized

" Highlighting Tweaks
highlight Search ctermbg=7 ctermfg=9

" Make the sign column background transparent/NONE
highlight SignColumn ctermbg=NONE guibg=NONE

" GitGutter sign highlights - transparent/NONE
highlight GitGutterAdd ctermbg=NONE guibg=NONE
highlight GitGutterChange ctermbg=NONE guibg=NONE
highlight GitGutterDelete ctermbg=NONE guibg=NONE
highlight GitGutterChangeDelete ctermbg=NONE guibg=NONE

" CoC Highlighting Tweaks
highlight CocInlayHint ctermfg=15 ctermbg=7

" CoC diagnostic sign highlights - blend with line numbers
" highlight CocErrorSign ctermbg=NONE guibg=NONE
" highlight CocWarningSign ctermbg=NONE guibg=NONE
" highlight CocInfoSign ctermbg=NONE guibg=NONE
" highlight CocHintSign ctermbg=NONE guibg=NONE
