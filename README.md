# .config

Dotfiles I share as this folder.

Neovim is **not** in here on purpose. `nvim/` is gitignored. That config is LazyVim, plugin-heavy, and local to machines that have it. I do not want to publish or sync it with these files.

## Configurations

* Alacritty
* clipse
* conky
* espanso
* functions
* fuzzel
* glow
* helix
* shell (zsh)
* tmux
* Vim (`.vimrc`)
* xfce4
* yazi
* Backgrounds

## Vim

`.vimrc` is the portable, plugin-free editor config. Single file: all logic and colors live here (no `autoload/` or `colors/`). `~/.vimrc` is a symlink to this file.

Leader is Space. Same habits as the local Neovim setup (leader, clipboard, colors, navigation) without plugins.

`<Space>?` opens the map list. In the popup:

* `j` / `k` — line
* `/` — search (`n` / `N` next / previous)
* `g` / `G` — top / bottom
* `q` / `Esc` — close

### Maps

**Files**

* `<Space>e` — toggle file explorer
* `<Space>ff` — project files (type to filter)
* `<Space>fo` — recent files (type to filter)
* `<Space>flg` — git-tracked files (type to filter)
* `<Space>sn` — nvim/vim config files (type to filter)

**Buffers**

* `<Space>fb` — pick buffer (type to filter)
* `<Space>bb` — new empty buffer
* `<Space>bd` — delete buffer
* `<Space>bD` — delete buffer (close window if split)
* `<Space>bw` — wipe buffer
* `S-h` / `S-l` — previous / next buffer
* click tab — switch to that buffer
* `Alt-Esc` — close other file buffers

**Search**

* `<Space>flf` — project grep (literal; `C-r` regex)
* `<Space>fs` — grep word under cursor
* `<Space>ft` — filter lines in this buffer
* `<Space>s/` — grep open buffers
* `<Space>/` — substitute word (or visual sel)
* `<Space>fh` — help (type to filter)
* `<Space>qs` — save session
* `<Space>ql` — load session
* `]q` / `[q` — next / previous quickfix
* `]Q` / `[Q` — last / first quickfix

**Edit**

* `gcc` / `gc` — toggle comment (line / motion or visual)
* `<Space>F` — format (html/css/xml/json/yaml/toml/…)
* `<Space>u` — undo tree
* `<Space>CR` — toggle terminal
* `<Space>?` — this map list
* `Alt-j` / `Alt-k` — move line (or selection)
* `Tab` / `S-Tab` — next / previous match (auto after 2 letters)
* `C-Space` — omni-complete
* `( [ { " '` and `` ` `` — auto-close; type closer to skip over
* `BS` — delete empty pair

**Windows**

* `C-h/j/k/l` — move (tmux-aware)
* `C-arrows` — resize splits

**Other**

* `:` — command palette (history + commands)
* `: C-p/C-n` — previous / next match in the list
* `: Tab/S-Tab` — complete command names and args
* `<Space>:` — classic command line
* `q:` — classic command-line window
* (no args) — welcome dashboard
* `Esc` — clear search highlight
* `Esc Esc` — hide terminal (job keeps running)
* `jj` — leave insert mode
* `x` / `dd` — delete without yanking
* `Y` — yank to end of line (visual: clipboard)
