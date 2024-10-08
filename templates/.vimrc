" System
set shell=/bin/bash
set clipboard^=unnamed
set nocompatible
filetype off
set rtp+=~/.vim/bundle/Vundle.vim

" Leader
let mapleader = ' '

call plug#begin()
" Can't Live Without
Plug 'danro/rename.vim'
Plug 'flazz/vim-colorschemes'
Plug 'kien/ctrlp.vim'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'

" Nice to have
Plug 'Raimondi/delimitMate'
Plug 'editorconfig/editorconfig-vim'
" Plug 'liuchengxu/vim-which-key'
Plug 'milkypostman/vim-togglelist'
Plug 'preservim/tagbar'
Plug 'preservim/vim-indent-guides'
Plug 'scrooloose/nerdtree'
Plug 'sjl/gundo.vim'

" AI / LLM
Plug 'github/copilot.vim'

" LSP
" Plug 'hrsh7th/vim-vsnip'
" Plug 'hrsh7th/vim-vsnip-integ'
Plug 'mattn/vim-lsp-settings' " for vim-lsp
Plug 'prabirshrestha/asyncomplete-lsp.vim'
Plug 'prabirshrestha/asyncomplete.vim' " for vim-lsp
Plug 'prabirshrestha/vim-lsp'

" Git
Plug 'airblade/vim-gitgutter'
Plug 'tommcdo/vim-fubitive'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rhubarb'

" Language Specific
" Plug 'MaxMEllon/vim-jsx-pretty'
" Plug 'OrangeT/vim-csharp'
" Plug 'dense-analysis/ale'
" Plug 'ekalinin/Dockerfile.vim'
" Plug 'fannheyward/coc-pyright'
" Plug 'fatih/vim-go'
" Plug 'jcf/vim-latex'
" Plug 'leafgarland/typescript-vim'
" Plug 'moll/vim-node'
" Plug 'mustache/vim-mustache-handlebars'
" Plug 'mv/mv-vim-puppet'
" Plug 'othree/html5.vim'
" Plug 'pangloss/vim-javascript'
" Plug 'peitalin/vim-jsx-typescript'
" Plug 'vim-ruby/vim-ruby'
" Plug 'vim-scripts/c.vim'
" Plug 'tpope/vim-rbenv'
" Plug 'tpope/vim-haml'
" Plug 'tpope/vim-markdown'
" Plug 'docunext/closetag.vim' " HTML/XML closing tags

" Unused
" Plug 'kana/vim-fakeclip'
" Plug 'mattn/gist-vim'
" Plug 'mattn/webapi-vim'
" Plug 'mileszs/ack.vim'
" Plug 'vim-scripts/loremipsum'
" Plug 'vim-scripts/vimwiki'
" Plug 'tpope/vim-abolish'
" Plug 'ervandew/supertab'
call plug#end()

filetype plugin indent on

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

" LSP
function! s:on_lsp_buffer_enabled() abort
  setlocal omnifunc=lsp#complete
  setlocal signcolumn=yes
  if exists('+tagfunc') | setlocal tagfunc=lsp#tagfunc | endif
  nmap <buffer> gd <plug>(lsp-definition)
  nmap <buffer> gs <plug>(lsp-document-symbol-search)
  nmap <buffer> gS <plug>(lsp-workspace-symbol-search)
  nmap <buffer> gr <plug>(lsp-references)
  nmap <buffer> gi <plug>(lsp-implementation)
  nmap <buffer> gt <plug>(lsp-type-definition)
  " nmap <buffer> <leader>rn <plug>(lsp-rename)
  nmap <buffer> [g <plug>(lsp-previous-diagnostic)
  nmap <buffer> ]g <plug>(lsp-next-diagnostic)
  nmap <buffer> K <plug>(lsp-hover)
  " nnoremap <buffer> <expr><c-f> lsp#scroll(+4)
  " nnoremap <buffer> <expr><c-d> lsp#scroll(-4)

  let g:lsp_format_sync_timeout = 1000
  autocmd! BufWritePre *.rs,*.go call execute('LspDocumentFormatSync')

  " refer to doc to add more commands
endfunction

augroup lsp_install
  au!
  " call s:on_lsp_buffer_enabled only for languages that has the server registered.
  autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END

" " LSP Folding
" set foldmethod=expr
"   \ foldexpr=lsp#ui#vim#folding#foldexpr()
"   \ foldtext=lsp#ui#vim#folding#foldtext()

" " vsnip snippets config
" " Expand
" imap <expr> <C-j>   vsnip#expandable()  ? '<Plug>(vsnip-expand)'         : '<C-j>'
" smap <expr> <C-j>   vsnip#expandable()  ? '<Plug>(vsnip-expand)'         : '<C-j>'

" " Expand or jump
" imap <expr> <C-l>   vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'
" smap <expr> <C-l>   vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'

" " Jump forward or backward
" imap <expr> <Tab>   vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<Tab>'
" smap <expr> <Tab>   vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<Tab>'
" imap <expr> <S-Tab> vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<S-Tab>'
" smap <expr> <S-Tab> vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<S-Tab>'

" " Select or cut text to use as $TM_SELECTED_TEXT in the next snippet.
" " See https://github.com/hrsh7th/vim-vsnip/pull/50
" nmap        s   <Plug>(vsnip-select-text)
" xmap        s   <Plug>(vsnip-select-text)
" nmap        S   <Plug>(vsnip-cut-text)
" xmap        S   <Plug>(vsnip-cut-text)

" If you want to use snippet for multiple filetypes, you can `g:vsnip_filetypes` for it.
" let g:vsnip_filetypes = {}
" let g:vsnip_filetypes.javascriptreact = ['javascript']
" let g:vsnip_filetypes.typescriptreact = ['typescript']

" Gist setup
" let g:github_token = $GITHUB_TOKEN
" let g:gist_open_browser_after_post = 1

" Syntax Highlighting
set t_Co=256
syntax enable
syntax on
set background=light
colorscheme solarized
filetype plugin indent plugin on

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
