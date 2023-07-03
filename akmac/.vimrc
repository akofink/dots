" System
set shell=/bin/bash
set clipboard^=unnamed
set nocompatible
filetype off
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" Github Bundles
Plugin 'airblade/vim-gitgutter'
Plugin 'danro/rename.vim'
Plugin 'docunext/closetag.vim'
Plugin 'editorconfig/editorconfig-vim'
Plugin 'ekalinin/Dockerfile.vim'
Plugin 'elixir-lang/vim-elixir'
Plugin 'fatih/vim-go'
Plugin 'flazz/vim-colorschemes'
Plugin 'jcf/vim-latex'
Plugin 'kana/vim-fakeclip'
Plugin 'kchmck/vim-coffee-script'
Plugin 'kien/ctrlp.vim'
Plugin 'leafgarland/typescript-vim'
Plugin 'majutsushi/tagbar'
Plugin 'mattn/gist-vim'
Plugin 'mattn/webapi-vim'
Plugin 'MaxMEllon/vim-jsx-pretty'
Plugin 'mileszs/ack.vim'
Plugin 'moll/vim-node'
Plugin 'mustache/vim-mustache-handlebars'
Plugin 'mv/mv-vim-puppet'
Plugin 'nathanaelkane/vim-indent-guides'
Plugin 'OrangeT/vim-csharp'
Plugin 'othree/html5.vim'
Plugin 'pangloss/vim-javascript'
Plugin 'peitalin/vim-jsx-typescript'
Plugin 'Raimondi/delimitMate'
Plugin 'rking/ag.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'scrooloose/syntastic'
Plugin 'Shougo/neocomplcache'
Plugin 'sjl/gundo.vim'
Plugin 'styled-components/vim-styled-components'
Plugin 'tpope/vim-abolish'
Plugin 'tpope/vim-commentary'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-haml'
Plugin 'tpope/vim-liquid'
Plugin 'tpope/vim-markdown'
Plugin 'tpope/vim-rails.git'
Plugin 'tpope/vim-rbenv'
Plugin 'tpope/vim-surround'
Plugin 'vim-ruby/vim-ruby'
Plugin 'vim-scripts/c.vim'
Plugin 'vim-scripts/loremipsum'
Plugin 'vim-scripts/supertab'
Plugin 'vim-scripts/vimwiki'
Plugin 'VundleVim/Vundle.vim'

" All of your Plugins must be added before the following line
call vundle#end()
filetype plugin indent on

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

" CtrlP Setup
set runtimepath^=~/.vim/bundle/ctrlp.vim
let g:ctrlp_show_hidden = 1
if executable('ag')
  let g:ctrlp_user_command = 'ag %s -l --nocolor --hidden -g ""'
endif

" Gist setup
let g:github_token = 
let g:gist_open_browser_after_post = 1

" Syntax Highlighting
set t_Co=256
syntax enable
syntax on
set background=light
colorscheme solarized
filetype plugin indent plugin on
let g:syntastic_ruby_exec = '~/.rbenv/shims/ruby'

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
au FileType nerdtree set number rnu

" Vim-latex
let g:Tex_MultipleCompileFormats = 'dvi,pdf'
map <leader>lb :!bibtexc %:r<CR>

" Leader
let mapleader = ' '

map <leader>n :NERDTreeToggle<CR>
map <leader>b :CtrlPBuffer<CR>
" move around with the arrow keys
noremap <silent> <Right> <c-w>l
noremap <silent> <Left> <c-w>h
noremap <silent> <Up> <c-w>k
noremap <silent> <Down> <c-w>j

" Editing macros
map <leader>wsx :%s/\v +$//g<CR>
" Command
map <leader><leader> :
" CtrlP
map <leader>f :CtrlP<CR>
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
map <leader>r :!./%<CR>
" Run Rspec
map <leader>t :!rspec spec<CR>
" Lorem Ipsum
map <leader>li :Loremipsum<CR>
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

" FileType specific settings
au FileType cs set shiftwidth=4 tabstop=4

" Debug statement shortcuts
au FileType Ruby map <leader>Br orequire 'pry'; binding.pry
au FileType R map <leader>Br obrowser()
au FileType Python map <leader>Br oimport pdb; pdb.set_trace()
