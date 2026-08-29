# Colors
autoload -U colors && colors

# xozide
eval "$(zoxide init zsh)"

# Add highlight enabled tab completion with colors
zstyle ':completion:*' menu select
eval "$(dircolors)"
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

force_color_prompt=yes

# Exports

# Color for manpages in less makes manpages a little easier to read
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

# Fuzzy
export FZF_DEFAULT_COMMAND='fd --type f'
export FZF_DEFAULT_OPTS='--layout=reverse --inline-info'

export FZF_CTRL_T_OPTS="
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"

export FZF_ALT_C_OPTS="
  --preview 'tree -C {}'"

# Terminal color
export TERM=xterm-256color

# Terminal Prompt — first line is cwd with a trailing slash (~/src/)
setopt PROMPT_SUBST
_hoolies_prompt_cwd=/
_hoolies_set_prompt_cwd() {
    local p
    p="$(print -P '%~')"
    if [[ "$p" == / ]]; then
        _hoolies_prompt_cwd=/
    else
        _hoolies_prompt_cwd="${p%/}/"
    fi
}

export PS1="
 %F{cyan}\${_hoolies_prompt_cwd}%f
 %F{white}%?  "

PS1=$'\n\n\n\n\n\e[6A'"$PS1"

export RPROMPT=
set-title() {
    printf '\033]0;%s\007' "$*"
}

# Patch and Editor
export PATH=$PATH:/usr/local/go/bin
export PATH="${HOME}/depot_tools:$PATH"
export EDITOR=nvim

# Functions
# Fuzzy
_fzf_compgen_path() {
    rg --files --glob "!.git" . "$1" | fzf --preview 'tree -C {}' "$@"
}

_fzf_compgen_dir() {
   fd --type d --hidden --follow --exclude ".git" . "$1" | fzf --preview 'tree -C {}' "$@"
}

_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)         find . -type d | fzf --preview 'tree -C {}' "$@" --border --bind 'ctrl-h:preview-up,ctrl-l:preview-down';;
    *)          fzf "$@" ;;
  esac
}
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# Empty line after command output; refresh the path on the first prompt line.
precmd() {
    print ""
    _hoolies_set_prompt_cwd
}

# Create Aliases for common tasks
alias grep='grep --color'
alias l.='ls -d .* --color --group-directories-first'
alias ll='ls --color -lAthr --group-directories-first'
alias ls='ls --color -A --group-directories-first'
alias mac='tail -n +44 /usr/share/wireshark/manuf | fzf'
alias path='echo $PATH | tr ":" "\n" | xargs -I {} sh -c '\''if [ -d "{}" ]; then printf "\033[32m%s\033[0m\n" "{}"; else printf "\033[31m%s\033[0m\n" "{}"; fi'\'''

# Emacs support
bindkey -e

# Accepts suggestions with ctrl space
bindkey '^ ' autosuggest-accept

# History Settings
HISTFILE=~/.histfile
HISTFILESIZE=10000
HISTSIZE=10000
SAVEHIST=$HISTSIZE


setopt APPEND_HISTORY
setopt BEEP EXTENDED_GLOB NOMATCH
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
unsetopt AUTO_CD


# Checks if syntax highlighting is install
if [ ! -d "$HOME/.zsh/zsh-syntax-highlighting" ]; then
  echo "Installing zsh syntax highlighting"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.zsh/zsh-syntax-highlighting
fi

# Check if zsh autosuggestions is installed
if [ ! -d "$HOME/.zsh/zsh-autosuggestions" ]; then
  echo "Installing zsh autosuggestions"
  git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.zsh/zsh-autosuggestions
fi

# check if zsh history susbtring search
if [ ! -d "$HOME/.zsh/zsh-history-substring-search" ]; then
  echo "Installing zsh history substring search."
  git clone https://github.com/zsh-users/zsh-history-substring-search.git $HOME/.zsh/zsh-history-substring-search
fi

# check if fzf dir navigator exists exists
if [ ! -d "$HOME/.zsh/fzf-dir-navigator" ]; then
  echo "Installing fzf dir navigator."
  git clone https://github.com/KulkarniKaustubh/fzf-dir-navigator.git $HOME/.zsh/fzf-dir-navigator
fi


# check if fzf dir navigator exists exists
if [ ! -d "$HOME/.zsh/zsh-rtfm" ]; then
  echo "Installing fzf RTFM."
  git clone https://github.com/hoolies/RTFM.git $HOME/.zsh/zsh-rtfm
fi

# Tmux setting for remote servers
# if [ -z "$TMUX" ]; then
#     tmux attach -t devbox || tmux new -s devbox
# fi


# Sourcing
source $HOME/.local/bin/env
source $HOME/.zsh/fzf-dir-navigator/fzf-dir-navigator.zsh
source $HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOME/.zsh/zsh-history-substring-search/zsh-history-substring-search.zsh
source $HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $HOME/.zsh/zsh-rtfm/rtfm.plugin.zsh
source /usr/share/fzf/completion.zsh
source /usr/share/fzf/key-bindings.zsh
source <(fzf --zsh)
# fzf --zsh rebinds Tab to fzf-completion; take it back for RTFM.
fzf_rtfm_rebind_tab
