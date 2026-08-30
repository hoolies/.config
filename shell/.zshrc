# Tab completion with colors
zstyle ':completion:*' menu select
if command -v dircolors >/dev/null 2>&1; then
    eval "$(dircolors)"
    zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
fi

# Color for manpages in less
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

# PATH: user tools first; skip missing dirs; drop duplicates
typeset -U path
for _hoolies_dir in /usr/local/go/bin "${HOME}/depot_tools"; do
    [[ -d "${_hoolies_dir}" ]] && path=("${_hoolies_dir}" "${path[@]}")
done
unset _hoolies_dir
rehash

export EDITOR=nvim
export VISUAL="$EDITOR"

# First prompt line is cwd with a trailing slash (~/src/)
setopt PROMPT_SUBST
_hoolies_prompt_cwd=/
_hoolies_prompt_pad=5

_hoolies_set_prompt_cwd() {
    local p
    p="$(print -P '%~')"
    if [[ "$p" == / ]]; then
        _hoolies_prompt_cwd=/
    else
        _hoolies_prompt_cwd="${p%/}/"
    fi
}

# Blank line after command output
_hoolies_prompt_blank() {
    printf '\n'
}

# Keep the two-line prompt off the bottom edge on tall terminals only.
# Short or resized terminals skip the spacer so \e[nA cannot wrap and glitch.
_hoolies_prompt_spacer() {
    emulate -L zsh
    local pad=${_hoolies_prompt_pad}
    (( LINES >= pad + 8 )) || return 0
    printf '\n%.0s' {1..$pad}
    printf '\033[%dA' $((pad + 1))
}

export PS1="
 %F{cyan}\${_hoolies_prompt_cwd}%f
 %F{white}%?  "

export RPROMPT=

set-title() {
    printf '\033]0;%s\007' "$*"
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _hoolies_prompt_blank
add-zsh-hook precmd _hoolies_set_prompt_cwd
add-zsh-hook precmd _hoolies_prompt_spacer

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
        cd) find . -type d | fzf --preview 'tree -C {}' "$@" --border --bind 'ctrl-h:preview-up,ctrl-l:preview-down' ;;
        *) fzf "$@" ;;
    esac
}

y() {
    emulate -L zsh
    setopt LOCAL_TRAPS
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")" || return 1
    trap 'rm -f -- "$tmp"' EXIT
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd <"$tmp" || true
    if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
        builtin cd -- "$cwd"
    fi
}

# Print PATH entries; green if the directory exists, red if not.
path() {
    emulate -L zsh
    local p
    for p in "${(@s/:/)PATH}"; do
        if [[ -d "$p" ]]; then
            printf '\033[32m%s\033[0m\n' "$p"
        else
            printf '\033[31m%s\033[0m\n' "$p"
        fi
    done
}

alias grep='grep --color'
alias l.='ls -d .* --color --group-directories-first'
alias ll='ls --color -lAthr --group-directories-first'
alias ls='ls --color -A --group-directories-first'

bindkey -e

# History
HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=$HISTSIZE
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt BEEP EXTENDED_GLOB NOMATCH
unsetopt AUTO_CD

# Tmux setting for remote servers
# if [ -z "$TMUX" ]; then
#     tmux attach -t devbox || tmux new -s devbox
# fi

_hoolies_source() {
    local f
    for f in "$@"; do
        [[ -f "$f" ]] && source -- "$f"
    done
}

_hoolies_source \
    "${HOME}/.local/bin/env" \
    "${HOME}/.zsh/fzf-dir-navigator/fzf-dir-navigator.zsh" \
    "${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" \
    "${HOME}/.zsh/zsh-history-substring-search/zsh-history-substring-search.zsh" \
    "${HOME}/.zsh/zsh-rtfm/rtfm.plugin.zsh"

if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

# fzf --zsh rebinds Tab to fzf-completion; take it back for RTFM.
if (( $+functions[fzf_rtfm_rebind_tab] )); then
    fzf_rtfm_rebind_tab
fi

if (( $+widgets[autosuggest-accept] )); then
    bindkey '^ ' autosuggest-accept
fi

if (( $+widgets[history-substring-search-up] )); then
    bindkey "${terminfo[kcuu1]:-$'^[[A'}" history-substring-search-up
    bindkey "${terminfo[kcud1]:-$'^[[B'}" history-substring-search-down
    bindkey '^P' history-substring-search-up
    bindkey '^N' history-substring-search-down
fi

# Syntax highlighting must be last so it wraps widgets from fzf / RTFM.
_hoolies_source "${HOME}/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
