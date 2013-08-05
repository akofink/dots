" System
set nocompatible
filetype off
set clipboard=unnamed

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" Github Bundles
Bundle 'gmarik/vundle'
Bundle 'tpope/vim-rails.git'
Bundle 'kien/ctrlp.vim'
Bundle 'kchmck/vim-coffee-script'
Bundle 'tpope/vim-fugitive'
Bundle 'tpope/vim-markdown'
Bundle 'tpope/vim-surround'
Bundle 'tpope/vim-rbenv'
Bundle 'scrooloose/nerdtree'
Bundle 'sjl/badwolf'
Bundle 'altercation/vim-colors-solarized'
Bundle 'vim-scripts/vimwiki'
Bundle 'Shougo/neocomplcache'
Bundle 'vim-scripts/loremipsum'
Bundle 'tpope/vim-haml'
Bundle 'scrooloose/nerdcommenter'
Bundle 'elixir-lang/vim-elixir'
Bundle 'vim-ruby/vim-ruby'
Bundle 'taichouchou2/vim-rsense'
Bundle 'othree/html5.vim'

" Syntax Highlighting
let g:solarized_termcolors=256
set background=dark
syntax enable
filetype plugin indent on
let g:syntastic_ruby_exec = '~/.rbenv/shims/ruby'
colorscheme desert

" Spacing and Wrapping
set expandtab
set softtabstop=2
set shiftwidth=2
set tabstop=2
set textwidth=80

" Interface
set showcmd

" Editing
set smartindent
set showmode
set showmatch
set list listchars=tab:>>,eol:¬,trail:·
set rnu
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
inoremap <tab> <c-r>=InsertTabWrapper()<cr>
inoremap <s-tab> <c-n>

" Searching
set incsearch
set hlsearch
set ignorecase smartcase

" File Storage
set autoread
set noswapfile
set nobackup
set nowritebackup

" NERDTree
let NERDTreeShowHidden=1

" Ctrl-P
let g:ctrlp_show_hidden = 1

" Custom remappings
map <Space> i<Space>

" Leader
let mapleader = ','
map <leader>f :CtrlP<CR>
map <leader>n :NERDTreeToggle<CR>
map <leader>b :CtrlPBuffer<CR>
" move around with the arrow keys
noremap <silent> <Right> <c-w>l
noremap <silent> <Left> <c-w>h
noremap <silent> <Up> <c-w>k
noremap <silent> <Down> <c-w>j

" Command
map <leader><leader> :
" Quit
map <leader>q :q<CR>
" Config
map <leader>c :e ~/.vimrc<CR>
" Reload Config
map <leader>R :so ~/.vimrc<CR>
" Relative Line Numbers
map <leader>lr :set rnu<CR>
" Fixed Line Numbers
map <leader>ln :set number<CR>
" Reload Tags
map <leader>T :!/usr/local/bin/ctags -R --exclude=.git --exclude=log *<CR><CR>
" Run
map <leader>r :!ruby %<CR>
" Lorem Ipsum
map <leader>li :Loremipsum<CR>
" Rails Bundle
map <leader>rbi :!bundle<CR>
" VIM Bundle
map <leader>bi :BundleInstall<CR>q
" Update dots
map <leader>dots :!cd ~/dots && ./test_update<CR><CR>
" VIM wiki
map <leader>wdiary :VimwikiDiaryIndex<CR>:VimwikiDiaryGenerateLinks<CR>
map <leader>wb :VimwikiAll2HTML<CR><CR>:Vimwiki2HTMLBrowse<CR><CR>
map <leader>wB :VimwikiBacklinks<CR><CR>:VimwikiAll2HTML<CR><CR>:Vimwiki2HTMLBrowse<CR><CR>
