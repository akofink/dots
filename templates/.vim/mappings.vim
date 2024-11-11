map <leader>s :set spell!<CR>

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
map <leader>< :foldclose<CR>
map <leader>> :foldopen<CR>

" Debug statement shortcuts
au FileType Ruby map <leader>Br orequire 'pry'; binding.pry
au FileType R map <leader>Br obrowser()
au FileType Python map <leader>Br oimport pdb; pdb.set_trace()
