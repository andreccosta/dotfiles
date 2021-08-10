syntax enable
hi Normal guibg=NONE ctermbg=NONE

set smartindent
set tabstop=2
set expandtab
set number
set cursorline
set showmatch
set incsearch

" only load plugins if Plug detected
if filereadable(expand("~/.vim/autoload/plug.vim"))

  call plug#begin('~/.local/share/vim/plugins')
  Plug 'sheerun/vim-polyglot'
  "Plug 'vim-pandoc/vim-pandoc'
  "Plug 'rwxrob/vim-pandoc-syntax-simple'
  Plug 'fatih/vim-go', { 'do': ':GoInstallBinaries' }
  "Plug 'pangloss/vim-javascript'
  "Plug 'tpope/vim-fugitive'
  Plug 'dracula/vim', { 'as': 'dracula' }
  Plug 'vim-airline/vim-airline'
  call plug#end()

  colorscheme dracula
endif

let g:airline_theme = 'dracula'
let g:airline#extensions#tabline#enabled = 0 
let g:airline#extensions#branch#enabled = 1 
let g:airline_section_warning = '' 
let g:airline_section_y = '' 
let g:airline_section_x = '' 
set laststatus=2
