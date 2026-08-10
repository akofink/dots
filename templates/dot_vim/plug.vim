call plug#begin()
" Can't Live Without
Plug 'danro/rename.vim'
Plug 'flazz/vim-colorschemes'
Plug 'ctrlpvim/ctrlp.vim'
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
imap <silent><script><expr> <C-J> copilot#Accept("\<CR>")
let g:copilot_no_tab_map = v:true

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


" Automatically install missing plugins on the first run. Vim-plug populates
" g:plugs with every declared plugin after plug#end(), so a plugin whose
" directory does not exist yet is missing. Install them synchronously
" (--sync) and reload the config once so the new plugins take effect without
" a restart. The check only fires while a plugin directory is absent, so it
" is idempotent and never retriggers after a successful install.
autocmd VimEnter *
  \  if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \ |   PlugInstall --sync | source $MYVIMRC
  \ | endif


" Plug related keybindings
map <leader>BI :PlugInstall<CR>
map <leader>PI :PlugInstall<CR>
map <leader>BU :PlugUpdate<CR>
map <leader>PU :PlugUpdate<CR>
