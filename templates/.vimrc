" System
set shell=/bin/bash
set clipboard^=unnamed
set nocompatible
filetype off
set rtp+=~/.vim/bundle/Vundle.vim

" Leader
let mapleader = ' '

source ~/.vim/plug.vim

set statusline=%f

source ~/.vim/coc-config.vim

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
map <leader>s :set spell!<CR>

" Global undo
silent !mkdir -p ~/.vim/undo > /dev/null 2>&1
set undofile
set undodir=~/.vim/undo

" Global Swap Dir
silent !mkdir -p ~/.vim/backups > /dev/null 2>&1
set backupdir=~/.vim/backups

" CtrlP Setup
" let g:ctrlp_max_files=0
" let g:ctrlp_custom_ignore = 'node_modules\|DS_Store\|git\|.venv|local'
set runtimepath^=~/.vim/bundle/ctrlp.vim
let g:ctrlp_show_hidden = 1
if executable('rg')
  let g:ctrlp_user_command = 'rg %s --files -g "!.git/" --color=never --hidden --glob ""'
elseif executable('ag')
  let g:ctrlp_user_command = 'ag %s -l --nocolor --hidden -g ""'
endif

" source ~/.vim/vim-lsp.vim

" source ~/.vim/gist.vim

" Syntax Highlighting
set t_Co=256
set background=light
colorscheme solarized
filetype plugin indent plugin on

" Highlighting Tweaks
highlight Search ctermbg=7 ctermfg=9

" CoC Highlighting Tweaks
highlight CocInlayHint ctermfg=15 ctermbg=7

" Spacing and Wrapping
set expandtab
set softtabstop=2
set shiftwidth=2
set tabstop=2
set textwidth=100
set colorcolumn=80,100,120

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
function! InsertTabWrapper()
  let col = col('.') - 1
  if !col || getline('.')[col - 1] !~ '\k'
    return "\<tab>"
  else
    return "\<c-p>"
  endif
endfunction
" inoremap <tab> <c-r>=InsertTabWrapper()<cr>
" inoremap <s-tab> <c-n>

" Searching
set incsearch
set hlsearch
set ignorecase smartcase

if executable('rg')
  " let g:ackprg = 'rg --vimgrep'
  let g:grepprg = 'rg --vimgrep'
elseif executable('ag')
  " let g:ackprg = 'ag --vimgrep'
  let g:grepprg = 'ag --vimgrep'
endif
command -nargs=* Ag :copen | Ggrep <args>

" File Storage
set autoread
set noswapfile
set nobackup
set nowritebackup

" NERDTree
let NERDTreeShowHidden=1
au FileType nerdtree set number rnu
map <C-n> :NERDTreeToggle<CR>
map <leader>n :NERDTreeToggle<CR>
map <leader>r :NERDTreeFind<CR>

" " Vim-latex
" let g:Tex_MultipleCompileFormats = 'dvi,pdf'
" map <leader>lb :!bibtexc %:r<CR>

" move around with the arrow keys
" noremap <silent> <Right> <c-w>l
" noremap <silent> <Left> <c-w>h
" noremap <silent> <Up> <c-w>k
" noremap <silent> <Down> <c-w>j

" Tagbar
map <leader>t :TagbarToggle<CR>
" CtrlP
map <leader>f :CtrlP<CR>
map <leader>b :CtrlPBuffer<CR>
" Config
map <leader>c :e ~/.vimrc<CR>
" Reload Config
map <leader>R :so ~/.vimrc<CR>
" Reload Tags
map <leader>T :!/usr/local/bin/ctags -R --exclude=.git --exclude=log *<CR><CR>
" Run
" map <leader>r :!./%<CR>
" VIM Plug
map <leader>BI :PlugInstall<CR>
map <leader>PI :PlugInstall<CR>
map <leader>BU :PlugUpdate<CR>
map <leader>PU :PlugUpdate<CR>
map <leader>< :foldclose<CR>
map <leader>> :foldopen<CR>

" FileType specific settings
au FileType cs set shiftwidth=4 tabstop=4

" Debug statement shortcuts
au FileType Ruby map <leader>Br orequire 'pry'; binding.pry
au FileType R map <leader>Br obrowser()
au FileType Python map <leader>Br oimport pdb; pdb.set_trace()
