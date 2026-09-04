# .config

Shared Linux dotfiles: terminal, shell, editors, and a few desktop tools.

## Install

Clone this repository, then run `bootstrap.sh`. It creates one symlink per file. Missing directories are created. Existing files and symlinks are overwritten.

```sh
git clone https://github.com/hoolies/.config /opt/
/opt/.config/bootstrap.sh
```

| This file | Becomes |
| --- | --- |
| `.vimrc` | `~/.vimrc` |
| `shell/.zshrc` | `~/.zshrc` |
| `alacritty/` | `~/.config/alacritty/` |
| `conky/conky.config` | `~/.config/conky/conky.config` |
| `espanso/` | `~/.config/espanso/` |
| `helix/` | `~/.config/helix/` |
| `tmux/tmux.conf` | `~/.config/tmux/tmux.conf` |
| `yazi/` | `~/.config/yazi/` |

`xfce4/` is machine-specific and is not linked. clipse, fuzzel, glow, and `functions/` are in the repo but bootstrap does not install them.

## Features

### Alacritty

Fullscreen terminal, no window decorations, Tokyo Night Moon colors, Hack Nerd Font at size 14, translucent background.

- Ctrl+Shift+Enter — new window
- Ctrl+mouse wheel — font size
- Ctrl+Shift+mouse wheel or Ctrl+Shift+Plus/Minus — opacity
- Ctrl+Shift+0 — reset opacity
- Ctrl+click a URL — open it
- Ctrl+click a `file:line:column` path — open it in Neovim
- Selecting text copies it to the clipboard

`alacritty-opacity` changes opacity live without rewriting the config.

### Conky

A small desktop overlay (bottom left, always underneath windows). It shows uptime, kernel, battery, CPU, Wi-Fi, public IP, memory, top processes, and a large clock.

### Espanso

Text expansion as you type. Snippets for email, markdown, the date, and clipboard helpers.

- `;mdtb` — clipboard spreadsheet → markdown table
- `;rs` — strip symbols from clipboard text
- `ippa` — expand a copied IP/CIDR into network details
- Scripts also include CSV → HTML table

### Helix

Tokyo Night Moon, relative line numbers, indent guides, inlay hints.

- Python uses Pyright, Ruff, and Black (line length 88)
- `H` / `L` — previous / next buffer
- Ctrl+/ — toggle comments
- Ctrl+R — reload config

### tmux

256-color terminal, mouse on, windows numbered from 1, vi copy mode. Splits open in the current directory. Yank goes to the Wayland clipboard (`wl-copy`).

- `a` — sync input to all panes
- `` ` `` — hide or show the status bar
- `c` — new named window
- `<` / `>` — swap windows
- Plugins: vim-tmux-navigator, Tokyo Night, resurrect/continuum (restore sessions), fzf, yank, logging, notify

TPM is used only if it is already installed at `~/.tmux/plugins/tpm`. The config does not clone it.

### Vim

One file, no plugins. Leader is Space. Same habits as the local Neovim setup.

`<Space>?` opens the map list (`j`/`k` move, `/` search, `q` or Esc close).

**Files**

- `<Space>e` — file explorer
- `<Space>ff` — project files
- `<Space>fo` — recent files
- `<Space>flg` — git-tracked files
- `<Space>sn` — vim/nvim config files

**Buffers**

- `<Space>fb` — pick buffer
- `<Space>bb` — new buffer
- `<Space>bd` / `<Space>bD` / `<Space>bw` — delete / close window / wipe
- Shift+h / Shift+l — previous / next buffer

**Search**

- `<Space>flf` — project grep (`Ctrl+R` for regex)
- `<Space>fs` — grep word under cursor
- `<Space>ft` — filter lines in this buffer
- `<Space>s/` — grep open buffers
- `<Space>/` — substitute word (or visual selection)

**Edit**

- `gcc` / `gc` — comment
- `<Space>F` — format
- `<Space>u` — undo tree
- `<Space>CR` — terminal
- Alt+j / Alt+k — move line
- `jj` — leave insert mode

**Windows**

- Ctrl+h/j/k/l — move (tmux-aware)
- Ctrl+arrows — resize

Empty Vim shows a dashboard. `x` and `dd` delete without yanking.

### Yazi

File manager. Opening a text file runs Neovim and waits until you quit.

### zsh

Interactive shell. Type `?` and Enter for the full manual (`zshrc.1`).

Prompt is two lines: directory, then exit status. After a command, its duration is shown on the right (milliseconds). Empty Enter hides the duration.

**Commands**

- `y` — open yazi, then `cd` to where you leave
- `showpath` — print `PATH` (green if the directory exists)
- `up [N]` — `cd` up N directories
- `cl [DIR]` — `cd` then `ls -la`
- `fe` — pick files with fzf and open them in `$EDITOR`
- `bak FILE` — copy to `FILE.YYYYMMDD-HHMMSS`

**Aliases:** `ls` / `ll` / `l.` with color; `d` for the directory stack.

**Keys:** Emacs layout. Ctrl+Space accepts an autosuggestion. Up/Down search history. Ctrl+T / Alt+C / Ctrl+R are fzf (files, directories, history).

Plugins are cloned into `~/.zsh` on first start: autosuggestions, syntax highlighting, history substring search, fzf-dir-navigator, RTFM. Run `_hoolies_update_zsh_plugins` to update them.

`$EDITOR` is vim. History lives under `~/.local/state/zsh/history`.

### Other files in this repo (not installed by bootstrap)

**clipse** — clipboard history (100 items, no duplicates). Enter pastes, `/` filters, `p` pins, `x` deletes.

**fuzzel** — app launcher. Hack Nerd Font, Nord-ish colors, launches apps in Alacritty.

**glow** — markdown viewer. 80-column wrap, no pager, no mouse.

**functions/pad.sh** — center a line of text in the terminal, with optional decorations.

**xfce4** — XFCE desktop, panel, and keyboard shortcuts for one machine. Do not symlink this blindly onto another box.
