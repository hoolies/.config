" Vim configuration — plugin-free port of https://github.com/hoolies/nvim
" Single-file: all logic and colors live here (no autoload/ or colors/ files).

scriptencoding utf-8

" Leader first: must exist before any mapping using <leader> is defined.
let g:mapleader = "\<Space>"
let g:maplocalleader = '\'

silent! call mkdir(expand('~/.vim/undodir'), 'p', 0700)

" =============================================================================
" Helper functions (single file; names are Hoolies* because foo#bar only loads from autoload/)
" =============================================================================

let s:term_winid = -1
let s:term_bufnr = -1

function! HooliesFloatingTermToggle() abort
  if !has('terminal')
    echoerr 'Vim needs +terminal for :term'
    return
  endif
  if s:term_winid != -1 && win_id2win(s:term_winid) > 0
    call win_gotoid(s:term_winid)
    close
    let s:term_winid = -1
    return
  endif
  let h = max([10, float2nr(&lines * 2 / 5)])
  execute 'botright' h 'new'
  let s:term_winid = win_getid()
  if s:term_bufnr != -1 && bufexists(s:term_bufnr) && getbufvar(s:term_bufnr, '&buftype') ==# 'terminal'
    execute 'buffer' s:term_bufnr
  else
    call term_start(&shell, {'curwin': 1, 'norestore': 1})
    let s:term_bufnr = bufnr('%')
  endif
  startinsert
endfunction

let s:undo_bufnr = -1

function! HooliesUndotreeToggle() abort
  if s:undo_bufnr != -1 && bufwinnr(s:undo_bufnr) != -1
    execute bufwinnr(s:undo_bufnr) . 'wincmd w'
    close
    let s:undo_bufnr = -1
    return
  endif
  let ut = undotree()
  silent vertical 40new
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
  let s:undo_bufnr = bufnr('%')
  call setline(1, printf('Undo (seq_cur=%s time_cur=%s)', ut.seq_cur, ut.time_cur))
  call setline(2, 'Commands: :earlier :later :undo | :help undotree()')
  call setline(3, '')
  let ln = 4
  if has_key(ut, 'entries')
    for e in ut.entries
      if type(e) == v:t_dict
        call setline(ln, printf('  seq=%s time=%s save=%s',
              \ get(e, 'seq', '?'), get(e, 'time', '?'), get(e, 'save', '?')))
      else
        call setline(ln, '  ' . string(e))
      endif
      let ln += 1
    endfor
  else
    call setline(ln, string(ut))
  endif
  setlocal nomodifiable
  nnoremap <buffer> <silent> q :close<CR>
endfunction

function! HooliesOldfilesPick() abort
  let files = filter(copy(v:oldfiles), 'filereadable(v:val)')
  if empty(files)
    echohl WarningMsg | echo 'No readable oldfiles' | echohl None
    return
  endif
  silent botright 12new
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
  call setline(1, files)
  nnoremap <buffer> <silent> <CR> :call HooliesOpenOldfileLine()<CR>
  nnoremap <buffer> <silent> q :bwipeout!<CR>
endfunction

function! HooliesOpenOldfileLine() abort
  let path = getline('.')
  if path ==# '' | return | endif
  bwipeout!
  execute 'edit' fnameescape(path)
endfunction

function! HooliesPickPaths(title, paths) abort
  if empty(a:paths)
    echohl WarningMsg | echo a:title . ': (empty)' | echohl None
    return
  endif
  silent botright 12new
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
  call setline(1, a:paths)
  nnoremap <buffer> <silent> <CR> :call HooliesOpenOldfileLine()<CR>
  nnoremap <buffer> <silent> q :bwipeout!<CR>
endfunction

function! HooliesFindConfigFiles() abort
  let roots = filter([
        \ expand('~/.config/nvim'),
        \ expand('~/.vim'),
        \ ], 'isdirectory(v:val)')
  let out = []
  for r in roots
    let out += glob(r . '/**/*.lua', 0, 1)
    let out += glob(r . '/**/*.vim', 0, 1)
  endfor
  call sort(out)
  call uniq(out)
  call HooliesPickPaths('Config files', out)
endfunction

function! HooliesGrepInteractive() abort
  call inputsave()
  let pat = input('Project grep pattern: ')
  call inputrestore()
  if pat ==# '' | return | endif
  call HooliesGrepFill(pat)
endfunction

function! HooliesGrepFill(pat) abort
  if executable('rg')
    let out = system('rg --vimgrep -- ' . shellescape(a:pat))
    if out ==# '' | echo 'No matches' | return | endif
    silent! cexpr out
  else
    try
      silent exe 'vimgrep /' . escape(a:pat, '/') . '/gj **/*'
    catch /^Vim\%((\a\+)\)\=:E/
      echohl WarningMsg | echo 'vimgrep failed (install ripgrep for best results)' | echohl None
      return
    endtry
  endif
  copen
endfunction

function! HooliesGrepCursorWord() abort
  let w = expand('<cword>')
  if w ==# '' | return | endif
  call HooliesGrepFill(w)
endfunction

function! HooliesGrepOpenBuffers(pat) abort
  let qf = []
  for b in range(1, bufnr('$'))
    if !bufloaded(b) || !buflisted(b) | continue | endif
    let fn = bufname(b)
    if fn ==# '' | continue | endif
    let lines = getbufline(b, 1, '$')
    let i = 1
    for line in lines
      if line =~# a:pat
        call add(qf, {'filename': fn, 'lnum': i, 'text': line})
      endif
      let i += 1
    endfor
  endfor
  call setqflist(qf, 'r')
  copen
endfunction

function! HooliesBufferPicker() abort
  call inputsave()
  let q = input('Filter buffers (empty = all): ')
  call inputrestore()
  let lines = []
  for b in range(1, bufnr('$'))
    if !buflisted(b) | continue | endif
    let n = bufname(b)
    if n ==# '' | let n = '[No Name]' | endif
    if q ==# '' || stridx(n, q) != -1
      call add(lines, n . "\t#" . b)
    endif
  endfor
  if empty(lines)
    echo 'No buffers'
    return
  endif
  silent botright 12new
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
  call setline(1, lines)
  nnoremap <buffer> <silent> <CR> :call HooliesOpenBufferPickLine()<CR>
  nnoremap <buffer> <silent> q :bwipeout!<CR>
endfunction

function! HooliesOpenBufferPickLine() abort
  let m = matchlist(getline('.'), '\t#\(\d\+\)$')
  if empty(m)
    bwipeout!
    return
  endif
  let b = str2nr(m[1])
  bwipeout!
  if b > 0 && bufexists(b)
    execute 'buffer' b
  endif
endfunction

function! HooliesFormatBuffer() abort
  let ft = &filetype
  let view = winsaveview()
  if ft ==# 'lua' && executable('stylua')
    silent! exe '%!stylua -'
  elseif ft ==# 'python' && executable('ruff')
    silent! exe '%!ruff format -'
  elseif ft ==# 'python' && executable('black')
    silent! exe '%!black -q -'
  elseif ft ==# 'go' && executable('goimports')
    silent! exe '%!goimports'
  elseif ft ==# 'go' && executable('gofmt')
    silent! exe '%!gofmt'
  elseif (ft ==# 'html' || ft ==# 'json' || ft ==# 'yaml' || ft ==# 'javascript' || ft ==# 'typescript') && executable('prettier')
    silent! exe '%!prettier --stdin-filepath ' . shellescape(expand('%:p'))
  elseif ft ==# 'sh' && executable('shfmt')
    silent! exe '%!shfmt'
  elseif ft ==# 'elixir' && executable('mix')
    silent! exe '%!mix format -'
  else
    silent! normal! gggqG
  endif
  call winrestview(view)
endfunction

function! HooliesHasFormatter() abort
  let ft = &filetype
  if ft ==# 'lua' && executable('stylua') | return 1 | endif
  if ft ==# 'python' && (executable('ruff') || executable('black')) | return 1 | endif
  if ft ==# 'go' && (executable('goimports') || executable('gofmt')) | return 1 | endif
  if (ft ==# 'html' || ft ==# 'json' || ft ==# 'yaml' || ft ==# 'javascript' || ft ==# 'typescript') && executable('prettier') | return 1 | endif
  if ft ==# 'sh' && executable('shfmt') | return 1 | endif
  if ft ==# 'elixir' && executable('mix') | return 1 | endif
  return 0
endfunction

function! HooliesFormatWritePre() abort
  if &modifiable == 0 || &bin || !HooliesHasFormatter() | return | endif
  call HooliesFormatBuffer()
endfunction

function! HooliesBufWritePre() abort
  if &modifiable
    keeppatterns %s/\s\+$//e
  endif
  call HooliesFormatWritePre()
endfunction

function! HooliesBufEnter() abort
  if &buftype ==# 'terminal'
    startinsert
  elseif &modifiable
    setlocal formatoptions-=c formatoptions-=r formatoptions-=o
  endif
endfunction

function! HooliesTmuxNavigate(dir) abort
  let prev = winnr()
  exe 'wincmd' a:dir
  if prev == winnr() && exists('$TMUX')
    let t = {'h': 'L', 'j': 'D', 'k': 'U', 'l': 'R'}
    if has_key(t, a:dir)
      silent! call system('tmux select-pane -' . t[a:dir])
    endif
  endif
endfunction

function! HooliesTabline() abort
  let s = ''
  for b in range(1, bufnr('$'))
    if !buflisted(b) | continue | endif
    let name = fnamemodify(bufname(b), ':t')
    if name ==# '' | let name = '[No Name]' | endif
    let s .= (b == bufnr('%') ? '%#TabLineSel#' : '%#TabLine#')
    let s .= '%' . b . 'T ' . name . ' %T'
  endfor
  return s
endfunction

function! HooliesStatusLine() abort
  return '%<%f %h%w%m%r%=%y %{&ff} %{strlen(&fenc)?&fenc:&enc} %l,%c/%L %P'
endfunction

function! HooliesFlashYank() abort
  if !exists('v:event') || get(v:event, 'operator', '') !=# 'y' | return | endif
  let l1 = getpos("'[")[1]
  let l2 = getpos("']")[1]
  if l1 < 1 || l2 < 1 | return | endif
  let pos = map(range(l1, l2), {_, l -> [l]})
  let mid = matchaddpos('Search', pos)
  if has('timers')
    call timer_start(300, {-> execute('silent! call matchdelete(' . mid . ')')})
  endif
endfunction

function! HooliesVimEnterNoArgs() abort
  if argc() == 0
    call HooliesOldfilesPick()
  elseif argc() == 1 && isdirectory(argv(0))
    exe 'cd' fnameescape(argv(0))
  endif
endfunction

function! HooliesCurrentBufferGrep() abort
  call inputsave()
  let pat = input('Fuzzy filter this buffer: ')
  call inputrestore()
  if pat ==# '' | return | endif
  let qf = []
  let i = 1
  for line in getline(1, '$')
    if stridx(line, pat) != -1
      call add(qf, {'filename': expand('%:p'), 'lnum': i, 'text': line})
    endif
    let i += 1
  endfor
  call setqflist(qf, 'r')
  copen
endfunction

function! HooliesGrepOpenBuffersInput() abort
  call inputsave()
  let pat = input('Grep open buffers (regex): ')
  call inputrestore()
  if pat ==# '' | return | endif
  call HooliesGrepOpenBuffers(pat)
endfunction

function! HooliesGitFiles() abort
  if !executable('git')
    echo 'git not found'
    return
  endif
  let lines = systemlist('git rev-parse --show-toplevel')
  let root = get(lines, 0, '')
  if v:shell_error || root ==# ''
    echo 'Not a git repo'
    return
  endif
  let files = systemlist('git ls-files')
  if v:shell_error
    echo 'git ls-files failed'
    return
  endif
  call map(files, {_, p -> root . '/' . p})
  call HooliesPickPaths('Git files', files)
endfunction

function! HooliesVimFuncLinkFix() abort
  " Runtime $VIMRUNTIME/syntax/vim.vim links these to vimError → red background
  hi! link vimFunc Function
  hi! link vim9Func Function
endfunction

function! HooliesApplyColors() abort
  hi clear
  if exists('syntax_on')
    syntax reset
  endif
  let g:colors_name = 'hoolies_storm'
  set background=dark
  let s:bg = '#24283b'
  let s:fg = '#c0caf5'
  let s:comment = '#565f89'
  let s:line = '#3b4261'
  let s:cursorline = '#292e42'
  let s:magenta = '#ff007c'
  if has('gui_running') || &termguicolors
    exe 'hi Normal guibg=' . s:bg . ' guifg=' . s:fg
    exe 'hi Comment guifg=' . s:comment
    exe 'hi LineNr guifg=' . s:line . ' gui=NONE cterm=NONE term=NONE'
    exe 'hi SignColumn guibg=' . s:bg . ' guifg=' . s:line . ' gui=NONE cterm=NONE'
    exe 'hi FoldColumn guibg=' . s:bg . ' guifg=' . s:line . ' gui=NONE cterm=NONE'
    exe 'hi CursorLine guibg=' . s:cursorline . ' cterm=NONE gui=NONE'
    exe 'hi CursorLineNr guifg=' . s:magenta . ' gui=NONE cterm=NONE term=NONE'
    silent! hi LineNrAbove guifg=#3b4261 gui=NONE cterm=NONE term=NONE
    silent! hi LineNrBelow guifg=#3b4261 gui=NONE cterm=NONE term=NONE
    hi CursorColumn guibg=#292e42
    exe 'hi IncSearch guibg=' . s:magenta . ' guifg=' . s:bg
    hi Search guibg=#3e68d7 guifg=#c0caf5
    hi StatusLine guibg=#1f2335 guifg=#a9b1d6
    hi StatusLineNC guibg=#1f2335 guifg=#565f89
    hi TabLine guibg=#1f2335 guifg=#565f89
    hi TabLineSel guibg=#292e42 guifg=#c0caf5 gui=bold
    hi TabLineFill guibg=#1f2335
    hi Pmenu guibg=#1f2335 guifg=#c0caf5
    hi PmenuSel guibg=#343b58 guifg=#c0caf5
    hi Visual guibg=#343b58
    " Spell: never use a background (term often simulates undercurl as a block)
    hi SpellBad gui=undercurl guisp=#f7768e guifg=NONE guibg=NONE ctermfg=203 ctermbg=NONE cterm=underline
    hi SpellCap gui=undercurl guisp=#e0af68 guifg=NONE guibg=NONE ctermfg=214 ctermbg=NONE cterm=underline
    hi SpellLocal gui=undercurl guisp=#9ece6a guifg=NONE guibg=NONE ctermfg=149 ctermbg=NONE cterm=underline
    hi SpellRare gui=undercurl guisp=#bb9af7 guifg=NONE guibg=NONE ctermfg=177 ctermbg=NONE cterm=underline
    hi Function guifg=#7aa2f7 guibg=NONE gui=NONE cterm=NONE
  else
    hi Normal ctermfg=252 ctermbg=235
    hi Comment ctermfg=60
    hi LineNr ctermfg=238 cterm=NONE
    hi SignColumn ctermbg=235 ctermfg=238 cterm=NONE
    hi FoldColumn ctermbg=235 ctermfg=238 cterm=NONE
    hi CursorLine cterm=NONE ctermbg=236
    hi CursorLineNr ctermfg=201 cterm=NONE
    hi IncSearch ctermbg=201 ctermfg=235
    hi SpellBad ctermfg=203 ctermbg=NONE cterm=underline
    hi SpellCap ctermfg=214 ctermbg=NONE cterm=underline
    hi SpellLocal ctermfg=149 ctermbg=NONE cterm=underline
    hi SpellRare ctermfg=177 ctermbg=NONE cterm=underline
    hi Function ctermfg=111 ctermbg=NONE cterm=NONE
  endif
  " After syntax reset, runtime vim.vim re-links vimFunc → Error (red bg) for foo( calls.
  call HooliesVimFuncLinkFix()
endfunction

" =============================================================================
" Options
" =============================================================================

set autoindent
set scrolloff=999
set showmatch
set splitright
set splitbelow
set autochdir
set iskeyword=@,48-57,192-255
set modifiable
if has('gui_running')
  set guicursor=n:block,i-ci:hor20,v-ve:block
endif

set autoread
set hidden
set updatetime=250

if has('clipboard')
  set clipboard=unnamedplus
endif

set cursorcolumn
set cursorline

set nowrap
set wrapscan
set whichwrap+=<,>,[,],h,l

set colorcolumn=0
set number
set numberwidth=5
set relativenumber
set ruler
if exists('&signcolumn')
  " 'yes' always reserves a column — often shows as a bright/white strip with no signs
  set signcolumn=auto
endif

set hlsearch
set ignorecase
set smartcase
set incsearch

set expandtab
set shiftwidth=2
set smartindent
set softtabstop=2
set tabstop=2

set undodir=~/.vim/undodir
set undofile
set undolevels=1000
set undoreload=1000

set encoding=utf-8
set fileencoding=utf-8
set showmode
set showtabline=2
" Spell off in code/config: avoids red/pink on names like github, nvim, win_id2win
set nospell
if has('termguicolors')
  set termguicolors
endif
set visualbell
set completeopt=menuone

set pumheight=12

if executable('rg')
  set grepprg=rg\ --vimgrep\ --sort\ path
  set grepformat=%f:%l:%c:%m
endif

set wildmenu
set wildmode=longest:full,full
set path+=**

set tabline=%!HooliesTabline()
set laststatus=2
set statusline=%!HooliesStatusLine()

set timeout
set timeoutlen=500
set ttimeout
if !has('gui_running')
  " Alt+j/k as ESC+j/k needs a longer key sequence timeout
  set ttimeoutlen=100
  execute "set <M-j>=\<Esc>j"
  execute "set <M-k>=\<Esc>k"
else
  set ttimeoutlen=50
endif

call HooliesApplyColors()

" =============================================================================
" Mappings
" =============================================================================

nnoremap <up> <Nop>
nnoremap <down> <Nop>
nnoremap <left> <Nop>
nnoremap <right> <Nop>

nnoremap <silent> <C-Up> :resize +2<CR>
nnoremap <silent> <C-Down> :resize -2<CR>
nnoremap <silent> <C-Left> :vertical resize -2<CR>
nnoremap <silent> <C-Right> :vertical resize +2<CR>

inoremap <C-k> <Up>
inoremap <C-j> <Down>
inoremap <C-h> <Left>
inoremap <C-l> <Right>
inoremap jj <Esc>

nnoremap <silent> <A-k> :move .-2<CR>==
nnoremap <silent> <A-j> :move .+1<CR>==
xnoremap <silent> <A-k> :move '<-2<CR>gv=gv
xnoremap <silent> <A-j> :move '>+1<CR>gv=gv
inoremap <silent> <A-k> <Esc>:move .-2<CR>==gi
inoremap <silent> <A-j> <Esc>:move .+1<CR>==gi

nnoremap <silent> <S-l> :bnext<CR>
nnoremap <silent> <S-h> :bprevious<CR>
nnoremap <silent> <leader>bd :bdelete<CR>
nnoremap <silent> <leader>bD :bdelete<CR>:q!<CR>
nnoremap <silent> <leader>bw :bwipeout<CR>
nnoremap <silent> <leader>bb :enew<CR>
nnoremap <silent> <A-ESC> :%bd<Bar>e#<Bar>bd#<CR>

tnoremap <silent> <C-h> <C-\><C-n><C-w>h
tnoremap <silent> <C-j> <C-\><C-n><C-w>j
tnoremap <silent> <C-k> <C-\><C-n><C-w>k
tnoremap <silent> <C-l> <C-\><C-n><C-w>l

nnoremap <silent> <leader>u :call HooliesUndotreeToggle()<CR>

nnoremap <silent> <Esc> :nohlsearch<CR>

nnoremap <silent> <Leader><CR> :call HooliesFloatingTermToggle()<CR>
tnoremap <silent> <Esc> <C-\><C-n>

nnoremap <silent> <leader>e :Explore<CR>

nnoremap <leader>/ :%s/\<<C-r><C-w>\>//g<Left><Left>
xnoremap <leader>/ y:%s/\V<C-r>=escape(@",'/\')<CR>//g<Left><Left>

nnoremap x "_x
xnoremap x "_x
nnoremap dd "_dd

xnoremap <silent> < <gv
xnoremap <silent> > >gv

nnoremap <silent> <C-h> :call HooliesTmuxNavigate('h')<CR>
nnoremap <silent> <C-j> :call HooliesTmuxNavigate('j')<CR>
nnoremap <silent> <C-k> :call HooliesTmuxNavigate('k')<CR>
nnoremap <silent> <C-l> :call HooliesTmuxNavigate('l')<CR>

nnoremap <silent> <leader>fb :call HooliesBufferPicker()<CR>
nnoremap <leader>ff :find 
nnoremap <silent> <leader>flf :call HooliesGrepInteractive()<CR>
nnoremap <silent> <leader>flg :call HooliesGitFiles()<CR>
nnoremap <silent> <leader>fh :help 
nnoremap <silent> <leader>fo :call HooliesOldfilesPick()<CR>
nnoremap <silent> <leader>fs :call HooliesGrepCursorWord()<CR>
nnoremap <silent> <leader>ft :call HooliesCurrentBufferGrep()<CR>
nnoremap <silent> <leader>s/ :call HooliesGrepOpenBuffersInput()<CR>
nnoremap <silent> <leader>sn :call HooliesFindConfigFiles()<CR>

nnoremap <silent> <leader>F :call HooliesFormatBuffer()<CR>

inoremap ( ()<Left>
inoremap [ []<Left>
inoremap { {}<Left>
inoremap " ""<Left>
inoremap ' ''<Left>

" Space alone = nop; define after all <leader> maps so leader is Space + next keys.
nnoremap <Space> <Nop>
xnoremap <Space> <Nop>

" =============================================================================
" Autocmds
" =============================================================================

augroup hoolies_vimrc
  autocmd!
  " Spell only where prose is expected (keeps .vimrc / code free of spell highlights)
  autocmd FileType markdown,gitcommit,text,typst,rst setlocal spell
  autocmd FileType vim call HooliesVimFuncLinkFix()
  autocmd ColorScheme * call HooliesVimFuncLinkFix()
  autocmd VimEnter * call HooliesVimEnterNoArgs()
  if exists('##TextYankPost')
    autocmd TextYankPost * call HooliesFlashYank()
  endif
  autocmd BufWritePre * call HooliesBufWritePre()
  autocmd BufReadPost * if line("'\"") >= 1 && line("'\"") <= line('$') | exe "normal! g`\"" | endif
  if exists('##TerminalOpen')
    autocmd TerminalOpen * setlocal nonumber norelativenumber
  endif
  autocmd BufEnter * call HooliesBufEnter()
augroup END
