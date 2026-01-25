" CtrlP Setup
" let g:ctrlp_max_files=0
" let g:ctrlp_custom_ignore = 'node_modules\|DS_Store\|git\|.venv|local'
set runtimepath^=~/.vim/bundle/ctrlp.vim
let g:ctrlp_show_hidden = 1
let g:ctrlp_working_path_mode = ''
if executable('rg')
  let g:ctrlp_user_command = 'rg %s --files -g "!.git/" --color=never --hidden --glob ""'
elseif executable('ag')
  let g:ctrlp_user_command = 'ag %s -l --nocolor --hidden -g ""'
endif

