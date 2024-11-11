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
" imap <silent><script><expr> <C-J> copilot#Accept("\<CR>")
" let g:copilot_no_tab_map = v:true

" LSP
" Plug 'hrsh7th/vim-vsnip'
" Plug 'hrsh7th/vim-vsnip-integ'
" Plug 'mattn/vim-lsp-settings' " for vim-lsp
" Plug 'prabirshrestha/asyncomplete-lsp.vim'
" Plug 'prabirshrestha/asyncomplete.vim' " for vim-lsp
" Plug 'prabirshrestha/vim-lsp'
Plug 'neoclide/coc.nvim', {'branch': 'release'}

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
