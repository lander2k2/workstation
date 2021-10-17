imap kj <Esc>

set t_Co=256
syntax on
"colorscheme molokai
highlight Comment cterm=bold

set nowrap
set number
highlight LineNr ctermfg=grey

set statusline+=%F,\ line:\ %l,\ col:\ %c
set laststatus=2

set smartindent
set tabstop=4
set expandtab
set shiftwidth=4
set softtabstop=4
set tw=80

let &colorcolumn=join(range(81,999),",")
highlight ColorColumn ctermbg=238

set noswapfile
set ffs=unix

set mmp=10000

filetype plugin indent on

" jinja
au BufNewFile,BufRead *.html,*.htm,*.shtml,*.stm,*.tpl set ft=jinja

" Show trailing whitespace
highlight ExtraWhitespace ctermbg=darkblue guibg=darkblue
match ExtraWhitespace /\s\+$/

" vim-go
call plug#begin()
Plug 'fatih/vim-go', { 'do': ':GoInstallBinaries' }
call plug#end()

" pathogen
execute pathogen#infect()

" search visually selected text
vnoremap // y/\V<C-R>"<CR>

" write prose
command! Prose highlight ColorColumn ctermbg=black|set wrap|set tw=0|set spell spelllang=en_us|TagbarToggle

" to break at 80 chars for docs - select text then
" gq

let g:tagbar_type_asciidoc = {
    \ 'ctagstype' : 'asciidoc',
    \ 'kinds' : [
        \ 'h:table of contents',
        \ 'a:anchors:1',
        \ 't:titles:1',
        \ 'n:includes:1',
        \ 'i:images:1',
        \ 'I:inline images:1'
    \ ],
    \ 'sort' : 0
\ }

