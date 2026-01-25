if executable('rg')
  " let g:ackprg = 'rg --vimgrep'
  let g:grepprg = 'rg --vimgrep'
elseif executable('ag')
  " let g:ackprg = 'ag --vimgrep'
  let g:grepprg = 'ag --vimgrep'
endif
command -nargs=* Ag :copen | Ggrep <args>
