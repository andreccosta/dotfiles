syntax enable
hi Normal guibg=NONE ctermbg=NONE

set smartindent
set tabstop=2
set expandtab
set number
set cursorline
set showmatch
set incsearch

" load plugins if Plug is detected
if filereadable(expand("~/.vim/autoload/plug.vim"))

	call plug#begin('~/.local/share/vim/plugins')
	Plug 'sheerun/vim-polyglot'
	Plug 'fatih/vim-go', { 'do': ':GoInstallBinaries' }
	"Plug 'pangloss/vim-javascript'
	Plug 'tpope/vim-fugitive'
	Plug 'vim-airline/vim-airline'
	Plug 'dracula/vim', { 'as': 'dracula' }
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
