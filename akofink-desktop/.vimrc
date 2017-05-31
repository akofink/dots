" System
set shell=/bin/bash
set clipboard=unnamedplus
set nocompatible

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" Github Bundles
Plugin 'Raimondi/delimitMate'
Plugin 'Shougo/neocomplcache'
Plugin 'airblade/vim-gitgutter'
Plugin 'chase/vim-ansible-yaml'
Plugin 'danro/rename.vim'
Plugin 'docunext/closetag.vim'
Plugin 'flazz/vim-colorschemes'
Plugin 'gmarik/Vundle.vim'
Plugin 'kana/vim-fakeclip'
Plugin 'kchmck/vim-coffee-script'
Plugin 'kien/ctrlp.vim'
Plugin 'klen/python-mode'
Plugin 'majutsushi/tagbar'
Plugin 'mattn/gist-vim'
Plugin 'mattn/webapi-vim'
Plugin 'mileszs/ack.vim'
Plugin 'mustache/vim-mustache-handlebars'
Plugin 'nathanaelkane/vim-indent-guides'
Plugin 'othree/html5.vim'
Plugin 'rking/ag.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'scrooloose/syntastic'
Plugin 'sjl/gundo.vim'
Plugin 'tpope/vim-abolish'
Plugin 'tpope/vim-commentary'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-git'
Plugin 'tpope/vim-haml'
Plugin 'tpope/vim-markdown'
Plugin 'tpope/vim-rails'
Plugin 'tpope/vim-rake'
Plugin 'tpope/vim-sleuth'
Plugin 'tpope/vim-surround'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'vim-ruby/vim-ruby'
Plugin 'vim-scripts/supertab'
Plugin 'vim-scripts/vimwiki'

" Indent Guides
" let g:indent_guides_enable_on_vim_startup = 1
" let g:indent_guides_start_level=2
" let g:indent_guides_guide_size=1

let g:airline#extensions#tabline#enabled = 1
let g:airline_theme = 'solarized'

" Spell check
set spell

" Global undo
silent !mkdir -p ~/.vim/undo > /dev/null 2>&1
set undofile
set undodir=~/.vim/undo

" Global Swap Dir
silent !mkdir -p ~/.vim/backups > /dev/null 2>&1
set backupdir=~/.vim/backups

" All of your Plugins must be added before the following line
call vundle#end()

" CtrlP Setup
set runtimepath^=~/.vim/bundle/ctrlp.vim
let g:ctrlp_follow_symlinks = 1

" Gist setup
let g:github_token = $GITHUB_TOKEN
let g:gist_open_browser_after_post = 1

" Syntax Highlighting
set t_Co=256
syntax enable
syntax on
set background=dark
colorscheme solarized
filetype indent plugin on
let g:syntastic_ruby_exec = '~/.rbenv/shims/ruby'

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
set number
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
let g:ctrlp_max_depth = 40
let g:ctrlp_max_files = 0

" Leader
let mapleader = ' '

map <leader>n :NERDTreeToggle<CR>
map <leader>b :CtrlPBuffer<CR>
" move around with the arrow keys
noremap <silent> <Right> <c-w>l
noremap <silent> <Left> <c-w>h
noremap <silent> <Up> <c-w>k
noremap <silent> <Down> <c-w>j

set colorcolumn=100

" Editing macros
map <leader>wsx :%s/\v +$//g<CR>
" Command
map <leader><leader> :
" CtrlP
map <leader>f :CtrlP .<CR>
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
map <leader>T :!ctags -R --exclude=.git --exclude=log .<CR><CR>
" Run
map <leader>r :!./%<CR>
" Run Rspec
map <leader>t :!rspec spec<CR>
" Rails Bundle
map <leader>rbi :!bundle<CR>
" VIM Bundle
map <leader>BI :BundleInstall<CR>q
map <leader>BU :BundleUpdate<CR>q
" Update dots
map <leader>dots :!cd ~/dots && ./test_update<CR><CR>
" VIM wiki
map <leader>wdiary :VimwikiDiaryIndex<CR>:VimwikiDiaryGenerateLinks<CR>
map <leader>wb :VimwikiAll2HTML<CR><CR>:Vimwiki2HTMLBrowse<CR><CR>
map <leader>wB :VimwikiBacklinks<CR><CR>:VimwikiAll2HTML<CR><CR>:Vimwiki2HTMLBrowse<CR><CR>
map <leader>< :foldclose<CR>
map <leader>> :foldopen<CR>

map <leader>m :!make<CR>
map <leader>s :set spell!<CR>
map <leader>) :bnext<CR>
map <leader>( :bprevious<CR>
