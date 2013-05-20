" System
set nocompatible

" Syntax Highlighting
syntax enable

" Color
set t_Co=256 " 256 colors
set background=dark
color grb256

" Spacing and Wrapping
set expandtab
set softtabstop=2
set shiftwidth=2
set tabstop=2
set textwidth=80

" Interface
set number
set showcmd

" Editing
set smartindent
set showmode
set showmatch
set list listchars=tab:>>,eol:¬,trail:·

" No Arrow Keys
map <Left> <Nop>
map <Right> <Nop>
map <Up> <Nop>
map <Down> <Nop>

" Searching
set incsearch
set hlsearch
set ignorecase smartcase

" File Storage
set autoread
set noswapfile
set nobackup
set nowritebackup

" Leader
let mapleader = ','

function! InsertTabWrapper()
  let col = col('.') - 1
  if !col || getline('.')[col - 1] !~ '\k'
    return "\<tab>"
  else
    return "\<c-p>"
  endif
endfunction
