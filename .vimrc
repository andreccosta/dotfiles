syntax enable
hi Normal guibg=NONE ctermbg=NONE

set smartindent
set smarttab
set tabstop=2
set shiftwidth=2
set expandtab
set number
set cursorline
set showmatch
set incsearch

set colorcolumn=80,120

" load plugins if Plug is detected
if filereadable(expand("~/.vim/autoload/plug.vim"))

	call plug#begin('~/.local/share/vim/plugins')
	Plug 'sheerun/vim-polyglot'
	Plug 'fatih/vim-go', { 'do': ':GoInstallBinaries' }
	
	"Plug 'pangloss/vim-javascript'
	Plug 'leafgarland/typescript-vim'
	
	Plug 'tpope/vim-fugitive'

	Plug 'vim-airline/vim-airline'
	Plug 'vim-airline/vim-airline-themes'
	" Plug 'dracula/vim', { 'as': 'dracula' }
	" Plug 'joshdick/onedark.vim', { 'as': 'onedark' }
	Plug 'haishanh/night-owl.vim'

	call plug#end()

	colorscheme night-owl
endif

let g:airline_theme = 'night_owl'
let g:airline#extensions#tabline#enabled = 0 
let g:airline#extensions#branch#enabled = 1 
let g:airline_powerline_fonts = 1
let g:airline_section_warning = '' 
let g:airline_section_y = '' 
let g:airline_section_x = '' 
let g:netrw_liststyle = 3
let g:netrw_banner = 0

set laststatus=2

