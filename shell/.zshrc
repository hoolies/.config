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

# Terminal Prompt
export PS1="
 %F{cyan}%~%f
 %F{white}%?  "

PS1=$'\n\n\n\n\n\e[6A'"$PS1"

export RPROMPT=
set-title() {
    echo -e "\e]0;$*\007"
}

# Patch and Editor
export PATH=$PATH:/usr/local/go/bin

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

# Overwrite zsh git default autocomplete
_git_fzf_complete() {
  local buffer_words=("${(z)LBUFFER}")
  local subcommand="${buffer_words[2]}"

  # Only proceed if the command starts with `git`
  [[ ${buffer_words[1]} != git ]] && zle expand-or-complete && return

  # If no subcommand is typed yet, show list of subcommands
  if [[ -z "$subcommand" ]]; then
    local selected=$(git help -a 2>/dev/null | \
      grep -E "^ +[a-zA-Z]" | awk '{print $1}' | sort -u | \
      fzf --preview 'git help {} 2>/dev/null | less -R -X -K' \
          --preview-window=right:70% --border --bind 'ctrl-h:preview-up,ctrl-l:preview-down')

    if [[ -n "$selected" ]]; then
      LBUFFER+=" $selected"
      zle redisplay
    fi
    return
  fi
  # Subcommand exists, use `man git-subcommand` to extract options
  local man_page="git-$subcommand"
  local options_start="$(($(man $man_page | col -bx | grep -n 'OPTIONS' | cut -d: -f1) + 1))"
  local options_end="$(man $man_page | col -bx | grep -n 'EXAMPLES' | cut -d: -f1)"

  local selected=$(man "$man_page" 2>/dev/null | col -bx | \
    sed -n "$options_start,$((${options_end} - 1))p;${options_end}q" | \
    grep -E '^\s{7}(-{1,2})' | \
    sed -E 's/^\s*//' | sort -u | fzf \
      --preview "man $man_page | col -bx | \
        sed -n "$options_start,$((${options_end} - 1))p;${options_end}q" | \
        rg --multiline '^\s*$(echo {})'"
        --preview-window=right:70% --border --bind 'ctrl-h:preview-up,ctrl-l:preview-down')

    # fzf --preview "man $man_page | col -bx | \
    # sed -n $options_start,$((${options_end} - 1))p;${options_end}q | \
    # less -R" \
    #     --preview-window=right:70% --border --bind 'ctrl-h:preview-up,ctrl-l:preview-down')

  if [[ -n "$selected" ]]; then
    LBUFFER+=" $selected"
    zle redisplay
  fi
}
zle -N _git_fzf_complete

_git_tab_dispatcher() {
  if [[ "$LBUFFER" == git* ]]; then
    _git_fzf_complete
  else
    zle expand-or-complete
  fi
}
zle -N _git_tab_dispatcher
bindkey '^I' _git_tab_dispatcher


# Add an empty line after the output
precmd() { print "" }

# Create Aliases for common tasks
alias ...='cd ../../..'
alias ..='cd ../..'
alias grep='grep --color'
alias l.='ls -d .* --color --group-directories-first'
alias ll='ls --color -lAthr --group-directories-first'
alias ls='ls --color -A --group-directories-first'
alias mac='tail -n +44 /usr/share/wireshark/manuf | fzf'

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
source /usr/share/fzf/completion.zsh
source /usr/share/fzf/key-bindings.zsh
source <(fzf --zsh)
