" Vim configuration — plugin-free port of https://github.com/hoolies/nvim
" For Vim (available everywhere). Neovim is a separate, unshared config.
" Single-file: all logic and colors live here (no autoload/ or colors/ files).

set nocompatible
scriptencoding utf-8

" Leader first: must exist before any mapping using <leader> is defined.
let g:mapleader = "\<Space>"
let g:maplocalleader = '\'

silent! call mkdir(expand('~/.vim/undodir'), 'p', 0700)
silent! call mkdir(expand('~/.vim/swap'), 'p', 0700)

" =============================================================================
" Helper functions (single file; names are Hoolies* because foo#bar only loads from autoload/)
" =============================================================================

let s:term_winid = -1
let s:term_bufnr = -1
let s:git_branch = ''
let s:git_branch_dir = ''
let s:hoolies_ac_timer = -1
let s:cmd_pal_id = -1
let s:cmd_pal_typed = ''
let s:cmd_pal_input = ''
let s:cmd_pal_idx = -1
let s:cmd_pal_all = []
let s:cmd_pal_items = []
let s:cmd_pal_comps = []
let s:cmd_pal_comp_i = -1
let s:cmd_pal_comp_pfx = ''

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
  call HooliesTermSetup()
  startinsert
endfunction

function! HooliesTermSetup() abort
  setlocal nonumber norelativenumber nobuflisted bufhidden=hide noswapfile
endfunction

function! HooliesTermHide() abort
  if win_getid() == s:term_winid
    let s:term_winid = -1
  endif
  close
endfunction

function! HooliesEscAfterNoHl() abort
  " :nohlsearch runs in the mapping itself (must not be only inside a function).
  if &buftype ==# 'terminal'
    call HooliesTermHide()
    return
  endif
  for m in getmatches()
    if get(m, 'group', '') ==# 'Search'
      silent! call matchdelete(m.id)
    endif
  endfor
endfunction

function! HooliesCloseOtherBuffers() abort
  let cur = bufnr('%')
  for b in range(1, bufnr('$'))
    if !buflisted(b) || b == cur
      continue
    endif
    if getbufvar(b, '&buftype') ==# 'terminal'
      continue
    endif
    execute 'bdelete' b
  endfor
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
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap nonumber norelativenumber
  let s:undo_bufnr = bufnr('%')
  call setline(1, printf('Undo (seq_cur=%s time_cur=%s)', ut.seq_cur, ut.time_cur))
  call setline(2, 'Enter: undo to seq  |  q: close  |  :earlier :later')
  call setline(3, '')
  let lines = []
  if has_key(ut, 'entries')
    let lines = HooliesUndotreeLines(ut.entries, 1)
  else
    let lines = [string(ut)]
  endif
  if !empty(lines)
    call setline(4, lines)
  endif
  setlocal nomodifiable
  nnoremap <buffer> <silent> q :close<CR>
  nnoremap <buffer> <silent> <CR> :call HooliesUndotreeApply()<CR>
endfunction

function! HooliesUndotreeLines(entries, indent) abort
  let lines = []
  for e in a:entries
    if type(e) != v:t_dict
      call add(lines, repeat('  ', a:indent) . string(e))
      continue
    endif
    call add(lines, printf('%sseq=%s time=%s save=%s',
          \ repeat('  ', a:indent),
          \ get(e, 'seq', '?'), get(e, 'time', '?'), get(e, 'save', '?')))
    if has_key(e, 'alt') && type(e.alt) == v:t_list
      let lines += HooliesUndotreeLines(e.alt, a:indent + 1)
    endif
  endfor
  return lines
endfunction

function! HooliesUndotreeApply() abort
  let m = matchlist(getline('.'), 'seq=\(\d\+\)')
  if empty(m)
    return
  endif
  let seq = m[1]
  close
  let s:undo_bufnr = -1
  try
    execute 'undo' seq
  catch
    echohl ErrorMsg
    echo 'undo failed: seq=' . seq
    echohl None
  endtry
endfunction

function! HooliesPickerSetup() abort
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap nonumber norelativenumber
  nnoremap <buffer> <silent> q :bwipeout!<CR>
  nnoremap <buffer> <silent> <Esc> :bwipeout!<CR>
endfunction

function! HooliesOldfilesPick() abort
  let files = []
  for path in v:oldfiles
    let p = expand(path)
    if p ==# '' || !filereadable(p)
      continue
    endif
    " Skip fake buffer names like [Dashboard] stored relative to cwd.
    if fnamemodify(p, ':t') =~# '^\[.\+\]$'
      continue
    endif
    call add(files, p)
  endfor
  if empty(files)
    echohl WarningMsg | echo 'No readable oldfiles' | echohl None
    return
  endif
  silent botright 12new
  call HooliesPickerSetup()
  call setline(1, files)
  nnoremap <buffer> <silent> <CR> :call HooliesOpenOldfileLine()<CR>
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
  call HooliesPickerSetup()
  call setline(1, a:paths)
  nnoremap <buffer> <silent> <CR> :call HooliesOpenOldfileLine()<CR>
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

function! HooliesGitRoot() abort
  if !executable('git')
    return ''
  endif
  let dir = expand('%:p:h')
  if dir ==# '' || !isdirectory(dir)
    let dir = getcwd()
  endif
  let lines = systemlist('git -C ' . shellescape(dir) . ' rev-parse --show-toplevel')
  if v:shell_error || empty(lines)
    return ''
  endif
  return lines[0]
endfunction

function! HooliesGrepFill(pat) abort
  let root = HooliesGitRoot()
  if executable('rg')
    let cmd = 'rg --vimgrep -- ' . shellescape(a:pat)
    if root !=# ''
      let cmd .= ' ' . shellescape(root)
    endif
    let out = system(cmd . ' 2>&1')
    if v:shell_error >= 2
      echohl ErrorMsg
      echo 'rg: ' . get(split(out, "\n"), 0, 'failed')
      echohl None
      return
    endif
    if v:shell_error || out ==# ''
      echo 'No matches'
      return
    endif
    silent! cexpr out
  else
    let save_cwd = getcwd()
    try
      if root !=# ''
        execute 'lcd' fnameescape(root)
      endif
      silent exe 'vimgrep /' . escape(a:pat, '/') . '/gj **/*'
    catch /^Vim\%((\a\+)\)\=:E/
      echohl WarningMsg | echo 'vimgrep failed (install ripgrep for best results)' | echohl None
      return
    finally
      execute 'lcd' fnameescape(save_cwd)
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
  try
    call match('', a:pat)
  catch
    echohl WarningMsg
    echo 'Invalid regex'
    echohl None
    return
  endtry
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
  call HooliesPickerSetup()
  call setline(1, lines)
  nnoremap <buffer> <silent> <CR> :call HooliesOpenBufferPickLine()<CR>
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

function! HooliesFormatBang(cmd) abort
  silent! execute '%!' . a:cmd
  if v:shell_error
    silent! undo
    echohl ErrorMsg
    echo 'Formatter failed: ' . a:cmd
    echohl None
  endif
endfunction

function! HooliesFormatBuffer() abort
  let ft = &filetype
  let view = winsaveview()
  if ft ==# 'lua' && executable('stylua')
    call HooliesFormatBang('stylua -')
  elseif ft ==# 'python' && executable('ruff')
    call HooliesFormatBang('ruff format -')
  elseif ft ==# 'python' && executable('black')
    call HooliesFormatBang('black -q -')
  elseif ft ==# 'go' && executable('goimports')
    call HooliesFormatBang('goimports')
  elseif ft ==# 'go' && executable('gofmt')
    call HooliesFormatBang('gofmt')
  elseif (ft ==# 'html' || ft ==# 'json' || ft ==# 'yaml' || ft ==# 'javascript' || ft ==# 'javascriptreact' || ft ==# 'typescript' || ft ==# 'typescriptreact' || ft ==# 'css') && executable('prettier')
    call HooliesFormatBang('prettier --stdin-filepath ' . shellescape(expand('%:p')))
  elseif (ft ==# 'sh' || ft ==# 'bash' || ft ==# 'zsh') && executable('shfmt')
    call HooliesFormatBang('shfmt -i 4 -ci')
  elseif ft ==# 'elixir' && executable('mix')
    call HooliesFormatBang('mix format -')
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
  if (ft ==# 'html' || ft ==# 'json' || ft ==# 'yaml' || ft ==# 'javascript' || ft ==# 'javascriptreact' || ft ==# 'typescript' || ft ==# 'typescriptreact' || ft ==# 'css') && executable('prettier') | return 1 | endif
  if (ft ==# 'sh' || ft ==# 'bash' || ft ==# 'zsh') && executable('shfmt') | return 1 | endif
  if ft ==# 'elixir' && executable('mix') | return 1 | endif
  return 0
endfunction

function! HooliesFormatWritePre() abort
  if !get(g:, 'hoolies_format_on_write', 1) | return | endif
  if &modifiable == 0 || &bin || !HooliesHasFormatter() | return | endif
  call HooliesFormatBuffer()
endfunction

function! HooliesBufWritePre() abort
  if &modifiable
    keeppatterns %s/\s\+$//e
  endif
  call HooliesFormatWritePre()
endfunction

function! HooliesGitBranchRefresh(...) abort
  let force = a:0 && a:1
  if &buftype !=# '' || !executable('git')
    let s:git_branch = ''
    let s:git_branch_dir = ''
    return
  endif
  let dir = expand('%:p:h')
  if dir ==# '' || !isdirectory(dir)
    let s:git_branch = ''
    let s:git_branch_dir = ''
    return
  endif
  if !force && dir ==# s:git_branch_dir
    return
  endif
  let s:git_branch_dir = dir
  let s:git_branch = ''
  let lines = systemlist('git -C ' . shellescape(dir) . ' rev-parse --abbrev-ref HEAD')
  if v:shell_error || empty(lines)
    return
  endif
  let s:git_branch = lines[0]
endfunction

function! HooliesStatusGit() abort
  return s:git_branch ==# '' ? '' : ' ' . s:git_branch
endfunction

function! HooliesBufEnter() abort
  call HooliesGitBranchRefresh()
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
  let click = has('tablineat')
  for b in range(1, bufnr('$'))
    if !buflisted(b) | continue | endif
    let name = fnamemodify(bufname(b), ':t')
    if name ==# '' | let name = '[No Name]' | endif
    if getbufvar(b, '&modified')
      let name .= '+'
    endif
    let s .= (b == bufnr('%') ? '%#TabLineSel#' : '%#TabLine#')
    if click
      let s .= '%' . b . '@HooliesTablineClick@ ' . name . ' %X'
    else
      let s .= ' ' . name . ' '
    endif
  endfor
  let s .= '%#TabLineFill#'
  return s
endfunction

function! HooliesTablineClick(minwid, nclicks, button, mods) abort
  if a:minwid > 0 && bufexists(a:minwid)
    execute 'buffer' a:minwid
  endif
endfunction

function! HooliesStatusLine() abort
  return '%<%f %h%w%m%r%{HooliesStatusGit()}%=%y %{&ff} %{strlen(&fenc)?&fenc:&enc} %l,%c/%L %P'
endfunction

function! HooliesSeedViminfo() abort
  " One-time: copy ~/.viminfo into ~/.vim/viminfo so recent files survive the move.
  let legacy = expand('~/.viminfo')
  let current = expand('~/.vim/viminfo')
  let marker = expand('~/.vim/viminfo.seeded')
  if filereadable(marker) || !filereadable(legacy)
    return
  endif
  try
    call mkdir(expand('~/.vim'), 'p', 0700)
    call writefile(readfile(legacy), current)
    call writefile(['seeded-from-home-viminfo'], marker)
  catch
  endtry
endfunction

function! HooliesClipboardTool() abort
  " Wayland + X11 both present: prefer wl-copy so yanks reach clipse / the compositor.
  if exists('$WAYLAND_DISPLAY') && executable('wl-copy') && executable('wl-paste')
    return 1
  endif
  if executable('xsel')
    return 1
  endif
  return has('clipboard')
endfunction

function! HooliesAlacrittyOpacity(opacity) abort
  if !exists('$ALACRITTY_SOCKET') || !executable('alacritty')
    return
  endif
  let win = exists('$ALACRITTY_WINDOW_ID') ? $ALACRITTY_WINDOW_ID : '-1'
  call system('alacritty msg -s ' . shellescape($ALACRITTY_SOCKET)
        \ . ' config -w ' . shellescape(win)
        \ . ' ' . shellescape('window.opacity=' . a:opacity))
endfunction

function! HooliesYankToSystem() abort
  if !exists('v:event') || get(v:event, 'operator', '') !=# 'y'
    return
  endif
  let reg = get(v:event, 'regname', '')
  if reg !=# '' && reg !=# '+' && reg !=# '*'
    return
  endif
  let text = join(get(v:event, 'regcontents', []), "\n")
  if get(v:event, 'regtype', '') =~# '^V'
    let text .= "\n"
  endif
  if exists('$WAYLAND_DISPLAY') && executable('wl-copy')
    call system('wl-copy --type text/plain', text)
  elseif executable('xsel')
    call system('xsel --nodetach -i -b', text)
  endif
endfunction

function! HooliesFlashYank() abort
  if !exists('v:event') || get(v:event, 'operator', '') !=# 'y' | return | endif
  call HooliesYankToSystem()
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
    call HooliesDashboard()
  elseif argc() == 1 && isdirectory(argv(0))
    let dir = fnamemodify(expand(argv(0)), ':p')
    exe 'cd' fnameescape(dir)
    " Replace Vim's full-window directory buffer with an empty edit + left explorer.
    enew
    execute 'Lexplore' fnameescape(dir)
    silent! bwipeout #
  endif
endfunction

function! HooliesDashboardLogo() abort
  return [
        \ '██╗  ██╗ ██████╗  ██████╗ ██╗     ██╗███████╗███████╗',
        \ '██║  ██║██╔═══██╗██╔═══██╗██║     ██║██╔════╝██╔════╝',
        \ '███████║██║   ██║██║   ██║██║     ██║█████╗  ███████╗',
        \ '██╔══██║██║   ██║██║   ██║██║     ██║██╔══╝  ╚════██║',
        \ '██║  ██║╚██████╔╝╚██████╔╝███████╗██║███████╗███████║',
        \ '╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝╚═╝╚══════╝╚══════╝',
        \ ]
endfunction

function! HooliesDashboardItems() abort
  return [
        \ ['f', 'Find file', 'call HooliesDashboardFind()'],
        \ ['n', 'New file', 'call HooliesDashboardNew()'],
        \ ['r', 'Recent files', 'call HooliesDashboardRecent()'],
        \ ['g', 'Project grep', 'call HooliesDashboardGrep()'],
        \ ['G', 'Git files', 'call HooliesDashboardGit()'],
        \ ['c', 'Config', 'call HooliesDashboardConfig()'],
        \ ['e', 'Explorer', 'call HooliesDashboardExplore()'],
        \ ['q', 'Quit', 'qa'],
        \ ]
endfunction

function! HooliesDashboardPadLeft(line, left) abort
  return repeat(' ', a:left) . a:line
endfunction

function! HooliesDashboardBlockWidth(lines) abort
  let w = 0
  for l in a:lines
    let w = max([w, strdisplaywidth(l)])
  endfor
  return w
endfunction

function! HooliesDashboardNormalize(lines, width) abort
  let out = []
  for l in a:lines
    call add(out, l . repeat(' ', a:width - strdisplaywidth(l)))
  endfor
  return out
endfunction

function! HooliesDashboardRender() abort
  let screen = max([&columns, 40])
  let logo = HooliesDashboardLogo()
  let logo_w = HooliesDashboardBlockWidth(logo)
  let logo = HooliesDashboardNormalize(logo, logo_w)
  let logo_left = max([0, (screen - logo_w) / 2])

  let sub = 'plugin-free Vim'
  let sub_left = max([0, logo_left + (logo_w - strdisplaywidth(sub)) / 2])

  let labels = []
  for item in HooliesDashboardItems()
    call add(labels, printf('[%s]  %s', item[0], item[1]))
  endfor
  let item_w = HooliesDashboardBlockWidth(labels)
  let labels = HooliesDashboardNormalize(labels, item_w)
  let item_left = max([0, logo_left + (logo_w - item_w) / 2])

  let body = []
  for l in logo
    call add(body, HooliesDashboardPadLeft(l, logo_left))
  endfor
  call add(body, '')
  call add(body, HooliesDashboardPadLeft(sub, sub_left))
  call add(body, '')
  for l in labels
    call add(body, HooliesDashboardPadLeft(l, item_left))
  endfor

  let top = max([0, (&lines - len(body) - 2) / 2])
  return repeat([''], top) + body
endfunction

function! HooliesDashboardClose() abort
  if &filetype ==# 'hoolies_dashboard'
    bwipeout!
  endif
endfunction

function! HooliesDashboardFind() abort
  call HooliesDashboardClose()
  call feedkeys(':find ', 'n')
endfunction

function! HooliesDashboardNew() abort
  call HooliesDashboardClose()
  enew
endfunction

function! HooliesDashboardRecent() abort
  call HooliesDashboardClose()
  call HooliesOldfilesPick()
endfunction

function! HooliesDashboardGrep() abort
  call HooliesDashboardClose()
  call HooliesGrepInteractive()
endfunction

function! HooliesDashboardGit() abort
  call HooliesDashboardClose()
  call HooliesGitFiles()
endfunction

function! HooliesDashboardConfig() abort
  call HooliesDashboardClose()
  call HooliesFindConfigFiles()
endfunction

function! HooliesDashboardExplore() abort
  call HooliesDashboardClose()
  call HooliesExploreToggle()
endfunction

function! HooliesDashboardHighlight() abort
  syntax match HooliesDashLogo /[█╔╗╚╝║═]/
  syntax match HooliesDashKey /\[.\]/
  syntax match HooliesDashSub /plugin-free Vim/
  hi! link HooliesDashLogo Function
  hi! link HooliesDashKey Number
  hi! link HooliesDashSub Comment
endfunction

function! HooliesDashboardMaps() abort
  for item in HooliesDashboardItems()
    execute 'nnoremap <buffer> <silent> ' . item[0] . ' :' . item[2] . '<CR>'
  endfor
  nnoremap <buffer> <silent> <Esc> :call HooliesDashboardNew()<CR>
endfunction

function! HooliesDashboard() abort
  keepalt enew
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
  setlocal nonumber norelativenumber nolist
  setlocal nocursorline nocursorcolumn
  setlocal nowrap colorcolumn=0 signcolumn=no
  setlocal scrolloff=0 sidescrolloff=0
  setlocal statusline=\ Hoolies%=
  setlocal filetype=hoolies_dashboard
  " Do not :file-rename this buffer — a relative name becomes cwd/[Name] in viminfo.
  call setline(1, HooliesDashboardRender())
  setlocal nomodifiable nomodified
  call HooliesDashboardHighlight()
  call HooliesDashboardMaps()
  " Put the cursor on the first menu row (keeps the padded layout stable).
  let lnum = 1
  while lnum <= line('$') && getline(lnum) !~# '\['
    let lnum += 1
  endwhile
  call cursor(lnum, 1)
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
  let root = HooliesGitRoot()
  if root ==# ''
    echo 'Not a git repo'
    return
  endif
  let files = systemlist('git -C ' . shellescape(root) . ' ls-files')
  if v:shell_error
    echo 'git ls-files failed'
    return
  endif
  call map(files, {_, p -> root . '/' . p})
  call HooliesPickPaths('Git files', files)
endfunction

function! HooliesExploreToggle() abort
  let i = 1
  while i <= winnr('$')
    if getbufvar(winbufnr(i), '&filetype') ==# 'netrw'
      execute i . 'close'
      return
    endif
    let i += 1
  endwhile
  let dir = expand('%:p:h')
  if dir ==# '' || !isdirectory(dir)
    Lexplore
  else
    execute 'Lexplore' fnameescape(dir)
  endif
endfunction

function! HooliesTabComplete() abort
  if pumvisible()
    return "\<C-n>"
  endif
  let col = col('.') - 1
  if col <= 0 || getline('.')[col - 1] =~# '\s'
    return "\<Tab>"
  endif
  return "\<C-n>"
endfunction

function! HooliesAutoComplete() abort
  if pumvisible() || mode() !=# 'i'
    return
  endif
  if !&modifiable || &readonly || &buftype !=# ''
    return
  endif
  let col = col('.') - 1
  if col < 2
    return
  endif
  let before = strpart(getline('.'), 0, col)
  if before !~# '\k\{2}$'
    return
  endif
  call feedkeys("\<C-n>", 'n')
endfunction

function! HooliesAutoCompleteTick(timer) abort
  let s:hoolies_ac_timer = -1
  call HooliesAutoComplete()
endfunction

function! HooliesAutoCompleteSchedule() abort
  if has('timers')
    if s:hoolies_ac_timer != -1
      call timer_stop(s:hoolies_ac_timer)
    endif
    let s:hoolies_ac_timer = timer_start(50, function('HooliesAutoCompleteTick'))
  else
    call HooliesAutoComplete()
  endif
endfunction

function! HooliesSetOmnifunc() abort
  if &omnifunc !=# ''
    return
  endif
  let by_ft = {
        \ 'python': 'python3complete#Complete',
        \ 'c': 'ccomplete#Complete',
        \ 'cpp': 'ccomplete#Complete',
        \ 'css': 'csscomplete#CompleteCSS',
        \ 'html': 'htmlcomplete#CompleteTags',
        \ 'htmldjango': 'htmlcomplete#CompleteTags',
        \ 'javascript': 'javascriptcomplete#CompleteJS',
        \ 'javascriptreact': 'javascriptcomplete#CompleteJS',
        \ 'php': 'phpcomplete#CompletePHP',
        \ 'ruby': 'rubycomplete#Complete',
        \ 'sql': 'sqlcomplete#Complete',
        \ 'xml': 'xmlcomplete#CompleteTags',
        \ }
  let name = get(by_ft, &filetype, 'syntaxcomplete#Complete')
  if !exists('*' . name)
    let name = 'syntaxcomplete#Complete'
  endif
  execute 'setlocal omnifunc=' . name
endfunction

function! HooliesMapsLines() abort
  return [
        \ 'Leader is Space. Close with q or Esc.',
        \ '',
        \ 'Files',
        \ '  <Space>e      toggle file explorer',
        \ '  <Space>ff     find file (:find)',
        \ '  <Space>fo     recent files',
        \ '  <Space>flg    git-tracked files',
        \ '  <Space>sn     nvim/vim config files',
        \ '',
        \ 'Buffers',
        \ '  <Space>fb     pick buffer',
        \ '  <Space>bb     new empty buffer',
        \ '  <Space>bd     delete buffer',
        \ '  <Space>bD     delete buffer and quit',
        \ '  <Space>bw     wipe buffer',
        \ '  S-h / S-l     previous / next buffer',
        \ '  click tab     switch to that buffer',
        \ '  Alt-Esc       close other file buffers',
        \ '',
        \ 'Search',
        \ '  <Space>flf    project grep',
        \ '  <Space>fs     grep word under cursor',
        \ '  <Space>ft     filter lines in this buffer',
        \ '  <Space>s/     grep open buffers',
        \ '  <Space>/      substitute word (or visual sel)',
        \ '  <Space>fh     help',
        \ '',
        \ 'Edit',
        \ '  <Space>F      format buffer',
        \ '  <Space>u      undo tree',
        \ '  <Space>CR     toggle terminal',
        \ '  <Space>?      this map list',
        \ '  Alt-j / Alt-k move line (or selection)',
        \ '  Tab / S-Tab   next / previous match (auto after 2 letters)',
        \ '  C-Space       omni-complete',
        \ '',
        \ 'Windows',
        \ '  C-h/j/k/l     move (tmux-aware)',
        \ '  C-arrows      resize splits',
        \ '',
        \ 'Other',
        \ '  :             command palette (history + commands)',
        \ '  : C-p/C-n     previous / next match in the list',
        \ '  : Tab/S-Tab   complete command names and args',
        \ '  <Space>:      classic command line',
        \ '  q:            classic command-line window',
        \ '  (no args)     welcome dashboard',
        \ '  Esc           clear search highlight',
        \ '  Esc Esc       hide terminal (job keeps running)',
        \ '  jj            leave insert mode',
        \ '  x / dd        delete without yanking',
        \ '  Y (visual)    yank to clipboard',
        \ ]
endfunction

function! HooliesCmdHistory() abort
  let out = []
  let i = histnr('cmd')
  while i >= 1 && len(out) < 80
    let h = histget('cmd', i)
    if h !=# '' && index(out, h) < 0
      call add(out, h)
    endif
    let i -= 1
  endwhile
  return out
endfunction

function! HooliesCmdPaletteItems() abort
  let q = s:cmd_pal_typed
  let qlow = tolower(q)
  let items = []
  let seen = {}
  let hist_n = 0
  for h in s:cmd_pal_all
    if q !=# '' && stridx(tolower(h), qlow) < 0
      continue
    endif
    if has_key(seen, h)
      continue
    endif
    let seen[h] = 1
    call add(items, {'k': 'h', 't': h})
    let hist_n += 1
    if hist_n >= 8
      break
    endif
  endfor
  if q !=# ''
    let cmd_n = 0
    for c in getcompletion(q, 'cmdline')
      if has_key(seen, c)
        continue
      endif
      let seen[c] = 1
      call add(items, {'k': 'c', 't': c})
      let cmd_n += 1
      if cmd_n >= 8
        break
      endif
    endfor
  endif
  return items
endfunction

function! HooliesCmdPaletteLines() abort
  let s:cmd_pal_items = HooliesCmdPaletteItems()
  let lines = ['> ' . s:cmd_pal_input . '▌']
  call add(lines, repeat('─', 56))
  if empty(s:cmd_pal_items)
    call add(lines, '  (type a command — Tab completes names and args)')
  else
    let i = 0
    let have_h = 0
    let have_c = 0
    for it in s:cmd_pal_items
      if it.k ==# 'h' && !have_h
        call add(lines, 'History')
        let have_h = 1
      endif
      if it.k ==# 'c' && !have_c
        call add(lines, 'Commands')
        let have_c = 1
      endif
      call add(lines, (i == s:cmd_pal_idx ? '▶ ' : '  ') . it.t)
      let i += 1
    endfor
  endif
  call add(lines, '')
  call add(lines, ' Tab complete  ·  C-p/C-n select  ·  Enter run  ·  Esc close')
  return lines
endfunction

function! HooliesCmdPaletteRefresh() abort
  if s:cmd_pal_id < 0 || !exists('*popup_settext')
    return
  endif
  call popup_settext(s:cmd_pal_id, HooliesCmdPaletteLines())
endfunction

function! HooliesCmdPaletteResetComp() abort
  let s:cmd_pal_comps = []
  let s:cmd_pal_comp_i = -1
  let s:cmd_pal_comp_pfx = ''
endfunction

function! HooliesCmdPaletteComplete(dir) abort
  let pfx = s:cmd_pal_typed
  if s:cmd_pal_comp_i >= 0 && s:cmd_pal_comp_pfx !=# ''
    let pfx = s:cmd_pal_comp_pfx
  endif
  let comps = getcompletion(pfx, 'cmdline')
  if empty(comps)
    return
  endif
  if s:cmd_pal_comps !=# comps
    let s:cmd_pal_comps = comps
    let s:cmd_pal_comp_pfx = pfx
    let s:cmd_pal_comp_i = a:dir > 0 ? 0 : len(comps) - 1
  else
    let n = len(s:cmd_pal_comps)
    let s:cmd_pal_comp_i = (s:cmd_pal_comp_i + a:dir + n) % n
  endif
  let s:cmd_pal_input = s:cmd_pal_comps[s:cmd_pal_comp_i]
  let s:cmd_pal_typed = s:cmd_pal_input
  let s:cmd_pal_idx = -1
endfunction

function! HooliesCmdPaletteHist(dir) abort
  let items = HooliesCmdPaletteItems()
  let s:cmd_pal_items = items
  if empty(items)
    return
  endif
  let last = len(items) - 1
  if s:cmd_pal_idx < 0
    let s:cmd_pal_idx = a:dir > 0 ? 0 : last
  else
    let s:cmd_pal_idx += a:dir > 0 ? 1 : -1
    if s:cmd_pal_idx < 0
      let s:cmd_pal_idx = last
    elseif s:cmd_pal_idx > last
      let s:cmd_pal_idx = 0
    endif
  endif
  let s:cmd_pal_input = items[s:cmd_pal_idx].t
  call HooliesCmdPaletteResetComp()
endfunction

function! HooliesCmdPaletteRun() abort
  let cmd = s:cmd_pal_input
  let id = s:cmd_pal_id
  let s:cmd_pal_id = -1
  if id >= 0
    call popup_close(id)
  endif
  if cmd ==# ''
    return
  endif
  call histadd('cmd', cmd)
  try
    execute cmd
  catch /^Vim\%((\a\+)\)\=:E/
    echohl ErrorMsg
    echo v:exception
    echohl None
  endtry
endfunction

function! HooliesCmdPaletteSetTyped(text) abort
  let s:cmd_pal_typed = a:text
  let s:cmd_pal_input = a:text
  let s:cmd_pal_idx = -1
  call HooliesCmdPaletteResetComp()
endfunction

function! HooliesCmdPaletteFilter(id, key) abort
  if a:key ==# "\<Esc>" || a:key ==# "\<C-c>"
    let s:cmd_pal_id = -1
    call popup_close(a:id)
    return 1
  endif
  if a:key ==# "\<CR>"
    call HooliesCmdPaletteRun()
    return 1
  endif
  if a:key ==# "\<Tab>"
    call HooliesCmdPaletteComplete(1)
    call HooliesCmdPaletteRefresh()
    return 1
  endif
  if a:key ==# "\<S-Tab>"
    call HooliesCmdPaletteComplete(-1)
    call HooliesCmdPaletteRefresh()
    return 1
  endif
  if a:key ==# "\<Up>" || a:key ==# "\<C-p>"
    call HooliesCmdPaletteHist(1)
    call HooliesCmdPaletteRefresh()
    return 1
  endif
  if a:key ==# "\<Down>" || a:key ==# "\<C-n>"
    call HooliesCmdPaletteHist(-1)
    call HooliesCmdPaletteRefresh()
    return 1
  endif
  if a:key ==# "\<BS>" || a:key ==# "\b" || a:key ==# "\<C-h>" || a:key ==# "\<Del>"
    let cur = s:cmd_pal_idx >= 0 ? s:cmd_pal_input : s:cmd_pal_typed
    if cur !=# ''
      call HooliesCmdPaletteSetTyped(strcharpart(cur, 0, strchars(cur) - 1))
      call HooliesCmdPaletteRefresh()
    endif
    return 1
  endif
  if a:key ==# "\<C-u>"
    call HooliesCmdPaletteSetTyped('')
    call HooliesCmdPaletteRefresh()
    return 1
  endif
  if a:key ==# "\<C-w>"
    let cur = s:cmd_pal_idx >= 0 ? s:cmd_pal_input : s:cmd_pal_typed
    call HooliesCmdPaletteSetTyped(substitute(cur, '\S\+\s*$', '', ''))
    call HooliesCmdPaletteRefresh()
    return 1
  endif
  if strchars(a:key) == 1 && char2nr(a:key) >= 32
    let cur = s:cmd_pal_idx >= 0 ? s:cmd_pal_input : s:cmd_pal_typed
    call HooliesCmdPaletteSetTyped(cur . a:key)
    call HooliesCmdPaletteRefresh()
    return 1
  endif
  return 1
endfunction

function! HooliesCmdPalette(...) abort
  if !exists('*popup_create')
    call feedkeys(':', 'n')
    return
  endif
  let prefill = a:0 ? a:1 : ''
  let s:cmd_pal_typed = prefill
  let s:cmd_pal_input = prefill
  let s:cmd_pal_idx = -1
  let s:cmd_pal_all = HooliesCmdHistory()
  let s:cmd_pal_items = []
  call HooliesCmdPaletteResetComp()
  let width = min([72, &columns - 6])
  try
    let s:cmd_pal_id = popup_create(HooliesCmdPaletteLines(), {
          \ 'title': ' Command ',
          \ 'pos': 'center',
          \ 'minwidth': width,
          \ 'maxwidth': width,
          \ 'maxheight': 20,
          \ 'border': [],
          \ 'padding': [0, 1, 0, 1],
          \ 'highlight': 'Pmenu',
          \ 'borderhighlight': ['Function'],
          \ 'filter': 'HooliesCmdPaletteFilter',
          \ 'mapping': 0,
          \ 'wrap': 0,
          \ 'zindex': 320,
          \ })
  catch
    let s:cmd_pal_id = -1
    call feedkeys(':', 'n')
  endtry
endfunction

function! HooliesMapsPopupFilter(id, key) abort
  " Do not close on '?' or Space: those are the keys that open this popup
  " (<leader>?), and Vim may still deliver them to the filter.
  if a:key ==# 'q' || a:key ==# "\<Esc>"
    call popup_close(a:id)
    return 1
  endif
  return 1
endfunction

function! HooliesMapsBindClose() abort
  nnoremap <buffer> <silent> q :close<CR>
  nnoremap <buffer> <silent> <Esc> :close<CR>
endfunction

function! HooliesShowMaps() abort
  let lines = HooliesMapsLines()
  if exists('*popup_create')
    try
      call popup_create(lines, {
            \ 'title': ' Maps ',
            \ 'pos': 'center',
            \ 'padding': [1, 2, 1, 2],
            \ 'border': [],
            \ 'highlight': 'Pmenu',
            \ 'borderhighlight': ['Function'],
            \ 'filter': 'HooliesMapsPopupFilter',
            \ 'mapping': 0,
            \ 'wrap': 0,
            \ 'zindex': 300,
            \ 'minwidth': 48,
            \ })
      return
    catch
    endtry
  endif
  silent botright 16new
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
  call setline(1, lines)
  setlocal nomodifiable
  call HooliesMapsBindClose()
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
    exe 'hi TabLine guibg=' . s:bg . ' guifg=' . s:comment
    exe 'hi TabLineSel guibg=' . s:bg . ' guifg=' . s:fg . ' gui=bold'
    exe 'hi TabLineFill guibg=' . s:bg . ' guifg=' . s:bg
    exe 'hi EndOfBuffer guibg=' . s:bg . ' guifg=' . s:bg
    hi Pmenu guibg=#292e42 guifg=#c0caf5
    hi PmenuSel guibg=#3e68d7 guifg=#ffffff gui=bold
    silent! hi PmenuMatch guifg=#7aa2f7 guibg=#292e42 gui=bold
    silent! hi PmenuMatchSel guifg=#ffffff guibg=#3e68d7 gui=bold
    hi Visual guibg=#343b58
    " Spell: never use a background (term often simulates undercurl as a block)
    hi SpellBad gui=undercurl guisp=#f7768e guifg=NONE guibg=NONE ctermfg=203 ctermbg=NONE cterm=underline
    hi SpellCap gui=undercurl guisp=#e0af68 guifg=NONE guibg=NONE ctermfg=214 ctermbg=NONE cterm=underline
    hi SpellLocal gui=undercurl guisp=#9ece6a guifg=NONE guibg=NONE ctermfg=149 ctermbg=NONE cterm=underline
    hi SpellRare gui=undercurl guisp=#bb9af7 guifg=NONE guibg=NONE ctermfg=177 ctermbg=NONE cterm=underline
    hi Function guifg=#7aa2f7 guibg=NONE gui=NONE cterm=NONE
    hi Constant guifg=#ff9e64 guibg=NONE
    hi String guifg=#9ece6a guibg=NONE
    hi Character guifg=#9ece6a guibg=NONE
    hi Number guifg=#ff9e64 guibg=NONE
    hi Boolean guifg=#ff9e64 guibg=NONE
    hi Float guifg=#ff9e64 guibg=NONE
    hi Identifier guifg=#bb9af7 guibg=NONE
    hi Statement guifg=#bb9af7 guibg=NONE
    hi Conditional guifg=#bb9af7 guibg=NONE
    hi Repeat guifg=#bb9af7 guibg=NONE
    hi Label guifg=#bb9af7 guibg=NONE
    hi Operator guifg=#89ddff guibg=NONE
    hi Keyword guifg=#bb9af7 guibg=NONE
    hi Exception guifg=#bb9af7 guibg=NONE
    hi PreProc guifg=#7dcfff guibg=NONE
    hi Include guifg=#7dcfff guibg=NONE
    hi Define guifg=#7dcfff guibg=NONE
    hi Macro guifg=#7dcfff guibg=NONE
    hi PreCondit guifg=#7dcfff guibg=NONE
    hi Type guifg=#2ac3de guibg=NONE
    hi StorageClass guifg=#2ac3de guibg=NONE
    hi Structure guifg=#2ac3de guibg=NONE
    hi Typedef guifg=#2ac3de guibg=NONE
    hi Special guifg=#7aa2f7 guibg=NONE
    hi SpecialChar guifg=#ff9e64 guibg=NONE
    hi Tag guifg=#7aa2f7 guibg=NONE
    hi Delimiter guifg=#89ddff guibg=NONE
    hi SpecialComment guifg=#565f89 guibg=NONE
    hi Debug guifg=#ff9e64 guibg=NONE
    hi Error guifg=#f7768e guibg=NONE
    hi Todo guifg=#e0af68 guibg=NONE gui=bold
    hi Title guifg=#7aa2f7 gui=bold
    hi Directory guifg=#7aa2f7
    hi MatchParen guifg=#ff9e64 guibg=#3b4261 gui=bold
    hi Underlined guifg=#7aa2f7 gui=underline
    hi NonText guifg=#3b4261
    hi SpecialKey guifg=#3b4261
    hi Folded guifg=#565f89 guibg=#1f2335
    hi VertSplit guifg=#1f2335 guibg=#1f2335
    hi WildMenu guibg=#3e68d7 guifg=#ffffff gui=bold
    hi PmenuSbar guibg=#292e42
    hi PmenuThumb guibg=#7aa2f7
    hi DiffAdd guibg=#283b4d guifg=NONE
    hi DiffChange guibg=#272d43 guifg=NONE
    hi DiffDelete guibg=#3f2d3d guifg=#f7768e
    hi DiffText guibg=#394b70 guifg=NONE
    hi StatusLineTerm guibg=#1f2335 guifg=#a9b1d6
    hi StatusLineTermNC guibg=#1f2335 guifg=#565f89
    hi QuickFixLine guibg=#343b58 guifg=#c0caf5
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
    hi Constant ctermfg=215
    hi String ctermfg=150
    hi Character ctermfg=150
    hi Number ctermfg=215
    hi Boolean ctermfg=215
    hi Float ctermfg=215
    hi Identifier ctermfg=176
    hi Statement ctermfg=141
    hi Conditional ctermfg=141
    hi Repeat ctermfg=141
    hi Label ctermfg=141
    hi Operator ctermfg=117
    hi Keyword ctermfg=141
    hi Exception ctermfg=141
    hi PreProc ctermfg=117
    hi Include ctermfg=117
    hi Define ctermfg=117
    hi Macro ctermfg=117
    hi PreCondit ctermfg=117
    hi Type ctermfg=80
    hi StorageClass ctermfg=80
    hi Structure ctermfg=80
    hi Typedef ctermfg=80
    hi Special ctermfg=111
    hi SpecialChar ctermfg=215
    hi Tag ctermfg=111
    hi Delimiter ctermfg=117
    hi SpecialComment ctermfg=60
    hi Debug ctermfg=215
    hi Error ctermfg=203
    hi Todo ctermfg=179 cterm=bold
    hi Title ctermfg=111 cterm=bold
    hi Directory ctermfg=111
    hi MatchParen ctermfg=215 ctermbg=238 cterm=bold
    hi Underlined ctermfg=111 cterm=underline
    hi NonText ctermfg=238
    hi SpecialKey ctermfg=238
    hi Folded ctermfg=60 ctermbg=234
    hi VertSplit ctermfg=234 ctermbg=234
    hi WildMenu ctermbg=61 ctermfg=231 cterm=bold
    hi Pmenu ctermfg=252 ctermbg=236
    hi PmenuSel ctermfg=231 ctermbg=61 cterm=bold
    silent! hi PmenuMatch ctermfg=111 ctermbg=236 cterm=bold
    silent! hi PmenuMatchSel ctermfg=231 ctermbg=61 cterm=bold
    hi PmenuSbar ctermbg=236
    hi PmenuThumb ctermbg=111
    hi Visual ctermbg=237
    hi Search ctermbg=61 ctermfg=252
    hi StatusLine ctermfg=146 ctermbg=234
    hi StatusLineNC ctermfg=60 ctermbg=234
    hi TabLine ctermfg=60 ctermbg=235
    hi TabLineSel ctermfg=252 ctermbg=235 cterm=bold
    hi TabLineFill ctermfg=235 ctermbg=235
    hi EndOfBuffer ctermfg=235 ctermbg=235
    hi CursorColumn ctermbg=236
    hi DiffAdd ctermbg=24 ctermfg=NONE
    hi DiffChange ctermbg=236 ctermfg=NONE
    hi DiffDelete ctermbg=52 ctermfg=203
    hi DiffText ctermbg=61 ctermfg=NONE
    hi StatusLineTerm ctermfg=146 ctermbg=234
    hi StatusLineTermNC ctermfg=60 ctermbg=234
    hi QuickFixLine ctermfg=252 ctermbg=237
  endif
  hi! link netrwDir Directory
  hi! link netrwClassify Directory
  hi! link netrwExe String
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
set diffopt+=vertical
set noautochdir
set iskeyword=@,48-57,192-255
if has('gui_running')
  set guicursor=n:block,i-ci:hor20,v-ve:block
endif

set autoread
set hidden
set updatetime=250
set mouse=a
set title
if exists('+viminfofile')
  call HooliesSeedViminfo()
  set viminfofile=~/.vim/viminfo
endif

if HooliesClipboardTool()
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
set shiftwidth=4
set softtabstop=4
set tabstop=4
set backspace=indent,eol,start
set virtualedit=block

set undodir=~/.vim/undodir
set undofile
set undolevels=1000
set directory=~/.vim/swap//

set encoding=utf-8
set showmode
set showtabline=2
set confirm
set history=1000
set display+=lastline
let &fillchars = 'eob: ,vert:│'
set nrformats-=octal
let g:hoolies_format_on_write = 1
" Spell off in code/config: avoids red/pink on names like github, nvim, win_id2win
set nospell
if has('termguicolors')
  if !has('gui_running')
    let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
    let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  endif
  set termguicolors
endif
set visualbell
set completeopt=menuone,noselect
set complete=.,w,b,u,t,i
set infercase
set shortmess+=c

set pumheight=12

" Built-in file explorer (no plugins). Lexplore is a left split; Enter opens the file.
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_browse_split = 4
let g:netrw_altv = 1
let g:netrw_winsize = 25
let g:netrw_keepdir = 0

if executable('rg')
  set grepprg=rg\ --vimgrep\ --sort\ path
  set grepformat=%f:%l:%c:%m
endif

set wildmenu
set wildmode=longest:full,full
set wildignorecase
if exists('+wildoptions')
  set wildoptions+=pum
  silent! set wildoptions+=fuzzy
endif
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

filetype plugin indent on
if !exists('g:syntax_on')
  syntax enable
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
nnoremap <silent> <A-ESC> :call HooliesCloseOtherBuffers()<CR>

tnoremap <silent> <C-h> <C-\><C-n><C-w>h
tnoremap <silent> <C-j> <C-\><C-n><C-w>j
tnoremap <silent> <C-k> <C-\><C-n><C-w>k
tnoremap <silent> <C-l> <C-\><C-n><C-w>l

nnoremap <silent> <leader>u :call HooliesUndotreeToggle()<CR>

nnoremap <silent> <Esc> :<C-u>nohlsearch<CR>:call HooliesEscAfterNoHl()<CR>

nnoremap <silent> <Leader><CR> :call HooliesFloatingTermToggle()<CR>
tnoremap <silent> <Esc> <C-\><C-n>

nnoremap <silent> <leader>e :call HooliesExploreToggle()<CR>
nnoremap <silent> <Leader>? :<C-u>call HooliesShowMaps()<CR>
nnoremap <silent> : <Cmd>call HooliesCmdPalette()<CR>
xnoremap <silent> : :<C-u>call HooliesCmdPalette("'<,'>")<CR>
nnoremap <silent> <Leader>: :

" Native cmdline (visual : ranges, feedkeys, q:) — prefix-matching history.
cnoremap <C-p> <Up>
cnoremap <C-n> <Down>

inoremap <silent> <expr> <Tab> HooliesTabComplete()
inoremap <silent> <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <silent> <expr> <CR> pumvisible() ? "\<C-y>" : "\<CR>"
inoremap <silent> <C-Space> <C-x><C-o>
if !has('gui_running')
  imap <C-@> <C-Space>
endif

nnoremap <leader>/ :%s/\<<C-r><C-w>\>//g<Left><Left>
xnoremap <leader>/ y:%s/\V<C-r>=escape(@",'/\')<CR>//g<Left><Left>

nnoremap x "_x
xnoremap x "_x
nnoremap dd "_dd

" Visual Y yanks the selection (not whole lines). "+Y then writes to the clipboard.
xnoremap Y "+y

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

" Space alone = nop; define after all <leader> maps so leader is Space + next keys.
nnoremap <Space> <Nop>
xnoremap <Space> <Nop>

" =============================================================================
" Autocmds
" =============================================================================

augroup hoolies_vimrc
  autocmd!
  " Spell only where prose is expected (keeps .vimrc / code free of spell highlights)
  autocmd FileType hoolies_dashboard call HooliesDashboardHighlight()
  autocmd FileType markdown,gitcommit,text,typst,rst setlocal spell
  autocmd FileType * call HooliesSetOmnifunc()
  autocmd FileType netrw setlocal nonumber norelativenumber
  autocmd FileType vim call HooliesVimFuncLinkFix()
  autocmd ColorScheme * call HooliesVimFuncLinkFix()
  autocmd VimEnter * call HooliesVimEnterNoArgs()
  if exists('##TextYankPost')
    autocmd TextYankPost * call HooliesFlashYank()
  endif
  autocmd BufWritePre * call HooliesBufWritePre()
  autocmd TextChangedI * call HooliesAutoCompleteSchedule()
  autocmd BufReadPost * if line("'\"") >= 1 && line("'\"") <= line('$') | exe "normal! g`\"" | endif
  if exists('##TerminalOpen')
    autocmd TerminalOpen * call HooliesTermSetup()
  endif
  autocmd VimEnter * call HooliesAlacrittyOpacity(1)
  autocmd VimLeave * call HooliesAlacrittyOpacity(0.67)
  autocmd BufEnter * call HooliesBufEnter()
  autocmd FocusGained * call HooliesGitBranchRefresh(1)
  autocmd FocusGained,BufEnter * if mode() !=# 'c' | checktime | endif
augroup END
