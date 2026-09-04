# .config

Dotfiles I share as this folder.


## Install

Clone this repository to `/opt/.config`, then run `bootstrap.sh`. It creates one symlink per file into `$HOME`. Existing files and symlinks are overwritten. `xfce4/` is machine-local and is not linked.

```sh
git clone https://github.com/hoolies/.config /opt/
/opt/.config/bootstrap.sh
```

| Source | Destination |
| --- | --- |
| `/opt/.config/.vimrc` | `~/.vimrc` |
| `/opt/.config/shell/.zshrc` | `~/.zshrc` |
| everything else | `~/.config/<same path>` |

Skipped: `.git/`, `xfce4/`, `.gitignore`, `README.md`, and `bootstrap.sh`.

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

`.vimrc` is the portable, plugin-free editor config in a single file.

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
* `/` `n` `N` — search; statusline shows `[2/5]`

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

* `:` — command (centered; Tab completion popup)
* `: C-p/C-n` — previous / next suggestion
* `: Tab/S-Tab` — complete command names and args
* `<Space>:` — classic command line
* `q:` — classic command-line window
* (no args) — welcome dashboard
* `Esc` — clear search highlight
* `Esc Esc` — hide terminal (job keeps running)
* `jj` — leave insert mode
* `x` / `dd` — delete without yanking
* `Y` — yank to end of line (visual: clipboard)
