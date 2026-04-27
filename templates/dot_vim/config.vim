" Leader
let mapleader = ' '

" System
set shell=/bin/zsh
set clipboard^=unnamed
let s:is_wsl = has('wsl') || (filereadable('/proc/version') && readfile('/proc/version')[0] =~? 'microsoft')
if s:is_wsl
  set clipboard^=unnamedplus
  " Route yank/paste through win32yank.exe so the Windows clipboard is used.
  function! s:Win32YankAvailable() abort
    return executable('win32yank.exe')
  endfunction

  function! s:Win32YankCopy(reg, type, lines) abort
    call system('win32yank.exe -i --crlf', join(a:lines, "\n"))
  endfunction

  function! s:Win32YankPaste(reg) abort
    return ['', split(system('win32yank.exe -o --lf'), "\n", 1)]
  endfunction

  let v:clipproviders['win32yank'] = {
    \ 'available': function('s:Win32YankAvailable'),
    \ 'copy': {
    \   '+': function('s:Win32YankCopy'),
    \   '*': function('s:Win32YankCopy'),
    \ },
    \ 'paste': {
    \   '+': function('s:Win32YankPaste'),
    \   '*': function('s:Win32YankPaste'),
    \ },
    \ }
  set clipmethod^=win32yank
endif
set nocompatible

" Command completions
set wildmenu
set wildmode=longest:full,full
set wildoptions=pum,tagfile

" Indent Guides
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_start_level=2
let g:indent_guides_guide_size=1

" Spell check
set spell

" Global undo
silent !mkdir -p ~/.vim/undo > /dev/null 2>&1
set undofile
set undodir=~/.vim/undo

" Global Swap Dir
silent !mkdir -p ~/.vim/backups > /dev/null 2>&1
set backupdir=~/.vim/backups
set autoread
set noswapfile

set statusline=%F

" Spacing and Wrapping
set expandtab
set softtabstop=2
set shiftwidth=2
set tabstop=2
set textwidth=100
set colorcolumn=80,100,120

" FileType specific settings
au FileType cs set shiftwidth=4 tabstop=4

" Interface
set showcmd

" Disable modelines
set nomodeline

" Editing
set smartindent
set showmode
set showmatch
" set list listchars=tab:>>,eol:Â
set list listchars=tab:\ \ ,eol:¬,trail:·
set number rnu
set backspace=indent,eol,start

" Multipurpose Tab Key
" function! InsertTabWrapper()
"   let col = col('.') - 1
"   if !col || getline('.')[col - 1] !~ '\k'
"     return "\<tab>"
"   else
"     return "\<c-p>"
"   endif
" endfunction
" inoremap <tab> <c-r>=InsertTabWrapper()<cr>
" inoremap <s-tab> <c-n>

" Searching
set incsearch
set hlsearch
set ignorecase smartcase
