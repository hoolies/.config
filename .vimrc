" Single-file: all logic and colors live here (no autoload/ or colors/ files).
" ~/.vimrc is a symlink to that file.

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
let s:cmd_pal_menu = -1
let s:cmd_pal_typed = ''
let s:cmd_pal_input = ''
let s:cmd_pal_idx = -1
let s:cmd_pal_all = []
let s:cmd_pal_items = []
let s:cmd_pal_comps = []
let s:cmd_pal_comp_i = -1
let s:cmd_pal_comp_pfx = ''
let s:cmd_pal_width = 72
let s:pick_id = -1
let s:pick_query = ''
let s:pick_all = []
let s:pick_items = []
let s:pick_idx = 0
let s:pick_title = ' Pick '
let s:pick_mode = 'filter'
let s:pick_grep_timer = -1
let s:pick_grep_regex = 0
let s:maps_query = ''
let s:maps_searching = 0
let s:maps_search_start = 1

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
  setlocal nonumber norelativenumber nobuflisted bufhidden=hide noswapfile nolist
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

function! HooliesEscExpr() abort
  " Lone Esc clears search. If more bytes are already queued (arrows / Alt),
  " do not consume the Esc prefix.
  let peek = getchar(0)
  if peek != 0
    return "\<Esc>" . (type(peek) == v:t_number ? nr2char(peek) : peek)
  endif
  return ":\<C-u>nohlsearch\<CR>:call HooliesEscAfterNoHl()\<CR>"
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
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
  setlocal nonumber norelativenumber nolist
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
    call add(lines, printf('%sseq=%s  %s  save=%s',
          \ repeat('  ', a:indent),
          \ get(e, 'seq', '?'),
          \ HooliesUndoTime(get(e, 'time', 0)),
          \ get(e, 'save', '?')))
    if has_key(e, 'alt') && type(e.alt) == v:t_list
      let lines += HooliesUndotreeLines(e.alt, a:indent + 1)
    endif
  endfor
  return lines
endfunction

function! HooliesUndoTime(ts) abort
  if type(a:ts) == v:t_number
    let t = a:ts
  elseif type(a:ts) == v:t_string && a:ts =~# '^\d\+$'
    let t = str2nr(a:ts)
  else
    return string(a:ts)
  endif
  if t <= 0
    return '?'
  endif
  return strftime('%Y-%m-%d %H:%M:%S', t)
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
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
  setlocal nonumber norelativenumber nolist
  nnoremap <buffer> <silent> q :bwipeout!<CR>
  nnoremap <buffer> <silent> <Esc> :bwipeout!<CR>
endfunction

function! HooliesFilterPickerLines() abort
  let q = tolower(s:pick_query)
  let s:pick_items = []
  if s:pick_mode ==# 'filter'
    for it in s:pick_all
      let hay = tolower(it.label)
      if has_key(it, 'path')
        let hay .= ' ' . tolower(it.path)
      endif
      if q ==# '' || stridx(hay, q) >= 0
        call add(s:pick_items, it)
      endif
    endfor
  else
    let s:pick_items = copy(s:pick_all)
  endif
  if s:pick_idx >= len(s:pick_items)
    let s:pick_idx = max([0, len(s:pick_items) - 1])
  endif
  let lines = ['> ' . s:pick_query . '▌']
  call add(lines, repeat('─', 56))
  if empty(s:pick_items)
    if s:pick_mode ==# 'grep' && strchars(s:pick_query) < 2
      call add(lines, '  (type 2+ characters to search)')
    elseif s:pick_mode ==# 'help' && s:pick_query ==# ''
      call add(lines, '  (type a help topic)')
    else
      call add(lines, '  (no matches)')
    endif
  else
    let last = len(s:pick_items) - 1
    let maxn = 16
    let start = 0
    if last > maxn
      let start = max([0, s:pick_idx - maxn / 2])
      if start + maxn > last
        let start = last - maxn
      endif
    endif
    let stop = min([last, start + maxn])
    if start > 0
      call add(lines, '  … ' . start . ' above')
    endif
    let i = start
    while i <= stop
      let it = s:pick_items[i]
      call add(lines, (i == s:pick_idx ? '▶ ' : '  ') . it.label)
      let i += 1
    endwhile
    if stop < last
      call add(lines, '  … ' . (last - stop) . ' more')
    endif
  endif
  call add(lines, '')
  if s:pick_mode ==# 'grep'
    let kind = s:pick_grep_regex ? 'regex' : 'literal'
    call add(lines, ' C-r ' . kind . '  ·  C-p/C-n  ·  Enter open + quickfix  ·  Esc')
  else
    call add(lines, ' type to filter  ·  C-p/C-n  ·  Enter open  ·  Esc close')
  endif
  return lines
endfunction

function! HooliesFilterPickerRefresh() abort
  if s:pick_id < 0 || !exists('*popup_settext')
    return
  endif
  call popup_settext(s:pick_id, HooliesFilterPickerLines())
endfunction

function! HooliesFilterPickerAccept() abort
  if empty(s:pick_items) || s:pick_idx < 0 || s:pick_idx >= len(s:pick_items)
    return
  endif
  let item = s:pick_items[s:pick_idx]
  let id = s:pick_id
  let s:pick_id = -1
  if id >= 0
    call popup_close(id)
  endif
  if item.kind ==# 'buf'
    if item.id > 0 && bufexists(item.id)
      execute 'buffer' item.id
    endif
  elseif item.kind ==# 'help'
    if get(item, 'tag', '') !=# ''
      try
        execute 'help' item.tag
      catch /^Vim\%((\a\+)\)\=:E/
        echo 'No help for ' . item.tag
      endtry
    endif
  elseif item.kind ==# 'grep'
    if get(item, 'path', '') ==# ''
      return
    endif
    call HooliesGrepToQuickfix()
    execute 'edit' fnameescape(item.path)
    if get(item, 'lnum', 0) > 0
      execute item.lnum
      normal! zvzz
    endif
  elseif get(item, 'path', '') !=# ''
    execute 'edit' fnameescape(item.path)
  endif
endfunction

function! HooliesFilterPickerMove(dir) abort
  if empty(s:pick_items)
    return
  endif
  let last = len(s:pick_items) - 1
  let s:pick_idx += a:dir
  if s:pick_idx < 0
    let s:pick_idx = last
  elseif s:pick_idx > last
    let s:pick_idx = 0
  endif
endfunction

function! HooliesFilterPickerFilter(id, key) abort
  if a:key ==# "\<Esc>" || a:key ==# "\<C-c>"
    let s:pick_id = -1
    call popup_close(a:id)
    return 1
  endif
  if a:key ==# "\<CR>"
    call HooliesFilterPickerAccept()
    return 1
  endif
  if a:key ==# "\<C-r>" && s:pick_mode ==# 'grep'
    let s:pick_grep_regex = !s:pick_grep_regex
    let s:pick_title = s:pick_grep_regex ? ' Grep regex ' : ' Grep literal '
    if s:pick_id >= 0 && exists('*popup_setoptions')
      call popup_setoptions(s:pick_id, {'title': s:pick_title})
    endif
    let s:pick_idx = 0
    call HooliesFilterPickerQueryChanged()
    return 1
  endif
  if a:key ==# "\<Up>" || a:key ==# "\<C-p>"
    call HooliesFilterPickerMove(-1)
    call HooliesFilterPickerRefresh()
    return 1
  endif
  if a:key ==# "\<Down>" || a:key ==# "\<C-n>"
    call HooliesFilterPickerMove(1)
    call HooliesFilterPickerRefresh()
    return 1
  endif
  if a:key ==# "\<BS>" || a:key ==# "\b" || a:key ==# "\<C-h>" || a:key ==# "\<Del>"
    if s:pick_query !=# ''
      let s:pick_query = strcharpart(s:pick_query, 0, strchars(s:pick_query) - 1)
      let s:pick_idx = 0
      call HooliesFilterPickerQueryChanged()
    endif
    return 1
  endif
  if a:key ==# "\<C-u>"
    let s:pick_query = ''
    let s:pick_idx = 0
    call HooliesFilterPickerQueryChanged()
    return 1
  endif
  if strchars(a:key) == 1 && char2nr(a:key) >= 32
    let s:pick_query .= a:key
    let s:pick_idx = 0
    call HooliesFilterPickerQueryChanged()
    return 1
  endif
  return 1
endfunction

function! HooliesFilterPickerQueryChanged() abort
  if s:pick_mode ==# 'grep'
    call HooliesFilterPickerRefresh()
    call HooliesGrepPickerSchedule()
  elseif s:pick_mode ==# 'help'
    call HooliesHelpPickerSearch()
    call HooliesFilterPickerRefresh()
  else
    call HooliesFilterPickerRefresh()
  endif
endfunction

function! HooliesFilterPickerSplit() abort
  silent botright 12new
  call HooliesPickerSetup()
  let lines = []
  for it in s:pick_all
    if it.kind ==# 'buf'
      call add(lines, it.label . "\t#" . it.id)
    else
      call add(lines, it.path)
    endif
  endfor
  call setline(1, lines)
  if get(s:pick_all, 0, {'kind': ''}).kind ==# 'buf'
    nnoremap <buffer> <silent> <CR> :call HooliesOpenBufferPickLine()<CR>
  else
    nnoremap <buffer> <silent> <CR> :call HooliesOpenOldfileLine()<CR>
  endif
endfunction

function! HooliesFilterPicker(title, items) abort
  let s:pick_mode = 'filter'
  if empty(a:items)
    echohl WarningMsg | echo a:title . ': (empty)' | echohl None
    return
  endif
  let s:pick_title = ' ' . a:title . ' '
  let s:pick_all = a:items
  let s:pick_query = ''
  let s:pick_idx = 0
  if !exists('*popup_create')
    call HooliesFilterPickerSplit()
    return
  endif
  let width = min([78, &columns - 6])
  try
    let s:pick_id = popup_create(HooliesFilterPickerLines(), {
          \ 'title': s:pick_title,
          \ 'pos': 'center',
          \ 'minwidth': width,
          \ 'maxwidth': width,
          \ 'maxheight': 22,
          \ 'border': [],
          \ 'padding': [0, 1, 0, 1],
          \ 'highlight': 'Pmenu',
          \ 'borderhighlight': ['Function'],
          \ 'filter': 'HooliesFilterPickerFilter',
          \ 'mapping': 0,
          \ 'wrap': 0,
          \ 'zindex': 310,
          \ })
  catch
    let s:pick_id = -1
    call HooliesFilterPickerSplit()
  endtry
endfunction

function! HooliesOldfilesPick() abort
  let items = []
  let seen = {}
  for path in v:oldfiles
    let p = resolve(expand(path))
    if p ==# '' || !filereadable(p) || has_key(seen, p)
      continue
    endif
    " Skip fake buffer names like [Dashboard] stored relative to cwd.
    if fnamemodify(p, ':t') =~# '^\[.\+\]$'
      continue
    endif
    let seen[p] = 1
    call add(items, {'kind': 'file', 'path': p, 'label': fnamemodify(p, ':~')})
  endfor
  call HooliesFilterPicker('Recent', items)
endfunction

function! HooliesOpenOldfileLine() abort
  let path = getline('.')
  if path ==# '' | return | endif
  bwipeout!
  execute 'edit' fnameescape(path)
endfunction

function! HooliesPickPaths(title, paths) abort
  let items = []
  let seen = {}
  for p in a:paths
    let path = resolve(expand(p))
    if path ==# '' || has_key(seen, path)
      continue
    endif
    let seen[path] = 1
    call add(items, {'kind': 'file', 'path': path, 'label': fnamemodify(path, ':~')})
  endfor
  call HooliesFilterPicker(a:title, items)
endfunction

function! HooliesFindConfigFiles() abort
  let roots = filter([
        \ expand('~/.config/nvim'),
        \ expand('~/.vim'),
        \ ], 'isdirectory(v:val)')
  let out = [
        \ expand('~/.vimrc'),
        \ expand('~/Projects/Bourne_Again/git_config/.config/.vimrc'),
        \ ]
  for r in roots
    let out += glob(r . '/**/*.lua', 0, 1)
    let out += glob(r . '/**/*.vim', 0, 1)
  endfor
  call HooliesPickPaths('Config', out)
endfunction

function! HooliesGrepToQuickfix() abort
  let qf = []
  for it in s:pick_all
    if get(it, 'kind', '') !=# 'grep' || get(it, 'path', '') ==# ''
      continue
    endif
    call add(qf, {
          \ 'filename': it.path,
          \ 'lnum': get(it, 'lnum', 1),
          \ 'col': get(it, 'col', 1),
          \ 'text': get(it, 'text', it.label),
          \ })
  endfor
  if empty(qf)
    return
  endif
  call setqflist(qf, 'r')
  call setqflist([], 'a', {'title': (s:pick_grep_regex ? 'Grep ' : 'Grep -F ') . s:pick_query})
endfunction

function! HooliesLivePickerOpen(title, mode, query) abort
  let s:pick_mode = a:mode
  if a:mode ==# 'grep'
    let s:pick_grep_regex = 0
    let s:pick_title = ' Grep literal '
  else
    let s:pick_title = ' ' . a:title . ' '
  endif
  let s:pick_all = []
  let s:pick_items = []
  let s:pick_query = a:query
  let s:pick_idx = 0
  if !exists('*popup_create')
    if a:mode ==# 'grep'
      if a:query ==# ''
        call inputsave()
        let pat = input('Project grep pattern: ')
        call inputrestore()
        if pat ==# '' | return | endif
        call HooliesGrepFill(pat)
      else
        call HooliesGrepFill(a:query)
      endif
    elseif a:mode ==# 'help'
      call feedkeys(':help ' . a:query, 'n')
    endif
    return
  endif
  let width = min([78, &columns - 6])
  try
    let s:pick_id = popup_create(HooliesFilterPickerLines(), {
          \ 'title': s:pick_title,
          \ 'pos': 'center',
          \ 'minwidth': width,
          \ 'maxwidth': width,
          \ 'maxheight': 22,
          \ 'border': [],
          \ 'padding': [0, 1, 0, 1],
          \ 'highlight': 'Pmenu',
          \ 'borderhighlight': ['Function'],
          \ 'filter': 'HooliesFilterPickerFilter',
          \ 'mapping': 0,
          \ 'wrap': 0,
          \ 'zindex': 310,
          \ })
  catch
    let s:pick_id = -1
    return
  endtry
  call HooliesFilterPickerQueryChanged()
endfunction

function! HooliesGrepPickerSchedule() abort
  if has('timers')
    if s:pick_grep_timer != -1
      call timer_stop(s:pick_grep_timer)
    endif
    let s:pick_grep_timer = timer_start(160, function('HooliesGrepPickerTick'))
  else
    call HooliesGrepPickerSearch()
  endif
endfunction

function! HooliesGrepPickerTick(timer) abort
  let s:pick_grep_timer = -1
  call HooliesGrepPickerSearch()
  call HooliesFilterPickerRefresh()
endfunction

function! HooliesGrepPickerSearch() abort
  let s:pick_all = []
  let q = s:pick_query
  if strchars(q) < 2
    return
  endif
  let root = HooliesGitRoot()
  let lines = []
  if executable('rg')
    let flags = s:pick_grep_regex ? '' : '-F '
    let cmd = 'rg --vimgrep --max-count 4 --max-filesize 1M ' . flags . '-- ' . shellescape(q)
    if root !=# ''
      let cmd .= ' ' . shellescape(root)
    endif
    let lines = systemlist(cmd)
    if v:shell_error >= 2
      call add(s:pick_all, {'kind': 'grep', 'path': '', 'lnum': 0, 'text': '', 'label': 'rg: invalid pattern or failed'})
      return
    endif
  else
    let save_cwd = getcwd()
    try
      if root !=# ''
        execute 'lcd' fnameescape(root)
      endif
      if s:pick_grep_regex
        let pat = escape(q, '/')
      else
        let pat = '\V' . escape(q, '/\')
      endif
      silent! execute 'vimgrep /' . pat . '/gj **/*'
    catch
    finally
      execute 'lcd' fnameescape(save_cwd)
    endtry
    for e in getqflist()
      if !has_key(e, 'bufnr') || e.bufnr <= 0
        continue
      endif
      let path = fnamemodify(bufname(e.bufnr), ':p')
      let text = get(e, 'text', '')
      let lnum = get(e, 'lnum', 0)
      call add(s:pick_all, {
            \ 'kind': 'grep',
            \ 'path': path,
            \ 'lnum': lnum,
            \ 'col': get(e, 'col', 1),
            \ 'text': text,
            \ 'label': fnamemodify(path, ':~') . ':' . lnum . '  ' . text,
            \ })
      if len(s:pick_all) >= 80
        break
      endif
    endfor
    return
  endif
  let n = 0
  for line in lines
    let m = matchlist(line, '^\(.\{-}\):\(\d\+\):\(\d\+\):\(.*\)$')
    if empty(m)
      continue
    endif
    let path = m[1]
    let lnum = str2nr(m[2])
    let col = str2nr(m[3])
    let text = m[4]
    call add(s:pick_all, {
          \ 'kind': 'grep',
          \ 'path': path,
          \ 'lnum': lnum,
          \ 'col': col,
          \ 'text': text,
          \ 'label': fnamemodify(path, ':~') . ':' . lnum . '  ' . text,
          \ })
    let n += 1
    if n >= 80
      break
    endif
  endfor
endfunction

function! HooliesHelpPickerSearch() abort
  let s:pick_all = []
  let q = s:pick_query
  if q ==# ''
    return
  endif
  for t in getcompletion(q, 'help')
    call add(s:pick_all, {'kind': 'help', 'tag': t, 'label': t})
    if len(s:pick_all) >= 60
      break
    endif
  endfor
endfunction

function! HooliesGrepInteractive() abort
  call HooliesLivePickerOpen('Grep', 'grep', '')
endfunction

function! HooliesHelpPick() abort
  call HooliesLivePickerOpen('Help', 'help', '')
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
    let cmd = 'rg --vimgrep -F -- ' . shellescape(a:pat)
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
      silent exe 'vimgrep /\V' . escape(a:pat, '/\') . '/gj **/*'
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
  call HooliesLivePickerOpen('Grep', 'grep', w)
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
  let items = []
  for b in range(1, bufnr('$'))
    if !buflisted(b) | continue | endif
    let n = bufname(b)
    if n ==# ''
      let label = '[No Name] #' . b
    else
      let label = fnamemodify(fnamemodify(n, ':p'), ':~')
    endif
    if getbufvar(b, '&modified')
      let label .= ' +'
    endif
    call add(items, {'kind': 'buf', 'id': b, 'label': label})
  endfor
  call HooliesFilterPicker('Buffers', items)
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

function! HooliesFormatExtCmd() abort
  let ft = &filetype
  if ft ==# 'lua' && executable('stylua')
    return 'stylua -'
  endif
  if ft ==# 'python' && executable('ruff')
    return 'ruff format -'
  endif
  if ft ==# 'python' && executable('black')
    return 'black -q -'
  endif
  if ft ==# 'go' && executable('goimports')
    return 'goimports'
  endif
  if ft ==# 'go' && executable('gofmt')
    return 'gofmt'
  endif
  if (ft ==# 'sh' || ft ==# 'bash' || ft ==# 'zsh') && executable('shfmt')
    return 'shfmt -i 4 -ci'
  endif
  if ft ==# 'elixir' && executable('mix')
    return 'mix format -'
  endif
  return ''
endfunction

function! HooliesFormatKind() abort
  let ft = &filetype
  if ft ==# 'json' || ft ==# 'jsonc'
    return 'json'
  endif
  if ft ==# 'yaml' || ft ==# 'yml'
    return 'yaml'
  endif
  if ft ==# 'toml'
    return 'toml'
  endif
  if ft ==# 'css' || ft ==# 'scss' || ft ==# 'less'
    return 'css'
  endif
  if ft ==# 'html' || ft ==# 'htmldjango'
    return 'html'
  endif
  if ft ==# 'xml' || ft ==# 'xsd' || ft ==# 'xslt' || ft ==# 'svg'
    return 'xml'
  endif
  return ''
endfunction

function! HooliesReplaceBuffer(text) abort
  let lines = split(a:text, "\n", 1)
  if !empty(lines) && lines[-1] ==# ''
    call remove(lines, -1)
  endif
  silent! keepjumps %delete _
  if empty(lines)
    call setline(1, '')
  else
    call setline(1, lines)
  endif
endfunction

function! HooliesJsonFromVim(val, level) abort
  let t = type(a:val)
  let pad = repeat('    ', a:level)
  let inn = repeat('    ', a:level + 1)
  if exists('v:null') && (a:val is# v:null || a:val is# v:none)
    return 'null'
  endif
  if exists('v:true') && a:val is# v:true
    return 'true'
  endif
  if exists('v:false') && a:val is# v:false
    return 'false'
  endif
  if t == type([])
    if empty(a:val)
      return '[]'
    endif
    let parts = []
    for item in a:val
      call add(parts, inn . HooliesJsonFromVim(item, a:level + 1))
    endfor
    return "[\n" . join(parts, ",\n") . "\n" . pad . ']'
  endif
  if t == type({})
    if empty(a:val)
      return '{}'
    endif
    let parts = []
    for k in sort(keys(a:val))
      let key = exists('*json_encode') ? json_encode(k) : '"' . substitute(k, '"', '\\"', 'g') . '"'
      call add(parts, inn . key . ': ' . HooliesJsonFromVim(a:val[k], a:level + 1))
    endfor
    return "{\n" . join(parts, ",\n") . "\n" . pad . '}'
  endif
  if exists('*json_encode') && (t == type('') || t == type(0) || t == type(0.0))
    return json_encode(a:val)
  endif
  if t == type('')
    return '"' . substitute(substitute(a:val, '\\', '\\\\', 'g'), '"', '\\"', 'g') . '"'
  endif
  return string(a:val)
endfunction

function! HooliesJsonPrettyScan(src) abort
  let out = ''
  let indent = 0
  let i = 0
  let n = strlen(a:src)
  let in_str = 0
  let esc = 0
  while i < n
    let c = strpart(a:src, i, 1)
    if in_str
      let out .= c
      if esc
        let esc = 0
      elseif c ==# '\'
        let esc = 1
      elseif c ==# '"'
        let in_str = 0
      endif
      let i += 1
      continue
    endif
    if c ==# '"'
      let in_str = 1
      let out .= c
    elseif c ==# '{' || c ==# '['
      let indent += 1
      let out .= c . "\n" . repeat('    ', indent)
    elseif c ==# '}' || c ==# ']'
      let indent = indent - 1
      if indent < 0
        throw 'invalid json'
      endif
      let out .= "\n" . repeat('    ', indent) . c
    elseif c ==# ','
      let out .= c . "\n" . repeat('    ', indent)
    elseif c ==# ':'
      let out .= ': '
    elseif c =~# '\s'
    else
      let out .= c
    endif
    let i += 1
  endwhile
  if in_str || indent != 0
    throw 'invalid json'
  endif
  return substitute(out, '\n\s*\n', '\n', 'g') . "\n"
endfunction

function! HooliesFmtJson(src) abort
  let src = substitute(a:src, '^\_s*\|\_s*$', '', 'g')
  if src ==# ''
    return ''
  endif
  if exists('*json_decode')
    let obj = json_decode(src)
    return HooliesJsonFromVim(obj, 0) . "\n"
  endif
  return HooliesJsonPrettyScan(src)
endfunction

function! HooliesYamlScalar(val) abort
  if exists('v:null') && (a:val is# v:null || a:val is# v:none)
    return 'null'
  endif
  if exists('v:true') && a:val is# v:true
    return 'true'
  endif
  if exists('v:false') && a:val is# v:false
    return 'false'
  endif
  let t = type(a:val)
  if t == type(0) || t == type(0.0)
    return exists('*json_encode') ? json_encode(a:val) : string(a:val)
  endif
  let s = type(a:val) == type('') ? a:val : string(a:val)
  if s ==# '' || s =~# '[:#\[\]{},&*!|>''"%@`]' || s =~# '^\s\|\s$' || s =~# '\n'
    return exists('*json_encode') ? json_encode(s) : '"' . substitute(s, '"', '\\"', 'g') . '"'
  endif
  return s
endfunction

function! HooliesYamlFromVim(val, level) abort
  let pad = repeat('  ', a:level)
  let t = type(a:val)
  if t == type({})
    if empty(a:val)
      return pad . '{}'
    endif
    let lines = []
    for k in keys(a:val)
      let v = a:val[k]
      let key = k =~# '^[A-Za-z0-9_.-]\+$' ? k : HooliesYamlScalar(k)
      if type(v) == type({}) || type(v) == type([])
        if empty(v)
          call add(lines, pad . key . ': ' . (type(v) == type([]) ? '[]' : '{}'))
        else
          call add(lines, pad . key . ':')
          call add(lines, HooliesYamlFromVim(v, a:level + 1))
        endif
      else
        call add(lines, pad . key . ': ' . HooliesYamlScalar(v))
      endif
    endfor
    return join(lines, "\n")
  endif
  if t == type([])
    if empty(a:val)
      return pad . '[]'
    endif
    let lines = []
    for item in a:val
      if type(item) == type({}) || type(item) == type([])
        if empty(item)
          call add(lines, pad . '- ' . (type(item) == type([]) ? '[]' : '{}'))
        else
          let body = HooliesYamlFromVim(item, a:level + 1)
          let blines = split(body, "\n")
          if !empty(blines)
            let blines[0] = pad . '- ' . substitute(blines[0], '^\s*', '', '')
            let i = 1
            while i < len(blines)
              let blines[i] = '  ' . blines[i]
              let i += 1
            endwhile
            call add(lines, join(blines, "\n"))
          endif
        endif
      else
        call add(lines, pad . '- ' . HooliesYamlScalar(item))
      endif
    endfor
    return join(lines, "\n")
  endif
  return pad . HooliesYamlScalar(a:val)
endfunction

function! HooliesFmtYaml(src) abort
  let src = substitute(a:src, '^\_s*\|\_s*$', '', 'g')
  if src ==# ''
    return ''
  endif
  if src =~# '^[\[{]' && exists('*json_decode')
    return HooliesYamlFromVim(json_decode(src), 0) . "\n"
  endif
  let lines = []
  for line in split(a:src, "\n", 0)
    let line = substitute(line, '\s\+$', '', '')
    if line =~# '^\s*#' || line =~# '^\s*$'
      call add(lines, line)
      continue
    endif
    let line = substitute(line, '^\(\s*[[:alnum:]_.-]\+\)\s*:\s*', '\1: ', '')
    let line = substitute(line, '^\(\s*-\)\s\+', '\1 ', '')
    call add(lines, line)
  endfor
  return join(lines, "\n") . "\n"
endfunction

function! HooliesFmtToml(src) abort
  let lines = []
  for line in split(a:src, "\n", 0)
    let line = substitute(line, '\s\+$', '', '')
    if line =~# '^\s*['
      if !empty(lines) && lines[-1] !~# '^\s*$'
        call add(lines, '')
      endif
      call add(lines, substitute(line, '\s\+', '', 'g'))
      continue
    endif
    if line =~# '^\s*#' || line =~# '^\s*$'
      call add(lines, line)
      continue
    endif
    let line = substitute(line, '^\s*\([^=[:space:]]\+\)\s*=\s*', '\1 = ', '')
    let line = substitute(line, ',\(\S\)', ', \1', 'g')
    call add(lines, line)
  endfor
  return join(lines, "\n") . "\n"
endfunction

function! HooliesFmtCss(src) abort
  let out = []
  let buf = ''
  let i = 0
  let n = strlen(a:src)
  let indent = 0
  while i < n
    let c = strpart(a:src, i, 1)
    if c ==# '/' && i + 1 < n && strpart(a:src, i + 1, 1) ==# '*'
      let j = stridx(a:src, '*/', i + 2)
      let j = j < 0 ? n : j + 2
      let tok = substitute(buf, '^\s\+\|\s\+$', '', 'g')
      let buf = ''
      if tok !=# ''
        call add(out, repeat('    ', indent) . HooliesCssDecl(tok))
      endif
      for cl in split(strpart(a:src, i, j - i), "\n")
        call add(out, repeat('    ', indent) . substitute(cl, '^\s\+\|\s\+$', '', 'g'))
      endfor
      let i = j
      continue
    endif
    if c ==# '"' || c ==# "'"
      let q = c
      let buf .= c
      let i += 1
      while i < n
        let ch = strpart(a:src, i, 1)
        let buf .= ch
        if ch ==# '\' && i + 1 < n
          let buf .= strpart(a:src, i + 1, 1)
          let i += 2
          continue
        endif
        if ch ==# q
          let i += 1
          break
        endif
        let i += 1
      endwhile
      continue
    endif
    if c ==# '{'
      let tok = substitute(buf, '^\s\+\|\s\+$', '', 'g')
      let buf = ''
      call add(out, repeat('    ', indent) . (tok ==# '' ? '{' : tok . ' {'))
      let indent += 1
      let i += 1
      continue
    endif
    if c ==# '}'
      let tok = substitute(buf, '^\s\+\|\s\+$', '', 'g')
      let buf = ''
      if tok !=# ''
        call add(out, repeat('    ', indent) . HooliesCssDecl(tok))
      endif
      let indent = indent < 1 ? 0 : indent - 1
      call add(out, repeat('    ', indent) . '}')
      let i += 1
      continue
    endif
    if c ==# ';'
      let tok = substitute(buf, '^\s\+\|\s\+$', '', 'g')
      let buf = ''
      call add(out, repeat('    ', indent) . HooliesCssDecl(tok))
      let i += 1
      continue
    endif
    let buf .= c
    let i += 1
  endwhile
  let tok = substitute(buf, '^\s\+\|\s\+$', '', 'g')
  if tok !=# ''
    call add(out, repeat('    ', indent) . (stridx(tok, ':') >= 0 ? HooliesCssDecl(tok) : tok))
  endif
  return substitute(join(out, "\n"), '\n\{3,}', '\n\n', 'g') . "\n"
endfunction

function! HooliesCssDecl(tok) abort
  let tok = substitute(a:tok, '^\s\+\|\s\+$', '', 'g')
  if tok ==# ''
    return ';'
  endif
  if tok =~# ':'
    let tok = substitute(tok, '\s*:\s*', ': ', '')
  endif
  if tok !~# ';$'
    let tok .= ';'
  endif
  return tok
endfunction

function! HooliesMarkupNextToken(src) abort
  let m = matchstr(a:src, '^<!--\_.\{-}-->')
  if m !=# ''
    return m
  endif
  let m = matchstr(a:src, '^<\(script\|style\|pre\|textarea\)\>[^>]*>\_.\{-}</\1>')
  if m !=# ''
    return m
  endif
  let m = matchstr(a:src, '^</\?[^>]\+>')
  if m !=# ''
    return m
  endif
  return matchstr(a:src, '^[^<]\+')
endfunction

function! HooliesFmtMarkup(src, html) abort
  let void = {
        \ 'area': 1, 'base': 1, 'br': 1, 'col': 1, 'embed': 1, 'hr': 1,
        \ 'img': 1, 'input': 1, 'link': 1, 'meta': 1, 'param': 1,
        \ 'source': 1, 'track': 1, 'wbr': 1,
        \ }
  let rest = a:src
  let indent = 0
  let out = []
  while rest !=# ''
    let tok = HooliesMarkupNextToken(rest)
    if tok ==# ''
      break
    endif
    let rest = strpart(rest, strlen(tok))
    let s = substitute(tok, '^\_s*\|\_s*$', '', 'g')
    if s ==# ''
      continue
    endif
    if s =~# '^<!--' || s =~? '^<\(script\|style\|pre\|textarea\)\>'
      call add(out, repeat('    ', indent) . s)
      continue
    endif
    if s =~# '^</'
      let indent = indent < 1 ? 0 : indent - 1
      call add(out, repeat('    ', indent) . s)
      continue
    endif
    if s =~# '^<'
      let nm = tolower(matchstr(s, '^</\=\zs\w\+'))
      call add(out, repeat('    ', indent) . s)
      if nm !=# '' && s !~# '/>$' && s !~# '^<!' && !(a:html && has_key(void, nm))
        let indent += 1
      endif
      continue
    endif
    for line in split(s, "\n")
      let line = substitute(line, '^\s\+\|\s\+$', '', 'g')
      if line !=# ''
        call add(out, repeat('    ', indent) . line)
      endif
    endfor
  endwhile
  return join(out, "\n") . "\n"
endfunction

function! HooliesFormatVim(kind) abort
  let src = join(getline(1, '$'), "\n")
  try
    if a:kind ==# 'json'
      let out = HooliesFmtJson(src)
    elseif a:kind ==# 'yaml'
      let out = HooliesFmtYaml(src)
    elseif a:kind ==# 'toml'
      let out = HooliesFmtToml(src)
    elseif a:kind ==# 'css'
      let out = HooliesFmtCss(src)
    elseif a:kind ==# 'html'
      let out = HooliesFmtMarkup(src, 1)
    elseif a:kind ==# 'xml'
      let out = HooliesFmtMarkup(src, 0)
    else
      throw 'unknown kind'
    endif
  catch
    echohl ErrorMsg
    echo 'Formatter failed: ' . v:exception
    echohl None
    return
  endtry
  call HooliesReplaceBuffer(out)
endfunction

function! HooliesFormatBuffer() abort
  let view = winsaveview()
  let ext = HooliesFormatExtCmd()
  let kind = HooliesFormatKind()
  if ext !=# ''
    call HooliesFormatBang(ext)
  elseif kind !=# ''
    call HooliesFormatVim(kind)
  else
    echohl WarningMsg
    echo 'No formatter for filetype: ' . (&filetype ==# '' ? '(none)' : &filetype)
    echohl None
  endif
  call winrestview(view)
endfunction

function! HooliesHasFormatter() abort
  return HooliesFormatExtCmd() !=# '' || HooliesFormatKind() !=# ''
endfunction

function! HooliesFileIsHuge() abort
  if line('$') > 20000
    return 1
  endif
  let path = expand('%:p')
  if path !=# '' && getfsize(path) > 1024 * 1024
    return 1
  endif
  return 0
endfunction

function! HooliesFormatWritePre() abort
  if !get(g:, 'hoolies_format_on_write', 1) | return | endif
  if &modifiable == 0 || &bin || HooliesFileIsHuge() || !HooliesHasFormatter() | return | endif
  call HooliesFormatBuffer()
endfunction

function! HooliesBufWritePre() abort
  if HooliesFileIsHuge()
    return
  endif
  if &modifiable && &filetype !~# '^\(markdown\|diff\|gitcommit\)$'
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

function! HooliesStatusFlags() abort
  let out = ''
  if exists('*reg_recording')
    let r = reg_recording()
    if r !=# ''
      let out .= ' @' . r
    endif
  endif
  if &paste
    let out .= ' PASTE'
  endif
  if &spell
    let out .= ' SPELL'
  endif
  if &readonly || !&modifiable
    let out .= ' RO'
  endif
  return out
endfunction

function! HooliesHugeFileMode() abort
  if &buftype !=# '' || &filetype ==# 'hoolies_dashboard'
    return
  endif
  if !HooliesFileIsHuge()
    return
  endif
  if get(b:, 'hoolies_huge', 0)
    return
  endif
  let b:hoolies_huge = 1
  setlocal norelativenumber nocursorcolumn nolist
  setlocal synmaxcol=120
  setlocal syntax=OFF
endfunction

function! HooliesSessionPath() abort
  return expand('~/.vim/session.vim')
endfunction

function! HooliesSessionSave() abort
  silent! call mkdir(expand('~/.vim'), 'p', 0700)
  execute 'mksession!' fnameescape(HooliesSessionPath())
  echo 'Session saved'
endfunction

function! HooliesSessionLoad() abort
  let p = HooliesSessionPath()
  if !filereadable(p)
    echo 'No session'
    return
  endif
  let g:hoolies_skip_dashboard = 1
  if &filetype ==# 'hoolies_dashboard'
    call HooliesDashboardClose()
  endif
  execute 'source' fnameescape(p)
endfunction

function! HooliesStartedWithSession() abort
  if get(g:, 'hoolies_skip_dashboard', 0)
    return 1
  endif
  if exists('v:argv')
    return index(v:argv, '-S') >= 0
  endif
  return 0
endfunction

function! HooliesBufEnter() abort
  call HooliesGitBranchRefresh()
  call HooliesHugeFileMode()
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

function! HooliesTablineLabel(b) abort
  let name = fnamemodify(bufname(a:b), ':t')
  if name ==# ''
    let name = '[No Name]'
  endif
  if getbufvar(a:b, '&modified')
    let name .= '+'
  endif
  if strdisplaywidth(name) > 18
    let name = strcharpart(name, 0, 16) . '…'
  endif
  return name
endfunction

function! HooliesTablineItem(b, name, click, current) abort
  let hl = a:current ? '%#TabLineSel#' : '%#TabLine#'
  if a:click
    return hl . '%' . a:b . '@HooliesTablineClick@ ' . a:name . ' %X'
  endif
  return hl . ' ' . a:name . ' '
endfunction

function! HooliesTabline() abort
  let click = has('tablineat')
  let listed = []
  for b in range(1, bufnr('$'))
    if buflisted(b)
      call add(listed, b)
    endif
  endfor
  if empty(listed)
    return '%#TabLineFill#'
  endif
  let cur = bufnr('%')
  let labels = []
  let widths = []
  for b in listed
    let name = HooliesTablineLabel(b)
    call add(labels, name)
    call add(widths, strdisplaywidth(name) + 2)
  endfor
  let total = 0
  for w in widths
    let total += w
  endfor
  let avail = max([&columns, 20])
  let show = range(len(listed))
  if total > avail
    let curi = index(listed, cur)
    if curi < 0
      let curi = 0
    endif
    let lo = curi
    let hi = curi
    let used = widths[curi]
    while lo > 0 || hi < len(listed) - 1
      let grew = 0
      if hi < len(listed) - 1 && used + widths[hi + 1] + 6 <= avail
        let hi += 1
        let used += widths[hi]
        let grew = 1
      endif
      if lo > 0 && used + widths[lo - 1] + 6 <= avail
        let lo -= 1
        let used += widths[lo]
        let grew = 1
      endif
      if !grew
        break
      endif
    endwhile
    let show = range(lo, hi)
  endif
  let s = ''
  if show[0] > 0
    let s .= '%#TabLine# <' . show[0] . ' '
  endif
  for i in show
    let s .= HooliesTablineItem(listed[i], labels[i], click, listed[i] == cur)
  endfor
  if show[-1] < len(listed) - 1
    let s .= '%#TabLine# ' . (len(listed) - 1 - show[-1]) . '> '
  endif
  let s .= '%#TabLineFill#'
  return s
endfunction

function! HooliesTablineClick(minwid, nclicks, button, mods) abort
  if a:minwid > 0 && bufexists(a:minwid)
    execute 'buffer' a:minwid
  endif
endfunction

function! HooliesSearchCount() abort
  if !v:hlsearch || !exists('*searchcount') || @/ ==# ''
    return ''
  endif
  try
    let info = searchcount({'recompute': 1, 'maxcount': 99, 'timeout': 50})
  catch
    return ''
  endtry
  if empty(info) || get(info, 'total', 0) == 0 || get(info, 'incomplete', 0) == 1
    return ''
  endif
  let tot = info.total
  if get(info, 'incomplete', 0) == 2
    return printf('[%d/%d+] ', info.current, tot)
  endif
  return printf('[%d/%d] ', info.current, tot)
endfunction

function! HooliesStatusLine() abort
  return '%<%f %h%w%m%{HooliesStatusFlags()}%{HooliesStatusGit()}%=%y %{&ff} %{strlen(&fenc)?&fenc:&enc} %{HooliesSearchCount()}%l,%c/%L %P'
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
  if HooliesStartedWithSession()
    return
  endif
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
  call HooliesProjectFiles()
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

function! HooliesProjectFiles() abort
  let root = HooliesGitRoot()
  let files = []
  if root !=# '' && executable('git')
    let files = systemlist('git -C ' . shellescape(root) . ' ls-files -co --exclude-standard')
    if v:shell_error
      let files = []
    else
      call map(files, {_, p -> root . '/' . p})
    endif
  endif
  if empty(files) && executable('rg')
    let dir = root !=# '' ? root : getcwd()
    let files = systemlist('rg --files --sort path -- ' . shellescape(dir))
  endif
  if empty(files)
    let dir = root !=# '' ? root : getcwd()
    let files = glob(dir . '/**/*', 0, 1)
    call filter(files, {_, p -> filereadable(p) && !isdirectory(p)})
  endif
  call filter(files, {_, p -> p !=# '' && filereadable(p)})
  call HooliesPickPaths('Files', files)
endfunction

function! HooliesBufferDeleteClose() abort
  let close_win = winnr('$') > 1
  bdelete
  if close_win && winnr('$') > 1
    close
  endif
endfunction

function! HooliesRestoreCursor() abort
  let name = expand('%:t')
  if name =~# '^\(COMMIT_EDITMSG\|MERGE_MSG\|REBASE_EDITMSG\|git-rebase-todo\)$'
    return
  endif
  if &filetype =~# '^\(gitcommit\|gitrebase\|xxd\)$'
    return
  endif
  if line("'\"") >= 1 && line("'\"") <= line('$')
    execute 'normal! g`"'
  endif
endfunction

function! HooliesCommentString() abort
  let cs = &commentstring
  if cs ==# '' || stridx(cs, '%s') < 0
    let by_ft = {
          \ 'vim': '" %s',
          \ 'python': '# %s',
          \ 'sh': '# %s',
          \ 'bash': '# %s',
          \ 'zsh': '# %s',
          \ 'lua': '-- %s',
          \ 'javascript': '// %s',
          \ 'javascriptreact': '// %s',
          \ 'typescript': '// %s',
          \ 'typescriptreact': '// %s',
          \ 'c': '// %s',
          \ 'cpp': '// %s',
          \ 'go': '// %s',
          \ 'rust': '// %s',
          \ }
    let cs = get(by_ft, &filetype, '# %s')
  endif
  return cs
endfunction

function! HooliesCommentParts() abort
  let cs = HooliesCommentString()
  let idx = stridx(cs, '%s')
  return [strpart(cs, 0, idx), strpart(cs, idx + 2)]
endfunction

function! HooliesCommentIsOn(line, left, right) abort
  let indent = matchstr(a:line, '^\s*')
  let rest = a:line[strlen(indent):]
  if stridx(rest, a:left) != 0
    return 0
  endif
  if a:right ==# ''
    return 1
  endif
  return rest =~# '\V' . escape(a:right, '\') . '\s\*\$'
endfunction

function! HooliesCommentApply(line, left, right) abort
  let indent = matchstr(a:line, '^\s*')
  return indent . a:left . a:line[strlen(indent):] . a:right
endfunction

function! HooliesCommentStrip(line, left, right) abort
  let indent = matchstr(a:line, '^\s*')
  let rest = a:line[strlen(indent):]
  if stridx(rest, a:left) == 0
    let rest = strpart(rest, strlen(a:left))
  endif
  if a:right !=# ''
    let rest = substitute(rest, '\V' . escape(a:right, '\') . '\s\*\$', '', '')
  endif
  return indent . rest
endfunction

function! HooliesCommentToggleLines(l1, l2) abort
  let [left, right] = HooliesCommentParts()
  let uncomment = 0
  for lnum in range(a:l1, a:l2)
    let line = getline(lnum)
    if line =~# '^\s*$'
      continue
    endif
    let uncomment = HooliesCommentIsOn(line, left, right)
    break
  endfor
  for lnum in range(a:l1, a:l2)
    let line = getline(lnum)
    if line =~# '^\s*$'
      continue
    endif
    if uncomment
      call setline(lnum, HooliesCommentStrip(line, left, right))
    else
      call setline(lnum, HooliesCommentApply(line, left, right))
    endif
  endfor
endfunction

function! HooliesCommentOp(type) abort
  call HooliesCommentToggleLines(line("'["), line("']"))
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

let s:pair_close = {'(': ')', '[': ']', '{': '}', '"': '"', "'": "'", '`': '`'}

function! HooliesPairNext() abort
  return strpart(getline('.'), col('.') - 1, 1)
endfunction

function! HooliesPairPrev() abort
  let c = col('.') - 2
  if c < 0
    return ''
  endif
  return strpart(getline('.'), c, 1)
endfunction

function! HooliesPairInString() abort
  let c = col('.')
  if c <= 1
    return 0
  endif
  let name = synIDattr(synIDtrans(synID(line('.'), c - 1, 1)), 'name')
  return name =~? 'string\|character\|quote'
endfunction

function! HooliesPairShouldOpen(open) abort
  if &paste || !&modifiable || &readonly || &buftype !=# ''
    return 0
  endif
  if (a:open ==# '"' || a:open ==# "'" || a:open ==# '`') && HooliesPairInString()
    return 0
  endif
  if a:open ==# "'" && &filetype =~# '^\(rust\|lisp\|scheme\|clojure\)$'
    return 0
  endif
  if a:open ==# '"' && &filetype =~# '^\(vim\|help\|gitcommit\)$'
    return 0
  endif
  let nxt = HooliesPairNext()
  if nxt !=# '' && nxt !~# '[[:space:])\]}>,;:]'
    return 0
  endif
  let prev = HooliesPairPrev()
  if a:open ==# "'" && prev =~# '\k\|[''"/\\]'
    return 0
  endif
  if (a:open ==# '"' || a:open ==# "'" || a:open ==# '`') && prev ==# a:open
    return 0
  endif
  if a:open ==# '"' && prev =~# '\k'
    return 0
  endif
  return 1
endfunction

function! HooliesPairOpen(open) abort
  if !HooliesPairShouldOpen(a:open)
    return a:open
  endif
  return a:open . s:pair_close[a:open] . "\<Left>"
endfunction

function! HooliesPairClose(close) abort
  if &paste
    return a:close
  endif
  if HooliesPairNext() ==# a:close
    return "\<Right>"
  endif
  return a:close
endfunction

function! HooliesPairQuote(q) abort
  if &paste
    return a:q
  endif
  if HooliesPairNext() ==# a:q
    return "\<Right>"
  endif
  if HooliesPairShouldOpen(a:q)
    return a:q . a:q . "\<Left>"
  endif
  return a:q
endfunction

function! HooliesPairBS() abort
  let prev = HooliesPairPrev()
  let nxt = HooliesPairNext()
  if prev !=# '' && has_key(s:pair_close, prev) && s:pair_close[prev] ==# nxt
    return "\<BS>\<Del>"
  endif
  return "\<BS>"
endfunction

function! HooliesPairLeftOrBS() abort
  let prev = HooliesPairPrev()
  let nxt = HooliesPairNext()
  if prev !=# '' && has_key(s:pair_close, prev) && s:pair_close[prev] ==# nxt
    return "\<BS>\<Del>"
  endif
  return "\<Left>"
endfunction

function! HooliesCR() abort
  if pumvisible()
    return "\<C-y>"
  endif
  let prev = HooliesPairPrev()
  let nxt = HooliesPairNext()
  if prev !=# '' && has_key(s:pair_close, prev) && s:pair_close[prev] ==# nxt
    return "\<CR>\<Esc>O"
  endif
  return "\<CR>"
endfunction

function! HooliesInCommentOrString() abort
  let c = max([1, col('.') - 1])
  let name = synIDattr(synIDtrans(synID(line('.'), c, 1)), 'name')
  return name =~? 'comment\|string\|character\|quote'
endfunction

function! HooliesAutoComplete() abort
  if pumvisible() || mode() !=# 'i'
    return
  endif
  if !&modifiable || &readonly || &buftype !=# ''
    return
  endif
  if get(b:, 'hoolies_huge', 0) || HooliesFileIsHuge()
    return
  endif
  if HooliesInCommentOrString()
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
        \ 'Files',
        \ '  <Space>e      toggle file explorer',
        \ '  <Space>ff     project files (type to filter)',
        \ '  <Space>fo     recent files (type to filter)',
        \ '  <Space>flg    git-tracked files (type to filter)',
        \ '  <Space>sn     nvim/vim config files (type to filter)',
        \ '',
        \ 'Buffers',
        \ '  <Space>fb     pick buffer (type to filter)',
        \ '  <Space>bb     new empty buffer',
        \ '  <Space>bd     delete buffer',
        \ '  <Space>bD     delete buffer (close window if split)',
        \ '  <Space>bw     wipe buffer',
        \ '  S-h / S-l     previous / next buffer',
        \ '  click tab     switch to that buffer',
        \ '  Alt-Esc       close other file buffers',
        \ '',
        \ 'Search',
        \ '  <Space>flf    project grep (literal; C-r regex)',
        \ '  <Space>fs     grep word under cursor',
        \ '  <Space>ft     filter lines in this buffer',
        \ '  <Space>s/     grep open buffers',
        \ '  <Space>/      substitute word (or visual sel)',
        \ '  <Space>fh     help (type to filter)',
        \ '  <Space>qs     save session',
        \ '  <Space>ql     load session',
        \ '  ]q / [q       next / previous quickfix',
        \ '  ]Q / [Q       last / first quickfix',
        \ '',
        \ 'Edit',
        \ '  gcc / gc      toggle comment (line / motion or visual)',
        \ '  <Space>F      format (html/css/xml/json/yaml/toml/…)',
        \ '  <Space>u      undo tree',
        \ '  <Space>CR     toggle terminal',
        \ '  <Space>?      this map list',
        \ '  Alt-j / Alt-k move line (or selection)',
        \ '  Tab / S-Tab   next / previous match (auto after 2 letters)',
        \ '  C-Space       omni-complete',
        \ '  ( [ { " '' `  auto-close; type closer to skip over',
        \ '  BS            delete empty pair',
        \ '',
        \ 'Windows',
        \ '  C-h/j/k/l     move (tmux-aware)',
        \ '  C-arrows      resize splits',
        \ '',
        \ 'Other',
        \ '  :             command (Tab completion popup)',
        \ '  : C-p/C-n     previous / next suggestion',
        \ '  : Tab/S-Tab   complete command names and args',
        \ '  <Space>:      classic command line',
        \ '  q:            classic command-line window',
        \ '  (no args)     welcome dashboard',
        \ '  / n N        search ([2/5] on the statusline)',
        \ '  Esc Esc       hide terminal (job keeps running)',
        \ '  jj            leave insert mode',
        \ '  x / dd        delete without yanking',
        \ '  Y             yank to end of line (visual: clipboard)',
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
    if hist_n >= 12
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
      if cmd_n >= 12
        break
      endif
    endfor
  endif
  return items
endfunction

function! HooliesCmdPalettePrompt() abort
  let s = ': ' . s:cmd_pal_input . '▌'
  let w = s:cmd_pal_width
  if strchars(s) > w
    let s = '…' . strcharpart(s, strchars(s) - w + 1)
  endif
  return s
endfunction

function! HooliesCmdPaletteCloseMenu() abort
  if s:cmd_pal_menu >= 0
    call popup_close(s:cmd_pal_menu)
    let s:cmd_pal_menu = -1
  endif
endfunction

function! HooliesCmdPaletteClosed(id, result) abort
  let s:cmd_pal_id = -1
  call HooliesCmdPaletteCloseMenu()
endfunction

function! HooliesCmdPaletteMenuRefresh() abort
  let s:cmd_pal_items = HooliesCmdPaletteItems()
  let lines = []
  for it in s:cmd_pal_items
    call add(lines, it.t)
  endfor
  if empty(lines) || s:cmd_pal_id < 0
    call HooliesCmdPaletteCloseMenu()
    return
  endif
  let pos = popup_getpos(s:cmd_pal_id)
  if empty(pos)
    call HooliesCmdPaletteCloseMenu()
    return
  endif
  let below = pos.line + pos.height
  let room = &lines - below
  let maxh = min([12, len(lines), max([1, room - 1])])
  let opts = {
        \ 'col': pos.col,
        \ 'minwidth': s:cmd_pal_width,
        \ 'maxwidth': s:cmd_pal_width,
        \ 'minheight': 1,
        \ 'maxheight': maxh,
        \ 'wrap': 0,
        \ 'scrollbar': 1,
        \ 'highlight': 'Pmenu',
        \ 'padding': [0, 1, 0, 1],
        \ 'border': [],
        \ 'borderhighlight': ['Pmenu'],
        \ 'mapping': 0,
        \ 'firstline': 0,
        \ 'zindex': 310,
        \ }
  if room >= 3
    let opts.line = below
    let opts.pos = 'topleft'
  else
    let opts.line = pos.line
    let opts.pos = 'botleft'
    let opts.maxheight = min([12, len(lines), max([1, pos.line - 2])])
  endif
  if s:cmd_pal_idx >= len(s:cmd_pal_items)
    let s:cmd_pal_idx = len(s:cmd_pal_items) - 1
  endif
  let opts.cursorline = s:cmd_pal_idx >= 0
  if s:cmd_pal_menu >= 0 && empty(popup_getpos(s:cmd_pal_menu))
    let s:cmd_pal_menu = -1
  endif
  if s:cmd_pal_menu >= 0
    call popup_settext(s:cmd_pal_menu, lines)
    call popup_setoptions(s:cmd_pal_menu, opts)
  else
    try
      let s:cmd_pal_menu = popup_create(lines, opts)
    catch
      let s:cmd_pal_menu = -1
      return
    endtry
  endif
  if s:cmd_pal_idx >= 0 && exists('*win_execute')
    call win_execute(s:cmd_pal_menu, 'call cursor(' . (s:cmd_pal_idx + 1) . ', 1)')
  endif
endfunction

function! HooliesCmdPaletteRefresh() abort
  if s:cmd_pal_id < 0 || !exists('*popup_settext')
    return
  endif
  call popup_settext(s:cmd_pal_id, [HooliesCmdPalettePrompt()])
  call HooliesCmdPaletteMenuRefresh()
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
  let i = 0
  for it in HooliesCmdPaletteItems()
    if it.t ==# s:cmd_pal_input
      let s:cmd_pal_idx = i
      break
    endif
    let i += 1
  endfor
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
  call HooliesCmdPaletteCloseMenu()
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
    call HooliesCmdPaletteCloseMenu()
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
  let s:cmd_pal_menu = -1
  call HooliesCmdPaletteResetComp()
  let s:cmd_pal_width = min([72, &columns - 6])
  try
    let s:cmd_pal_id = popup_create([HooliesCmdPalettePrompt()], {
          \ 'title': ' Command ',
          \ 'pos': 'center',
          \ 'minwidth': s:cmd_pal_width,
          \ 'maxwidth': s:cmd_pal_width,
          \ 'minheight': 1,
          \ 'maxheight': 1,
          \ 'border': [],
          \ 'padding': [0, 1, 0, 1],
          \ 'highlight': 'Pmenu',
          \ 'borderhighlight': ['Function'],
          \ 'filter': 'HooliesCmdPaletteFilter',
          \ 'callback': 'HooliesCmdPaletteClosed',
          \ 'mapping': 0,
          \ 'wrap': 0,
          \ 'zindex': 320,
          \ })
    call HooliesCmdPaletteMenuRefresh()
  catch
    let s:cmd_pal_id = -1
    call HooliesCmdPaletteCloseMenu()
    call feedkeys(':', 'n')
  endtry
endfunction

function! HooliesMapsSearchBegin() abort
  let s:maps_search_start = line('.')
  call clearmatches()
endfunction

function! HooliesMapsSearchClear() abort
  call clearmatches()
  call cursor(s:maps_search_start, 1)
endfunction

function! HooliesMapsSearchGo(dir) abort
  call clearmatches()
  if s:maps_query ==# ''
    call cursor(s:maps_search_start, 1)
    return
  endif
  let pat = '\c\V' . escape(s:maps_query, '\')
  silent! call matchadd('Search', pat)
  if a:dir == 0
    call cursor(s:maps_search_start, 1)
    if search(pat, 'cW') == 0
      call search(pat, 'cw')
    endif
  elseif a:dir > 0
    if search(pat, 'W') == 0
      call search(pat, 'w')
    endif
  else
    if search(pat, 'bW') == 0
      call search(pat, 'bw')
    endif
  endif
endfunction

function! HooliesMapsPopupClosed(id, result) abort
  let s:maps_query = ''
  let s:maps_searching = 0
endfunction

function! HooliesMapsPopupFilter(id, key) abort
  " Leftover '?' from <leader>? must not start a search or close.
  if !s:maps_searching && a:key ==# '?'
    return 1
  endif
  if s:maps_searching
    if a:key ==# "\<Esc>"
      let s:maps_searching = 0
      let s:maps_query = ''
      if exists('*win_execute')
        call win_execute(a:id, 'call HooliesMapsSearchClear()')
      endif
      return 1
    endif
    if a:key ==# "\<CR>"
      let s:maps_searching = 0
      return 1
    endif
    if a:key ==# "\<BS>" || a:key ==# "\b" || a:key ==# "\<C-h>"
      if s:maps_query !=# ''
        let s:maps_query = strcharpart(s:maps_query, 0, strchars(s:maps_query) - 1)
      endif
      if exists('*win_execute')
        call win_execute(a:id, 'call HooliesMapsSearchGo(0)')
      endif
      return 1
    endif
    if a:key ==# "\<C-u>"
      let s:maps_query = ''
      if exists('*win_execute')
        call win_execute(a:id, 'call HooliesMapsSearchGo(0)')
      endif
      return 1
    endif
    if strchars(a:key) == 1 && char2nr(a:key) >= 32
      let s:maps_query .= a:key
      if exists('*win_execute')
        call win_execute(a:id, 'call HooliesMapsSearchGo(0)')
      endif
    endif
    return 1
  endif
  if a:key ==# 'q' || a:key ==# "\<Esc>"
    call popup_close(a:id)
    return 1
  endif
  if !exists('*win_execute')
    return 1
  endif
  if a:key ==# '/'
    let s:maps_searching = 1
    let s:maps_query = ''
    call win_execute(a:id, 'call HooliesMapsSearchBegin()')
  elseif a:key ==# 'n' && s:maps_query !=# ''
    call win_execute(a:id, 'call HooliesMapsSearchGo(1)')
  elseif a:key ==# 'N' && s:maps_query !=# ''
    call win_execute(a:id, 'call HooliesMapsSearchGo(-1)')
  elseif a:key ==# 'g'
    call win_execute(a:id, 'normal! gg')
  elseif a:key ==# 'G'
    call win_execute(a:id, 'normal! G')
  elseif exists('*popup_filter_menu') && (a:key ==# 'j' || a:key ==# 'k')
    return popup_filter_menu(a:id, a:key)
  endif
  return 1
endfunction

function! HooliesMapsBindClose() abort
  nnoremap <buffer> <silent> q :close<CR>
  nnoremap <buffer> <silent> <Esc> :close<CR>
endfunction

function! HooliesShowMaps() abort
  let lines = HooliesMapsLines()
  let s:maps_query = ''
  let s:maps_searching = 0
  if exists('*popup_create')
    try
      let maxh = min([28, &lines - 6])
      let id = popup_create(lines, {
            \ 'title': ' Maps ',
            \ 'pos': 'center',
            \ 'padding': [1, 2, 1, 2],
            \ 'border': [],
            \ 'highlight': 'Pmenu',
            \ 'borderhighlight': ['Function'],
            \ 'filter': 'HooliesMapsPopupFilter',
            \ 'callback': 'HooliesMapsPopupClosed',
            \ 'mapping': 0,
            \ 'wrap': 0,
            \ 'cursorline': 1,
            \ 'firstline': 0,
            \ 'zindex': 300,
            \ 'minwidth': 48,
            \ 'maxheight': maxh,
            \ 'scrollbar': 1,
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
    hi! link PopupSelected PmenuSel
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
    hi! link PopupSelected PmenuSel
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
set noshowmatch
set splitright
set splitbelow
set diffopt+=vertical
silent! set diffopt+=algorithm:patience
silent! set diffopt+=linematch:60
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
set viminfo='1000,<200,s100,h,:1000,/1000

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
if exists('+splitkeep')
  set splitkeep=screen
endif
if exists('+jumpoptions')
  set jumpoptions+=stack
endif
set list
let &listchars = 'tab:» ,trail:·,extends:»,precedes:«,nbsp:␣'

set undodir=~/.vim/undodir
set undofile
set undolevels=10000
set synmaxcol=300
set sessionoptions=blank,buffers,curdir,folds,help,tabpages,winsize
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
set spelllang=en_us
if has('termguicolors')
  if !has('gui_running')
    let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
    let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  endif
  set termguicolors
endif
set visualbell
set completeopt=menuone,noselect
set complete=.,w,b,u,t
set infercase
set shortmess+=c
set shortmess-=S

set pumheight=12

" Built-in file explorer (no plugins). Lexplore is a left split; Enter opens the file.
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_browse_split = 4
let g:netrw_altv = 1
let g:netrw_winsize = 25
let g:netrw_keepdir = 1

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
set wildignore+=*/.git/*,*/.hg/*,*/.svn/*
set wildignore+=*/node_modules/*,*/target/*,*/dist/*,*/build/*,*/.build/*
set wildignore+=*/__pycache__/*,*/.mypy_cache/*,*/.venv/*,*/venv/*,*/.tox/*
set wildignore+=*.o,*.obj,*.pyc,*.pyo,*.so,*.class,*.swp,*.swo,*~

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
inoremap <silent> <expr> <C-h> HooliesPairLeftOrBS()
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
nnoremap <silent> <leader>bD :call HooliesBufferDeleteClose()<CR>
nnoremap <silent> <leader>bw :bwipeout<CR>
nnoremap <silent> <leader>bb :enew<CR>
nnoremap <silent> <A-ESC> :call HooliesCloseOtherBuffers()<CR>

tnoremap <silent> <C-h> <C-\><C-n><C-w>h
tnoremap <silent> <C-j> <C-\><C-n><C-w>j
tnoremap <silent> <C-k> <C-\><C-n><C-w>k
tnoremap <silent> <C-l> <C-\><C-n><C-w>l

nnoremap <silent> <leader>u :call HooliesUndotreeToggle()<CR>

nnoremap <silent> <expr> <Esc> HooliesEscExpr()

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
inoremap <silent> <expr> <CR> HooliesCR()
inoremap <silent> <expr> <BS> HooliesPairBS()
inoremap <silent> <expr> ( HooliesPairOpen('(')
inoremap <silent> <expr> [ HooliesPairOpen('[')
inoremap <silent> <expr> { HooliesPairOpen('{')
inoremap <silent> <expr> ) HooliesPairClose(')')
inoremap <silent> <expr> ] HooliesPairClose(']')
inoremap <silent> <expr> } HooliesPairClose('}')
inoremap <silent> <expr> " HooliesPairQuote('"')
inoremap <silent> <expr> ' HooliesPairQuote("'")
inoremap <silent> <expr> ` HooliesPairQuote('`')
inoremap <silent> <C-Space> <C-x><C-o>
if !has('gui_running')
  imap <C-@> <C-Space>
endif

nnoremap <leader>/ :%s/\<<C-r><C-w>\>//g<Left><Left>
xnoremap <leader>/ y:%s/\V<C-r>=escape(@",'/\')<CR>//g<Left><Left>

nnoremap x "_x
xnoremap x "_x
nnoremap dd "_dd

nnoremap Y y$
" Visual Y yanks the selection (not whole lines). "+Y then writes to the clipboard.
xnoremap Y "+y

nnoremap <silent> gcc :set opfunc=HooliesCommentOp<CR>g@_
nnoremap <silent> gc :set opfunc=HooliesCommentOp<CR>g@
xnoremap <silent> gc :<C-u>call HooliesCommentToggleLines(line("'<"), line("'>"))<CR>

nnoremap <silent> ]q :cnext<CR>
nnoremap <silent> [q :cprevious<CR>
nnoremap <silent> ]Q :clast<CR>
nnoremap <silent> [Q :cfirst<CR>

xnoremap <silent> < <gv
xnoremap <silent> > >gv

nnoremap <silent> <C-h> :call HooliesTmuxNavigate('h')<CR>
nnoremap <silent> <C-j> :call HooliesTmuxNavigate('j')<CR>
nnoremap <silent> <C-k> :call HooliesTmuxNavigate('k')<CR>
nnoremap <silent> <C-l> :call HooliesTmuxNavigate('l')<CR>

nnoremap <silent> <leader>fb :call HooliesBufferPicker()<CR>
nnoremap <silent> <leader>ff :call HooliesProjectFiles()<CR>
nnoremap <silent> <leader>flf :call HooliesGrepInteractive()<CR>
nnoremap <silent> <leader>flg :call HooliesGitFiles()<CR>
nnoremap <silent> <leader>fh :call HooliesHelpPick()<CR>
nnoremap <silent> <leader>qs :call HooliesSessionSave()<CR>
nnoremap <silent> <leader>ql :call HooliesSessionLoad()<CR> 
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
  autocmd FileType markdown,gitcommit,text,typst,rst setlocal spell spelllang=en_us
  autocmd FileType * call HooliesSetOmnifunc()
  autocmd FileType netrw setlocal nonumber norelativenumber nolist
  autocmd FileType vim call HooliesVimFuncLinkFix()
  autocmd ColorScheme * call HooliesVimFuncLinkFix()
  autocmd VimEnter * call HooliesVimEnterNoArgs()
  if exists('##TextYankPost')
    autocmd TextYankPost * call HooliesFlashYank()
  endif
  autocmd BufWritePre * call HooliesBufWritePre()
  autocmd TextChangedI * call HooliesAutoCompleteSchedule()
  autocmd BufReadPost * call HooliesRestoreCursor()
  autocmd BufReadPost * call HooliesHugeFileMode()
  if exists('##TerminalOpen')
    autocmd TerminalOpen * call HooliesTermSetup()
  endif
  autocmd VimEnter * call HooliesAlacrittyOpacity(1)
  autocmd VimLeave * call HooliesAlacrittyOpacity(0.67)
  autocmd BufEnter * call HooliesBufEnter()
  autocmd FocusGained * call HooliesGitBranchRefresh(1)
  autocmd FocusGained,BufEnter * if mode() !=# 'c' | checktime | endif
augroup END
